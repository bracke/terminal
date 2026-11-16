# Bracke Terminal shell integration for interactive Bash.
[[ $- == *i* ]] || return 0
[[ -n ${BRACKE_TERMINAL_SHELL_INTEGRATION_LOADED-} ]] && return 0
BRACKE_TERMINAL_SHELL_INTEGRATION_LOADED=1

__bracke_osc() {
    printf '\033]%s\033\\' "$1"
}

__bracke_urlencode_path() {
    local value=$PWD out= ch hex i
    LC_ALL=C
    for ((i = 0; i < ${#value}; i++)); do
        ch=${value:i:1}
        case $ch in
            [a-zA-Z0-9/_.~-]) out+=$ch ;;
            *) printf -v hex '%%%02X' "'$ch"; out+=$hex ;;
        esac
    done
    printf '%s' "$out"
}

__bracke_prompt_command() {
    local command_status=$?
    if [[ ${__bracke_command_started-0} == 1 ]]; then
        __bracke_osc "133;D;$command_status"
        __bracke_command_started=0
    fi
    __bracke_osc "7;file://${HOSTNAME-}$(__bracke_urlencode_path)"
    __bracke_osc '133;A'
    __bracke_at_prompt=1
}

__bracke_preexec() {
    [[ ${__bracke_at_prompt-0} == 1 ]] || return 0
    case ${BASH_COMMAND-} in
        __bracke_*|"${PROMPT_COMMAND-}") return 0 ;;
    esac
    __bracke_at_prompt=0
    __bracke_command_started=1
    __bracke_osc '133;B'
    __bracke_osc '133;C'
}

if [[ -n ${PROMPT_COMMAND-} ]]; then
    PROMPT_COMMAND="__bracke_prompt_command;${PROMPT_COMMAND}"
else
    PROMPT_COMMAND=__bracke_prompt_command
fi
trap '__bracke_preexec' DEBUG
