# Productivity

General workflow tools, not code-specific.

## User-invoked

Reachable only when you type them (Claude Code: `disable-model-invocation: true`; Codex: `policy.allow_implicit_invocation: false` in `agents/openai.yaml`).

- **[grill-me](./grill-me/SKILL.md)** — Get relentlessly interviewed about a plan or design until every branch of the design tree is resolved.
- **[handoff](./handoff/SKILL.md)** — Compact the current conversation into a handoff document so another agent can continue the work.
- **[teach](./teach/SKILL.md)** — Teach the user a new skill or concept over multiple sessions, using the current directory as a stateful teaching workspace.
- **[to-questionnaire](./to-questionnaire/SKILL.md)** — Turn a decision you can't answer alone into a Markdown questionnaire for the one person who can — filled in async, or together over a meeting.
- **[wait-what](./wait-what/SKILL.md)** — Fire this the moment a message doesn't land. The agent re-pitches it with the context you're missing, in plain English, using your `CONTEXT.md` vocabulary.
- **[edit-article](./edit-article/SKILL.md)** — Edit and improve an article draft section by section: restructure to respect information dependencies, then tighten prose with your confirmation at each step.

## Model-invoked

Model- or user-reachable (rich trigger phrasing so the model can reach for them).

- **[grilling](./grilling/SKILL.md)** — Interview the user relentlessly about a plan, decision, or idea until every branch of the design tree is resolved.
- **[writing-for-agents](./writing-for-agents/SKILL.md)** — Writing documents for agents: skills, AGENTS.md/CLAUDE.md, and any doc an agent reaches by a pointer.
- **[rename-thread](./rename-thread/SKILL.md)** — Emit a copy-able `/rename` block that gives the current thread a findable title, delivered in the turn's final message.
- **[gpt-image-2](./gpt-image-2/SKILL.md)** — Generate or edit images with OpenAI's gpt-image-2 via the mcp-image MCP server, filed per project as `<slug>/<prefix>-<subject>-v<NN>.png`.
- **[obsidian-vault](./obsidian-vault/SKILL.md)** — Search, create, and manage notes in the Obsidian vault with wikilinks and index notes.
