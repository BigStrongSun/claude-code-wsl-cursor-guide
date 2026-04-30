using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;

internal static class ClaudeWslWrapper
{
    private static int Main(string[] args)
    {
        var claudeArgs = StripWrappedClaudeExecutable(args).ToList();
        var wslArgs = new List<string>
        {
            "-d",
            "openclaw",
            "--",
            "env",
            "HOME=/home/openclaw",
            "PATH=/usr/local/bin:/usr/bin:/bin",
            "ANTHROPIC_BASE_URL=http://100.99.98.29:5000",
            "ANTHROPIC_AUTH_TOKEN=<YOUR_LLM_API_KEY>",
            "ANTHROPIC_MODEL=qwen3.6",
            "ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3.6",
            "ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3.6",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3.6",
            "ANTHROPIC_CUSTOM_MODEL_OPTION=qwen3.6",
            "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME=Qwen3.6 vLLM",
            "ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION=Remote qwen3.6 served by OpenAI-compatible API",
            "CLAUDE_CODE_ATTRIBUTION_HEADER=0",
            "API_TIMEOUT_MS=600000",
            "NO_PROXY=100.99.98.29,localhost,127.0.0.1",
            "no_proxy=100.99.98.29,localhost,127.0.0.1",
            "claude"
        };
        wslArgs.AddRange(claudeArgs);

        var startInfo = new ProcessStartInfo
        {
            FileName = "wsl.exe",
            Arguments = string.Join(" ", wslArgs.Select(QuoteWindowsArgument)),
            UseShellExecute = false,
        };

        try
        {
            using (var process = Process.Start(startInfo))
            {
                process.WaitForExit();
                return process.ExitCode;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("Failed to launch WSL Claude Code: " + ex.Message);
            return 1;
        }
    }

    private static IEnumerable<string> StripWrappedClaudeExecutable(string[] args)
    {
        if (args.Length >= 2 && IsNodeExecutable(args[0]) && IsClaudeEntrypoint(args[1]))
        {
            return args.Skip(2);
        }

        if (args.Length >= 1 && IsClaudeEntrypoint(args[0]))
        {
            return args.Skip(1);
        }

        return args;
    }

    private static bool IsNodeExecutable(string value)
    {
        var normalized = value.Replace('\\', '/').ToLowerInvariant();
        return normalized.EndsWith("/node.exe") || normalized.EndsWith("/node");
    }

    private static bool IsClaudeEntrypoint(string value)
    {
        var normalized = value.Replace('\\', '/').ToLowerInvariant();
        return normalized.EndsWith("/claude.exe")
            || normalized.EndsWith("/claude")
            || normalized.EndsWith("/cli.js")
            || normalized.EndsWith("/claude-wsl-wrapper.js");
    }

    private static string QuoteWindowsArgument(string arg)
    {
        if (arg.Length == 0)
        {
            return "\"\"";
        }

        var needsQuotes = arg.Any(ch => char.IsWhiteSpace(ch) || ch == '"');
        if (!needsQuotes)
        {
            return arg;
        }

        var builder = new StringBuilder();
        builder.Append('"');
        var backslashes = 0;
        foreach (var ch in arg)
        {
            if (ch == '\\')
            {
                backslashes++;
                continue;
            }

            if (ch == '"')
            {
                builder.Append('\\', backslashes * 2 + 1);
                builder.Append('"');
                backslashes = 0;
                continue;
            }

            builder.Append('\\', backslashes);
            backslashes = 0;
            builder.Append(ch);
        }

        builder.Append('\\', backslashes * 2);
        builder.Append('"');
        return builder.ToString();
    }
}
