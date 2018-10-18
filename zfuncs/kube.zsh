k() {
    command kubectl --namespace="${KUBE_NAMESPACE:-default}" $@
}

alias kgp='k get pods'
alias kgs='k get svc'
alias kgn='k get ns'

kubectl() {
    k "$@"
}

kn() {
    kns "$@"
}

kc() {
    local config_dir="$HOME/.kube/configs"
    if [ -n "$1" ]; then
        export KUBECONFIG="${config_dir}/${1}.yaml"
        return
    fi

    local config_dir="$HOME/.kube/configs"
    local configs="$(find $config_dir -name '*.yaml')"
    # get just the name of the file without the base path or the yaml extension
    local clean_configs=$(echo "$configs" | xargs basename | sed 's/\.yaml//')
    # if our KUBECONFIG is already set, then check if it's set to a kubeconfig
    # in our kubeconfig dir
    if [ -n "$KUBECONFIG" ]; then
        local current="$KUBECONFIG"
        local current_clean="$(basename $current | sed 's/\.yaml//')"
        # if the current kubeconfig is one of the available options, bolden it
        # for selection
        if echo $configs | grep -q "$current"; then
            clean_configs=$(echo "$clean_configs" | sed "s/$current_clean/$(tput bold)$current_clean$(tput sgr0)/")
        fi
    fi
    local fzf_cmd=(fzf --select-1 --ansi)
    if [ -z "$DISABLE_KC_PREVIEW" ]; then
        local jq_expr='del(.users,.clusters[].cluster["certificate-authority-data"])'
        fzf_cmd+=(--preview 'faq -f yaml '"'$jq_expr'"' '"$config_dir"'/{}.yaml | head -$LINES')
    fi
    export KUBECONFIG="$(echo "$clean_configs" | "${fzf_cmd[@]}" | xargs printf "$config_dir/%s.yaml")"
}

kns() {
    if [ -n "$1" ]; then
        export KUBE_NAMESPACE="$1"
        return
    fi
    local ns="${KUBE_NAMESPACE:-default}"
    local namespaces="$(command kubectl get ns -o=custom-columns=:.metadata.name --no-headers)"
    local fzf_cmd=(fzf --select-1 --ansi)
    if [ -z "$DISABLE_KNS_PREVIEW" ]; then
        fzf_cmd+=(--preview 'command kubectl get pods --namespace {} | head -$LINES')
    fi
    export KUBE_NAMESPACE="$(echo "$namespaces" | sed "s/$ns/$(tput bold)$ns$(tput sgr0)/" | "${fzf_cmd[@]}" )"
}

kcns() {
    if [ -n "$1" ]; then
        kc "$1"
    else
        kc
    fi
    if [ -n "$2" ]; then
        kns "$2"
    else
        kns
    fi
}

function kpod() {
    local POD
    local CONTAINER
    local PRINT_CONTAINER=false
    local NAMESPACE
    local SELECTOR
    local PARAMS=()

    while [ $# -gt 0 ]; do
        local key="$1"
        local value="$2"
        case "$1" in
            -p|--pod)
                POD=$value
                shift 2
                ;;
            -c|--container)
                CONTAINER=$value
                shift 2
                ;;
            --print-container)
                PRINT_CONTAINER=true
                shift 1
                ;;
            -n|--namespace)
                NAMESPACE=$value
                shift 2
                ;;
            -l|--selector)
                SELECTOR=$value
                shift 2
                ;;
            --) # end argument parsing and pass the rest as arguments to the logs command
                shift
                PARAMS+=($@)
                break
                ;;
            -*|--*=) # unsupported flags
                echo "Error: Unsupported flag $key" >&2
                return 1
                ;;
            *) # preserve positional arguments
                PARAMS+=("$key")
                shift
                ;;
        esac
    done
    # set positional arguments in their proper place
    set -- "${PARAMS[@]}"


    if [ "$#" -eq 0 ]; then
        local POD_CMD=(kubectl get pods --no-headers)
        if [ -n "$NAMESPACE" ]; then
            POD_CMD+=(--namespace "$NAMESPACE")
        fi
        if [ -n "$SELECTOR" ]; then
            POD_CMD+=(--selector "$SELECTOR")
        fi

        # As long as the pod flag isn't passed in, we try to determine the pod
        if [ -z "$POD" ]; then
            POD=$("${POD_CMD[@]}" | fzf --select-1 | awk '{print $1}')
        fi

        if [ "$POD" == "" ]; then
            echo "Must select a pod or specify one via flags"
            return 1
        fi

        if [ "$PRINT_CONTAINER" == "true" ]; then
            local CONTAINER_CMD=(kubectl get pod "$POD" -o json)
            if [ -n "$NAMESPACE" ]; then
                CONTAINER_CMD+=(--namespace "$NAMESPACE")
            fi

            local CONTAINERS="$(${CONTAINER_CMD[@]} | jq -r '.spec.containers[].name')"
            if [ -z "$CONTAINER" ]; then
                CONTAINER="$(echo "$CONTAINERS" | fzf --select-1)"
            elif ! echo $CONTAINERS | grep -q "^${CONTAINER}$"; then
                echo "Invalid container $CONTAINER, not in container list: ${$(echo $CONTAINERS | paste -sd ', ' -)}"
                return 1
            fi
            if [ "$CONTAINER" == "" ]; then
                echo "Must specify container for pod $POD. Choices: ${$(echo $CONTAINERS | paste -sd ', ' -)}"
                return 1
            fi

            echo "$CONTAINER"
        else
            echo "$POD"
        fi
    else
        # handle args
    fi
}

function kexec() {
    local POD
    local CONTAINER
    local NAMESPACE
    local SELECTOR
    local PARAMS=()

    while [ $# -gt 0 ]; do
        local key="$1"
        local value="$2"
        case "$1" in
            -p|--pod)
                POD=$value
                shift 2
                ;;
            -c|--container)
                CONTAINER=$value
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE=$value
                shift 2
                ;;
            -l|--selector)
                SELECTOR=$value
                shift 2
                ;;
            --) # end argument parsing and pass the rest as arguments to the logs command
                shift
                PARAMS+=($@)
                break
                ;;
            -*|--*=) # unsupported flags
                echo "Error: Unsupported flag $key" >&2
                return 1
                ;;
            *) # preserve positional arguments
                PARAMS+=("$key")
                shift
                ;;
        esac
    done
    # set positional arguments in their proper place
    set -- "${PARAMS[@]}"

    if [ -z "$POD" ]; then
        POD="$(kpod -n "$NAMESPACE" -l "$SELECTOR")"
        local RET=$?
        if [ $RET -ne 0 ]; then
            echo "$POD"
            return $RET
        fi
    fi

    if [ -z "$POD" ]; then
        echo "Must specify pod!"
        return 1
    fi

    if [ -z "$CONTAINER" ]; then
        CONTAINER="$(kpod -p "$POD" -n "$NAMESPACE" -l "$SELECTOR" --print-container)"
        local RET=$?
        if [ $RET -ne 0 ]; then
            echo "$CONTAINER"
            return $RET
        fi
    fi

    if [ -z "$CONTAINER" ]; then
        echo "Must specify container!"
        return 1
    fi

    local COLUMNS=$(tput cols)
    local LINES=$(tput lines)
    local TERM=xterm
    local EXEC_CMD=(kubectl exec -i -t "$POD" -c "$CONTAINER")
    if [ -n "$NAMESPACE" ]; then
        EXEC_CMD+=(--namespace "$NAMESPACE")
    fi

    # if arguments are passed, then invoke that command instead of a shell
    if [ $# -gt 0 ]; then
        EXEC_CMD+=(-- "$@")
    else
        # test if bash exists, if it does, we'll use bash, otherwise use sh
        "${EXEC_CMD[@]}" -- test -e /bin/bash 2> /dev/null
        if [ $? -eq 0 ] ; then
            local KUBE_SHELL=${KUBE_SHELL:-/bin/bash}
        else
            local KUBE_SHELL=${KUBE_SHELL:-/bin/sh}
        fi
        # execute our shell
        EXEC_CMD+=(-- "$KUBE_SHELL" -il)
    fi
    echo "${EXEC_CMD[@]}"
    "${EXEC_CMD[@]}"
}

function klogs() {
    local POD
    local CONTAINER
    local NAMESPACE
    local SELECTOR
    local FOLLOW=false
    local PREVIOUS=false
    local SINCE
    local PARAMS=()

    while [ $# -gt 0 ]; do
        local key="$1"
        local value="$2"
        case "$1" in
            --pod)
                POD=$value
                shift 2
                ;;
            -c|--container)
                CONTAINER=$value
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE=$value
                shift 2
                ;;
            -l|--selector)
                SELECTOR=$value
                shift 2
                ;;
            -f|--follow)
                FOLLOW=true
                shift 1
                ;;
            -p|--previous)
                PREVIOUS=true
                shift 1
                ;;
            --since)
                SINCE=$value
                shift 2
                ;;
            --) # end argument parsing and pass the rest as arguments to the logs command
                shift
                PARAMS+=($@)
                break
                ;;
            -*|--*=) # unsupported flags
                echo "Error: Unsupported flag $key" >&2
                return 1
                ;;
            *) # preserve positional arguments
                PARAMS+=("$key")
                shift
                ;;
        esac
    done
    # set positional arguments in their proper place
    set -- "${PARAMS[@]}"

    if [ -z "$POD" ]; then
        POD="$(kpod -n "$NAMESPACE" -l "$SELECTOR")"
        local RET=$?
        if [ $RET -ne 0 ]; then
            echo "$POD"
            return $RET
        fi
    fi

    if [ -z "$POD" ]; then
        echo "Must specify pod!"
        return 1
    fi

    if [ -z "$CONTAINER" ]; then
        CONTAINER="$(kpod -p "$POD" -n "$NAMESPACE" -l "$SELECTOR" --print-container)"
        local RET=$?
        if [ $RET -ne 0 ]; then
            echo "$CONTAINER"
            return $RET
        fi
    fi

    if [ -z "$CONTAINER" ]; then
        echo "Must specify container!"
        return 1
    fi

    local LOGS_CMD=(kubectl logs "$POD" -c "$CONTAINER")
    if [ -n "$NAMESPACE" ]; then
        LOGS_CMD+=(--namespace "$NAMESPACE")
    fi
    if [ -n "$SINCE" ]; then
        LOGS_CMD+=(--since "$SINCE")
    fi
    if [ "$FOLLOW" == "true" ]; then
        LOGS_CMD+=(-f)
    fi
    if [ "$PREVIOUS" == "true" ]; then
        LOGS_CMD+=(-p)
    fi

    LOGS_CMD+=("$@")
    echo "${LOGS_CMD[@]}"
    "${LOGS_CMD[@]}"
}
