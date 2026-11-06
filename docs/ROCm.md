# XDNA2 with ROCm

The backend shares GGML GPU buffers and transfer operations with the selected
GPU. `HYBRID_GPU_DEVICE=ROCm0` selects ROCm; the existing default remains
`Vulkan0`. An explicit missing device fails instead of selecting a different GPU.

`Dockerfile.rocm` builds a matched b10944 GGML/llama.cpp/plugin bundle on Ubuntu
24.04, using TheRock10.1.0 for gfx1150 and the private XRT libraries from the
verified FLM1.0.12 portable archive. Compilers and the SDK remain in build stages.
The release archive includes isolated userspace libraries; it does not install
host kernel drivers. Pass `/dev/dri`, `/dev/kfd`, `/dev/accel/accel0`, render/video
groups and unlimited memlock to the consuming container.

Eligible prefill matrix operations use the NPU. Attention, routing, routed
experts, recurrent state and decode remain on the GPU. Runtime packing of
eligible weights is separate from converting the source GGUF: the source file
is never rewritten. Reduced-precision NPU arithmetic can change output. No
performance improvement is implied by selecting the backend.

Host launcher, instruction layout, packing and placement-plan tests pass.
ROCm compilation and actual NPU/ROCm numerical/performance acceptance are
separate release gates; see the deployment receipt before treating the profile
as hardware validated. Use `HYBRID_REQUIRE_NPU=0` only for a GPU baseline.
