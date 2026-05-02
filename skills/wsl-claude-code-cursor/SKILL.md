---
name: wsl-claude-code-cursor
description: Set up, repair, or document Claude Code running in WSL for Windows Cursor through the official Claude Code extension and a Windows-to-WSL process wrapper. Use when installing or fixing WSL Node/npm, Claude Code CLI, cc-switch profiles, Cursor `claudeCode.claudeProcessWrapper`, shared Claude session history, or when changing Claude Code API endpoint/model/token settings and needing to verify that the target LLM endpoint is Anthropic Messages-compatible.
---

# WSL Claude Code Cursor

Use this skill for Windows-hosted Cursor where Claude Code should execute inside WSL. Keep the scope to the client/workstation side: WSL, Claude Code CLI, `cc-switch`, Cursor settings, wrapper compilation, API profile wiring, and validation. Do not manage the service machine, vLLM deployment, SearXNG, Zoraxy, certificates, or public relay infrastructure from this skill.

## Workflow

1. Read [references/install-runbook.md](references/install-runbook.md) before making changes.
2. If the user is changing endpoint, token, model name, context length, streaming, or WebSearch expectations, also read [references/llm-api-requirements.md](references/llm-api-requirements.md).
3. Verify live state before editing:
   - WSL distro and Linux user.
   - `node`, `npm`, `claude`, and `cc-switch` in a non-interactive WSL shell.
   - Claude config directory and active `cc-switch` profile.
   - Cursor user settings and installed Claude Code extension path.
4. Keep three layers separate:
   - WSL toolchain: Node/npm, Claude Code, `cc-switch`, Linux PATH/symlinks.
   - LLM API profile: Anthropic Messages-compatible base URL, token, model aliases, timeout, proxy bypass.
   - Cursor integration: Windows extension process launching WSL Claude through `claudeCode.claudeProcessWrapper`.
5. Use the wrapper template in [scripts/ClaudeWslWrapper.cs](scripts/ClaudeWslWrapper.cs). Compile it with .NET Framework `csc.exe` into `%APPDATA%\Cursor\User\scripts`.
6. Prefer a Windows-visible `CLAUDE_CONFIG_DIR` for Cursor use, for example `/mnt/c/Users/<user>/.claude`, so Cursor and WSL Claude can see the same session files.
7. Never commit real API keys. Use placeholders such as `<YOUR_LLM_API_KEY>` or `<VLLM_API_KEY>`.

## API Switching Rules

When switching Claude Code to a different backend:

- Set `ANTHROPIC_BASE_URL` to the endpoint root, not `/v1`, unless the backend explicitly requires otherwise.
- Set both `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` when compatibility is uncertain.
- Set all default model aliases (`ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`) to a model that the backend actually serves.
- Validate `/v1/models` and a real `/v1/messages` request before declaring the profile working.
- If the endpoint is private/Tailscale/local, set `NO_PROXY` and `no_proxy` so private traffic does not inherit a stale corporate or local proxy.
- If the backend is Qwen or another non-Claude model behind an Anthropic-compatible shim, explain that the protocol is Anthropic-compatible but the model is not Claude.

## Validation

After setup or repair, validate all relevant layers:

```powershell
wsl.exe -d openclaw -- bash -lc 'node -v; npm -v; claude --version; cc-switch current'
wsl.exe -d openclaw -- bash -lc 'cc-switch test -c --endpoint chat --timeout 60s'
& "$env:APPDATA\Cursor\User\scripts\claude-wsl-wrapper.exe" "$env:USERPROFILE\.cursor\extensions\anthropic.claude-code-<version>-win32-x64\resources\native-binary\claude.exe" --version
```

For session-history fixes, verify the Windows-visible project history exists:

```powershell
Test-Path "$env:USERPROFILE\.claude\projects\<windows-project-key>"
```

If direct API checks work but Cursor fails, inspect Cursor wrapper settings and the environment inherited by the wrapper before blaming the model backend.
