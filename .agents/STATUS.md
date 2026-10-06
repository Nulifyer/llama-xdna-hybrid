# Linux port status

Current batch complete: Linux port, pinned native runtime, CI, experimental
GitHub release and GHCR image published and checked on HX 370.
Source release is `linux-v0.1.0` at `aad0b9894a492520d12cd60157762a396e7f3a9c`.
See [Linux setup and evidence](../docs/Linux.md).

Verified: Linux CI eight host/nodriver tests, Windows CI, release archive
checksum, exact release image NPU self-test, dispatch, matmul, injected-NaN
fallback and copy-budget tests. GPU and hybrid chat produced matching output
after a 9,644-token prompt. Synthetic prototype benchmarks covered 8K/32K/64K.
Keep prototype userspace timings separate from released-image checks.

Both own hardware probes were removed, with no volume removal. Original
Lemonade remains stopped. No production stack or model settings were changed.

Next action: evaluate a narrow Lemonade native recipe for this common-GGML
runtime. The Homelab repository owns that source review and integration plan.
No Lemonade fork or integration test exists yet. Ordinary system llama wiring
alone does not reserve the NPU against concurrent FLM loads.

Known limits: upstream mid-request NPU failure can use slow CPU fallback.
Larger-model quality, tools, cold-start latency and recovery remain unverified.
The recipe must own both GPU and NPU and reject or evict conflicting NPU loads.
FLM-to-llama state conversion is a separate engine problem; this runtime does
not use FLM weights or export FLM state. No Python production serving.
