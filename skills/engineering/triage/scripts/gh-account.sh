#!/usr/bin/env bash
# Print the logged-in gh account that owns this repo's committer email, or
# nothing when there is no match.
#
# Reads only the repo-local identity (the [user] section of .git/config), not
# the global one: a repo-local email is a deliberate per-repo choice, while the
# global one is just a default. Matches it against every account `gh auth
# status` knows on github.com, in order:
#
#   1. a users.noreply.github.com address, which names its login outright;
#   2. the account's public profile email;
#   3. the account's full email list, when its token has the `user:email` scope.
#
# The caller uses the login per command, never via `gh auth switch`, which
# would change the active account globally and race parallel sessions:
#
#   GH_TOKEN="$(gh auth token --user <login>)" gh <args>
#
# Always exits 0; an empty result means "use gh as it is".
#
# usage: gh-account.sh

set -uo pipefail

EMAIL="$(git config --local --get user.email 2>/dev/null | tr '[:upper:]' '[:lower:]')"
[ -n "$EMAIL" ] || exit 0

LOGINS="$(gh auth status --hostname github.com --json hosts \
  --jq '.hosts["github.com"][]? | select(.state == "success") | .login' 2>/dev/null)"
[ -n "$LOGINS" ] || exit 0

# 1. <id>+<login>@users.noreply.github.com, or the older <login>@users.noreply.github.com.
case "$EMAIL" in
  *@users.noreply.github.com)
    NOREPLY="${EMAIL%@users.noreply.github.com}"
    NOREPLY="${NOREPLY#*+}"
    while IFS= read -r login; do
      if [ "$(printf '%s' "$login" | tr '[:upper:]' '[:lower:]')" = "$NOREPLY" ]; then
        echo "$login"; exit 0
      fi
    done <<< "$LOGINS"
    ;;
esac

# 2 and 3, one account at a time.
while IFS= read -r login; do
  TOKEN="$(gh auth token --hostname github.com --user "$login" 2>/dev/null)" || continue
  EMAILS="$( {
    GH_TOKEN="$TOKEN" gh api user --jq '.email // empty' 2>/dev/null
    GH_TOKEN="$TOKEN" gh api user/emails --jq '.[].email' 2>/dev/null
  } | tr '[:upper:]' '[:lower:]')"
  if printf '%s\n' "$EMAILS" | grep -qxF "$EMAIL"; then
    echo "$login"; exit 0
  fi
done <<< "$LOGINS"

exit 0
