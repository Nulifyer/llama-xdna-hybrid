#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp "$root/tools/hybrid-server" "$tmp/"
cat > "$tmp/llama-server" <<'SERVER'
#!/usr/bin/env bash
if [[ ${1:-} == --list-devices ]]; then
    case $TEST_DEVICES in
        both) printf 'Available devices:\n  XDNA0: NPU\n  Vulkan0: GPU\n' ;;
        failed) printf 'xdna: not offering XDNA0: self-test failed\nAvailable devices:\n  Vulkan0: GPU\n' ;;
        npu) printf 'Available devices:\n  XDNA0: NPU\n' ;;
    esac
else
    printf '%s\n' "$@"
fi
SERVER
chmod +x "$tmp/llama-server"
export TEST_DEVICES=both HYBRID_REQUIRE_NPU=1
unset GGML_XDNA_HOST_ONLY
"$tmp/hybrid-server" --model example.gguf > "$tmp/args" 2> "$tmp/log"
grep -qx 'XDNA0,Vulkan0' "$tmp/args"
for TEST_DEVICES in failed npu; do
    export TEST_DEVICES
    if "$tmp/hybrid-server" --model example.gguf > /dev/null 2>&1; then
        echo "FAIL: serving started with $TEST_DEVICES devices" >&2; exit 1
    fi
done
export TEST_DEVICES=both GGML_XDNA_HOST_ONLY=1
if "$tmp/hybrid-server" --model example.gguf > /dev/null 2>&1; then
    echo 'FAIL: host reference passed the hardware gate' >&2; exit 1
fi
unset GGML_XDNA_HOST_ONLY
export HYBRID_REQUIRE_NPU=0 TEST_DEVICES=failed
"$tmp/hybrid-server" --model example.gguf > "$tmp/args"
grep -qx Vulkan0 "$tmp/args"
export HYBRID_REQUIRE_NPU=invalid
if "$tmp/hybrid-server" --model example.gguf > /dev/null 2>&1; then
    echo 'FAIL: invalid mode was accepted' >&2; exit 1
fi
echo 'PASS: hybrid startup rejects failed hardware and reference mode; GPU comparison is explicit'
