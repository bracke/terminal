#!/bin/sh
set -eu
if [ "$#" -ne 3 ]; then
    printf '%s\n' "usage: $0 MANIFEST ARCHIVE MINISIGN_PUBLIC_KEY" >&2
    exit 2
fi
manifest=$1
archive=$2
public_key=$3
command -v minisign >/dev/null
command -v sha256sum >/dev/null
minisign -V -p "$public_key" -m "$manifest"
minisign -V -p "$public_key" -m "$archive"
format=$(sed -n 's/^format=//p' "$manifest")
expected=$(sed -n 's/^sha256=//p' "$manifest")
expected_bytes=$(sed -n 's/^bytes=//p' "$manifest")
test "$format" = "bracke-update-v1"
test -n "$expected"
test "$(sha256sum "$archive" | awk '{print $1}')" = "$expected"
test "$(wc -c < "$archive" | tr -d ' ')" = "$expected_bytes"
printf '%s\n' "Verified $archive"
