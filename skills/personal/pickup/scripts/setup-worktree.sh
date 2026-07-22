#!/usr/bin/env bash
# Create and provision an isolated /pickup worktree.
#
# Deterministic half of /pickup step 5: worktree off origin/main, gitignored
# container, copied env files, a collision-free dev-server PORT, dependencies
# installed. Everything requiring judgement (reading the contract, the project's
# database rules) stays with the agent.
#
# usage: setup-worktree.sh <id> <branch> [--no-install] [--skip-port-guard]
#
# Exits non-zero — creating nothing — when a precondition the skill says to
# "stop and ask" about fails: an existing worktree, or a dev script that would
# silently ignore the assigned PORT.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

ID=""
BRANCH=""
DO_INSTALL=1
PORT_GUARD=1

while [ $# -gt 0 ]; do
  case "$1" in
    --no-install) DO_INSTALL=0 ;;
    --skip-port-guard) PORT_GUARD=0 ;;
    -*) echo "setup-worktree: unknown flag $1" >&2; exit 2 ;;
    *)
      if [ -z "$ID" ]; then ID="$1"
      elif [ -z "$BRANCH" ]; then BRANCH="$1"
      else echo "setup-worktree: unexpected argument $1" >&2; exit 2
      fi
      ;;
  esac
  shift
done

if [ -z "$ID" ] || [ -z "$BRANCH" ]; then
  echo "usage: setup-worktree.sh <id> <branch> [--no-install] [--skip-port-guard]" >&2
  exit 2
fi

# Lowercase the id so GitHub numbers and Linear identifiers land identically.
ID="$(printf '%s' "$ID" | tr '[:upper:]' '[:lower:]')"

MAIN="$(git worktree list --porcelain | awk '/^worktree / {print $2; exit}')"
if [ -z "$MAIN" ]; then
  echo "setup-worktree: not inside a git repository" >&2
  exit 2
fi
WT="$MAIN/.worktrees/$ID"

BASE="${PICKUP_PORT_BASE:-3100}"
SIZE="${PICKUP_PORT_SIZE:-900}"

echo "main checkout: $MAIN"
echo "worktree:      $WT"
echo "branch:        $BRANCH (from origin/main)"
echo

# ── Preconditions (checked before anything is created) ──────────────

if [ -e "$WT" ]; then
  echo "REFUSING: $WT already exists — an earlier run on this ticket did not clean up." >&2
  echo "Inspect it, then either resume there or 'git -C \"$MAIN\" worktree remove \"$WT\"'." >&2
  exit 3
fi

if git -C "$MAIN" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "REFUSING: branch '$BRANCH' already exists locally." >&2
  exit 3
fi

# The dev script must both defer to $PORT and source .env.local into its own
# shell, or the PORT assigned below is silently ignored and the worktree serves
# on a port that may belong to the main checkout.
if [ "$PORT_GUARD" -eq 1 ] && [ -f "$MAIN/package.json" ]; then
  guard_output="$(python3 "$SCRIPT_DIR/lib/dev-port-guard.py" "$MAIN/package.json")"
  PINNED_PORTS="$(printf '%s\n' "$guard_output" | sed -n 's/^PINNED //p')"
  if printf '%s\n' "$guard_output" | grep -q '^PROBLEMS$'; then
    echo "REFUSING: this project's dev script would ignore the assigned PORT." >&2
    printf '%s\n' "$guard_output" | sed -n '/^PROBLEMS$/,$p' | tail -n +2 >&2
    cat >&2 <<'EOF'

Fix the project's package.json first (a one-time prerequisite commit, NOT part
of this ticket's PR):

  "dev": "set -a; [ -f .env.local ] && . ./.env.local; set +a; next dev -p ${PORT:-3008}"

Then re-run. Use --skip-port-guard only if this project has no dev server to run.
EOF
    exit 4
  fi
else
  PINNED_PORTS=""
fi

# ── Create the worktree ─────────────────────────────────────────────

# Git does not auto-ignore a nested worktree; without this the main checkout
# shows the whole worktree as untracked. Clone-local, so nothing to commit.
GIT_COMMON="$(git -C "$MAIN" rev-parse --path-format=absolute --git-common-dir)"
mkdir -p "$GIT_COMMON/info"
grep -qxF '/.worktrees/' "$GIT_COMMON/info/exclude" 2>/dev/null \
  || echo '/.worktrees/' >> "$GIT_COMMON/info/exclude"

git -C "$MAIN" fetch origin --quiet
# Branch point is always origin/main — the skill forbids stacked PRs.
git -C "$MAIN" worktree add "$WT" -b "$BRANCH" origin/main

# ── Copy gitignored local files ─────────────────────────────────────

copied=""
for f in "$MAIN"/.env*; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  [ "$b" = ".env.example" ] && continue
  cp "$f" "$WT/$b"
  copied="$copied $b"
done
echo "copied env files:${copied:- (none found)}"

# ── Assign a dev-server port ────────────────────────────────────────

slug="$(awk '
  /^##[[:space:]]*Project slug/ { in_block = 1; next }
  in_block && /^##[[:space:]]/  { exit }
  in_block && /slug:/ { sub(/^.*slug:[[:space:]]*/, ""); print; exit }
' "$MAIN/CLAUDE.md" 2>/dev/null || true)"
slug="$(printf '%s' "$slug" | tr -d '[:space:]')"
[ -n "$slug" ] || slug="$(basename "$MAIN")"

# Ports already claimed by sibling worktrees count as taken even when their
# server is down — otherwise two worktrees collide the moment both start.
reserved="$PINNED_PORTS
$(grep -hE '^[A-Z_]*PORT=' "$MAIN"/.worktrees/*/.env* "$MAIN"/.env* 2>/dev/null \
    | cut -d= -f2 | tr -d '\042\047' || true)"

is_taken() {
  printf '%s\n' $reserved | grep -qxF "$1" && return 0
  lsof -iTCP:"$1" -sTCP:LISTEN -n -P >/dev/null 2>&1
}

port=$(( BASE + ($(printf '%s' "$slug-$ID" | cksum | cut -d' ' -f1) % SIZE) ))
preferred="$port"
attempts=0
while is_taken "$port"; do
  port=$(( port >= BASE + SIZE - 1 ? BASE : port + 1 ))
  attempts=$((attempts + 1))
  if [ "$attempts" -ge "$SIZE" ]; then
    echo "setup-worktree: no free port in $BASE-$((BASE + SIZE - 1))" >&2
    exit 5
  fi
done

set_env_var() {
  # Replace rather than append: a copied .env.local may already pin PORT.
  local name="$1" value="$2" file="$WT/.env.local"
  [ -f "$file" ] && sed -i '' "/^${name}=/d" "$file"
  printf '%s=%s\n' "$name" "$value" >> "$file"
}

set_env_var PORT "$port"
if [ "$port" = "$preferred" ]; then
  echo "assigned PORT=$port (hash of '$slug-$ID')"
else
  echo "assigned PORT=$port (preferred $preferred was taken)"
fi

# Secondary ports, declared in the project's own worktree doc as e.g.
# "INNGEST_PORT = PORT + 10000".
if [ -f "$MAIN/docs/agents/worktrees.md" ]; then
  while read -r name offset; do
    [ -n "${name:-}" ] || continue
    set_env_var "$name" "$((port + offset))"
    echo "assigned $name=$((port + offset))"
  done < <(awk '
      /^##[[:space:]]*Secondary ports/ { in_block = 1; next }
      in_block && /^##[[:space:]]/     { exit }
      in_block                         { print }
    ' "$MAIN/docs/agents/worktrees.md" \
    | grep -oE '[A-Z][A-Z_]*_PORT[[:space:]]*=[[:space:]]*PORT[[:space:]]*\+[[:space:]]*[0-9]+' \
    | sed -E 's/[[:space:]]*=[[:space:]]*PORT[[:space:]]*\+[[:space:]]*/ /')
fi

# ── Install dependencies ────────────────────────────────────────────

if [ "$DO_INSTALL" -eq 1 ] && [ -f "$WT/package.json" ]; then
  if [ -f "$WT/pnpm-lock.yaml" ]; then
    (cd "$WT" && pnpm install)
  elif [ -f "$WT/yarn.lock" ]; then
    (cd "$WT" && yarn install)
  elif [ -f "$WT/bun.lockb" ] || [ -f "$WT/bun.lock" ]; then
    (cd "$WT" && bun install)
  else
    (cd "$WT" && npm install)
  fi
fi

# ── Summary ─────────────────────────────────────────────────────────

cat <<EOF

────────────────────────────────────────────────────────────
worktree ready
  path:   $WT
  branch: $BRANCH
  port:   http://localhost:$port
  cd "$WT" for the rest of the session.
EOF

if [ -f "$MAIN/docs/agents/worktrees.md" ]; then
  cat <<EOF

STILL YOURS TO DO — this project has docs/agents/worktrees.md. Read it and
follow it before running any migration or starting the dev server (it is where
throwaway-database rules live; this script never touches a database).
EOF
fi
echo "────────────────────────────────────────────────────────────"
