#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
out=${1:?usage: package-linux.sh OUTPUT_DIRECTORY}
mkdir -p "$out/llama-xdna-hybrid/licenses"
out=$(cd -- "$out" && pwd)
cp -a "$root/third_party/llama-b10944/." "$out/llama-xdna-hybrid/"
install -m755 "$root/tools/hybrid-server" "$out/llama-xdna-hybrid/hybrid-server"
actual=$(sha256sum "$root/kernels/bfp16_gemm/prebuilt/bfp16_gemm.xclbin" | cut -d' ' -f1)
[[ $(jq -r .kernel.sha256 "$root/kernels/hybrid-manifest.json") == "$actual" ]] || { echo 'Kernel manifest checksum mismatch' >&2; exit 1; }
jq --arg patch "$(cat "$out/llama-xdna-hybrid/HYBRID_PATCH_SHA256")" '.llama.patch_sha256=$patch'     "$root/kernels/hybrid-manifest.json" > "$out/llama-xdna-hybrid/hybrid-manifest.json"
cp "$root/LICENSE" "$out/llama-xdna-hybrid/licenses/LICENSE.ggml-xdna"
cp "$root/vendor/xrt/LICENSE" "$out/llama-xdna-hybrid/licenses/LICENSE.xrt-headers"
cp "$root/vendor/xrt/NOTICE" "$out/llama-xdna-hybrid/licenses/NOTICE.xrt-headers"
cp "$root/NOTICE" "$out/llama-xdna-hybrid/licenses/NOTICE.ggml-xdna"
cp "$root/kernels/bfp16_gemm/LICENSE" "$out/llama-xdna-hybrid/licenses/LICENSE.kernel"
printf 'source_revision=%s\nllama_tag=b10944\nllama_revision=b6b003d2cb29647d968302eb2db8da6f66303b3e\n' \
    "${SOURCE_REVISION:-unknown}" > "$out/llama-xdna-hybrid/BUILD_INFO"
tar -czf "$out/llama-xdna-hybrid-linux-x86_64.tar.gz" -C "$out" llama-xdna-hybrid
(cd -- "$out" && sha256sum llama-xdna-hybrid-linux-x86_64.tar.gz > SHA256SUMS)
