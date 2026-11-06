#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
revision=b6b003d2cb29647d968302eb2db8da6f66303b3e
source_dir="$root/third_party/llama-source"
variant=${HYBRID_GPU_BACKEND:-vulkan}
case $variant in vulkan|rocm) ;; *) echo "Unsupported GPU backend: $variant" >&2; exit 1 ;; esac
dist=${HYBRID_LLAMA_DIST:-"$root/third_party/llama-b10944"}
build_dir="$source_dir/build-$variant"
gpu_options=(-DGGML_VULKAN=ON)
if [[ $variant == rocm ]]; then
    gpu_options=(-DGGML_VULKAN=OFF -DGGML_HIP=ON -DAMDGPU_TARGETS="${HYBRID_AMDGPU_TARGET:-gfx1150}")
fi
headers="$root/third_party/ggml-b10944"
mkdir -p "$root/third_party"
if [[ ! -d "$source_dir/.git" ]]; then
    git clone --quiet --depth 1 --branch b10944 https://github.com/ggml-org/llama.cpp.git "$source_dir"
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$revision" ]] || { echo 'Unexpected llama source revision' >&2; exit 1; }
patch="$root/patches/llama-b10944-hybrid.patch"
if git -C "$source_dir" apply --check "$patch"; then
    git -C "$source_dir" apply "$patch"
elif ! git -C "$source_dir" apply --reverse --check "$patch"; then
    echo 'Source differs from the pinned hybrid patch' >&2; exit 1
fi
cmake -S "$source_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release \
    "${gpu_options[@]}" -DGGML_BACKEND_DL=ON -DGGML_NATIVE=OFF -DGGML_CPU_ALL_VARIANTS=ON \
    -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TOOLS=ON \
    -DLLAMA_BUILD_SERVER=ON -DLLAMA_CURL=OFF -DLLAMA_SERVER_SSL=OFF
cmake --build "$build_dir" --target llama-server llama-bench llama-quantize -j"${HYBRID_BUILD_JOBS:-4}"
mkdir -p "$dist" "$headers/include" "$headers/src"
cp -a "$build_dir/bin/." "$dist/"
cp "$source_dir/ggml/include/"*.h "$headers/include/"
for file in ggml-backend-impl.h ggml-impl.h ggml-common.h; do cp "$source_dir/ggml/src/$file" "$headers/src/"; done
cp "$source_dir/LICENSE" "$dist/LICENSE.llama.cpp"
sha256sum "$patch" | cut -d' ' -f1 > "$dist/HYBRID_PATCH_SHA256"
