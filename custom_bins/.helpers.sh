#!/usr/bin/env bash

echoerr() { echo "$@" 1>&2; }

_internal_kubectl() {
    command kubectl --namespace="${KUBE_NAMESPACE:-default}" "$@"
}

_internal_kpods() {
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
                echoerr "Error: Unsupported flag $key" >&2
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
        local POD_CMD=(_internal_kubectl get pods --no-headers)
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
            echoerr "Must select a pod or specify one via flags"
            return 1
        fi

        if [ "$PRINT_CONTAINER" == "true" ]; then
            local CONTAINER_CMD=(_internal_kubectl get pod "$POD" -o json)
            if [ -n "$NAMESPACE" ]; then
                CONTAINER_CMD+=(--namespace "$NAMESPACE")
            fi

            local CONTAINERS="$(${CONTAINER_CMD[@]} | jq -r '.spec.containers[].name')"
            if [ -z "$CONTAINER" ]; then
                CONTAINER="$(echo "$CONTAINERS" | fzf --select-1)"
            elif ! echo $CONTAINERS | grep -q "^${CONTAINER}$"; then
                echoerr "Invalid container $CONTAINER, not in container list: ${$(echo $CONTAINERS | paste -sd ', ' -)}"
                return 1
            fi
            if [ "$CONTAINER" == "" ]; then
                echoerr "Must specify container for pod $POD. Choices: ${$(echo $CONTAINERS | paste -sd ', ' -)}"
                return 1
            fi

            echo "$CONTAINER"
        else
            echo "$POD"
        fi
    else
        # handle args
        echoerr "Do not currently support args"
        exit 1
    fi
}

_internal_kexec() {
    local POD
    local CONTAINER
    local NAMESPACE
    local SELECTOR
    local TTY
    local INTERACTIVE
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
            -it|-ti)
                INTERACTIVE=true
                TTY=true
                shift 1
                ;;
            -i)
                INTERACTIVE=true
                shift 1
                ;;
            -t)
                TTY=true
                shift 1
                ;;
            --) # end argument parsing and pass the rest as arguments to the logs command
                shift
                PARAMS+=("$@")
                break
                ;;
            -*|--*=) # unsupported flags
                echoerr "Error: Unsupported flag $key" >&2
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
        POD="$(_internal_kpods -n "$NAMESPACE" -l "$SELECTOR")"
        local RET=$?
        if [ $RET -ne 0 ]; then
            echoerr "$POD"
            return $RET
        fi
    fi

    if [ -z "$POD" ]; then
        echoerr "Must specify pod!"
        return 1
    fi

    if [ -z "$CONTAINER" ]; then
        CONTAINER="$(_internal_kpods -p "$POD" -n "$NAMESPACE" -l "$SELECTOR" --print-container)"
        local RET=$?
        if [ $RET -ne 0 ]; then
            echoerr "$CONTAINER"
            return $RET
        fi
    fi

    if [ -z "$CONTAINER" ]; then
        echoerr "Must specify container!"
        return 1
    fi

    local COLUMNS=$(tput cols)
    local LINES=$(tput lines)
    local TERM=xterm
    local EXEC_CMD=(_internal_kubectl exec "$POD" -c "$CONTAINER")

    if [ "$INTERACTIVE" == "true" ]; then
        EXEC_CMD+=(-i)
    fi
    if [ "$TTY" == "true" ]; then
        EXEC_CMD+=(-t)
    fi

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
    echoerr "${EXEC_CMD[@]}"
    "${EXEC_CMD[@]}"
}

function _internal_klogs() {
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
                echoerr "Error: Unsupported flag $key" >&2
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
        POD="$(_internal_kpods -n "$NAMESPACE" -l "$SELECTOR")"
        local RET=$?
        if [ $RET -ne 0 ]; then
            echoerr "$POD"
            return $RET
        fi
    fi

    if [ -z "$POD" ]; then
        echoerr "Must specify pod!"
        return 1
    fi

    if [ -z "$CONTAINER" ]; then
        CONTAINER="$(_internal_kpods -p "$POD" -n "$NAMESPACE" -l "$SELECTOR" --print-container)"
        local RET=$?
        if [ $RET -ne 0 ]; then
            echoerr "$CONTAINER"
            return $RET
        fi
    fi

    if [ -z "$CONTAINER" ]; then
        echoerr "Must specify container!"
        return 1
    fi

    local LOGS_CMD=(_internal_kubectl logs "$POD" -c "$CONTAINER")
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
    echoerr "${LOGS_CMD[@]}"
    "${LOGS_CMD[@]}"
}
