FROM ubuntu:26.04 AS build
ARG DEBIAN_FRONTEND=noninteractive
ARG XRT_VERSION=1:2.21.75+dfsg-4
ARG SOURCE_REVISION=unknown
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git cmake make g++ uuid-dev libxrt-dev=${XRT_VERSION} \
    libvulkan1 mesa-vulkan-drivers libssl3t64 libbrotli1 libzstd1 zlib1g \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY . .
RUN tools/fetch-llama.sh && \
    cmake -S . -B build-linux -DCMAKE_BUILD_TYPE=Release -DGGML_XDNA_NPU=ON && \
    cmake --build build-linux -j4 && \
    VK_DRIVER_FILES="$(find /usr/share/vulkan/icd.d -name '*lvp*.json' -print -quit)" \
    GGML_VK_VISIBLE_DEVICES=0 GGML_VK_DISABLE_F16=1 GGML_VK_DISABLE_COOPMAT=1 GGML_XDNA_PINNED=0 \
    ctest --test-dir build-linux -L 'host|nodriver' --output-on-failure && \
    tools/package-linux.sh /out

FROM scratch AS artifacts
COPY --from=build /out/ /

FROM ubuntu:26.04 AS runtime
ARG DEBIAN_FRONTEND=noninteractive
ARG XRT_VERSION=1:2.21.75+dfsg-4
ARG SOURCE_REVISION=unknown
LABEL org.opencontainers.image.source="https://github.com/Nulifyer/llama-xdna-hybrid" \
    org.opencontainers.image.revision="${SOURCE_REVISION}" \
    org.opencontainers.image.description="Experimental Linux XDNA2 prefill and Vulkan decoding"
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl libxrt2=${XRT_VERSION} libxrt-npu2=${XRT_VERSION} \
    libvulkan1 mesa-vulkan-drivers libssl3t64 libbrotli1 libzstd1 zlib1g libgomp1 \
    && rm -rf /var/lib/apt/lists/* && useradd --create-home --uid 10001 model
COPY --from=build /out/llama-xdna-hybrid/ /opt/llama/
ENV LD_LIBRARY_PATH=/opt/llama GGML_BACKEND_PATH=/opt/llama/libggml-xdna.so \
    HYBRID_REQUIRE_NPU=1
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["/opt/llama/hybrid-server"]
