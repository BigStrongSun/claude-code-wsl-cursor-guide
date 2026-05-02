# LLM API Requirements For Claude Code

Use this reference when changing Claude Code from one model endpoint to another.

## Required Protocol

Claude Code expects an Anthropic Messages-compatible API:

```text
POST <ANTHROPIC_BASE_URL>/v1/messages
GET  <ANTHROPIC_BASE_URL>/v1/models
```

The base URL should normally be the endpoint root:

```bash
export ANTHROPIC_BASE_URL=https://your-endpoint.example
```

Do not set it to `https://your-endpoint.example/v1` unless the target client or proxy explicitly requires that shape. Claude Code commonly appends `/v1/messages` itself.

## Minimum Request Compatibility

The backend should accept:

- `model`
- `max_tokens`
- `messages`
- optional `system`
- optional `stream`
- optional `tools`
- `anthropic-version` header
- `x-api-key` and/or `authorization` header

A minimal request should work:

```json
{
  "model": "qwen3.6",
  "max_tokens": 64,
  "messages": [
    {
      "role": "user",
      "content": "Reply with exactly: pong"
    }
  ]
}
```

## Streaming Requirement

Claude Code commonly uses streaming. The backend and every proxy in front of it should support SSE or chunked streaming without buffering the full response until completion.

If streaming is broken, symptoms can look like:

- Cursor panel appears stuck.
- Claude Code times out.
- Tool progress never appears.
- Final output appears only after a long delay.

## Tool Compatibility

Claude Code sends client-side tools and may also send Anthropic server-side tools. The backend should either support them or fail clearly.

Common expectations:

- Normal client tools use `name`, `description`, and `input_schema`.
- Anthropic WebSearch server-side tools may look like `web_search_20250305` or `web_search_20260209`.
- A backend that does not implement server-side WebSearch should return a clear unsupported-tool error rather than silently dropping the tool.

For local vLLM/Qwen compatibility, WebSearch usually requires an additional shim or patch. Do not assume a plain OpenAI-compatible `/v1/chat/completions` server can handle Claude Code WebSearch.

## Model Requirements

The served model should be able to:

- Follow tool-use instructions.
- Return structured JSON-like tool calls when the compatibility layer expects them.
- Handle long system prompts and tool schemas.
- Fit the intended context length for Claude Code sessions.
- Produce useful code edits and shell-command reasoning.

For Qwen-style models:

- Map all Claude model aliases to the served model name, for example `qwen3.6`.
- Consider disabling thinking in compatibility layers if thinking consumes the output budget or breaks tool-call formatting.
- Validate with realistic Claude Code prompts, not only a one-line ping.

## Environment Variables

Use both auth variables when unsure which one the installed Claude Code version or shim reads:

```bash
export ANTHROPIC_BASE_URL=https://your-endpoint.example
export ANTHROPIC_API_KEY=<YOUR_LLM_API_KEY>
export ANTHROPIC_AUTH_TOKEN=<YOUR_LLM_API_KEY>
export ANTHROPIC_MODEL=qwen3.6
export ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3.6
export ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3.6
export ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3.6
export API_TIMEOUT_MS=600000
```

For private or local addresses, bypass proxy inheritance:

```bash
export NO_PROXY=localhost,127.0.0.1,100.99.98.29
export no_proxy=localhost,127.0.0.1,100.99.98.29
```

Adjust the private IP list for the actual deployment.

## Validation Commands

Model list:

```powershell
curl.exe -k "$env:ANTHROPIC_BASE_URL/v1/models"
```

Messages request:

```powershell
$body = @{
  model = "qwen3.6"
  max_tokens = 64
  messages = @(@{ role = "user"; content = "Reply with exactly: pong" })
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
  -Uri "$env:ANTHROPIC_BASE_URL/v1/messages" `
  -Method POST `
  -ContentType "application/json" `
  -Headers @{
    "anthropic-version" = "2023-06-01"
    "x-api-key" = "<YOUR_LLM_API_KEY>"
  } `
  -Body $body
```

Claude Code profile check:

```powershell
wsl.exe -d openclaw -- bash -lc 'cc-switch current; cc-switch test -c --endpoint chat --timeout 60s'
```

Wrapper check:

```powershell
& "$env:APPDATA\Cursor\User\scripts\claude-wsl-wrapper.exe" "$env:USERPROFILE\.cursor\extensions\anthropic.claude-code-<version>-win32-x64\resources\native-binary\claude.exe" --version
```

## Common Misconfigurations

| Symptom | Likely cause |
| --- | --- |
| Requests go to `/v1/v1/messages` | `ANTHROPIC_BASE_URL` includes `/v1` when it should be the root. |
| CLI works but Cursor fails | Cursor wrapper or inherited environment differs from the shell. |
| Direct curl works but WSL/Cursor times out | Proxy variables are routing private traffic through a bad proxy. |
| Model list works but chat fails | `/v1/models` exists, but `/v1/messages` is not truly Anthropic-compatible. |
| Tool calls fail | Backend only supports OpenAI chat completions, not Anthropic Messages tool semantics. |
| WebSearch disappears | Proxy or backend dropped the `tools` body, or the backend lacks WebSearch support. |
