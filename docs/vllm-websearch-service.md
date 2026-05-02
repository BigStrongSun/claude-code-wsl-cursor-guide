# vLLM WebSearch Service Machine

This document records the service-machine side of the local WebSearch stack used by vLLM and Claude Code.

The goal is to let Claude Code, OpenAI-compatible clients, and local Qwen/vLLM share one search stack:

- SearXNG performs web search.
- The MCP `browser` server backs OpenAI Responses `web_search_preview`.
- vLLM Anthropic WebSearch patches handle Claude Code native `web_search_20250305` / `web_search_20260209`.

## Runtime Architecture

```text
Claude Code / Anthropic Messages
  -> vLLM /v1/messages
  -> Anthropic WebSearch compatibility patch
  -> local SearXNG
  -> fetched pages + extracted evidence
  -> model answer with server_tool_use / web_search_tool_result / citations

OpenAI Responses API
  -> vLLM /v1/responses
  -> web_search_preview compatibility patch
  -> MCP tool server named browser
  -> local SearXNG or ddgs fallback
```

Current local services:

| Component | Endpoint or setting |
| --- | --- |
| vLLM endpoint | `http://127.0.0.1:5000/v1` |
| SearXNG | `http://127.0.0.1:8888/search` |
| MCP browser/search server | `http://127.0.0.1:8890/sse` |
| vLLM tool server flag | `--tool-server 127.0.0.1:8890` |
| Current model | `qwen3.6` |

Required vLLM environment:

```bash
VLLM_USE_EXPERIMENTAL_PARSER_CONTEXT=1
VLLM_ENABLE_RESPONSES_API_STORE=1
```

The MCP server `serverInfo.name` must be `browser`, because vLLM 0.19.x maps OpenAI `web_search_preview` to the internal MCP namespace `browser`.

## OpenAI Responses WebSearch

Request shape:

```json
{
  "model": "qwen3.6",
  "input": "Search the web for the latest vLLM release notes and summarize them.",
  "tools": [
    {
      "type": "web_search_preview"
    }
  ],
  "max_output_tokens": 512
}
```

The local vLLM 0.19.1 patch updates:

```text
vllm/entrypoints/openai/responses/utils.py
```

It renders:

```json
{"type": "web_search_preview"}
```

into a Qwen-callable function schema, then vLLM calls `browser.search` through the MCP tool server.

## Anthropic Messages / Claude Code WebSearch

Claude Code sends WebSearch as an Anthropic server-side tool to `/v1/messages`.

Typical request:

```json
{
  "model": "qwen3.6",
  "max_tokens": 8192,
  "stream": true,
  "messages": [
    {
      "role": "user",
      "content": "Web SearchvLLM latest release notes 2026"
    }
  ],
  "tools": [
    {
      "type": "web_search_20250305",
      "name": "web_search",
      "max_uses": 8
    }
  ]
}
```

Supported WebSearch tool types:

- `web_search_20250305`
- `web_search_20260209`
- `web_search-20250305`
- `web_search-20260209`
- `web_search_converter-20250902`

If the WebSearch tool has no `name`, the patch defaults it to:

```json
{"name": "web_search"}
```

## Request-Level Parameters

The patched Anthropic route accepts these fields:

| Field | Meaning |
| --- | --- |
| `model` | Model name, currently `qwen3.6`. |
| `max_tokens` | Final answer output budget. It does not control fetched web evidence length. |
| `stream` | Whether to stream the response. Claude Code usually streams. |
| `system` | Optional system prompt. Query extraction tries to avoid system-prompt contamination. |
| `messages` | Anthropic Messages array. Claude Code search helper often emits `Web Search<query>`. |
| `tools` | Can contain Anthropic server-side WebSearch tools and normal Claude Code client tools. |

Recognized WebSearch tool definition fields:

| Field | Meaning |
| --- | --- |
| `type` | One of the supported WebSearch tool types. |
| `name` | Optional; defaults to `web_search`. |
| `input_schema` | Optional; native Anthropic WebSearch normally omits it. |
| `max_uses` | Optional request-level limit, clamped by the server. |
| `allowed_domains` | Optional allow-list for result domains and subdomains. |
| `blocked_domains` | Optional block-list for result domains and subdomains. |
| `user_location` | Accepted for protocol compatibility; local SearXNG mapping is limited. |

Recognized internal search-call parameters:

```json
{
  "query": "vLLM latest release notes 2026",
  "time_range": "month",
  "freshness": "month"
}
```

| Field | Meaning |
| --- | --- |
| `query` | Required search query. |
| `q` | Alias for `query`. |
| `time_range` | Optional SearXNG time range. |
| `freshness` | Alias for `time_range`. |

If the Claude Code helper returns only:

```json
{"query":"vLLM latest release notes 2026"}
```

the patch treats it as a search request instead of returning that JSON to the user.

## Service-Level Search Defaults

These vLLM process environment variables control the default search budget and require a vLLM restart after changes:

```bash
VLLM_ANTHROPIC_WEB_SEARCH_URL=http://127.0.0.1:8888/search
VLLM_ANTHROPIC_WEB_SEARCH_TIMEOUT=45
VLLM_ANTHROPIC_WEB_SEARCH_RESULTS=32
VLLM_ANTHROPIC_WEB_SEARCH_FETCH_TOP=16
VLLM_ANTHROPIC_WEB_SEARCH_MAX_CONTENT_CHARS=16000
VLLM_ANTHROPIC_WEB_SEARCH_MAX_FETCH_BYTES=12000000
VLLM_ANTHROPIC_WEB_SEARCH_ENGINES=duckduckgo,brave,google,startpage,bing
VLLM_ANTHROPIC_WEB_SEARCH_CATEGORIES=general
VLLM_ANTHROPIC_WEB_SEARCH_LANGUAGE=auto
VLLM_ANTHROPIC_WEB_SEARCH_SAFESEARCH=0
```

Priority order:

```text
request WebSearch tool fields and tool-call parameters
  > vLLM process environment variables
  > patch defaults
```

Request-level parameters that do not require a restart:

- `max_tokens`
- `max_output_tokens`
- `max_uses`
- `allowed_domains`
- `blocked_domains`
- `time_range` / `freshness`

Process-level defaults that require a restart:

- `VLLM_ANTHROPIC_WEB_SEARCH_RESULTS`
- `VLLM_ANTHROPIC_WEB_SEARCH_FETCH_TOP`
- `VLLM_ANTHROPIC_WEB_SEARCH_MAX_CONTENT_CHARS`
- `VLLM_ANTHROPIC_WEB_SEARCH_MAX_FETCH_BYTES`
- `VLLM_ANTHROPIC_WEB_SEARCH_ENGINES`
- `VLLM_ANTHROPIC_WEB_SEARCH_CATEGORIES`
- `VLLM_ANTHROPIC_WEB_SEARCH_LANGUAGE`
- `VLLM_ANTHROPIC_WEB_SEARCH_SAFESEARCH`
- `VLLM_ANTHROPIC_WEB_SEARCH_TIMEOUT`

Restart example:

```powershell
wsl -d Ubuntu -- systemctl --user restart vllm-qwen36-tp.service
```

## Anthropic WebSearch Execution Flow

1. `anthropic/protocol.py` relaxes tool schema validation so native Anthropic WebSearch can omit `input_schema`.
2. `anthropic/serving.py` recognizes server-side WebSearch tools during `/v1/messages` handling.
3. Claude Code helper prompts like `Web Search <query>` or `WebSearch<query>` are converted into search queries.
4. If the model emits only `{"query":"..."}`, the patch intercepts it and executes search.
5. Search is sent to local SearXNG with engine, category, safe-search, language, time-range, and domain filters.
6. Results are canonicalized and deduplicated.
7. vLLM fetches selected result pages and extracts HTML/text content.
8. Extracted text is selected by query relevance and reranked.
9. Selected evidence is injected back as an internal tool result.
10. The post-search answer turn disables Qwen thinking through `chat_template_kwargs.enable_thinking=false`.
11. The response is shaped into Anthropic-style content blocks:
    - `server_tool_use`
    - `web_search_tool_result`
    - final `text`
    - citation metadata
    - `usage.server_tool_use.web_search_requests`
12. If final text is empty or still only `{"query":"..."}`, the server produces a markdown fallback summary from real search results.

Streaming and non-streaming `/v1/messages` are both supported. Streaming should emit `server_tool_use` and `web_search_tool_result` before final text.

## Search Quality Controls

The current Anthropic WebSearch path includes:

- Multi-engine SearXNG aggregation
- URL canonicalization and deduplication
- `allowed_domains` / `blocked_domains`
- SSRF protection for loopback, local networks, and private IPs
- Top-result page fetching
- HTML extraction, preferring `trafilatura` with stdlib fallback
- Query-aware excerpt selection
- Local rerank
- Common mojibake cleanup
- Date and weekday intent rerank for queries such as `今天星期几`

## Token And Evidence Budgets

`max_tokens` and `max_output_tokens` control the final answer budget, not how much search evidence can be fetched.

The current strong-search default is tuned for a large context window:

| Setting | Meaning |
| --- | --- |
| `RESULTS=32` | Keep up to 32 final search results. |
| `FETCH_TOP=16` | Fetch up to 16 pages. |
| `MAX_CONTENT_CHARS=16000` | Keep up to 16000 extracted characters per fetched page. |
| `MAX_FETCH_BYTES=12000000` | Read up to 12 MB raw content per page. |
| `TIMEOUT=45` | Search/fetch timeout in seconds. |

If search is slow, SearXNG is rate-limited, or prompts become too large, lower these first:

```bash
VLLM_ANTHROPIC_WEB_SEARCH_RESULTS
VLLM_ANTHROPIC_WEB_SEARCH_FETCH_TOP
VLLM_ANTHROPIC_WEB_SEARCH_MAX_CONTENT_CHARS
```

If only the final answer is truncated, increase request-level `max_tokens`.

## Validation

Check services:

```powershell
wsl -d Ubuntu -- bash -lc "systemctl --user is-active vllm-qwen36-tp.service; systemctl --user is-active searxng-local.service; systemctl --user is-active agent-websearch.service"
```

Anthropic WebSearch smoke test:

```powershell
wsl -d Ubuntu -- python3 "/mnt/c/Users/sunda/Documents/VLLM/agent websearch/smoke_anthropic_web_search.py" --base-url http://127.0.0.1:5000 --model qwen3.6 --query "Web Search今天星期几"
```

Strong-search smoke test:

```powershell
wsl -d Ubuntu -- python3 "/mnt/c/Users/sunda/Documents/VLLM/agent websearch/smoke_anthropic_web_search.py" --base-url http://127.0.0.1:5000 --model qwen3.6 --query "Web SearchvLLM latest release notes 2026" --max-tokens 900
```

Expected signals:

- `server_tool_use`
- `web_search_tool_result`
- `search_results` greater than 0
- `usage.server_tool_use.web_search_requests=1`
- final `text` is not just `{"query":"..."}`

Check vLLM search environment:

```powershell
$mainPid = (wsl -d Ubuntu -- systemctl --user show -p MainPID --value vllm-qwen36-tp.service).Trim()
wsl -d Ubuntu -- bash -lc "strings /proc/$mainPid/environ | grep '^VLLM_ANTHROPIC_WEB_SEARCH' | sort"
```

Logs:

```powershell
wsl -d Ubuntu -- journalctl --user -u vllm-qwen36-tp.service --since "20 minutes ago" --no-pager
wsl -d Ubuntu -- journalctl --user -u searxng-local.service --since "20 minutes ago" --no-pager
```

## Troubleshooting

| Symptom | Likely cause | Check |
| --- | --- | --- |
| Final answer is `{"query":"..."}` | vLLM is not running the latest Anthropic WebSearch patch. | Restart vLLM and confirm patch version. |
| Only thinking, no final text | Output budget was consumed by Qwen thinking. | Confirm the post-search answer turn disables thinking. |
| SearXNG logs show 403 or rate limits | Some upstream engines are rate-limiting. | SearXNG should still return other engine results. |
| Search is slow | Search/fetch budget is high. | Lower `FETCH_TOP`, `MAX_CONTENT_CHARS`, or `TIMEOUT`. |
| Results are too broad | Query is too broad. | Use `allowed_domains`, reduce results, or strengthen query. |

## Patch Files

The source service uses these vLLM 0.19.1 patch files:

```text
patches/vllm-0.19.1-anthropic-messages-web-search.patch
patches/vllm-0.19.1-openai-responses-web-search-preview.patch
```

Apply from the vLLM site-packages root:

```bash
SITE_PACKAGES="$(
  python - <<'PY'
import pathlib
import vllm
print(pathlib.Path(vllm.__file__).resolve().parents[1])
PY
)"

cd "$SITE_PACKAGES"
patch -p1 < /path/to/agent\ websearch/patches/vllm-0.19.1-anthropic-messages-web-search.patch
patch -p1 < /path/to/agent\ websearch/patches/vllm-0.19.1-openai-responses-web-search-preview.patch
```

Restart vLLM after applying patches. Rebase the patches after upgrading vLLM.
