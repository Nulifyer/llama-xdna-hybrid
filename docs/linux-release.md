Experimental Linux XDNA2 + Vulkan execution for one GGUF model.

Linux now builds pinned llama.cpp b10944 from source with explicit prompt/decode
phase propagation and placement-aware graph reuse. Eligible prompt matmuls use
XDNA2; attention, recurrent state and token decoding remain on Vulkan. Mixed
batches and speculative verification use GPU. This is partial NPU prefill.

The native C++ OpenAI-compatible server exposes authenticated hybrid counters
through /props, caps NPU copies to available memory, and rejects affected
requests on NPU errors. An unresolved kernel wait exits the process. No Python
serving or FLM state conversion is used. See hybrid-manifest.json for coverage.

GitHub CI verifies builds and host tests. Hardware evidence is attached after
HX370 verification. CI alone does not establish NPU correctness or performance.
The launcher requires a successful kernel self-test before hybrid startup.

Use the checksummed archive on Ubuntu 26.04 with XRT/Vulkan, or the matching
GHCR release image. No stable/latest tag is published.

Mellum/MoE routing now retains original router-logit precision on Vulkan. A
configurable output-width floor avoids narrow NPU projections when measurements
favor Vulkan. Native counters also cover matrix-only execution, and expose the
resolved placement controls. Q6 numerical fixtures cover Mellum attention shapes.
