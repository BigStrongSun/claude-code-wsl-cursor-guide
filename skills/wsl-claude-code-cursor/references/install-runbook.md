# Windows + WSL Claude Code + Cursor Runbook

This runbook installs and wires Claude Code for a Windows host where Cursor runs on Windows, but Claude Code runs in WSL. It covers the workstation/client side only: WSL toolchain, Claude Code, `cc-switch`, API profile settings, shared local session history, and the Cursor plugin wrapper. It does not manage the model server, vLLM, SearXNG, public proxy, or certificate infrastructure.

The concrete machine used for this runbook is:

- Windows shell: PowerShell
- WSL distro: `openclaw`
- WSL user: `openclaw`
- Linux home: `/home/openclaw`
- Project path from Windows: `C:\Users\sunda\Documents\Codex repo\openclaw`
- Project path from WSL: `/mnt/c/Users/sunda/Documents/Codex repo/openclaw`
- Remote model API: `http://100.99.98.29:5000`
- Model ID: `qwen3.6`
- API key placeholder used in examples: `<YOUR_LLM_API_KEY>`

Replace those values when applying this to another machine.

## 1. Install Or Verify WSL

Check WSL state:

```powershell
wsl.exe -l -v
```

Expected for this setup:

```text
NAME       STATE    VERSION
openclaw   Running  2
```

If WSL is not installed:

```powershell
wsl.exe --install -d Ubuntu-24.04
```

If the distro must be renamed/imported as `openclaw`, use the export/import pattern:

```powershell
wsl.exe --export Ubuntu-24.04 .\.wsl\Ubuntu-24.04.tar
wsl.exe --unregister Ubuntu-24.04
wsl.exe --import openclaw .\.wsl\openclaw .\.wsl\Ubuntu-24.04.tar --version 2
```

Then create or verify the Linux user. For this machine the user is `openclaw`.

```powershell
wsl.exe -d openclaw -- bash -lc 'id; printf "USER=%s HOME=%s\n" "$USER" "$HOME"; cat /etc/os-release | sed -n "1,8p"'
```

## 2. Sudo And PATH Baseline

Verify passwordless sudo if automation needs it:

```powershell
wsl.exe -d openclaw -- bash -lc 'sudo -n whoami'
```

Expected:

```text
root
```

If needed, create a sudoers file from an elevated or root-capable shell:

```bash
echo 'openclaw ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/opencode
sudo chmod 0440 /etc/sudoers.d/opencode
sudo visudo -cf /etc/sudoers.d/opencode
sudo -n whoami
```

For non-interactive tools, do not rely on `.bashrc`. Put stable command symlinks in `/usr/local/bin`.

## 3. Install Node.js And npm In WSL

First verify whether Node/npm already exist:

```powershell
wsl.exe -d openclaw -- bash -lc 'command -v node; command -v npm; node -v; npm -v; npm config get prefix'
```

In the validated setup, Node/npm already existed under:

```text
/home/openclaw/.local/node-v22.22.2-linux-x64
```

If missing, prefer a user-local Node install or a distro package source that does not force global npm packages into root-owned paths. After install, expose stable symlinks:

```bash
sudo ln -sf "$HOME/.local/node-v22.22.2-linux-x64/bin/node" /usr/local/bin/node
sudo ln -sf "$HOME/.local/node-v22.22.2-linux-x64/bin/npm" /usr/local/bin/npm
```

Validate:

```powershell
wsl.exe -d openclaw -- bash -lc 'env -i HOME=/home/openclaw PATH=/usr/local/bin:/usr/bin:/bin node -v; env -i HOME=/home/openclaw PATH=/usr/local/bin:/usr/bin:/bin npm -v'
```

## 4. Install Claude Code And cc-switch In WSL

Install both packages with npm, without `sudo npm install -g`:

```powershell
wsl.exe -d openclaw -- bash -lc 'npm install -g @anthropic-ai/claude-code @hobeeliu/cc-switch'
```

Expose stable command symlinks:

```powershell
wsl.exe -d openclaw -- bash -lc 'sudo ln -sf /home/openclaw/.local/node-v22.22.2-linux-x64/bin/claude /usr/local/bin/claude; sudo ln -sf /home/openclaw/.local/node-v22.22.2-linux-x64/bin/cc-switch /usr/local/bin/cc-switch'
```

Validate:

```powershell
wsl.exe -d openclaw -- bash -lc 'command -v claude; claude --version; command -v cc-switch; cc-switch --version'
```

Expected shape:

```text
/usr/local/bin/claude
2.1.123 (Claude Code)
/usr/local/bin/cc-switch
cc-switch version 1.1.1
```

## 5. Understand API Protocols

Claude Code uses Anthropic-style settings and endpoint shape:

```text
ANTHROPIC_BASE_URL=http://100.99.98.29:5000
ANTHROPIC_AUTH_TOKEN=<YOUR_LLM_API_KEY>
ANTHROPIC_MODEL=qwen3.6
```

It calls an Anthropic Messages-compatible endpoint:

```text
POST /v1/messages
```

OpenCode with `@ai-sdk/openai-compatible` uses an OpenAI-compatible endpoint:

```text
baseURL=http://100.99.98.29:5000/v1
POST /v1/chat/completions
```

These are different wire protocols. A server may expose both, but Claude Code should be configured through `ANTHROPIC_*`, not `OPENAI_*`.

Before switching Claude Code to a different API endpoint or model, read [llm-api-requirements.md](llm-api-requirements.md). The target backend must be Anthropic Messages-compatible, not merely OpenAI chat-completions-compatible.

## 6. Configure LLM API Keys And cc-switch

Create a Windows-visible Claude settings directory. This lets the Windows Cursor extension and WSL Claude Code read the same session history:

```powershell
wsl.exe -d openclaw -- bash -lc 'mkdir -p /mnt/c/Users/sunda/.claude/profiles/templates'
```

Create `C:\Users\sunda\.claude\settings.json` from Windows, or `/mnt/c/Users/sunda/.claude/settings.json` from WSL:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://100.99.98.29:5000",
    "ANTHROPIC_AUTH_TOKEN": "<YOUR_LLM_API_KEY>",
    "ANTHROPIC_MODEL": "qwen3.6",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "qwen3.6",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "qwen3.6",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "qwen3.6",
    "ANTHROPIC_CUSTOM_MODEL_OPTION": "qwen3.6",
    "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME": "Qwen3.6 vLLM",
    "ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION": "Remote qwen3.6 served by OpenAI-compatible API",
    "CLAUDE_CODE_ATTRIBUTION_HEADER": "0",
    "API_TIMEOUT_MS": "600000",
    "NO_PROXY": "100.99.98.29,localhost,127.0.0.1",
    "no_proxy": "100.99.98.29,localhost,127.0.0.1"
  },
  "model": "qwen3.6",
  "availableModels": [
    "qwen3.6"
  ],
  "theme": "auto"
}
```

Create `/mnt/c/Users/sunda/.claude/profiles/qwen3.6-vllm.json` with the same model/env payload, then set the active profile:

```bash
printf 'qwen3.6-vllm' > /mnt/c/Users/sunda/.claude/profiles/.current
```

Validate:

```powershell
wsl.exe -d openclaw -- bash -lc 'CLAUDE_CONFIG_DIR=/mnt/c/Users/sunda/.claude cc-switch current; CLAUDE_CONFIG_DIR=/mnt/c/Users/sunda/.claude cc-switch view qwen3.6-vllm --raw; CLAUDE_CONFIG_DIR=/mnt/c/Users/sunda/.claude cc-switch test -c --endpoint chat --timeout 60s'
```

Expected:

```text
Current configuration: qwen3.6-vllm
Result: Configuration is functional
```

If Claude Code was previously run with the default WSL config directory, migrate existing state into the shared Windows-visible config directory:

```powershell
wsl.exe -d openclaw -- bash -lc 'mkdir -p /mnt/c/Users/sunda/.claude/projects; cp -a ~/.claude/profiles /mnt/c/Users/sunda/.claude/ 2>/dev/null || true; cp -a ~/.claude/cc-switch /mnt/c/Users/sunda/.claude/ 2>/dev/null || true; cp -a ~/.claude/history.jsonl /mnt/c/Users/sunda/.claude/ 2>/dev/null || true; cp -a ~/.claude/sessions /mnt/c/Users/sunda/.claude/ 2>/dev/null || true; cp -a ~/.claude/projects/-mnt-c-Users-sunda-Documents-Codex-repo-openclaw /mnt/c/Users/sunda/.claude/projects/ 2>/dev/null || true'
```

Cursor's Sessions view runs in the Windows extension process and lists sessions by Windows project path. If existing sessions were created in WSL, add a Windows project-key junction that points to the WSL project-key directory:

```powershell
$projects="$env:USERPROFILE\.claude\projects"
$windowsKey="C--Users-sunda-Documents-Codex-repo-openclaw"
$wslKey="-mnt-c-Users-sunda-Documents-Codex-repo-openclaw"
New-Item -ItemType Directory -Force $projects | Out-Null
cmd /c mklink /J "$projects\$windowsKey" "$projects\$wslKey"
```

## 7. Verify Remote API And Proxy Behavior

For private/Tailscale addresses, proxy variables can break direct requests. Verify with proxy variables cleared:

```powershell
wsl.exe -d openclaw -- bash -lc 'env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy curl -sS --max-time 20 http://100.99.98.29:5000/v1/models'
```

If direct API calls fail with Squid/503 but `cc-switch test` succeeds, suspect inherited proxy state. Keep these env vars in Claude/Cursor config:

```text
NO_PROXY=100.99.98.29,localhost,127.0.0.1
no_proxy=100.99.98.29,localhost,127.0.0.1
```

## 8. Configure OpenCode For The Same Remote API

OpenCode's config is separate from Claude Code. For this machine:

```text
~/.config/opencode/opencode.json
```

Relevant shape:

```json
{
  "provider": {
    "qwen-vllm": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Qwen 3.6 (vLLM)",
      "options": {
        "baseURL": "http://100.99.98.29:5000/v1",
        "apiKey": "<YOUR_LLM_API_KEY>",
        "chat_template_kwargs": {
          "enable_thinking": false
        },
        "timeout": 600000
      },
      "models": {
        "qwen3.6": {
          "name": "qwen3.6",
          "limit": {
            "context": 262144,
            "output": 8192
          }
        }
      }
    }
  },
  "model": "qwen-vllm/qwen3.6",
  "small_model": "qwen-vllm/qwen3.6"
}
```

Important distinction:

- OpenCode uses `/v1/chat/completions` through an OpenAI-compatible provider.
- Claude Code uses `/v1/messages` through Anthropic-compatible environment variables.
- Qwen thinking may need to be disabled for OpenCode through `chat_template_kwargs.enable_thinking=false`.

## 9. Install And Configure The Cursor Claude Code Plugin

The official Cursor/VS Code extension is:

```text
anthropic.claude-code-<version>-win32-x64
```

It contributes two views:

- Main Claude Code chat view.
- Sessions/history view.

They share the same `claudeCode.*` settings.

Cursor is a Windows process. It cannot directly spawn WSL's `/usr/local/bin/claude`. Use `claudeCode.claudeProcessWrapper` with a Windows executable wrapper.

## 10. Build The Windows-to-WSL Wrapper

Create this source file:

```text
C:\Users\sunda\AppData\Roaming\Cursor\User\scripts\ClaudeWslWrapper.cs
```

Use the template from the skill resource:

```text
scripts/ClaudeWslWrapper.cs
```

Compile it with the .NET Framework compiler built into Windows:

```powershell
New-Item -ItemType Directory -Force "$env:APPDATA\Cursor\User\scripts" | Out-Null
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe /platform:x64 /out:"$env:APPDATA\Cursor\User\scripts\claude-wsl-wrapper.exe" "$env:APPDATA\Cursor\User\scripts\ClaudeWslWrapper.cs"
```

The wrapper intentionally discards the Windows extension's bundled `claude.exe` argument and runs:

```text
wsl.exe -d openclaw -- env HOME=/home/openclaw CLAUDE_CONFIG_DIR=/mnt/c/Users/sunda/.claude ... claude <original args>
```

`CLAUDE_CONFIG_DIR` is required for stable Cursor session history. Without it, WSL Claude writes conversations under `/home/openclaw/.claude`, while the Windows Cursor extension lists sessions from `C:\Users\sunda\.claude`.

## 11. Configure Cursor User Settings

Edit:

```text
C:\Users\sunda\AppData\Roaming\Cursor\User\settings.json
```

Add:

```json
{
  "claudeCode.claudeProcessWrapper": "C:\\Users\\sunda\\AppData\\Roaming\\Cursor\\User\\scripts\\claude-wsl-wrapper.exe",
  "claudeCode.disableLoginPrompt": true,
  "claudeCode.environmentVariables": [
    {
      "name": "ANTHROPIC_BASE_URL",
      "value": "http://100.99.98.29:5000"
    },
    {
      "name": "ANTHROPIC_AUTH_TOKEN",
      "value": "<YOUR_LLM_API_KEY>"
    },
    {
      "name": "ANTHROPIC_MODEL",
      "value": "qwen3.6"
    },
    {
      "name": "ANTHROPIC_DEFAULT_OPUS_MODEL",
      "value": "qwen3.6"
    },
    {
      "name": "ANTHROPIC_DEFAULT_SONNET_MODEL",
      "value": "qwen3.6"
    },
    {
      "name": "ANTHROPIC_DEFAULT_HAIKU_MODEL",
      "value": "qwen3.6"
    },
    {
      "name": "ANTHROPIC_CUSTOM_MODEL_OPTION",
      "value": "qwen3.6"
    },
    {
      "name": "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME",
      "value": "Qwen3.6 vLLM"
    },
    {
      "name": "ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION",
      "value": "Remote qwen3.6 served by OpenAI-compatible API"
    },
    {
      "name": "CLAUDE_CODE_ATTRIBUTION_HEADER",
      "value": "0"
    },
    {
      "name": "API_TIMEOUT_MS",
      "value": "600000"
    },
    {
      "name": "NO_PROXY",
      "value": "100.99.98.29,localhost,127.0.0.1"
    },
    {
      "name": "no_proxy",
      "value": "100.99.98.29,localhost,127.0.0.1"
    }
  ]
}
```

Reload Cursor with `Developer: Reload Window`, or restart Cursor.

## 12. Configure Bypass Permissions Optional

Claude Code bypass permissions skips permission prompts. Treat it as an explicit user choice, not a silent default. If the user did not already ask for it, explain the risk and ask whether they want it enabled.

Use the bundled script from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\skills\wsl-claude-code-cursor\scripts\Set-ClaudeBypassPermissions.ps1 -Mode status
```

Enable bypass permissions:

```powershell
powershell -ExecutionPolicy Bypass -File .\skills\wsl-claude-code-cursor\scripts\Set-ClaudeBypassPermissions.ps1 -Mode enable
```

Disable bypass permissions:

```powershell
powershell -ExecutionPolicy Bypass -File .\skills\wsl-claude-code-cursor\scripts\Set-ClaudeBypassPermissions.ps1 -Mode disable
```

The script updates both layers:

- Cursor settings: `claudeCode.allowDangerouslySkipPermissions=true` and `claudeCode.initialPermissionMode=bypassPermissions`.
- Claude settings: `permissions.defaultMode=bypassPermissions`.

When disabling, the script sets `claudeCode.allowDangerouslySkipPermissions=false` and removes only the bypass defaults it previously manages. It keeps unrelated settings in place. If the wrapper uses a non-default shared config directory, pass it explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File .\skills\wsl-claude-code-cursor\scripts\Set-ClaudeBypassPermissions.ps1 -Mode enable -ClaudeConfigDir "C:\Users\sunda\.claude"
```

## 13. Validate Cursor Wrapper

Run from PowerShell:

```powershell
$wrapper="$env:APPDATA\Cursor\User\scripts\claude-wsl-wrapper.exe"
$native="$env:USERPROFILE\.cursor\extensions\anthropic.claude-code-2.1.123-win32-x64\resources\native-binary\claude.exe"
& $wrapper $native --version
& $wrapper $native --print "Say hi" --model qwen3.6
Test-Path "$env:USERPROFILE\.claude\projects\C--Users-sunda-Documents-Codex-repo-openclaw"
```

Expected:

```text
2.1.123 (Claude Code)
Hi!
```

If this works, the Cursor extension should work after reload.

## 14. Common Failure Modes

`claude` works interactively but not from tools:

- Cause: non-interactive shell does not source `.bashrc`.
- Fix: symlink `/usr/local/bin/claude` and `/usr/local/bin/cc-switch`.

Cursor plugin cannot launch WSL Claude:

- Cause: Windows extension host cannot spawn WSL Linux binaries directly.
- Fix: use `claudeCode.claudeProcessWrapper` with a Windows `.exe` wrapper.

Cursor plugin loses past conversations after restart:

- Cause: the Windows extension lists sessions from `C:\Users\sunda\.claude`, but WSL Claude wrote them under `/home/openclaw/.claude`.
- Fix: set `CLAUDE_CONFIG_DIR=/mnt/c/Users/sunda/.claude` in the wrapper, migrate old WSL sessions, and create the Windows project-key junction.

Direct API curl returns Squid HTML/503:

- Cause: inherited proxy variables route private IP traffic through a stale proxy.
- Fix: set `NO_PROXY/no_proxy`, and test with `env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy`.

OpenCode and Claude Code appear to use different APIs:

- Correct: OpenCode uses OpenAI-compatible `/v1/chat/completions`; Claude Code uses Anthropic-compatible `/v1/messages`.

Do not start or modify local `qwen3.6-vllm.service` unless the user's target backend is explicitly local. If the target is `http://100.99.98.29:5000`, treat it as remote and leave local vLLM alone.
