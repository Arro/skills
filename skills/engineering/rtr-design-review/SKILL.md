---
name: rtr-design-review
description: Design review pipeline stage — capture screenshots of visual changes (capture mode) or convert human feedback into work tickets (fix-spec mode).
---

Two-mode design review stage for the RTR pipeline. The trigger label determines
which mode runs:

- **Capture mode** (`design-review` without prior capture): screenshot every
  surface named in the issue and post them as a comment.
- **Fix-spec mode** (`design-changes-requested`): read the human's feedback,
  author a `ready-for-agent` spec issue, and close the design-review bookmark.

This is an autonomous cron run with no human present. The monitor script
determines which mode to trigger based on the issue's labels and capture-marker
state.

## Capture mode

Triggered when the monitor outputs `design-review:<id>` for an issue that has
the `design-review` label but no capture marker comment.

### 1. Claim the issue

```sh
gh issue edit <id> --add-label being-design-reviewed --remove-label design-review
```

If this fails, stop — do not capture an issue you did not claim.

### 2. Read the issue body

Parse the issue body for:
- **"Where to look"** section — contains concrete routes (e.g.,
  `/auth/sign-in`, `/g/[projectId]/loop`) or descriptions of surfaces to
  capture.
- **"Worth a human eye on"** bullets — specific call-outs that each screenshot
  should be captioned with.
- **Angry/edge states** — any described interactions to trigger before
  capturing (e.g., "submit with bad credentials to see the red error banner").

If the issue body has no "Where to look" section, capture the app's home page
and note the absence in the comment.

### 3. Set up the capture worktree

Use the persistent capture worktree at `.worktrees/design-capture`:

```sh
# Create if it doesn't exist, off origin/main
if [ ! -d .worktrees/design-capture ]; then
  git worktree add .worktrees/design-capture origin/main --detach
fi
cd .worktrees/design-capture
git fetch origin
git reset --hard origin/main
```

### 4. Provision a throwaway Neon branch

Database branches are mandatory. Create one with the Neon MCP tool
`mcp__Neon__create_branch`:
- `projectId`: `soft-feather-28170515`
- `branchName`: `design-capture/<id>`
- `expiresAt`: now + 7 days (ISO 8601)

Get its connection string with `mcp__Neon__get_connection_string` and rewrite
the `DATABASE_URL=` line in the worktree's `.env`.

Run `npm run prisma:generate` to sync the Prisma client to the branch schema.

### 5. Boot the dev server

```sh
npm run dev:bg
```

The worktree's `.env.local` assigns a dedicated `PORT` (distinct from the main
checkout's 3008). Wait for the server to be ready by checking
`http://localhost:$PORT`.

Auth is bypassed via `AUTH_DEVELOPMENT_BYPASS_ENABLED=true` in the `.env`.

### 6. Capture screenshots

For each surface named in the "Where to look" section:

1. **Resolve dynamic parameters.** If a route contains `[projectId]`, `[sceneId]`,
   or similar, query the database for a real ID. Prefer the **SEIJI** project per
   `CLAUDE.md` convention. Use `mcp__Neon__run_sql` on the throwaway branch to
   find IDs.

2. **Navigate** to the full URL (e.g.,
   `http://localhost:$PORT/s/clx123/source`) using browser tools.

3. **Wait for rendering.** For React Three Fiber / Three.js surfaces, wait a
   few seconds for shader compilation and frame settlement before capturing.

4. **Perform any described interactions** (e.g., submit a form with bad input
   to trigger an error state).

5. **Capture the screenshot** at 1440×900 viewport.

6. **Name the file** `<issue>-<surface-slug>.png` (e.g., `194-sign-in-page.png`).

For unreachable surfaces (e.g., a state requiring live generated content not
in the database), post a note instead of a screenshot.

### 7. Push screenshots to the design-captures branch

```sh
# Switch to the design-captures orphan branch in a temp clone
cd /tmp/design-captures-<id>
git clone --branch design-captures --single-branch . /tmp/design-captures-<id>
# Or if already cloned, fetch and checkout
cp /path/to/screenshots/*.png /tmp/design-captures-<id>/
cd /tmp/design-captures-<id>
git add *.png
git commit -m "Design captures for issue #<id>"
git push origin design-captures
CAPTURE_SHA=$(git rev-parse HEAD)
```

### 8. Post the capture comment

Comment on the issue with:
- The marker: `<!-- design-capture: sha=<CAPTURE_SHA> -->`
- For each surface: a heading with the "Worth a human eye on" bullet text,
  followed by the screenshot image referenced by commit SHA:

  ```markdown
  ![](https://raw.githubusercontent.com/Arro/ready-to-rig/<CAPTURE_SHA>/path/to/screenshot.png)
  ```

  Images are referenced by commit SHA, not branch tip, so they remain
  accessible even if the branch is force-pushed later.

- Any notes about unreachable surfaces.

Post via:
```sh
gh issue comment <id> --body-file /tmp/capture-comment.md
```

### 9. Relabel and clean up

```sh
gh issue edit <id> --remove-label being-design-reviewed --add-label design-review
```

Stop the dev server:
```sh
~/.hermes/skills/pickup/scripts/stop-dev-servers.sh .worktrees/design-capture
```

### 10. Report

Report "OK, issue #<id> design capture complete — N screenshots posted".

### Recovery (capture mode)

Never leave an issue stranded in `being-design-reviewed`. If you stop after
step 1 without posting the capture comment:
```sh
gh issue edit <id> --remove-label being-design-reviewed --add-label design-review
```
The sweeper also recovers this after 45 minutes. Capture is idempotent — safe
to retry.

---

## Fix-spec mode

Triggered when the monitor outputs `design-changes-requested:<id>` for an issue
that has both `design-review` and `design-changes-requested` labels (meaning the
human has reviewed the screenshots and requested changes).

### 1. Claim the issue

```sh
gh issue edit <id> --add-label fixing-design
```

Note: do not remove `design-review` or `design-changes-requested` yet — they
are cleared when the issue is closed.

If this fails, stop.

### 2. Check for an existing "Superseded by" comment

Before creating a duplicate spec issue, check if one was already created:
```sh
gh issue view <id> --json comments --jq \
  '[.comments[] | select(.body | contains("Superseded by"))] | length'
```

If > 0, the spec was already authored in a prior run. Remove the claim and
stop:
```sh
gh issue edit <id> --remove-label fixing-design
```

### 3. Read the human's feedback

Fetch the issue's comments. The human's feedback is in the comment(s) after
the capture marker comment (`<!-- design-capture: sha=... -->`). Comments by
"Arro" (the project owner) after the capture are the feedback to convert into
a spec.

```sh
gh issue view <id> --json comments --jq '.comments[] | "\(.author.login): \(.body)"'
```

### 4. Author a new ready-for-agent issue

Create a new issue in Arro/ready-to-rig:
- **Title**: "Design fix: <short summary of the requested change>"
- **Body**: Include:
  - A `## Agent Brief` section with the feedback quoted verbatim.
  - Acceptance criteria derived from the feedback.
  - A link to the original design-review issue: "Originated from design review
    #<id>".
  - The routes/surfaces to change (from the original issue's "Where to look").
- **Labels**: `ready-for-agent`

```sh
gh issue create --repo Arro/ready-to-rig \
  --title "Design fix: <summary>" \
  --body-file /tmp/design-fix-spec.md \
  --label ready-for-agent
```

Capture the new issue number as `<NEW_ID>`.

### 5. Close the design-review issue

Comment on the design-review issue:
```
Superseded by #<NEW_ID> — feedback converted to a ready-for-agent spec issue.
The normal flywheel (conquer → review → fix → ship) will build the change.
Ship will create a fresh design-review bookmark when it merges.
```

Then close the issue:
```sh
gh issue close <id> --comment "Superseded by #<NEW_ID>"
```

### 6. Drop the claim

```sh
gh issue edit <id> --remove-label fixing-design
```

The issue is now closed. The `design-review` and `design-changes-requested`
labels remain on the closed issue (harmless — closed issues don't trigger the
monitor).

### 7. Report

Report "OK, issue #<id> design fix-spec complete — created #<NEW_ID> as
ready-for-agent".

### Recovery (fix-spec mode)

Never leave an issue stranded in `fixing-design`. If you stop after step 1
without closing the issue:
```sh
gh issue edit <id> --remove-label fixing-design
```
The sweeper also recovers this after 45 minutes, reverting to
`design-changes-requested`.

---

## Constraints

- Never merge, never push to `main`, never run wrapup.
- Never modify ready-to-rig application code — this stage captures and
  reports, it does not implement changes.
- The capture worktree is persistent (`.worktrees/design-capture`), reset to
  `origin/main` each run. Do not delete it.
- Always stop the dev server before reporting, on success or failure.
- Screenshots are referenced by commit SHA on `raw.githubusercontent.com`,
  never by branch tip — older comments must not lose their images.
