# Linux hybrid engine status

Released `linux-v0.2.0` from `5f6ff4c49bdd9fa8320f1f35de53d077df9f275f` and
deployed its pinned image as Homelab Portainer stack 73, `ai-hybrid`, endpoint 7.
Linux main/release and Windows CI passed. Exact-image NPU numerical/phase/budget
checks and strict injected-error GPU recovery passed. Production HTTPS auth,
continuation, queued clients, tool-call smoke and cancelled-stream recovery passed.
`docs/Linux.md` and `docs/evidence/hx370-native-v0.2.json` own verification and limits.

Coverage remains partial NPU prefill: supported GEMMs and fused gate/up use XDNA2;
Vulkan owns attention, recurrence, state and decode. FLM techniques guide artifact
and resident-kernel contracts; its private model engines are not linked. No Python
production server is introduced. The service uses Qwen3.5-2B Q4_K_M, 32K context,
one slot and an 8 GiB NPU copy budget. Homelab owns deployment and consumer routing.

Warmed native prefill took 19.9% less time at 8K and 9.5% less at 32K. The 64K
comparison established no useful gain. Cold copies, host load and unbalanced run
order limit these results. Genuine driver-hang recovery and broad model quality
remain unverified. Preserve historical v0.1 evidence as separate measurements.

Next action: use the measured long-context bottleneck to plan NPU attention and
recurrence kernels and explicit Lemonade GPU/NPU admission. Manager integration
alone does not provide full NPU prefill. Original Lemonade remains stopped;
existing consumers have not been repointed.
