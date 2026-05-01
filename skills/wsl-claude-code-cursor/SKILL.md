---
name: wsl-claude-code-cursor
description: Set up, repair, or document a Windows + WSL Claude Code workflow with Node/npm in WSL, Claude Code, cc-switch profiles, remote LLM API keys, OpenCode/Qwen-compatible endpoint notes, and Cursor/VS Code Claude Code plugin integration through a Windows-to-WSL wrapper. Use when installing WSL, configuring Claude Code in WSL, configuring cc-switch, configuring Cursor's official Anthropic Claude Code extension, or debugging whether Claude Code is using Anthropic Messages API vs OpenAI-compatible API.
---

# WSL Claude Code Cursor

## Workflow

Use this skill for Windows-hosted Cursor with Claude Code running inside a WSL distro such as `openclaw`.

1. Read [references/install-runbook.md](references/install-runbook.md) before making changes.
2. Verify live state first: WSL distro, Linux user, `node`, `npm`, `claude`, `cc-switch`, target API reachability, and Cursor extension/settings.
3. Keep three layers separate:
   - WSL toolchain: Node/npm, Claude Code, cc-switch, Linux PATH/symlinks.
   - Model API: Anthropic Messages endpoint for Claude Code, OpenAI-compatible endpoint for OpenCode.
   - Cursor integration: Windows extension process launching WSL Claude through `claudeCode.claudeProcessWrapper`.
4. Do not assume a local vLLM service is involved. Prefer the configured remote API in `ANTHROPIC_BASE_URL` / OpenCode `baseURL`.
5. If Windows Cursor must launch WSL Claude, use the wrapper template in [scripts/ClaudeWslWrapper.cs](scripts/ClaudeWslWrapper.cs) and compile it with .NET Framework `csc.exe`.

## Validation

After setup or repair, validate all relevant layers:

```powershell
wsl.exe -d openclaw -- bash -lc 'node -v; npm -v; claude --version; cc-switch current'
wsl.exe -d openclaw -- bash -lc 'cc-switch test -c --endpoint chat --timeout 60s'
& "$env:APPDATA\Cursor\User\scripts\claude-wsl-wrapper.exe" "$env:USERPROFILE\.cursor\extensions\anthropic.claude-code-2.1.123-win32-x64\resources\native-binary\claude.exe" --print "Say hi" --model qwen3.6
Test-Path "$env:USERPROFILE\.claude\projects\C--Users-sunda-Documents-Codex-repo-openclaw"
```

If direct `curl` to a Tailscale/private API fails but `cc-switch` succeeds, check proxy inheritance before blaming the model server. Use `NO_PROXY/no_proxy` for private IPs such as `100.99.98.29`. Never commit real API keys; use placeholders in public docs.
