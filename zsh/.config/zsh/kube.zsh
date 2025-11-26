#!/usr/bin/env zsh

echoerr() { echo "$@" 1>&2; }

kssm() {
  local node=${1:?Usage: kssm <k8s-node_name>}
  shift
  local INSTANCE_ID=$(kubectl get nodes "${node}" -o yaml | yq '.spec.providerID | split("/") | .[-1]')
  if [[ -z "$INSTANCE_ID" ]]; then
    echoerr "Unable to get instance ID for $node"
    return 1
  fi
  local AWS_REGION=$(kubectl get nodes "${node}" -o json | jq '.metadata.labels["topology.kubernetes.io/region"]' -r)
  if [[ -z "$AWS_REGION" ]]; then
    echoerr "Unable to get region for $node"
    return 1
  fi
  local CMD=(aws ssm start-session --target "$INSTANCE_ID" $@)
  echoerr "${CMD[@]}"
  # subshell to scope export
  (
    export AWS_REGION
    "${CMD[@]}"
  )
}

kssm-exec() {
  local node=${1:?Usage: kssm-exec <k8s-node_name> <args>}
  shift
  PARAMETERS="$(jq -rnc '{command: $ARGS.positional}' --args "$@")"
  CMD=(kssm "${node}" --document-name AWS-StartInteractiveCommand --parameters "${PARAMETERS}")
  echoerr "${CMD[@]}"
  "${CMD[@]}"
}

kssm-ssh-copy-id() {
  local node=${1:?Usage: kssm-exec <k8s-node_name> <key>}
  local key_file=${2:-"${HOME}/.ssh/id_rsa.pub"}

  KEY="$(cat "${key_file}")"
  kssm-exec "${node}" "sudo [ ! -f /home/ec2-user/.ssh/authorized_keys ] || ! sudo grep -q '$KEY' /home/ec2-user/.ssh/authorized_keys && echo '$KEY' | sudo tee -a /home/ec2-user/.ssh/authorized_keys && echo key added || echo key already exists"
}

kssm-ssh() {
  local node=${1:?Usage: kssm-exec <k8s-node_name>}
  shift
  local INSTANCE_ID=$(kubectl get nodes "${node}" -o yaml | yq '.spec.providerID | split("/") | .[-1]')
  if [[ -z "$INSTANCE_ID" ]]; then
    echoerr "Unable to get instance ID for $node"
    return 1
  fi
  local AWS_REGION=$(kubectl get nodes "${node}" -o json | jq '.metadata.labels["topology.kubernetes.io/region"]' -r)
  if [[ -z "$AWS_REGION" ]]; then
    echoerr "Unable to get region for $node"
    return 1
  fi
  local CMD=(ssh "ec2-user@$INSTANCE_ID" "$@")
  echoerr "${CMD[@]}"
  # subshell to scope export
  (
    export AWS_REGION
    "${CMD[@]}"
  )
}

kube-get-pod-resources-json() {
  kubectl get pods -o json "$@" |
    jq -r '
      (
        .items[]
        | {
          namespace: .metadata.namespace,
                pod: .metadata.name,
                resources: (
                  .spec.containers[].resources
                  | {
                    memory_request: .requests.memory,
                    cpu_request: .requests.cpu,
                    memory_limit: .limits.memory
                  }
              )
            }
      )
      '
}

kube-get-pod-resources() {
  kube-get-pod-resources-json $@ |
    jq -n -r '
      ["NAMESPACE", "POD", "MEMORY_REQUEST", "CPU_REQUEST", "MEMORY_LIMIT"],
      (
        inputs
        | [.namespace, .pod, (.resources | to_entries | map(.value // "unset"))[]]
      )
      | @tsv
      ' |
    column -t -s $'\t'
}

kube-get-pod-resources-missing() {
  kube-get-pod-resources-json $@ |
    jq -n -r '
      ["NAMESPACE", "POD", "MEMORY_REQUEST", "CPU_REQUEST", "MEMORY_LIMIT"],
      (
        inputs
        | select(.resources | to_entries | select(any(.value==null)))
        | [.namespace, .pod, (.resources | to_entries | map(.value // "unset"))[]]
      )
      | @tsv
      ' |
    column -t -s $'\t'
}
_args_index() {
  local needle=$1
  shift
  local index=0
  for arg in "$@"; do
    (( index++ ))
    if [[ "$arg" == "$needle"* ]]; then
      echo $index
      return 0
    fi
  done
  return 1
}

_args_contains() {
  local needle=$1
  shift
  # Ignore the index output
  _args_index "$needle" "$@" >/dev/null
}


__extract_kubectl_namespace_from_args() {
  local namespace namespace_args_index
  namespace="default"

  # Get the index of the --namespace or -n argument if provided
  namespace_args_index=$(_args_index namespace "$@" || _args_index -n "$@")

  if [[ -n "$namespace_args_index" ]]; then
    namespace="${args[$namespace_args_index + 1]}"
  fi

  echo $namespace
}

__infer_kubectl_pod_from_args() {
  local pod prev_arg
  # Try to infer the pod name from args
  # Skip the first argument since it's the command itself, and remember zsh
  # indexes starting at 1
  for ((i = 2; i <= $#; i++)); do
    arg=${@[i]}
    # Store the previous argument unless it's the first iteration
    if [[ $i -gt 0 ]]; then
      prev_arg="${@[i-1]}"
    else
      prev_arg=""
    fi
    # Find the first non flag, non-logs argument
    if [[ "$arg" == -* || "$arg" == "logs"  ]]; then
      continue
    fi
    # If the previous argument was -n/--namespace, skip this one, as it's the naemspace value
    if [[ "$prev_arg" == "-n" || "$prev_arg" == "--namespace" ]]; then
      continue
    fi
    # What remains is hopefully a pod name
    pod="$arg"
    echo $pod
    return 0
  done
  return 1
}

__kubectl_get_pods() {
  local namespace=${1:?}
  kubectl --namespace="${namespace}" get pods -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n'
}

__kubectl_get_services() {
  local namespace=${1:?}
  kubectl --namespace="${namespace}" get services -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n'
}

__helper_fzf_complete_kubectl_pods() {
  local namespace=${1:?}
  shift

  # fuzzy complete pod names
  _fzf_complete --prompt="pod> " -- "$@" < <(__kubectl_get_pods "${namespace}")
}

__helper_fzf_complete_kubectl_pod_containers() {
  local namespace=${1:?}
  local pod=${2:?}
  shift 2

  # fuzzy complete container names for a given pod
  _fzf_complete --prompt="container($pod)> " -- "$@" < <(
    kubectl --namespace="${namespace}" get pod "${pod}" -o jsonpath='{.spec.containers[*].name}' | tr ' ' '\n'
  )
}

__helper_fzf_complete_kubectl_namespaces() {
  _fzf_complete --prompt="namespace> " -- "$@" < <(
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n'
  )
}

__helper_fzf_complete_kubectl_port_forward_target() {
  local namespace=${1:?}
  shift

  local pods services

  services=$(__kubectl_get_services "${namespace}" | awk '{print "service/" $0}')
  pods=$(__kubectl_get_pods "${namespace}" | awk '{print "pod/" $0}')

  # fuzzy complete pods and service name for port-forward command
  _fzf_complete --prompt="service and pods> " -- "$@" < <(
    echo "${services}"
    echo "${pods}"
  )
}

__helper_fzf_complete_kubectl_resource_types() {
  _fzf_complete --prompt="resource type> " -- "$@" < <(
    kubectl api-resources --no-headers -o name
  )
}

__helper_fzf_complete_workload() {
  local namespace=${1:-} # namespace is optional
  local namespace_args=()
  if [[ -n "$namespace" ]]; then
    namespace_args=(--namespace="${namespace}")
    shift
  fi

  _fzf_complete --prompt="workload> " -- "$@" < <(
    kubectl "${namespace_args[@]}" get deployments,statefulsets,daemonsets,replicasets -o jsonpath='{range .items[*]}{.kind}/{.metadata.name}{"\n"}{end}'
  )
}

__helper_fzf_complete_workload_by_type() {
  local namespace=${1:?}
  local workload_type=${2:?}
  shift 2

  _fzf_complete --prompt="workload(${workload_type})> " -- "$@"  < <(
    kubectl --namespace="${namespace}" get "${workload_type}" -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | awk -v kind="$workload_type" '{print kind "/" $0}'
  )
}

__kube_workload_type_long_names=(pod deployment statefulset daemonset replicaset)
__kube_workload_type_plural_names=(pods deployments statefulsets daemonsets replicasets)
__kube_workload_type_short_names=(po deploy sts ds rs)
# Long names + short names + plurals
__kube_workload_type_all_names=(${__kube_workload_type_long_names[@]} ${__kube_workload_type_plural_names[@]} ${__kube_workload_type_short_names[@]})

__helper_fzf_complete_kubectl() {
  local args namespace last_arg
  args=(${(z)1})
  last_arg="${args[-1]}"
  namespace=$(__extract_kubectl_namespace_from_args ${args[@]})

  if [[ "${last_arg}" == "--namespace" || "${last_arg}" == "-n" ]]; then
    __helper_fzf_complete_kubectl_namespaces "$@"
  elif [[ "${last_arg}" == "--context" ]]; then
    _fzf_complete --prompt="context> " -- "$@" < <(
      kubectl config get-contexts -o name
    )
  elif _args_contains logs "${args[@]}"; then
    if [[ "${last_arg}" == "-c" || "${last_arg}" == "--container" ]]; then
      local pod
      pod=$(__infer_kubectl_pod_from_args "${args[@]}")
      if [[ -z "$pod" ]]; then
        echoerr "Unable to infer pod name for container completion"
        return 1
      fi

      __helper_fzf_complete_kubectl_pod_containers "$namespace" "$pod" "$@"
      return
    fi
    # Check for workload
    for workload_type in "${__kube_workload_type_all_names[@]}"; do
      # Since the argument we're checking for has not been completed yet, we need to
      # check $prefix instead. We also append / the comparison because that's
      # the separator when querying logs for a non-pod workload
      if [[ "$prefix" == "${workload_type}/"* ]]; then
        __helper_fzf_complete_workload_by_type "$namespace" "$workload_type" "$@"
        return
      fi
    done

    __helper_fzf_complete_kubectl_pods $namespace "$@"
  elif _args_contains exec "${args[@]}"; then
    __helper_fzf_complete_kubectl_pods $namespace "$@"
  elif _args_contains port-forward "${args[@]}"; then
    __helper_fzf_complete_kubectl_port_forward_target $namespace "$@"
  elif _args_contains get "${args[@]}" || _args_contains describe "${args[@]}" || _args_contains delete "${args[@]}" ; then
    if _args_contains pod "${args[@]}"; then
      __helper_fzf_complete_kubectl_pods $namespace "$@"
    fi
    # TODO detect if no resource types are provided
    __helper_fzf_complete_kubectl_resource_types "$@"
  elif _args_contains explain "${args[@]}"; then
    __helper_fzf_complete_kubectl_resource_types "$@"
  elif [[ ${args[(ie)create]} -le ${#args} && ("${last_arg}" == "-f" || "${last_arg}" == "--filename") ]]; then # if create and -f/--filename
    _fzf_path_completion "$prefix" "$@"
  fi
}

# shellcheck disable=all
{
  # Define fzf completion functions for kubectl, k, and kubecolor
  for cmd in kubectl k kubecolor; do
    _fzf_complete_${cmd}() {
      __helper_fzf_complete_kubectl "$@"
    }
  done
}

_fzf_complete_stern() {
  local args namespace last_arg
  args=(${(z)1})
  last_arg="${args[-1]}"
  namespace=$(__extract_kubectl_namespace_from_args ${args[@]})

  if [[ "${last_arg}" == "--namespace" || "${last_arg}" == "-n" ]]; then
    __helper_fzf_complete_kubectl_namespaces "$@"
  elif [[ "${last_arg}" == "--context" ]]; then
    _fzf_complete --prompt="context> " -- "$@" < <(
      kubectl config get-contexts -o name
    )
  fi
}
