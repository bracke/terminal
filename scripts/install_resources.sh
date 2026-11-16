#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
integration_dir="$data_home/bracke-terminal/shell-integration"
terminfo_dir=${TERMINFO:-"$HOME/.terminfo"}

mkdir -p "$integration_dir" "$terminfo_dir"
cp "$project_dir"/resources/shell-integration/bracke-terminal.* "$integration_dir/"
tic -x -o "$terminfo_dir" \
    "$project_dir/resources/terminfo/bracke-terminal.terminfo"

printf '%s\n' "Installed shell integration in $integration_dir"
printf '%s\n' "Installed bracke-terminal terminfo in $terminfo_dir"
