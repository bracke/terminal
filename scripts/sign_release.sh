#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    printf '%s\n' "usage: $0 ARCHIVE CHANNEL BASE_URL" >&2
    exit 2
fi
if [ -z "${BRACKE_UPDATE_SECRET_KEY:-}" ]; then
    printf '%s\n' "BRACKE_UPDATE_SECRET_KEY must name a minisign secret key" >&2
    exit 2
fi
archive=$1
channel=$2
base_url=${3%/}
case "$channel" in
    stable|beta|nightly) ;;
    *) printf '%s\n' "channel must be stable, beta, or nightly" >&2; exit 2 ;;
esac
case "$archive" in
    */*) archive_dir=${archive%/*}; archive_name=${archive##*/} ;;
    *) archive_dir=.; archive_name=$archive ;;
esac
manifest="$archive_dir/$channel.update"
test -f "$archive"
command -v minisign >/dev/null
command -v sha256sum >/dev/null
checksum=$(sha256sum "$archive" | awk '{print $1}')
bytes=$(wc -c < "$archive" | tr -d ' ')
version=${VERSION:-0.1.0-dev}
platform=${PLATFORM:-linux-x86_64}
{
    printf '%s\n' "format=bracke-update-v1"
    printf '%s\n' "channel=$channel"
    printf '%s\n' "version=$version"
    printf '%s\n' "platform=$platform"
    printf '%s\n' "url=$base_url/$archive_name"
    printf '%s\n' "sha256=$checksum"
    printf '%s\n' "bytes=$bytes"
} > "$manifest"
minisign -S -s "$BRACKE_UPDATE_SECRET_KEY" -m "$archive"
minisign -S -s "$BRACKE_UPDATE_SECRET_KEY" -m "$manifest"
printf '%s\n' "Signed $archive and $manifest"
