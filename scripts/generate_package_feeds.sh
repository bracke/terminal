#!/bin/sh
set -eu
if [ "$#" -ne 5 ]; then
    printf '%s\n' "usage: $0 VERSION ARCHIVE_URL SHA256 SIZE OUTPUT_DIR" >&2
    exit 2
fi
version=$1
url=$2
checksum=$3
size=$4
output=$5
case "$checksum" in
    *[!0-9a-fA-F]*|'') printf '%s\n' "invalid SHA-256" >&2; exit 2 ;;
esac
test "$(printf '%s' "$checksum" | wc -c)" -eq 64
case "$size" in *[!0-9]*|'') printf '%s\n' "invalid size" >&2; exit 2 ;; esac
mkdir -p "$output/homebrew" "$output/winget" "$output/debian"
sed -e "s|@VERSION@|$version|g" -e "s|@URL@|$url|g" \
    -e "s|@SHA256@|$checksum|g" \
    packaging/homebrew/bracke-terminal.rb.in \
    > "$output/homebrew/bracke-terminal.rb"
sed -e "s|@VERSION@|$version|g" -e "s|@URL@|$url|g" \
    -e "s|@SHA256@|$checksum|g" \
    packaging/winget/io.bracke.Terminal.installer.yaml.in \
    > "$output/winget/io.bracke.Terminal.installer.yaml"
sed -e "s|@VERSION@|$version|g" \
    packaging/winget/io.bracke.Terminal.yaml.in \
    > "$output/winget/io.bracke.Terminal.yaml"
cp packaging/debian/bracke-terminal.sources.in \
    "$output/debian/bracke-terminal.sources"
printf '%s\n' "$size" > "$output/archive.size"
printf '%s\n' "Generated package-feed metadata under $output"
