#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tag=b10944
revision=b6b003d2cb29647d968302eb2db8da6f66303b3e
archive_sha=de48f1c0890365d432dea3db1d8e9482686748fe5821f211719779e5724bdc7b
mkdir -p "$root/third_party"
dist="$root/third_party/llama-$tag"
headers="$root/third_party/ggml-$tag"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
if [[ ! -f "$dist/llama-server" ]]; then
    curl --fail --location --retry 3 --silent --show-error "https://github.com/ggml-org/llama.cpp/releases/download/$tag/llama-$tag-bin-ubuntu-vulkan-x64.tar.gz" -o "$tmp/llama.tar.gz"
    printf '%s  %s\n' "$archive_sha" "$tmp/llama.tar.gz" | sha256sum --check --status
    mkdir -p "$dist"
    tar -xzf "$tmp/llama.tar.gz" -C "$tmp"
    binary=$(find "$tmp" -type f -name llama-server -print -quit)
    [[ -n "$binary" ]] || { echo 'llama-server missing from pinned archive' >&2; exit 1; }
    cp -a "$(dirname "$binary")/." "$dist/"
fi
if [[ ! -f "$headers/src/ggml-backend-impl.h" ]]; then
    git clone --quiet --depth 1 --branch "$tag" https://github.com/ggml-org/llama.cpp.git "$tmp/source"
    [[ $(git -C "$tmp/source" rev-parse HEAD) == "$revision" ]] || { echo 'llama.cpp tag revision changed' >&2; exit 1; }
    mkdir -p "$headers/include" "$headers/src"
    cp "$tmp/source/ggml/include/"*.h "$headers/include/"
    for file in ggml-backend-impl.h ggml-impl.h ggml-common.h; do cp "$tmp/source/ggml/src/$file" "$headers/src/"; done
    cp "$tmp/source/LICENSE" "$dist/LICENSE.llama.cpp"
fi
printf 'Pinned llama.cpp %s ready at %s\n' "$tag" "$dist"
