# Linux port status

Current action: build and run the port in an isolated container on the HX 370
Docker host, then complete the GitHub build and container release.

Verified locally: full XRT-enabled compilation using XRT 2.25 runtime libraries
and vendored 2.20 headers; all seven host/nodriver CTest cases passed.
This workstation has no AMD NPU. These checks do not establish NPU execution.

Hardware probe: `homelab-hybrid-port-probe-20261006`, isolated from production,
with read-only model/runtime caches. Original Lemonade remains stopped.
The probe is temporary and must be removed after testing.

Design: NPU takes eligible bulk-prefill work through GGML's scheduler. Vulkan
retains attention and persistent state, avoiding cross-runtime KV import.
Linux Docker builder/runtime use Ubuntu 26.04 and packaged XRT 2.21.75.
Hosted CI can test only compilation and host reference. Release tags `linux-v*`
remain experimental until the recorded hardware gates pass.

Known limitation: upstream mid-request NPU failure can use slow CPU fallback.
See [Linux setup](../docs/Linux.md). The launcher requires NPU readiness at
startup; that does not establish failure recovery during a request.
