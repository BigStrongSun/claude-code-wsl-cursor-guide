# WSL Claude Code Cursor Skill

这个目录是一个可复用的 Codex skill，用来指导 Codex 在 Windows + WSL + Cursor 环境里安装、修复或解释 Claude Code。

它面向两类读者：

- 想直接使用 skill 的 Codex/Cursor 用户。
- 想了解这个 skill 做了什么、能做什么、不能做什么的新手。

## 这个 skill 解决什么问题

Cursor 的 Claude Code 插件运行在 Windows 进程里，但很多人希望真正的 Claude Code CLI 跑在 WSL 中。这样做的好处是：

- 开发工具链更接近 Linux 环境。
- Node/npm、Claude Code、`cc-switch` 可以统一装在 WSL。
- 可以接入自建或远程的 Anthropic-compatible LLM API。
- 可以通过 WSL 访问 Linux 工具、shell、项目路径和权限模型。

问题是 Cursor 不能直接启动 WSL 里的 Linux `claude`，所以需要一个 Windows wrapper：

```text
Cursor Claude Code 插件
  -> claudeCode.claudeProcessWrapper
  -> Windows wrapper exe
  -> wsl.exe -d <distro> -- claude
```

这个 skill 就是用来把这条链路装好、修好、解释清楚。

## 目录结构

```text
wsl-claude-code-cursor/
  SKILL.md
  README.md
  agents/
    openai.yaml
  references/
    install-runbook.md
    llm-api-requirements.md
  scripts/
    ClaudeWslWrapper.cs
```

| 文件 | 作用 |
| --- | --- |
| `SKILL.md` | Codex 真正读取的 skill 入口，包含执行流程和边界。 |
| `README.md` | 给人看的说明文档。 |
| `agents/openai.yaml` | skill 在 UI 中展示的名称、简介和默认提示词。 |
| `references/install-runbook.md` | 完整安装和修复 runbook。 |
| `references/llm-api-requirements.md` | 切换 API/model/token 时，后端 LLM 必须满足的要求。 |
| `scripts/ClaudeWslWrapper.cs` | Windows 到 WSL 的 wrapper 模板。 |

## 推荐中文提示词

完整安装：

```text
使用 wsl-claude-code-cursor skill，帮我在 Windows Cursor 中接入 WSL 里的 Claude Code。请先检查当前 WSL、Node/npm、claude、cc-switch、Cursor 插件和 wrapper 状态，再修复配置，最后验证 Claude Code 能从 Cursor 启动。
```

切换模型 API：

```text
使用 wsl-claude-code-cursor skill，帮我把 Cursor 插件里的 Claude Code 切到新的 Anthropic-compatible API。请检查这个 API 是否满足 Claude Code 的 /v1/messages、streaming、tools、模型别名和 token 要求，并更新 WSL/cc-switch/wrapper/Cursor 配置。
```

修复历史会话：

```text
使用 wsl-claude-code-cursor skill，帮我修复 Cursor 重启后看不到 WSL Claude Code 历史会话的问题。请检查 CLAUDE_CONFIG_DIR、Windows .claude 目录、WSL 项目 key 和 Cursor Sessions 视图读取路径。
```

## 能做什么

- 安装或修复 WSL 中的 Node.js/npm。
- 安装或修复 Claude Code CLI。
- 安装或修复 `cc-switch`。
- 配置 Claude Code profile 和 API 环境变量。
- 编译 Windows wrapper。
- 更新 Cursor 的 `claudeCode.claudeProcessWrapper`。
- 让 Cursor 插件和 WSL CLI 共用 Claude 会话历史。
- 检查目标 API 是否满足 Claude Code 的 Anthropic Messages 兼容要求。

## 不做什么

这个 skill 不负责服务端部署。它不会：

- 部署 vLLM。
- 配置 SearXNG。
- 配置 MCP browser。
- 配置 Zoraxy 或公网代理。
- 管理证书、域名、端口转发。
- 下载模型权重。
- 修服务机 systemd。

如果目标 API 不满足 Claude Code 需要，这个 skill 只会指出问题和需要的接口形态，不会改服务端。

## 切换 API 时的 LLM 要求

Claude Code 不是普通 OpenAI chat completions 客户端。后端至少要兼容：

```text
POST /v1/messages
GET  /v1/models
```

并且要能处理：

- `model`
- `max_tokens`
- `messages`
- `system`
- `stream`
- `tools`
- `anthropic-version`
- `x-api-key` 或 `authorization`

如果只提供 `/v1/chat/completions`，通常不能直接给 Claude Code 用。

对于 Qwen、Llama、DeepSeek 这类非 Claude 模型，必须有 Anthropic-compatible shim 或适配层。模型名可以是 `qwen3.6` 之类，但 Claude Code 看到的是 Anthropic Messages 协议。

## 关键设计：共享历史

Cursor 插件运行在 Windows，WSL Claude CLI 运行在 Linux。默认情况下它们会看不同的 `.claude` 目录：

```text
Windows: C:\Users\<user>\.claude
WSL:     /home/<linux-user>/.claude
```

为了让 Cursor 重启后还能看到 WSL Claude 的历史会话，wrapper 应该设置：

```text
CLAUDE_CONFIG_DIR=/mnt/c/Users/<user>/.claude
```

这样 Cursor 和 WSL Claude 都读写 Windows 可见的同一套历史。

## 验证

常用验证命令：

```powershell
wsl.exe -d openclaw -- bash -lc 'node -v; npm -v; claude --version; cc-switch current'
wsl.exe -d openclaw -- bash -lc 'cc-switch test -c --endpoint chat --timeout 60s'
```

wrapper 验证：

```powershell
$wrapper="$env:APPDATA\Cursor\User\scripts\claude-wsl-wrapper.exe"
$native="$env:USERPROFILE\.cursor\extensions\anthropic.claude-code-<version>-win32-x64\resources\native-binary\claude.exe"
& $wrapper $native --version
```

skill 自身校验：

```powershell
wsl.exe -d openclaw -- python3 /mnt/c/Users/sunda/.codex/skills/.system/skill-creator/scripts/quick_validate.py /mnt/c/Users/sunda/Documents/Codex\ repo/openclaw/skills/wsl-claude-code-cursor
```

## 安全

公开仓库里不要提交：

- 真实 API key
- GitHub token
- `.claude` 运行态历史
- 私有日志
- 私有证书
- 模型权重

示例统一使用：

```text
<YOUR_LLM_API_KEY>
<VLLM_API_KEY>
```
