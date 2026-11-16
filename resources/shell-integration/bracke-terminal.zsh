# Bracke Terminal shell integration for interactive Zsh.
[[ -o interactive ]] || return 0
[[ -n ${BRACKE_TERMINAL_SHELL_INTEGRATION_LOADED-} ]] && return 0
typeset -g BRACKE_TERMINAL_SHELL_INTEGRATION_LOADED=1
autoload -Uz add-zsh-hook

__bracke_osc() {
    printf '\033]%s\033\\' "$1"
}

__bracke_precmd() {
    local command_status=$?
    if (( ${__bracke_command_started:-0} )); then
        __bracke_osc "133;D;$command_status"
        typeset -g __bracke_command_started=0
    fi
    __bracke_osc "7;file://${HOST:-}${(q)PWD}"
    __bracke_osc '133;A'
}

__bracke_preexec() {
    __bracke_osc '133;B'
    __bracke_osc '133;C'
    typeset -g __bracke_command_started=1
}

add-zsh-hook precmd __bracke_precmd
add-zsh-hook preexec __bracke_preexec
