# Linux hybrid runtime

## Scope

Target: Ryzen AI 9 HX 370, Radeon 890M and XDNA2 on Linux. This fork ports the
upstream C++ backend rather than maintaining a second llama.cpp implementation.
The plugin, llama.cpp binaries and matching GGML headers use release b10944.
The download script checks the binary archive SHA-256 and source commit.

The NPU takes supported weight GEMMs and adjacent operations for batches of
at least 1,024 tokens. Vulkan owns model weights, attention and persistent
state, and generates the reply. This is partial NPU prefill on the same model.
It does not import FLM state, consume FLM model files or require Python serving.
GGUF weights are converted to the kernel's BFP16 representation in memory.

## Container

Build with `docker build -t llama-xdna-hybrid .`. GitHub CI performs the same
build, runs host-reference tests and publishes a GHCR image for each main
commit. A `linux-v*` tag publishes an experimental GitHub release, a checksummed
archive and an image carrying that tag. No stable `latest` tag is published.

Use the published image with a verified digest. Example:

```bash
docker run --rm --name hybrid-test \
  --device /dev/accel/accel0 --device /dev/dri \
  --group-add "$(stat -c %g /dev/accel/accel0)" \
  --group-add "$(stat -c %g /dev/dri/renderD128)" \
  --cap-drop ALL --security-opt no-new-privileges \
  --memory 24g --cpus 20 --shm-size 2g \
  -p 127.0.0.1:8080:8080 \
  -v /host/models:/models:ro \
  ghcr.io/nulifyer/llama-xdna-hybrid:linux-v0.1.0 \
  --model /models/model.gguf --ctx-size 32768 --parallel 1
```

The host needs a working `amdxdna` kernel driver and firmware. The image supplies
Ubuntu 26.04 userspace, XRT 2.21.75 and Mesa Vulkan. It does not install host
drivers. Adjust the device path and groups to the host. `/dev/kfd` is not needed
for Vulkan. The service runs as UID 10001; model mounts must be readable by it.

New GHCR packages are private by default. Authenticate Docker before pulling,
or use a configured Portainer registry. The homelab already has authenticated
GHCR registry ID 4. Its helper can pull without exporting registry credentials:

```bash
PORTAINER_TIMEOUT=0 ./portainer.sh pull --registry 4 \
  ghcr.io/nulifyer/llama-xdna-hybrid:linux-v0.1.0
```

That command runs from the separate Homelab repository. Image publishing uses
the repository's GitHub Actions token; no personal token is embedded in a build.

The launcher requires successful kernel self-test and both XDNA0 and Vulkan0.
It refuses host-reference mode in hybrid serving. `HYBRID_REQUIRE_NPU=0` selects
Vulkan alone for a comparison. `--list-devices`, `--version` and `--help` can be
used without enabling hybrid serving. Server arguments configure context,
sampling and API authentication using llama.cpp's existing interface.

The HTTP interface is llama.cpp's native OpenAI-compatible API. Integrate this
image through the homelab's existing routing and authentication rules after
hardware validation. No production stack or model alias is changed by this
repository. Download tracking and model inventory remain a separate manager's
responsibility.

## Local build

On Ubuntu 26.04, install the builder dependencies listed in Dockerfile, then:

```bash
tools/fetch-llama.sh
cmake -S . -B build-linux -DCMAKE_BUILD_TYPE=Release -DGGML_XDNA_NPU=ON
cmake --build build-linux -j4
ctest --test-dir build-linux -L 'host|nodriver' --output-on-failure
ctest --test-dir build-linux -L npu --output-on-failure
tools/package-linux.sh dist
```

The `nodriver` test is for a machine without an NPU. Do not run that label on
the target hardware. `GGML_XDNA_NPU=OFF` builds a host reference for development;
it is not an accelerated runtime. Linux needs XRT shared libraries even when
no NPU is present. The kernel self-test decides whether to expose XDNA0.

## Validation and limits

Before deployment, require the kernel self-test, hardware dispatch and matmul
tests, same-model hybrid inference, output-quality checks and repeated matched
GPU comparisons. Record cold weight-copy cost separately from warmed prompt
processing. Check 8K, 32K and 64K prompts with equal tokens, context capacity,
cache state, batches and sampling. Record resource peaks and any NPU fallback.
The homelab's earlier FLM versus GPU timings do not predict this backend's gain.

The default NPU copy budget is 20 GB and is bounded by available host/container
memory. There is an additional GPU copy of the model and cache. Keep the budget
conservative until the Linux driver allocation limits have been measured.
An explicit `GGML_XDNA_MAX_COPY_GB` overrides that automatic budget. The device's
advertised Vulkan memory is not the container limit. Measure host RAM, container
memory and device use together. Enable llama-server `--metrics` for its request
metrics; Docker resource statistics do not attribute every allocation by device.

Upstream failure handling may finish an already scheduled piece on a slow CPU
reference before moving later work to Vulkan. This can cause a long request
delay. The launcher checks startup readiness; it does not fix that mid-request
behavior. Do not advertise production recovery guarantees until it is tested
and improved. GPU attention can also limit long-context speedups.

## HX 370 verification

The experimental [linux-v0.1.0 release](https://github.com/Nulifyer/llama-xdna-hybrid/releases/tag/linux-v0.1.0)
was built by Linux CI, with all eight host/nodriver checks passing. Windows CI
also passed. The release archive checksum was verified after download.
The released image digest is
`sha256:81692f3ddbb714423333390a84f4a6321bcb1af656520ce93ea25f768b14bdd8`.

On HX 370, that image passed the NPU self-test, dispatch, matmul, injected-NaN
fallback and memory-budget checks. GPU-only and hybrid OpenAI chat both
returned `4` after the same 9,644-token prompt, with no cached prompt tokens.
The hybrid log records actual NPU submissions. This is a continuation smoke
check, not a tool-calling or general quality evaluation. The image supplies
XRT 2.21.75 and Mesa 26.0.8; `python3` was absent from PATH. Peak container
memory across these image checks was about 1.97 GiB with no cgroup OOM events.

A separate Ubuntu 24.04/XRT 2.25 prototype ran native synthetic `llama-bench`
prefill tests, excluding warmup and initial loading, three repetitions each:

| Prompt tokens | Vulkan mean | Hybrid mean | Time reduction |
| --- | --- | --- | --- |
| 8,192 | 5.565 s | 5.195 s | 6.6% |
| 32,768 | 35.511 s | 33.982 s | 4.3% |
| 65,536 | 110.993 s | 106.846 s | 3.7% |

These gains are provisional: other host stacks remained running and image
pulls/readiness checks overlapped the long comparison. They do not establish
performance for the released userspace or larger models. GPU attention still
dominates long prompts. Cold copies, quality and failure recovery need further
checks before production adoption.

The [prototype record](evidence/hx370-prototype.json) contains benchmark samples,
model checksum, NPU traces and memory counters. The [image record](evidence/hx370-image.json)
contains exact image identities, hardware checks, request results and cleanup.
Both temporary probes were removed without removing volumes. Original Lemonade
remains stopped. No production stack, alias or model default was changed.

## Maintenance

Port ownership is in `cmake/Linux.cmake`, `src/xdna-platform.*`, the Linux
branches of `src/xdna-npu.cpp`, `tools/*.sh`, Dockerfile and the Linux workflow.
Keep upstream Windows behavior intact. Update llama binaries and headers
together, verify the new checksum/commit and rerun hardware correctness before
changing the pin. Preserve MIT, XRT and kernel notices in distributed artifacts.
