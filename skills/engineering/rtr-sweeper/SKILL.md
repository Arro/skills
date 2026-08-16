---
name: rtr-sweeper
description: Recover blocked and stranded issues — un-park blocked, rescue in-progress.
---

Recovery routine for the RTR issue flywheel. Handles two conditions:

1. **Un-park blocked issues** whose blockers have all closed.
2. **Rescue stranded issues** stuck in in-progress labels for more than 45 minutes.

This is an autonomous cron run with no human present. The monitor script has
already identified the work — its output (injected as context) tells you
exactly which issues need recovery and why.

## Steps

### 1. Un-park blocked issues

For each issue the monitor flagged as `unpark:<id>`:

1. Double-check that all blockers are closed:
   ```sh
   gh api "repos/Arro/ready-to-rig/issues/<id>/dependencies/blocked_by" \
     --jq '[.[] | select(.state=="open")] | length'
   ```
   If the count is not `0`, skip this issue — the monitor may have raced with
   a blocker re-opening.

2. If truly unblocked, swap the label:
   ```sh
   gh issue edit <id> --remove-label blocked --add-label ready-for-agent
   ```

3. Comment on the issue: "Blocker(s) closed — returning to the ready-for-agent
   queue." Only if the newest comment is not already that same note.

### 2. Rescue stranded issues

For each issue the monitor flagged as `stranded:<label>:<id>`:

The recovery action depends on which in-progress label it's stuck in:

- **`being-built`** → `ready-for-agent`
  ```sh
  gh issue edit <id> --remove-label being-built --add-label ready-for-agent
  ```
  Comment: "Stranded in being-built for >45 min — returned to ready-for-agent queue."

- **`being-code-reviewed`** → `ready-for-code-review`
  ```sh
  gh issue edit <id> --remove-label being-code-reviewed --add-label ready-for-code-review
  ```
  Comment: "Stranded in being-code-reviewed for >45 min — returned to ready-for-code-review queue."

- **`making-requested-changes`** → leave unlabeled (do NOT restore `changes-requested`)
  ```sh
  gh issue edit <id> --remove-label making-requested-changes
  ```
  Comment: "Stranded in making-requested-changes for >45 min — cleared claim. Not re-queued to changes-requested (would retry a doomed fix)."

- **`being-shipped`** → `ready-for-human`
  ```sh
  gh issue edit <id> --remove-label being-shipped --add-label ready-for-human
  ```
  Comment: "Stranded in being-shipped for >45 min — escalated to ready-for-human. Merge failures need human attention."

- **`being-design-reviewed`** → `design-review`
  ```sh
  gh issue edit <id> --remove-label being-design-reviewed --add-label design-review
  ```
  Comment: "Stranded in being-design-reviewed for >45 min — returned to design-review queue. Capture is idempotent, safe to retry."

- **`fixing-design`** → `design-changes-requested`
  ```sh
  gh issue edit <id> --remove-label fixing-design --add-label design-changes-requested
  ```
  Comment: "Stranded in fixing-design for >45 min — returned to design-changes-requested. Safe to re-attempt the spec-writing run; skill checks for existing Superseded-by comment before creating a duplicate."

### 3. Verify

After recovery actions, verify each label swap succeeded:
```sh
gh issue view <id> --json labels --jq '.labels[].name'
```

### 4. Stop

Report a summary of what was recovered. If nothing was recovered (the monitor
shouldn't have fired, but double-check), report "OK, nothing to recover".

## Reporting

On success (issues recovered): list each issue and the recovery action taken.
This will be delivered to the user's chat — recovery events are exceptions
worth knowing about.

On no work (false monitor trigger): report "OK, nothing to recover".

## Constraints

- Do not attempt to do the actual work of any stage (don't build, review, fix,
  ship, or capture). The sweeper only moves issues back to where the
  appropriate stage can pick them up.
- Do not delete branches, close PRs, or merge anything.
- Only post comments if the newest comment on the issue is not already the same
  note — this runs on a schedule, don't spam.
- Always verify the label swap succeeded before moving on.
