# Mellum Q6 hybrid placement

Mellum2.1 has 28 layers, width 2,304 and 64 experts with eight selected per token.
The inspected Q6_K GGUF uses Q6_K attention weights, Q6_K expert gate/up weights,
Q8_0 expert down weights and F32 router logits. The pinned llama.cpp b10944 graph
already implements its sliding-window attention and MoE operations.

The backend preserves `blk.<layer>.ffn_gate_inp.weight` router logits on Vulkan.
Ordinary projections remain eligible under phase, shape, work and copy-budget
checks. Routed `MUL_MAT_ID` operations remain on Vulkan. Reducing precision in
upstream projections can still change routing. Router placement alone does not
establish identical expert selection or broad output quality.

`GGML_XDNA_MIN_OUTPUT_WIDTH` adds a per-process projection-width floor. Zero
preserves the previous size policy. A value of 1,024 keeps Mellum's 512-wide K/V
projections on Vulkan while permitting Q and attention output projections.
The manager owns the saved per-model value and passes it through the environment.
Other profiles retain the zero default. This setting does not move model weights
or KV state away from the GPU.

Native `/props.hybrid` reports the resolved width floor, minimum prompt rows,
host threads and block-claiming policy. Both block execution and matrix-only
execution count actual NPU nodes, successful pieces and staging. CPU reference
execution does not increment NPU work counters.

The Homelab repository owns model registration, release deployment, matched
performance measurements and consumer acceptance. Its runtime-selection document
links the Mellum evidence. Hardware checks in this repository cover Mellum's three
Q6 attention shapes against FP64 reference values and the CPU implementation.
They also verify that router logits remain on Vulkan above the normal work floor.
