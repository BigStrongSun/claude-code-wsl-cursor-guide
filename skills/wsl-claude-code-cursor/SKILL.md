---
name: wsl-claude-code-cursor
description: Set up, repair, or document Claude Code running in WSL for Windows Cursor through the official Claude Code extension and a Windows-to-WSL process wrapper. Use when installing or fixing WSL Node/npm, Claude Code CLI, cc-switch profiles, Cursor `claudeCode.claudeProcessWrapper`, shared Claude session history, Chinese setup prompts, or when changing Claude Code API endpoint/model/token settings and needing to verify that the target LLM endpoint is Anthropic Messages-compatible.
---

# WSL Claude Code Cursor

这个 skill 用来让 Codex 帮用户在 Windows + WSL + Cursor 环境里安装、修复或解释 Claude Code。它只处理客户端/工作站侧：WSL、Node/npm、Claude Code CLI、`cc-switch`、Cursor 插件、Windows-to-WSL wrapper、Claude 本地配置和会话历史。不要用这个 skill 去管理服务机、vLLM 部署、SearXNG、Zoraxy、公网代理、证书或模型权重。

## 中文默认提示词

当用户想让 Codex 使用这个 skill 时，可以直接这样说：

```text
使用 wsl-claude-code-cursor skill，帮我在 Windows Cursor 中接入 WSL 里的 Claude Code。请先检查当前 WSL、Node/npm、claude、cc-switch、Cursor 插件和 wrapper 状态，再修复配置，最后验证 Claude Code 能从 Cursor 启动。
```

如果用户要切换 API 或模型，可以这样说：

```text
使用 wsl-claude-code-cursor skill，帮我把 Cursor 插件里的 Claude Code 切到新的 Anthropic-compatible API。请检查这个 API 是否满足 Claude Code 的 /v1/messages、streaming、tools、模型别名和 token 要求，并更新 WSL/cc-switch/wrapper/Cursor 配置。
```

如果用户只想修复历史会话，可以这样说：

```text
使用 wsl-claude-code-cursor skill，帮我修复 Cursor 重启后看不到 WSL Claude Code 历史会话的问题。请检查 CLAUDE_CONFIG_DIR、Windows .claude 目录、WSL 项目 key 和 Cursor Sessions 视图读取路径。
```

## 使用边界

应该做：

- 检查或安装 WSL 里的 Node.js/npm。
- 安装或修复 WSL 里的 `claude` 和 `cc-switch`。
- 配置 Claude Code 的 `settings.json`、profiles 和 active profile。
- 配置 Cursor 用户设置里的 `claudeCode.claudeProcessWrapper`。
- 编译 Windows wrapper，让 Cursor 能启动 WSL `claude`。
- 配置 `CLAUDE_CONFIG_DIR`，让 Cursor 插件和 WSL CLI 共用历史会话。
- 验证 Anthropic-compatible API 是否满足 Claude Code 需要。

不应该做：

- 部署或升级 vLLM。
- 修改 SearXNG、MCP browser、Zoraxy 或公网中转。
- 管理证书、域名、端口映射或服务机 systemd。
- 提交真实 API key、token、`.claude` 运行态历史或私有日志。

## 工作流

1. 读取 [references/install-runbook.md](references/install-runbook.md)。
2. 如果用户要切换 endpoint、token、模型名、上下文、streaming、tools 或 WebSearch，读取 [references/llm-api-requirements.md](references/llm-api-requirements.md)。
3. 先检查现场，不要直接改配置：
   - `wsl.exe -l -v`
   - WSL 用户、`HOME`、发行版版本。
   - 非交互 shell 下的 `node`、`npm`、`claude`、`cc-switch`。
   - `~/.claude` 或共享 `CLAUDE_CONFIG_DIR`。
   - Cursor `settings.json`。
   - 已安装的 `anthropic.claude-code-*` 扩展路径。
4. 分层判断问题：
   - WSL 工具链问题：PATH、npm prefix、symlink、sudo、Node 版本。
   - API profile 问题：base URL、token、模型别名、timeout、proxy、协议兼容。
   - Cursor 集成问题：wrapper 路径、wrapper 编译、Windows/WSL 路径映射、Cursor 插件环境。
   - 会话历史问题：`CLAUDE_CONFIG_DIR`、Windows project key、WSL project key、junction。
5. 使用 [scripts/ClaudeWslWrapper.cs](scripts/ClaudeWslWrapper.cs) 作为 wrapper 模板。编译到 `%APPDATA%\Cursor\User\scripts`。
6. 优先把 Cursor 场景的 Claude 配置放到 Windows 可见目录，例如 `/mnt/c/Users/<user>/.claude`，并通过 `CLAUDE_CONFIG_DIR` 注入 WSL Claude。
7. 所有示例密钥必须写成 `<YOUR_LLM_API_KEY>` 或 `<VLLM_API_KEY>`。

## API 切换规则

切换 Claude Code 后端时，先确认目标后端是 Anthropic Messages-compatible，而不是只有 OpenAI `/v1/chat/completions`。

必须确认：

- `ANTHROPIC_BASE_URL` 通常指向 endpoint 根路径，不带 `/v1`。
- 后端支持 `POST /v1/messages`。
- 后端支持 `GET /v1/models` 或至少有等价模型探测方式。
- 后端能处理 `model`、`max_tokens`、`messages`、`system`、`stream`、`tools`。
- 代理不丢 `anthropic-version`、`content-type`、`x-api-key`、`authorization`。
- streaming/SSE 不被代理缓冲到请求结束。
- 所有 Claude model alias 都映射到实际存在的模型。

推荐同时设置：

```bash
ANTHROPIC_API_KEY=<YOUR_LLM_API_KEY>
ANTHROPIC_AUTH_TOKEN=<YOUR_LLM_API_KEY>
ANTHROPIC_MODEL=<MODEL_NAME>
ANTHROPIC_DEFAULT_OPUS_MODEL=<MODEL_NAME>
ANTHROPIC_DEFAULT_SONNET_MODEL=<MODEL_NAME>
ANTHROPIC_DEFAULT_HAIKU_MODEL=<MODEL_NAME>
API_TIMEOUT_MS=600000
```

如果后端是 Qwen、Llama、DeepSeek 等非 Claude 模型，要明确说明：这是 Anthropic 协议兼容，不是 Claude 模型本身。工具调用、WebSearch、thinking 行为和上下文长度都需要实测。

## 常见故障判断

| 现象 | 优先检查 |
| --- | --- |
| PowerShell 能跑，Cursor 不能跑 | `claudeCode.claudeProcessWrapper` 路径、wrapper 编译结果、Cursor 扩展版本。 |
| WSL 交互 shell 能跑，自动化不能跑 | 非交互 PATH、`/usr/local/bin/claude`、npm prefix。 |
| 模型列表能访问，聊天失败 | `/v1/messages` 是否真的 Anthropic-compatible。 |
| 直连 API 正常，Cursor 超时 | wrapper 继承的 proxy、`NO_PROXY/no_proxy`、timeout。 |
| Cursor 重启后历史没了 | `CLAUDE_CONFIG_DIR` 是否共享、Windows project-key junction 是否存在。 |
| WebSearch 消失或报错 | 后端是否支持 Anthropic server-side WebSearch；这个 skill 只验证客户端请求形状，不修服务端。 |

## 验证命令

WSL 工具链：

```powershell
wsl.exe -d openclaw -- bash -lc 'node -v; npm -v; claude --version; cc-switch current'
```

API profile：

```powershell
wsl.exe -d openclaw -- bash -lc 'cc-switch test -c --endpoint chat --timeout 60s'
```

Cursor wrapper：

```powershell
$wrapper="$env:APPDATA\Cursor\User\scripts\claude-wsl-wrapper.exe"
$native="$env:USERPROFILE\.cursor\extensions\anthropic.claude-code-<version>-win32-x64\resources\native-binary\claude.exe"
& $wrapper $native --version
```

共享历史目录：

```powershell
Test-Path "$env:USERPROFILE\.claude\projects\<windows-project-key>"
```

如果这些都通过，再让用户重启 Cursor 或运行 `Developer: Reload Window`。
