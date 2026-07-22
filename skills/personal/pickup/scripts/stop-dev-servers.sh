#!/usr/bin/env bash
# Stop the dev servers belonging to one worktree — and only that worktree.
#
# Shared by /pickup (step 10), /wrapup (teardown) and /test-drive (collapse).
# Ports come from the worktree's own env files, so a worktree that was assigned
# several (PORT, INNGEST_PORT, …) is fully cleared. A listener whose working
# directory is outside the worktree is left alone: it belongs to the main
# checkout or another worktree, and killing it would take down someone else's
# server.
#
# usage: stop-dev-servers.sh <worktree-path>

set -uo pipefail

WT="${1:-}"
if [ -z "$WT" ]; then
  echo "usage: stop-dev-servers.sh <worktree-path>" >&2
  exit 2
fi
if [ ! -d "$WT" ]; then
  echo "stop-dev-servers: no such directory: $WT" >&2
  exit 2
fi

# lsof reports symlink-resolved paths, so compare against a resolved root.
WT="$(cd "$WT" && pwd -P)"

killed=0
checked=0

# \042 = double quote, \047 = single quote — env values are often quoted.
for port in $(grep -hE '^[A-Z_]*PORT=' "$WT"/.env* 2>/dev/null | cut -d= -f2 | tr -d '\042\047' | sort -u); do
  case "$port" in
    '' | *[!0-9]*) continue ;;
  esac
  checked=$((checked + 1))
  for pid in $(lsof -tiTCP:"$port" -sTCP:LISTEN -n -P 2>/dev/null); do
    cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')"
    case "$cwd" in
      "$WT" | "$WT"/*)
        if kill "$pid" 2>/dev/null; then
          echo "stopped pid $pid on port $port"
          killed=$((killed + 1))
        else
          echo "could not kill pid $pid on port $port" >&2
        fi
        ;;
      *)
        echo "left pid $pid on port $port alone — its cwd ($cwd) is outside this worktree"
        ;;
    esac
  done
done

if [ "$checked" -eq 0 ]; then
  echo "no *PORT= entries found in $WT/.env* — nothing to stop"
elif [ "$killed" -eq 0 ]; then
  echo "no dev servers from this worktree were listening"
fi

exit 0
