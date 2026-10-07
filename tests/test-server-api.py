#!/usr/bin/env python3
"""Offline acceptance checks. This file is never installed in the serving image.

The runner supplies request(method, path, body) -> (status, parsed JSON).
Use it against a private probe through Docker exec, or an authenticated HTTPS
service. No credentials are included in the evidence returned by this module.
"""
from concurrent.futures import ThreadPoolExecutor


def chat_body(messages, model="small-task"):
    return {"model": model, "messages": messages, "temperature": 0,
            "max_tokens": 32, "cache_prompt": False,
            "chat_template_kwargs": {"enable_thinking": False}}


def answer(response):
    return response["choices"][0]["message"]["content"].strip()


def long_messages():
    return [{"role": "user", "content":
             "Ignore the filler and answer only the arithmetic question at the end.\n"
             + "This is filler for a context test. " * 1200
             + "\nWhat is 2 + 2? Reply with only the number."}]


def run(request, hybrid=True):
    checks = {}
    status, before = request("GET", "/props", None)
    assert status == 200, ("props", status)
    if hybrid:
        h = before["hybrid"]
        assert h["interface_version"] == 1 and not h["full_npu_prefill"]
        assert not h["npu_disabled"]
    messages = long_messages()
    status, first = request("POST", "/v1/chat/completions", chat_body(messages))
    assert status == 200 and answer(first) == "4", ("long chat", status, first)
    assert first["usage"]["prompt_tokens"] > 8192
    assert first["timings"]["cache_n"] == 0
    checks["long_chat"] = first
    status, after = request("GET", "/props", None)
    assert status == 200
    if hybrid:
        h = after["hybrid"]
        assert h["npu_pieces"] > before["hybrid"]["npu_pieces"]
        assert h["prefill_plans"] > before["hybrid"]["prefill_plans"]
        assert h["decode_plans"] > before["hybrid"]["decode_plans"]
        assert h["npu_planned_weight_bytes"] <= h["npu_copy_budget_bytes"]
        assert not h["npu_disabled"] and h["failures"] == 0
    messages += [{"role": "assistant", "content": "4"},
                 {"role": "user", "content": "Add 3 to your previous answer. Reply with only the number."}]
    follow_body = chat_body(messages)
    follow_body["cache_prompt"] = True
    status, follow = request("POST", "/v1/chat/completions", follow_body)
    assert status == 200 and answer(follow) == "7", ("continuation", status, follow)
    assert follow["timings"]["cache_n"] > 8192, "follow-up replayed the cached prompt"
    checks["continuation"] = follow
    status, continued = request("GET", "/props", None)
    assert status == 200
    # Two clients queue independent requests, even with a single inference slot.
    def small(prompt):
        status, result = request("POST", "/v1/chat/completions",
                                 chat_body([{"role": "user", "content": prompt}]))
        assert status == 200, ("concurrent client", status, result)
        return result
    with ThreadPoolExecutor(max_workers=2) as pool:
        a = pool.submit(small, "What is 2 + 2? Reply with only the number.")
        b = pool.submit(small, "What is 3 + 3? Reply with only the number.")
        results = [a.result(), b.result()]
    assert [answer(x) for x in results] == ["4", "6"], results
    checks["concurrent_clients"] = results
    tool_body = chat_body([{"role": "user", "content":
                           "Turn on the kitchen light using turn_on. Its entity_id is light.kitchen."}])
    tool_body["max_tokens"] = 128
    tool_body["tools"] = [{"type": "function", "function": {"name": "turn_on",
                          "description": "Turn on a Home Assistant entity.",
                          "parameters": {"type": "object", "properties": {
                              "entity_id": {"type": "string"}}, "required": ["entity_id"]}}}]
    status, tool = request("POST", "/v1/chat/completions", tool_body)
    assert status == 200, ("tool smoke", status, tool)
    calls = tool["choices"][0]["message"].get("tool_calls", [])
    assert len(calls) == 1 and calls[0]["function"]["name"] == "turn_on", tool
    import json
    assert json.loads(calls[0]["function"]["arguments"])["entity_id"] == "light.kitchen", tool
    checks["single_tool_smoke"] = tool
    status, end = request("GET", "/props", None)
    assert status == 200
    if hybrid:
        assert end["hybrid"]["npu_pieces"] == continued["hybrid"]["npu_pieces"], "short requests unexpectedly used NPU"
        assert not end["hybrid"]["npu_disabled"]
    checks["props_before"] = before.get("hybrid")
    checks["props_after"] = end.get("hybrid")
    return checks


def run_failure(request):
    """Use a fresh isolated process with GGML_XDNA_NAN_AFTER=0."""
    status, failed = request("POST", "/v1/chat/completions", chat_body(long_messages()))
    assert status == 500, ("strict NPU failure", status, failed)
    status, props = request("GET", "/props", None)
    assert status == 200
    h = props["hybrid"]
    assert h["npu_disabled"] and h["failures"] == 1
    # The next fresh request must rebuild placement and recompute all state.
    status, recovered = request("POST", "/v1/chat/completions", chat_body(long_messages()))
    assert status == 200 and answer(recovered) == "4", ("GPU recovery", status, recovered)
    assert recovered["timings"]["cache_n"] == 0
    status, end = request("GET", "/props", None)
    assert status == 200 and end["hybrid"]["npu_pieces"] == h["npu_pieces"]
    return {"failed_request": failed, "props_disabled": h,
            "fresh_gpu_recovery": recovered, "props_after": end["hybrid"]}


if __name__ == "__main__":
    import json
    import os
    import sys
    import urllib.error
    import urllib.request
    base = os.environ["HYBRID_TEST_URL"].rstrip("/")
    key = os.environ.get("HYBRID_TEST_API_KEY", "")

    def request(method, path, body):
        headers = {"Content-Type": "application/json"}
        if key:
            headers["Authorization"] = "Bearer " + key
        req = urllib.request.Request(base + path, method=method, headers=headers,
                                     data=None if body is None else json.dumps(body).encode())
        try:
            response = urllib.request.urlopen(req, timeout=180)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.status, json.load(response)

    result = run_failure(request) if "--failure" in sys.argv else run(request, "--gpu" not in sys.argv)
    print(json.dumps(result, indent=2))
