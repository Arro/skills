#!/usr/bin/env bash
# Fetch, gate and claim a GitHub issue for /pickup — steps 1-3 in one call.
#
# Prints the contract the agent implements against (the most recent
# "## Agent Brief" comment if there is one, otherwise the issue body), plus a
# suggested branch name and thread label. Assigning the issue is the mutex that
# stops two parallel /pickup sessions grabbing the same ticket, so it happens
# here, before any worktree exists.
#
# Linear tickets have no equivalent — use the Linear MCP tools per the skill.
#
# usage: claim-ticket.sh <issue-number> [--repo owner/name] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

ID=""
REPO=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift ;;
    --dry-run) DRY_RUN=1 ;;
    -*) echo "claim-ticket: unknown flag $1" >&2; exit 2 ;;
    *) ID="${1#\#}" ;;
  esac
  shift
done

if [ -z "$ID" ]; then
  echo "usage: claim-ticket.sh <issue-number> [--repo owner/name] [--dry-run]" >&2
  exit 2
fi

if [ -z "$REPO" ]; then
  # Without a repo to infer from, gh will happily resolve to something else
  # entirely — refuse rather than claim a ticket in the wrong project.
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "claim-ticket: not inside a git repository — run from the project checkout," >&2
    echo "or pass --repo owner/name explicitly." >&2
    exit 2
  fi
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi
echo "repo: $REPO"

ME="$(gh api user -q .login)"
ISSUE_JSON="$(gh issue view "$ID" --repo "$REPO" \
  --json number,title,body,state,url,labels,assignees,comments)"

# Gating and presentation over that one payload. The JSON travels by
# environment; the helper's trailing "EXIT <code>" marker becomes our status.
DECISION="$(ISSUE_JSON="$ISSUE_JSON" python3 "$SCRIPT_DIR/lib/issue-report.py" "$ME")"

# Surface everything except the trailing exit marker.
printf '%s\n' "$DECISION" | sed '/^EXIT [0-9]*$/d'

CODE="$(printf '%s\n' "$DECISION" | sed -n 's/^EXIT \([0-9]*\)$/\1/p' | tail -1)"
if [ "${CODE:-1}" -ne 0 ]; then
  exit "${CODE:-1}"
fi

# ── Claim it ────────────────────────────────────────────────────────

if printf '%s' "$ISSUE_JSON" | grep -q "\"login\":\"$ME\""; then
  echo
  echo "already assigned to you — resuming."
elif [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "[dry-run] would assign #$ID to $ME"
else
  gh issue edit "$ID" --repo "$REPO" --add-assignee @me >/dev/null
  echo
  echo "claimed: #$ID assigned to $ME"
fi
