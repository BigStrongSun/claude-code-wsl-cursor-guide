# WSL + Claude Code + cc-switch + Cursor 安装配置流程

本文档记录 Windows 上使用 Cursor、WSL 中运行 Claude Code，并接入远程模型 API 的完整流程。详细可复用版本已做成 Codex skill：`C:\Users\sunda\.codex\skills\wsl-claude-code-cursor`。

## 1. 目标架构

```text
Windows Cursor Claude Code 插件
-> claudeCode.claudeProcessWrapper
-> wsl.exe -d openclaw -- claude
-> WSL 内 Claude Code / cc-switch
-> Anthropic Messages API: http://100.99.98.29:5000/v1/messages
-> qwen3.6
```

注意区分两套协议：

- Claude Code 使用 Anthropic 兼容协议，环境变量是 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_MODEL`。
- OpenCode 使用 OpenAI 兼容协议，通常是 `baseURL=http://100.99.98.29:5000/v1` 和 `/v1/chat/completions`。

## 2. WSL 检查或安装

```powershell
wsl.exe -l -v
```

本机目标状态：

```text
openclaw  Running  2
```

如果没有 WSL：

```powershell
wsl.exe --install -d Ubuntu-24.04
```

如果需要导出/导入并命名为 `openclaw`：

```powershell
wsl.exe --export Ubuntu-24.04 .\.wsl\Ubuntu-24.04.tar
wsl.exe --unregister Ubuntu-24.04
wsl.exe --import openclaw .\.wsl\openclaw .\.wsl\Ubuntu-24.04.tar --version 2
```

验证用户和系统：

```powershell
wsl.exe -d openclaw -- bash -lc 'id; printf "USER=%s HOME=%s\n" "$USER" "$HOME"; cat /etc/os-release | sed -n "1,8p"'
```

## 3. sudo 和非交互 PATH

验证 sudo：

```powershell
wsl.exe -d openclaw -- bash -lc 'sudo -n whoami'
```

期望输出：

```text
root
```

如果需要配置免密 sudo：

```bash
echo 'openclaw ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/opencode
sudo chmod 0440 /etc/sudoers.d/opencode
sudo visudo -cf /etc/sudoers.d/opencode
sudo -n whoami
```

非交互 shell 不一定加载 `.bashrc`，所以关键命令要放到 `/usr/local/bin`。

## 4. Node.js 和 npm

先检查：

```powershell
wsl.exe -d openclaw -- bash -lc 'command -v node; command -v npm; node -v; npm -v; npm config get prefix'
```

本机已验证的 Node/npm prefix：

```text
/home/openclaw/.local/node-v22.22.2-linux-x64
```

如需暴露稳定入口：

```bash
sudo ln -sf "$HOME/.local/node-v22.22.2-linux-x64/bin/node" /usr/local/bin/node
sudo ln -sf "$HOME/.local/node-v22.22.2-linux-x64/bin/npm" /usr/local/bin/npm
```

验证非交互可用：

```powershell
wsl.exe -d openclaw -- bash -lc 'env -i HOME=/home/openclaw PATH=/usr/local/bin:/usr/bin:/bin node -v; env -i HOME=/home/openclaw PATH=/usr/local/bin:/usr/bin:/bin npm -v'
```

## 5. 安装 Claude Code 和 cc-switch

不要用 `sudo npm install -g`：

```powershell
wsl.exe -d openclaw -- bash -lc 'npm install -g @anthropic-ai/claude-code @hobeeliu/cc-switch'
```

创建稳定入口：

```powershell
wsl.exe -d openclaw -- bash -lc 'sudo ln -sf /home/openclaw/.local/node-v22.22.2-linux-x64/bin/claude /usr/local/bin/claude; sudo ln -sf /home/openclaw/.local/node-v22.22.2-linux-x64/bin/cc-switch /usr/local/bin/cc-switch'
```

验证：

```powershell
wsl.exe -d openclaw -- bash -lc 'command -v claude; claude --version; command -v cc-switch; cc-switch --version'
```

## 6. 配置 LLM API Key 和 cc-switch

创建目录：

```powershell
wsl.exe -d openclaw -- bash -lc 'mkdir -p ~/.claude/profiles/templates'
```

`~/.claude/settings.json` 和 `~/.claude/profiles/qwen3.6-vllm.json` 使用同一组核心配置：

```json
{
  "model": "qwen3.6",
  "availableModels": ["qwen3.6"],
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
  }
}
```

设置当前 profile：

```bash
printf 'qwen3.6-vllm' > ~/.claude/profiles/.current
chmod 700 ~/.claude ~/.claude/profiles ~/.claude/profiles/templates
chmod 600 ~/.claude/settings.json ~/.claude/profiles/qwen3.6-vllm.json ~/.claude/profiles/.current
```

验证：

```powershell
wsl.exe -d openclaw -- bash -lc 'cc-switch current; cc-switch test -c --endpoint chat --timeout 60s'
```

## 7. 远程 API 和代理验证

远程 API 是 `100.99.98.29:5000`，不是本机 vLLM 服务。不要因为本机有 `qwen3.6-vllm.service` 就误启动或修改它。

绕过代理检查模型列表：

```powershell
wsl.exe -d openclaw -- bash -lc 'env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy curl -sS --max-time 20 http://100.99.98.29:5000/v1/models'
```

如果看到 Squid HTML 或 503，优先检查代理环境变量，并确保设置：

```text
NO_PROXY=100.99.98.29,localhost,127.0.0.1
no_proxy=100.99.98.29,localhost,127.0.0.1
```

## 8. Cursor 插件配置

官方插件目录形如：

```text
C:\Users\sunda\.cursor\extensions\anthropic.claude-code-2.1.123-win32-x64
```

Cursor 是 Windows 进程，不能直接执行 WSL 的 `/usr/local/bin/claude`，所以需要 Windows wrapper。

wrapper 路径：

```text
C:\Users\sunda\AppData\Roaming\Cursor\User\scripts\claude-wsl-wrapper.exe
```

源码模板在 skill 中：

```text
C:\Users\sunda\.codex\skills\wsl-claude-code-cursor\scripts\ClaudeWslWrapper.cs
```

编译：

```powershell
New-Item -ItemType Directory -Force "$env:APPDATA\Cursor\User\scripts" | Out-Null
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe /platform:x64 /out:"$env:APPDATA\Cursor\User\scripts\claude-wsl-wrapper.exe" "$env:APPDATA\Cursor\User\scripts\ClaudeWslWrapper.cs"
```

Cursor 用户设置：

```text
C:\Users\sunda\AppData\Roaming\Cursor\User\settings.json
```

关键字段：

```json
{
  "claudeCode.claudeProcessWrapper": "C:\\Users\\sunda\\AppData\\Roaming\\Cursor\\User\\scripts\\claude-wsl-wrapper.exe",
  "claudeCode.disableLoginPrompt": true
}
```

同时可在 `claudeCode.environmentVariables` 中放入同一组 `ANTHROPIC_*`、`NO_PROXY`、`API_TIMEOUT_MS`。

配置后重启 Cursor，或执行 `Developer: Reload Window`。

## 9. 最终验证

WSL 侧：

```powershell
wsl.exe -d openclaw -- bash -lc 'node -v; npm -v; claude --version; cc-switch current; cc-switch test -c --endpoint chat --timeout 60s'
```

Windows wrapper 侧：

```powershell
$wrapper="$env:APPDATA\Cursor\User\scripts\claude-wsl-wrapper.exe"
$native="$env:USERPROFILE\.cursor\extensions\anthropic.claude-code-2.1.123-win32-x64\resources\native-binary\claude.exe"
& $wrapper $native --version
& $wrapper $native --print "Say hi" --model qwen3.6
```

期望：

```text
2.1.123 (Claude Code)
Hi!
```

## 10. 常见问题

`claude` 交互可用但自动化不可用：

原因通常是非交互 shell 没有加载 `.bashrc`。用 `/usr/local/bin` symlink 修复。

Cursor 插件为什么需要 wrapper：

插件运行在 Windows 扩展宿主里，不能直接 spawn WSL Linux 二进制。`claudeProcessWrapper` 会收到插件自带 `claude.exe` 路径和原始参数，wrapper 要丢弃这个 Windows `claude.exe` 参数，再转发到 `wsl.exe -d openclaw -- claude ...`。

Claude Code 到底走 Anthropic 还是 OpenAI：

Claude Code 走 Anthropic Messages 形状的 `/v1/messages`；OpenCode 走 OpenAI-compatible `/v1/chat/completions`。同一个远程服务可以同时暴露两种协议。

不要误碰本地 vLLM：

如果目标后端是 `http://100.99.98.29:5000`，就不要启动或调本机 `qwen3.6-vllm.service`，除非用户明确要求本机模型服务。
