#!/usr/bin/env bash
set -euo pipefail

# NOTE: This is a dev-only script, like link-skills.sh. It is not a supported
# installer.
#
# OpenCode finds the skills link-skills.sh puts in ~/.agents/skills, but only
# the model can load them (through its `skill` tool): OpenCode has no
# /skill-name syntax. This script gives every user-invoked skill (the ones
# with `disable-model-invocation: true`) a matching OpenCode command at
# ~/.config/opencode/commands/<name>.md, so `/grab 123` works. Each command is
# a thin shim that tells the model to load the skill, so the skill's text still
# lives only in this repo. Run link-skills.sh first, and re-run both after
# adding, removing, or renaming a skill. Restart OpenCode to pick up changes.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/commands"

# Every shim carries this phrase. It is how a later run tells its own files
# apart from commands the user wrote by hand, and only its own files are
# ever overwritten or removed.
MARKER="skill with the skill tool and follow its instructions"

# Print one frontmatter field's value, with any surrounding double quotes
# removed. Only single-line values are supported, which is all this repo uses.
field() {
  awk -v key="$2" '
    NR == 1 && /^---$/ { fm = 1; next }
    fm && /^---$/ { exit }
    fm && index($0, key ": ") == 1 { print substr($0, length(key) + 3); exit }
  ' "$1" | sed -e 's/^"\(.*\)"$/\1/'
}

yaml_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

mkdir -p "$DEST"

# Same selection as link-skills.sh: skip `deprecated/` and `misc/`.
wanted=()
while IFS= read -r -d '' skill_md; do
  [ "$(field "$skill_md" disable-model-invocation)" = "true" ] || continue

  name="$(field "$skill_md" name)"
  description="$(field "$skill_md" description)"
  hint="$(field "$skill_md" argument-hint)"
  [ -n "$hint" ] && description="$description (Arguments: $hint)"
  target="$DEST/$name.md"

  if [ -e "$target" ] && ! grep -qF "$MARKER" "$target"; then
    echo "skipped $name: $target exists and was not written by this script" >&2
    continue
  fi

  cat > "$target" <<EOF
---
description: "$(yaml_escape "$description")"
---
Load the \`$name\` $MARKER.

Arguments: \$ARGUMENTS
EOF
  wanted+=("$name")
  echo "wrote /$name -> $target"
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' -not -path '*/misc/*' -print0)

# Remove shims for skills that were renamed, removed, or made model-invoked.
for shim in "$DEST"/*.md; do
  [ -e "$shim" ] || continue
  grep -qF "$MARKER" "$shim" || continue
  name="$(basename "$shim" .md)"
  case " ${wanted[*]:-} " in
    *" $name "*) ;;
    *) rm "$shim" && echo "removed stale /$name" ;;
  esac
done
