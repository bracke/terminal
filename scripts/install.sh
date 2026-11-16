#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
prefix=${PREFIX:-/usr/local}
destdir=${DESTDIR:-}
root="$destdir$prefix"
binary=${BRACKE_TERMINAL_BINARY:-"$project_dir/bin/terminal"}

if [ ! -x "$binary" ]; then
    printf '%s\n' "Missing $binary; run 'alr build' first." >&2
    exit 1
fi

install -d "$root/bin" "$root/share/applications" \
    "$root/share/metainfo" "$root/share/bracke-terminal/shell-integration" \
    "$root/share/terminfo"
install -m 0755 "$binary" "$root/bin/bracke-terminal"
install -m 0644 "$project_dir/resources/applications/io.bracke.Terminal.desktop" \
    "$root/share/applications/"
install -m 0644 "$project_dir/resources/metainfo/io.bracke.Terminal.metainfo.xml" \
    "$root/share/metainfo/"
install -m 0644 "$project_dir"/resources/shell-integration/bracke-terminal.* \
    "$root/share/bracke-terminal/shell-integration/"
tic -x -o "$root/share/terminfo" \
    "$project_dir/resources/terminfo/bracke-terminal.terminfo"

printf '%s\n' "Installed Bracke Terminal under $root"
