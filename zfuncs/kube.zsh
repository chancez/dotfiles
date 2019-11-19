kc() {
    local config_dir="$HOME/.kube/configs"
    if [ -n "$1" ]; then
        export KUBECONFIG="${config_dir}/${1}.yaml"
        return
    fi

    local config_dir="$HOME/.kube/configs"
    local configs="$(find $config_dir -name '*.yaml')"
    # get just the name of the file without the base path or the yaml extension
    local clean_configs=$(echo "$configs" | xargs -I{} basename {} | sed 's/\.yaml//')
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
