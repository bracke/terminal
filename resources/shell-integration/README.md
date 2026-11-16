# Shell integration

These scripts publish the current directory with OSC 7 and command boundaries
with OSC 133. They are idempotent and affect interactive shells only.

Source the matching file from the shell startup file. An installed copy lives
under `${XDG_DATA_HOME:-$HOME/.local/share}/bracke-terminal/shell-integration`.

```sh
# Bash / Zsh
source "$HOME/.local/share/bracke-terminal/shell-integration/bracke-terminal.bash"

# Fish
source ~/.local/share/bracke-terminal/shell-integration/bracke-terminal.fish

# Nushell
source ~/.local/share/bracke-terminal/shell-integration/bracke-terminal.nu
```
