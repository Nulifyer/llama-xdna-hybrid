#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
dd if=/dev/urandom of="$temporary/runtime.tar.gz" bs=1024 count=9 status=none
expected=$(sha256sum "$temporary/runtime.tar.gz" | cut -d' ' -f1)
"$root/tools/split-release.sh" "$temporary/runtime.tar.gz" 4096
[[ $(cat "$temporary/runtime.partcount") == 3 ]]
[[ ! -e "$temporary/runtime.tar.gz" ]]
actual=$(cat "$temporary"/runtime.part*-of-03.tar.gz | sha256sum | cut -d' ' -f1)
[[ $actual == "$expected" ]]
printf 'small archive' > "$temporary/small.tar.gz"
"$root/tools/split-release.sh" "$temporary/small.tar.gz" 4096
[[ -e "$temporary/small.tar.gz" && ! -e "$temporary/small.partcount" ]]
echo 'PASS: split release parts reconstruct the exact archive; small releases stay whole'
