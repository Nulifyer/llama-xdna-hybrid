#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
out=${1:?usage: package-linux.sh OUTPUT_DIRECTORY}
mkdir -p "$out/llama-xdna-hybrid/licenses"
out=$(cd -- "$out" && pwd)
cp -a "$root/third_party/llama-b10944/." "$out/llama-xdna-hybrid/"
install -m755 "$root/tools/hybrid-server" "$out/llama-xdna-hybrid/hybrid-server"
cp "$root/LICENSE" "$out/llama-xdna-hybrid/licenses/LICENSE.ggml-xdna"
cp "$root/vendor/xrt/LICENSE" "$out/llama-xdna-hybrid/licenses/LICENSE.xrt-headers"
cp "$root/NOTICE" "$out/llama-xdna-hybrid/licenses/NOTICE.ggml-xdna"
cp "$root/kernels/bfp16_gemm/LICENSE" "$out/llama-xdna-hybrid/licenses/LICENSE.kernel"
tar -czf "$out/llama-xdna-hybrid-linux-x86_64.tar.gz" -C "$out" llama-xdna-hybrid
(cd -- "$out" && sha256sum llama-xdna-hybrid-linux-x86_64.tar.gz > SHA256SUMS)
