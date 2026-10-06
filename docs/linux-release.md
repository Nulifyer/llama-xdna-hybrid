Experimental Linux XDNA2 + Vulkan backend for the same model.

The image contains pinned llama.cpp b10944, the XDNA plugin and its BFP16
kernel. It runs eligible prefill operations on the NPU and keeps attention,
the KV cache and token decoding on Vulkan. Small batches use Vulkan.

GitHub CI checks compilation and host-reference tests. It cannot validate an
NPU. Consult docs/Linux.md and the recorded hardware results before deployment.
The server refuses hybrid startup unless the NPU kernel self-test passes.

The archive needs Ubuntu 26.04 userspace, XRT and Vulkan libraries. Prefer the
container. Images are published to ghcr.io/nulifyer/llama-xdna-hybrid using the
release tag. No stable/latest tag is published at this stage.
