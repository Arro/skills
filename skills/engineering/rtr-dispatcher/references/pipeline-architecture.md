# RTR Pipeline Architecture

The event-driven issue flywheel for the ready-to-rig project, running in Hermes.

## Design principles

1. **Fresh context per stage** — each stage is a completely fresh, independent
   session with minimal context. No orchestrator accumulates context across
   stages. The label state machine on GitHub is the handoff mechanism.
2. **Event-based, not schedule-based** — stages fire when their trigger label
   appears, not on a fixed clock. Latency between stages: ~1 minute (the
   monitor poll interval), not hours.
3. **One loop, one dispatcher** — a single monitor script checks all trigger
   labels in one pass. A single dispatcher agent wakes up, reads which labels
   have work, and routes to the appropriate stage skill. This is one cron job,
   one API call per label per tick, not four separate jobs.
4. **Sweeper is separate** — recovery (un-parking blocked issues, rescuing
   stranded in-progress issues) runs on a 5-minute interval with different
   detection logic.

## Components

### Monitor scripts (`~/.hermes/scripts/`)

| Script | Schedule | Purpose |
|--------|----------|---------|
| `rtr-monitor-pipeline.sh` | 1 min | Checks all 6 trigger labels in one pass, including design-review with capture-marker detection |
| `rtr-monitor-sweeper.sh` | 5 min | Checks for blocked issues to un-park + stranded in-progress issues (8 in-progress labels) |

**Hash suppression pattern (critical):** Hermes hashes the monitor script's
stdout and suppresses the agent run if the hash is unchanged from the last
tick. The scripts exploit this:

- **No work** → output nothing (empty stdout). Hash is stable across ticks.
  Agent never fires. Zero tokens, zero API calls beyond the `gh` query.
- **Work exists** → output the issue numbers + a nonce (`date +%s`). The nonce
  changes every second, so the hash changes every tick. The agent fires and
  keeps retrying until it successfully claims (removes the trigger label).
  Once claimed, the next tick's `gh` output is empty → silence returns.

This is what makes the system event-driven rather than schedule-driven: the
agent only wakes when GitHub state changes, not when a clock ticks.

**Design-review marker detection:** For `design-review` issues, the monitor
makes a per-issue `gh api` call to check comments for the
`<!-- design-capture: sha=... -->` marker. Only issues without a marker trigger
capture mode. Issues with a marker AND the `design-changes-requested` label
trigger fix-spec mode. Issues with a marker and no `design-changes-requested`
are awaiting human verdict and do not trigger the agent.

### Cron jobs

Two cron jobs total:

1. **RTR Pipeline** (`every 1m`, `repeat: 999999`) — monitor checks labels,
   dispatcher agent processes oldest issue per stage. Toolsets: `terminal`,
   `file`, `delegation`, `browser` (browser needed for screenshot capture).
2. **RTR Sweeper** (`every 5m`, `repeat: 999999`) — monitor checks for
   recovery conditions, sweeper agent fixes them.

### Stage skills

| Skill | Trigger label | In-progress label | Terminal labels |
|-------|--------------|-------------------|-----------------|
| `rtr-conquer` | `ready-for-agent` | `being-built` | `ready-for-code-review`, `blocked` |
| `rtr-review` | `ready-for-code-review` | `being-code-reviewed` | `code-review-passed`, `changes-requested` |
| `rtr-fix` | `changes-requested` | `making-requested-changes` | `ready-for-code-review`, `ready-for-human` |
| `rtr-ship` | `code-review-passed` | `being-shipped` | (merged/closed) |
| `rtr-design-review` (capture) | `design-review` (no marker) | `being-design-reviewed` | `design-review` (with marker) |
| `rtr-design-review` (fix-spec) | `design-changes-requested` | `fixing-design` | (issue closed as "Superseded by #N") |

### Sweeper recovery rules

Issues stranded in in-progress labels for >45 minutes get rescued:

| Stranded label | Recovery action |
|----------------|-----------------|
| `being-built` | → `ready-for-agent` (conquer re-picks) |
| `being-code-reviewed` | → `ready-for-code-review` (review re-picks) |
| `making-requested-changes` | leave unlabeled (don't retry a doomed fix) |
| `being-shipped` | → `ready-for-human` (merge failures need humans) |
| `being-design-reviewed` | → `design-review` (capture is idempotent, safe to retry) |
| `fixing-design` | → `design-changes-requested` (safe to re-attempt spec-writing) |

Blocked issues whose blockers have all closed get un-parked to
`ready-for-agent`.

### Design-review label state machine

| Label | Role | Color | Set by |
|---|---|---|---|
| `design-review` | Queue (needs capture or awaiting human) | `#5319E7` (purple) | rtr-ship, or sweeper recovery |
| `being-design-reviewed` | Capture in progress | `#FBCA04` (yellow) | rtr-design-review claim |
| `design-changes-requested` | Human wants changes | `#D93F0B` (red) | Phil |
| `fixing-design` | Fix-spec in progress | `#FBCA04` (yellow) | rtr-design-review claim |

Capture mode transitions:
```
design-review  --[claim]-->  being-design-reviewed
being-design-reviewed  --[capture ok]-->  design-review  (marker comment posted)
being-design-reviewed  --[capture fail]-->  design-review  (future retry, or ready-for-human after N fails)
```

Fix-spec mode transitions:
```
design-review + design-changes-requested  --[claim]-->  fixing-design
fixing-design  --[spec created]-->  (issue closed as "Superseded by #N")
```

Human verdicts:
```
design-review (captured)  --[Phil closes issue]-->  (approved, done)
design-review (captured)  --[Phil comments + adds design-changes-requested]-->  (enter fix-spec mode)
```

## Prerequisites

### Neon MCP server

The pipeline requires the Neon MCP server to be configured in Hermes for
database branch creation (worktrees must run against throwaway Neon branches,
not production). Setup:

```bash
hermes mcp add Neon --url "https://mcp.neon.tech/mcp" --auth header
# Pipe: "Bearer <neon-api-key>"
```

The API key is stored in `~/.hermes/.env` as `MCP_NEON_API_KEY`. The Neon
project ID for ready-to-rig is `soft-feather-28170515`.

### Browser toolset

The RTR Pipeline cron job must have the `browser` toolset enabled for
screenshot capture in design-review capture mode. The browser toolset provides
page navigation and screenshot capabilities via headless Chrome.

### design-captures branch

A `design-captures` orphan branch (no shared history with `main`) must exist
in the ready-to-rig repo. Screenshots are pushed to this branch and referenced
by commit SHA on `raw.githubusercontent.com`.

### Path migration

Upstream skills (pickup, wrapup) reference `~/.claude/skills/pickup/scripts/`.
In Hermes, the scripts are at `~/.hermes/skills/pickup/scripts/`. The scripts
use `BASH_SOURCE` so they work from either location, but the rtr-* skill
instructions point to the Hermes path.

### GitHub labels

All labels must exist in the repo: `ready-for-agent`, `ready-for-code-review`,
`being-built`, `being-code-reviewed`, `code-review-passed`, `changes-requested`,
`making-requested-changes`, `being-shipped`, `blocked`, `ready-for-human`,
`design-review`, `being-design-reviewed`, `design-changes-requested`,
`fixing-design`.

## Cron job setup gotcha

**`schedule: "1m"` defaults to a one-shot job.** You MUST explicitly set
`repeat: 999999` when creating the cron job, or it will fire once and stop.
The `cronjob` tool's `repeat` parameter description says "Omit for defaults
(once for one-shot, forever for recurring)" but in practice, duration
schedules like `"1m"` and `"5m"` default to one-shot unless `repeat` is
explicitly set to a large number.

## Delivery model

- **Successful runs**: report "OK" with minimal detail. Near-silent.
- **Failures/exceptions**: detailed report delivered to the user's chat.
- **Sweeper recoveries**: always delivered (exceptions worth knowing about).
