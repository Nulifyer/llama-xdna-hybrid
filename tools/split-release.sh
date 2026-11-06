#!/usr/bin/env bash
set -euo pipefail
archive=${1:?usage: split-release.sh ARCHIVE.tar.gz [PART_BYTES]}
part_bytes=${2:-1610612736}
[[ $part_bytes =~ ^[0-9]+$ && $part_bytes -gt 0 ]] || { echo 'Part size must be positive bytes' >&2; exit 1; }
size=$(stat -c %s "$archive")
((size > part_bytes)) || exit 0
base=${archive%.tar.gz}
parts=$(((size + part_bytes - 1) / part_bytes))
((parts <= 99)) || { echo 'Too many release parts' >&2; exit 1; }
printf -v total '%02d' "$parts"
staging=$(mktemp -d "$(dirname "$archive")/.split-XXXXXX")
trap 'rm -rf "$staging"' EXIT
split -b "$part_bytes" --numeric-suffixes=1 --suffix-length=2 "$archive" "$staging/part"
for chunk in "$staging"/part*; do
    index=${chunk##*part}
    mv "$chunk" "$base.part${index}-of-${total}.tar.gz"
done
printf '%s\n' "$parts" > "$base.partcount"
rm "$archive"
