#!/usr/bin/env zsh

# Set FZF options before loading fzf plugin
export FZF_DEFAULT_COMMAND='rg --files'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
# adds previews to completion
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

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

# Custom fuzzy completion for "git" command
_fzf_complete_git() {
  local cmd=$1
  case "${${(z)cmd}[2]}" in
    # Function usage from: https://github.com/junegunn/fzf-git.sh
    add|rm|reset|restore) LBUFFER="${cmd}$(_fzf_git_files | __fzf_git_join)";;
    rebase|checkout|switch) LBUFFER="${cmd}$(_fzf_git_branches)";;
    *) _fzf_path_completion "$prefix" "$@";;
  esac
}

_fzf_complete_gco() {
  shift
  _fzf_complete_git "git checkout $@"
}

_extract_namespace_from_args() {
  local namespace namespace_args_index
  namespace="default"

  # Get the index of the --namespace or -n argument if provided
  namespace_args_index=$(_args_index namespace "$@" || _args_index -n "$@")

  if [[ -n "$namespace_args_index" ]]; then
    namespace="${args[$namespace_args_index + 1]}"
  fi

  echo $namespace
}

_helper_fzf_get_pods() {
  local namespace=${1:?}
  kubectl --namespace="${namespace}" get pods -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n'
}

_helper_fzf_get_services() {
  local namespace=${1:?}
  kubectl --namespace="${namespace}" get services -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n'
}

_helper_fzf_complete_pods() {
  local namespace=${1:?}
  shift

  # fuzzy complete pod names for logs command
  _fzf_complete --prompt="pod> " -- "$@" < <(_helper_fzf_get_pods "${namespace}")
}

_helper_fzf_complete_namespaces() {
  _fzf_complete --prompt="namespace> " -- "$@" < <(
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n'
  )
}

_helper_fzf_complete_port_forward() {
  local namespace=${1:?}
  shift

  local pods services

  services=$(_helper_fzf_get_services "${namespace}" | awk '{print "service/" $0}')
  pods=$(_helper_fzf_get_pods "${namespace}" | awk '{print "pod/" $0}')

  # fuzzy complete pods and service name for port-forward command
  _fzf_complete --prompt="service and pods> " -- "$@" < <(
    echo "${services}"
    echo "${pods}"
  )
}

_helper_fzf_complete_kubectl() {
  local args namespace last_arg
  args=(${(z)1})
  last_arg="${args[-1]}"
  namespace=$(_extract_namespace_from_args ${args[@]})

  if [[ "${last_arg}" == "--namespace" || "${last_arg}" == "-n" ]]; then # Check if the previous arg was --namespace or -n
    _helper_fzf_complete_namespaces "$@"
  elif _args_contains logs "${args[@]}"; then # check if "logs" is one of the previous args
    _helper_fzf_complete_pods $namespace "$@"
  elif _args_contains port-forward "${args[@]}"; then # check if "logs" is one of the previous args
    _helper_fzf_complete_port_forward $namespace "$@"
  elif _args_contains pod "${args[@]}"; then # check if "pod" is one of the previous args
    if _args_contains get "${args[@]}" || _args_contains describe "${args[@]}" || _args_contains delete "${args[@]}" ; then # check if "get/describe" is one of the previous args
      _helper_fzf_complete_pods $namespace "$@"
    fi
  elif [[ ${args[(ie)create]} -le ${#args} && ("${last_arg}" == "-f" || "${last_arg}" == "--filename") ]]; then # if create and -f/--filename
    _fzf_path_completion "$prefix" "$@"
  fi
}

# shellcheck disable=all
{
  for cmd in kubectl k kubecolor; do
    _fzf_complete_${cmd}() {
      _helper_fzf_complete_kubectl "$@"
    }
  done
}

# fzf based cd without args
cd() {
    if [[ "$#" != 0 ]]; then
        builtin cd "$@";
        return
    fi
    while true; do
        local lsd=$(echo ".." && ls -p | grep '/$' | sed 's;/$;;')
        local dir="$(printf '%s\n' "${lsd[@]}" |
            fzf --reverse --preview '
                __cd_nxt="$(echo {})";
                __cd_path="$(echo $(pwd)/${__cd_nxt} | sed "s;//;/;")";
                echo $__cd_path;
                echo;
                ls -p --color=always "${__cd_path}";
        ')"
        [[ ${#dir} != 0 ]] || return 0
        builtin cd "$dir" &> /dev/null
    done
}

j() {
  cd "$(jump top | fzf --reverse)"
}
