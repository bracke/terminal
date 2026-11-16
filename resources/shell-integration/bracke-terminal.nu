# Bracke Terminal shell integration for Nushell.
def --env __bracke_osc [payload: string] {
    print -n $"\u{1b}]($payload)\u{1b}\\"
}

def --env __bracke_prompt [] {
    __bracke_osc $"7;file://(sys host | get hostname)($env.PWD | url encode)"
    __bracke_osc "133;A"
}

$env.config = ($env.config | upsert hooks.pre_prompt {
    __bracke_prompt
})
$env.config = ($env.config | upsert hooks.pre_execution {
    __bracke_osc "133;B"
    __bracke_osc "133;C"
})
