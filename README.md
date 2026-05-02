# Claude Code + WSL + Cursor + vLLM 本地部署指南

这个仓库记录的是一套个人本地 AI 开发环境的搭建过程：在 Windows 上使用 Cursor 的 Claude Code 插件，但把真正的 Claude Code CLI 放在 WSL 里运行，再把请求转发到自己部署的 vLLM 服务。后端模型目前是 `qwen3.6`，同时补上了本地 WebSearch 能力，让 Claude Code 的联网搜索请求也可以走自己的服务机。

它不是一个“一键安装器”，而是一份尽量可复用、可审计的部署说明。新手可以把它当成路线图：先理解每一层负责什么，再按文档逐步配置。

## 我做了什么

我把整个系统拆成四层：

1. Windows 客户端层：Cursor 运行在 Windows 上，安装官方 Claude Code 插件。
2. WSL 工具层：Claude Code CLI、Node.js、npm、`cc-switch` 实际安装在 WSL 里。
3. 模型服务层：服务机运行 vLLM，对外提供 OpenAI-compatible 和 Anthropic-compatible API。
4. 公网中转层：中转机用 Zoraxy 把公网 HTTPS 请求透明转发到服务机。

最终效果是：

- Cursor 里的 Claude Code 插件可以调用 WSL 里的 `claude`。
- Claude Code 可以使用自己部署的 `qwen3.6` vLLM 后端，而不是官方 Claude 模型。
- OpenAI-compatible 客户端可以走 `/vllm/v1`。
- Claude Code / Anthropic Messages-compatible 客户端可以走 `/v1/messages`。
- Claude Code 的 WebSearch server-side tool 可以在服务机侧通过 vLLM 补丁、本地 SearXNG 和 MCP browser 服务执行。
- Cursor 重启后，Claude Code 的历史会话能从共享的 `.claude` 目录恢复。

## 总体架构

```text
Windows Cursor
  -> Claude Code 插件
  -> claudeCode.claudeProcessWrapper
  -> Windows wrapper exe
  -> wsl.exe -d openclaw -- claude
  -> WSL Claude Code CLI
  -> Anthropic Messages-compatible API
  -> 公网中转或 Tailscale 内网
  -> vLLM qwen3.6
  -> 可选 WebSearch: SearXNG + MCP browser + vLLM patches
```

OpenAI-compatible 客户端走另一条入口：

```text
OpenAI SDK / OpenAI-compatible tool
  -> https://www.matrixminecraft.cn:24443/vllm/v1
  -> Zoraxy
  -> http://100.99.98.29:5000/v1
  -> vLLM qwen3.6
```

Claude Code / Anthropic-compatible 客户端使用根路径作为 base URL：

```text
Claude Code
  ANTHROPIC_BASE_URL=https://www.matrixminecraft.cn:24443
  -> POST /v1/messages
  -> Zoraxy
  -> http://100.99.98.29:5000/v1/messages
  -> vLLM qwen3.6
```

注意：`ANTHROPIC_BASE_URL` 不要写成 `.../v1`，否则客户端可能拼出 `/v1/v1/messages`。

## 仓库文档怎么读

建议按这个顺序看：

| 文档 | 适合谁看 | 内容 |
| --- | --- | --- |
| [wsl-claude-code-cursor-install.md](wsl-claude-code-cursor-install.md) | 第一次搭建的人 | 中文主线安装说明：Windows、WSL、Claude Code、`cc-switch`、Cursor wrapper。 |
| [skills/wsl-claude-code-cursor/README.md](skills/wsl-claude-code-cursor/README.md) | 想交给 Codex 自动执行的人 | 可复用 Codex skill，聚焦 WSL + Cursor 里运行 Claude Code，不管理服务机和代理。 |
| [skills/wsl-claude-code-cursor/references/install-runbook.md](skills/wsl-claude-code-cursor/references/install-runbook.md) | 想复用流程的人 | 更结构化的 runbook，适合按步骤验证和排障。 |
| [skills/wsl-claude-code-cursor/scripts/ClaudeWslWrapper.cs](skills/wsl-claude-code-cursor/scripts/ClaudeWslWrapper.cs) | 需要接 Cursor 插件的人 | Windows 到 WSL 的 Claude Code wrapper 模板。 |
| [docs/vllm-public-access.md](docs/vllm-public-access.md) | 需要公网访问的人 | 公网入口、OpenAI/Anthropic base URL、Zoraxy 路由和透明转发要求。 |
| [docs/vllm-websearch-service.md](docs/vllm-websearch-service.md) | 维护服务机的人 | vLLM、SearXNG、MCP browser、Claude Code WebSearch 补丁、验证和排障。 |

## 客户端侧：Windows Cursor 调 WSL Claude Code

Cursor 是 Windows 程序，不能直接执行 WSL 里的 Linux `claude` 二进制。所以这里用了 `claudeCode.claudeProcessWrapper`：

```text
Cursor 插件传入自己的 claude.exe 参数
  -> wrapper 丢弃这个 Windows claude.exe
  -> wrapper 调用 wsl.exe -d openclaw -- env ... claude <原始参数>
```

wrapper 里最关键的几件事：

- 指定 WSL distro：`openclaw`
- 设置稳定 PATH：`/usr/local/bin:/usr/bin:/bin`
- 设置模型 API 环境变量：`ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、模型名等
- 设置 `NO_PROXY`，避免 Tailscale / 私网请求被错误代理
- 设置 `CLAUDE_CONFIG_DIR=/mnt/c/Users/sunda/.claude`

`CLAUDE_CONFIG_DIR` 很重要。没有它时，WSL CLI 会把历史写到：

```text
/home/openclaw/.claude
```

而 Cursor 插件在 Windows 侧会尝试读取：

```text
C:\Users\sunda\.claude
```

两边不一致时，Cursor 重启后可能看不到 CLI 里的历史会话。这个仓库里的 runbook 已经记录了共享配置目录和 Windows project-key junction 的处理方式。

## 服务端侧：vLLM 与 qwen3.6

服务机通过 vLLM 提供模型 API。当前模型名统一写作：

```text
qwen3.6
```

它同时服务两类协议：

- OpenAI-compatible：`/v1/chat/completions`、`/v1/models`、`/v1/responses`
- Anthropic-compatible：`/v1/messages`、`/v1/models`

这只是协议兼容，不代表后端部署了 Claude 模型。Claude Code 发来的 Anthropic Messages 请求会被 vLLM 兼容层处理，再交给 `qwen3.6`。

## WebSearch 是怎么接进去的

Claude Code 会把 WebSearch 当成 Anthropic server-side tool 发到 `/v1/messages`，例如：

```json
{
  "type": "web_search_20250305",
  "name": "web_search",
  "max_uses": 8
}
```

本项目服务机侧的处理方式是：

1. vLLM Anthropic Messages 补丁识别 `web_search_20250305` / `web_search_20260209`。
2. 从 Claude Code 的请求或 helper prompt 中提取搜索 query。
3. 调用本地 SearXNG 做联网检索。
4. 抓取和提取候选网页正文。
5. 做 URL 去重、正文截取、query-aware rerank。
6. 把搜索证据作为 tool result 注入回模型。
7. 返回 Anthropic 风格的 `server_tool_use`、`web_search_tool_result`、最终文本和引用信息。

OpenAI Responses API 的 `web_search_preview` 则通过 vLLM 的 MCP tool server 映射到名为 `browser` 的 MCP 服务。

详细参数、环境变量和排障见 [docs/vllm-websearch-service.md](docs/vllm-websearch-service.md)。

## 公网中转怎么做

公网入口目前是：

```text
https://www.matrixminecraft.cn:24443
```

因为家宽环境下常见的 `80/443` 端口可能不可用，所以 HTTPS 使用高端口 `24443`。

Zoraxy 的职责是透明反向代理。它不应该理解 WebSearch，也不应该改写请求 body。尤其要保留：

- HTTP method
- path
- query string，例如 `/v1/messages?beta=true`
- request body
- `anthropic-version`
- `content-type`
- `x-api-key`
- `authorization`
- SSE / chunked streaming response

OpenAI-compatible 客户端使用：

```bash
export OPENAI_BASE_URL=https://www.matrixminecraft.cn:24443/vllm/v1
export OPENAI_API_KEY=<VLLM_API_KEY>
```

Claude Code 使用：

```bash
export ANTHROPIC_BASE_URL=https://www.matrixminecraft.cn:24443
export ANTHROPIC_API_KEY=<VLLM_API_KEY>
export ANTHROPIC_AUTH_TOKEN=<VLLM_API_KEY>
export ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3.6
export ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3.6
export ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3.6
```

详细路由表和验证命令见 [docs/vllm-public-access.md](docs/vllm-public-access.md)。

## 最小验证路径

先确认 WSL 里的工具链：

```powershell
wsl.exe -d openclaw -- bash -lc 'node -v; npm -v; claude --version; cc-switch current'
```

验证 Cursor wrapper：

```powershell
$wrapper="$env:APPDATA\Cursor\User\scripts\claude-wsl-wrapper.exe"
$native="$env:USERPROFILE\.cursor\extensions\anthropic.claude-code-2.1.123-win32-x64\resources\native-binary\claude.exe"
& $wrapper $native --version
```

验证 OpenAI-compatible 公网入口：

```powershell
curl.exe -k https://www.matrixminecraft.cn:24443/vllm/v1/models
```

验证 Anthropic-compatible 公网入口：

```powershell
curl.exe -k https://www.matrixminecraft.cn:24443/v1/models
```

验证服务机三个核心服务：

```powershell
wsl -d Ubuntu -- bash -lc "systemctl --user is-active vllm-qwen36-tp.service; systemctl --user is-active searxng-local.service; systemctl --user is-active agent-websearch.service"
```

## 安全说明

这是公开仓库，所以不要提交真实凭据。

文档和示例里应该使用：

```text
<VLLM_API_KEY>
<YOUR_LLM_API_KEY>
```

不要提交：

- 真实 API key
- GitHub token
- 私有证书
- `.claude` 运行态历史
- 服务机私有日志
- 本地模型权重
- WSL `.vhdx`、导出 tar、下载镜像

如果你 fork 或复用这个仓库，建议先搜索这些模式：

```bash
grep -R "ghp_\|sk-\|vllm-local" -n .
```

## 适合复用的部分

这套文档最有复用价值的是这些设计：

- Windows Cursor 通过 wrapper 调 WSL Claude Code。
- 使用 `CLAUDE_CONFIG_DIR` 解决 Windows 插件和 WSL CLI 的会话历史不一致。
- 把 Claude Code 的 Anthropic Messages 请求转给自建 vLLM。
- 用 Zoraxy 做透明公网中转，而不是在代理层模拟 WebSearch。
- 在 vLLM 服务机侧实现 WebSearch，这样 Claude Code、OpenAI-compatible 客户端和本地模型共享同一套搜索栈。

如果你的机器名、WSL distro、模型名、域名、Tailscale IP 不同，把文档里的固定值替换成自己的即可。
