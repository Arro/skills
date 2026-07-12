# Machine setup

Once per machine. Ask the user two things: which folder images should collect in (any writable absolute path — this becomes `IMAGE_OUTPUT_DIR`), and to fill in their own OpenAI API key where `<key>` appears below — the key never passes through chat.

Requirements: Node.js 18+ with network access (`npx -y mcp-image` fetches the package from npm on first run). `IMAGE_PROVIDER=openai` is what selects gpt-image-2 — the server defaults to Gemini without it.

## Claude Code

Have the user run:

```
claude mcp add mcp-image --scope user \
  --env IMAGE_PROVIDER=openai \
  --env OPENAI_API_KEY=<key> \
  --env IMAGE_OUTPUT_DIR=<chosen folder> \
  -- npx -y mcp-image
```

## Codex

Add to `~/.codex/config.toml`:

```toml
[mcp_servers.mcp-image]
command = "npx"
args = ["-y", "mcp-image"]
env = { IMAGE_PROVIDER = "openai", OPENAI_API_KEY = "<key>", IMAGE_OUTPUT_DIR = "<chosen folder>" }
```

## Optional env

- `IMAGE_QUALITY` — default quality preset (`fast` / `balanced` / `quality`); per-call `quality` overrides it.
- `SKIP_PROMPT_ENHANCEMENT=true` — send prompts verbatim, bypassing the server's optimizer.
