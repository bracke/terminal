# Bracke Terminal shell integration for interactive Fish.
status is-interactive; or exit 0
set -q BRACKE_TERMINAL_SHELL_INTEGRATION_LOADED; and exit 0
set -gx BRACKE_TERMINAL_SHELL_INTEGRATION_LOADED 1

function __bracke_osc
    printf '\e]%s\e\\' "$argv[1]"
end

function __bracke_prompt --on-event fish_prompt
    __bracke_osc "7;file://"(hostname)(string escape --style=url "$PWD")
    __bracke_osc '133;A'
end

function __bracke_preexec --on-event fish_preexec
    __bracke_osc '133;B'
    __bracke_osc '133;C'
end

function __bracke_postexec --on-event fish_postexec
    __bracke_osc "133;D;$status"
end
