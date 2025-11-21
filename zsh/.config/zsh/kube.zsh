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
