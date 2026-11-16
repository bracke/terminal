#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
version=${VERSION:-0.1.0-dev}
output=${1:-"$project_dir/bracke-terminal-$version-linux.tar.gz"}
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT HUP INT TERM

DESTDIR="$stage" PREFIX=/usr BRACKE_TERMINAL_BINARY="$project_dir/bin/terminal" \
    "$script_dir/install.sh"
tar --sort=name --mtime='UTC 2020-01-01' --owner=0 --group=0 --numeric-owner \
    -C "$stage" -czf "$output" .
printf '%s\n' "Created $output"
