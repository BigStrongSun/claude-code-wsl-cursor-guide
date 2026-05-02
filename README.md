# Claude Code WSL Cursor Guide

This repository documents a Windows + WSL Claude Code setup that can run from Cursor and route requests to a local or relayed vLLM backend.

## Main Guides

| Document | Purpose |
| --- | --- |
| [wsl-claude-code-cursor-install.md](wsl-claude-code-cursor-install.md) | Chinese setup guide for Windows Cursor, WSL Claude Code, cc-switch, and the wrapper. |
| [skills/wsl-claude-code-cursor/references/install-runbook.md](skills/wsl-claude-code-cursor/references/install-runbook.md) | Reusable runbook used by the local Codex skill. |
| [docs/vllm-public-access.md](docs/vllm-public-access.md) | Public relay URLs, Zoraxy routes, and OpenAI/Anthropic client configuration. |
| [docs/vllm-websearch-service.md](docs/vllm-websearch-service.md) | Service-machine vLLM, SearXNG, MCP browser, and Anthropic WebSearch behavior. |

## Current Backend Shape

```text
Windows Cursor Claude Code extension
  -> claudeCode.claudeProcessWrapper
  -> WSL claude
  -> Anthropic Messages-compatible endpoint
  -> vLLM qwen3.6
  -> optional local WebSearch through SearXNG
```

For Claude Code, set `ANTHROPIC_BASE_URL` to the endpoint root. Do not append `/v1`; Claude Code appends `/v1/messages` itself.

For OpenAI-compatible clients, set the OpenAI base URL to the `/vllm/v1` route documented in [docs/vllm-public-access.md](docs/vllm-public-access.md).

Do not commit real API keys. Use placeholders such as `<VLLM_API_KEY>` in repository docs and examples.
