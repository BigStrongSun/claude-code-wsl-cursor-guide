# vLLM Public Access And Relay

This document records the public relay topology for Claude Code and OpenAI-compatible clients that use the vLLM service.

## Quick Reference

| Client type | Base URL | Model | Notes |
| --- | --- | --- | --- |
| OpenAI-compatible clients | `https://www.matrixminecraft.cn:24443/vllm/v1` | `qwen3.6` | Use this as `OPENAI_BASE_URL` or SDK `base_url`. |
| Anthropic-compatible clients | `https://www.matrixminecraft.cn:24443` | `qwen3.6` | Use this as `ANTHROPIC_BASE_URL`. Do not append `/v1`. |

The Anthropic-compatible route is still served by the same local `qwen3.6` vLLM backend. It does not mean a Claude model is deployed behind the service.

Use placeholders for keys in committed docs and scripts:

```bash
export OPENAI_API_KEY=<VLLM_API_KEY>
export ANTHROPIC_API_KEY=<VLLM_API_KEY>
export ANTHROPIC_AUTH_TOKEN=<VLLM_API_KEY>
```

## Machines

| Component | Address | Role |
| --- | --- | --- |
| Public HTTPS entrypoint | `https://www.matrixminecraft.cn:24443` | Public access through the relay host. |
| Service machine | `100.99.98.29` | Runs vLLM, OpenWebUI, ACPsClaw, AIP services, and search services. |
| Relay machine | `100.99.98.31` | Runs Zoraxy, local mTLS bridge, and legacy Anthropic fallback adapter. |
| Zoraxy config | `C:\Users\MODT\Documents\AgentTunnel\zoraxy\conf\proxy\root.config` | Restart Zoraxy after route changes. |
| Zoraxy admin | `http://127.0.0.1:8000` | Use only from the relay machine. |

## OpenAI-Compatible Access

| Capability | Public URL | Upstream target |
| --- | --- | --- |
| API base URL | `https://www.matrixminecraft.cn:24443/vllm/v1` | `http://100.99.98.29:5000/v1` |
| Models | `https://www.matrixminecraft.cn:24443/vllm/v1/models` | `http://100.99.98.29:5000/v1/models` |
| Chat completions | `https://www.matrixminecraft.cn:24443/vllm/v1/chat/completions` | `http://100.99.98.29:5000/v1/chat/completions` |

Environment example:

```bash
export OPENAI_BASE_URL=https://www.matrixminecraft.cn:24443/vllm/v1
export OPENAI_API_KEY=<VLLM_API_KEY>
```

PowerShell smoke test:

```powershell
curl.exe -k https://www.matrixminecraft.cn:24443/vllm/v1/models

$body = @{
  model = "qwen3.6"
  messages = @(@{ role = "user"; content = "Reply with exactly: pong" })
  max_tokens = 64
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
  -Uri "https://www.matrixminecraft.cn:24443/vllm/v1/chat/completions" `
  -Method POST `
  -ContentType "application/json" `
  -Headers @{ Authorization = "Bearer <VLLM_API_KEY>" } `
  -Body $body
```

## Anthropic-Compatible Access

Claude Code and Anthropic Messages-compatible clients should use the relay root as the base URL:

```bash
export ANTHROPIC_BASE_URL=https://www.matrixminecraft.cn:24443
export ANTHROPIC_API_KEY=<VLLM_API_KEY>
export ANTHROPIC_AUTH_TOKEN=<VLLM_API_KEY>
export ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3.6
export ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3.6
export ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3.6
```

| Capability | Public URL | Upstream target |
| --- | --- | --- |
| API base URL | `https://www.matrixminecraft.cn:24443` | Zoraxy root entrypoint |
| Messages API | `https://www.matrixminecraft.cn:24443/v1/messages` | `http://100.99.98.29:5000/v1/messages` |
| Models API | `https://www.matrixminecraft.cn:24443/v1/models` | `http://100.99.98.29:5000/v1/models` |

PowerShell smoke test:

```powershell
$body = @{
  model = "qwen3.6"
  max_tokens = 128
  messages = @(@{ role = "user"; content = "Reply with exactly: pong" })
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
  -Uri "https://www.matrixminecraft.cn:24443/v1/messages?beta=true" `
  -Method POST `
  -ContentType "application/json" `
  -Headers @{
    "anthropic-version" = "2023-06-01"
    "x-api-key" = "<VLLM_API_KEY>"
  } `
  -Body $body
```

## Zoraxy Route Contract

Zoraxy should be a transparent HTTP reverse proxy. WebSearch logic belongs in vLLM, not in the relay.

Required behavior:

| Requirement | Reason |
| --- | --- |
| Preserve request body | WebSearch tool definitions live in the JSON `tools` array. |
| Preserve query string | Claude Code can call `/v1/messages?beta=true`. |
| Preserve headers | Keep `anthropic-version`, `content-type`, `x-api-key`, and `authorization`. |
| Support streaming | Claude Code commonly uses SSE / chunked responses. |
| Use long timeouts | Strong WebSearch may need search, fetch, rerank, and generation time. Use 300-600 seconds. |
| Do not auto-append `/v1` | Claude Code appends `/v1/messages` itself from the base URL. |

Recommended Anthropic route:

```text
https://www.matrixminecraft.cn:24443/v1/messages
  -> http://100.99.98.29:5000/v1/messages
```

Avoid this broken route:

```text
https://www.matrixminecraft.cn:24443/v1/messages
  -> http://100.99.98.29:5000/v1/v1/messages
```

Current public route table:

| Public path | Zoraxy target | Purpose |
| --- | --- | --- |
| `/` | `100.99.98.29:8080` | OpenWebUI |
| `/vllm` | `100.99.98.29:5000` | OpenAI-compatible path |
| `/v1` | `100.99.98.29:5000/v1` | Anthropic-compatible path |
| `/anthropic` | `127.0.0.1:26200/anthropic` | Legacy fallback adapter |
| `/challenge` | `100.99.98.29:8010/challenge` | Challenge service |
| `/claw` | `100.99.98.29:18790` | ACPsClaw gateway |
| `/acps-aip-v2/beijing_food` | `127.0.0.1:26100/acps-aip-v2/beijing_food` | AIP mTLS bridge |
| `/acps-aip-v2/beijing_rural` | `127.0.0.1:26100/acps-aip-v2/beijing_rural` | AIP mTLS bridge |
| `/acps-aip-v2/beijing_urban` | `127.0.0.1:26100/acps-aip-v2/beijing_urban` | AIP mTLS bridge |
| `/acps-aip-v2/china_hotel` | `127.0.0.1:26100/acps-aip-v2/china_hotel` | AIP mTLS bridge |
| `/acps-aip-v2/china_transport` | `127.0.0.1:26100/acps-aip-v2/china_transport` | AIP mTLS bridge |

Restart Zoraxy after config changes:

```powershell
Restart-Service Zoraxy -Force
```

## Other Public Services

| Service | Public URL | Upstream target |
| --- | --- | --- |
| OpenWebUI | `https://www.matrixminecraft.cn:24443/` | `http://100.99.98.29:8080` |
| Challenge status | `https://www.matrixminecraft.cn:24443/challenge/status` | `http://100.99.98.29:8010/challenge/status` |
| Challenge API base | `https://www.matrixminecraft.cn:24443/challenge/api/v1` | `http://100.99.98.29:8010/challenge/api/v1` |
| ACPsClaw gateway | `https://www.matrixminecraft.cn:24443/claw/` | `http://100.99.98.29:18790` |

## AIP mTLS Public Services

The relay forwards AIP public paths to a local mTLS bridge on `127.0.0.1:26100`; the bridge then uses a client certificate to call the service machine.

| AIP service | Public health URL | Bridge target | mTLS upstream |
| --- | --- | --- | --- |
| `beijing_food` | `https://www.matrixminecraft.cn:24443/acps-aip-v2/beijing_food/health` | `http://127.0.0.1:26100/acps-aip-v2/beijing_food/health` | `https://100.99.98.29:59221/health` |
| `beijing_rural` | `https://www.matrixminecraft.cn:24443/acps-aip-v2/beijing_rural/health` | `http://127.0.0.1:26100/acps-aip-v2/beijing_rural/health` | `https://100.99.98.29:59222/health` |
| `beijing_urban` | `https://www.matrixminecraft.cn:24443/acps-aip-v2/beijing_urban/health` | `http://127.0.0.1:26100/acps-aip-v2/beijing_urban/health` | `https://100.99.98.29:59223/health` |
| `china_hotel` | `https://www.matrixminecraft.cn:24443/acps-aip-v2/china_hotel/health` | `http://127.0.0.1:26100/acps-aip-v2/china_hotel/health` | `https://100.99.98.29:59224/health` |
| `china_transport` | `https://www.matrixminecraft.cn:24443/acps-aip-v2/china_transport/health` | `http://127.0.0.1:26100/acps-aip-v2/china_transport/health` | `https://100.99.98.29:59225/health` |

## Common Checks

| Check | Command |
| --- | --- |
| OpenAI model list | `curl.exe -k https://www.matrixminecraft.cn:24443/vllm/v1/models` |
| Anthropic route model list | `curl.exe -k https://www.matrixminecraft.cn:24443/v1/models` |
| Challenge | `curl.exe -k https://www.matrixminecraft.cn:24443/challenge/status` |
| Claw | `curl.exe -k https://www.matrixminecraft.cn:24443/claw/` |
| AIP sample | `curl.exe -k https://www.matrixminecraft.cn:24443/acps-aip-v2/beijing_food/health` |
| vLLM TCP | `Test-NetConnection 100.99.98.29 -Port 5000` |
