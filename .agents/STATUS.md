# Linux hybrid engine status

Current batch: source-built llama.cpp phase integration, strict NPU errors,
placement metrics, bounded copies, release and separate Portainer deployment.
The user explicitly authorized implementation, tests, publishing and deployment.
Homelab owns consumer integration and infrastructure configuration.

Local verification: patched llama-server and llama-bench compile. Eight host
checks passed before the added real-plugin phase contract assertions. Hardware
verification and CI remain required before releasing linux-v0.2.0.

Coverage is partial NPU prefill. Supported weight GEMMs and fused gate/up use
XDNA2; Vulkan owns attention, recurrence, state and decode. FLM techniques guided
artifact/capability and resident-kernel contracts; its private model engines are
not linked. Full NPU attention/recurrence kernels are still future work.

Next action: publish inspected source, pass CI, verify the new image on HX370,
release linux-v0.2.0 and deploy an authenticated, bounded ai-hybrid stack.
Original Lemonade remains stopped. Do not repoint existing consumers implicitly.

Previous linux-v0.1.0 evidence remains in docs/evidence. Its synthetic benchmark
results do not establish performance of the new source-built release.
