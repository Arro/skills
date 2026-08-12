"""Check that a project's dev scripts will honour an externally assigned PORT.

Two independent things can defeat the assignment, and both must hold:

  1. the script defers to ${PORT:-<default>} rather than a hardcoded -p number
     (a hardcoded flag always wins), and
  2. the script sources .env.local into its *own* shell before that flag is
     expanded — ${PORT:-3008} is substituted by the shell npm spawns, long
     before any dotenv loader in Node runs, so writing PORT into .env.local
     alone never reaches it.

Prints "PINNED <ports…>" (defaults the project pins, which a worktree must not
land on) and, when something is wrong, "PROBLEMS" followed by one line per
offending script.

usage: dev-port-guard.py <path-to-package.json>
"""

import json
import re
import sys

BINDS_PORT = re.compile(r"\$\{PORT|(?<![\w-])-p\s|--port")
SOURCES_ENV = re.compile(r"(^|;|&&|\|\||\s)(\.|source)\s+\.?/?\.env\.local")
PINNED_DEFAULT = re.compile(r"\$\{PORT:-(\d+)\}")


def main() -> None:
    with open(sys.argv[1]) as handle:
        scripts = json.load(handle).get("scripts") or {}

    problems = []
    for name, body in scripts.items():
        body = body or ""
        if not name.startswith("dev") or not BINDS_PORT.search(body):
            continue
        missing = []
        if "${PORT" not in body:
            missing.append("does not defer to ${PORT:-<default>} (a hardcoded port always wins)")
        if not SOURCES_ENV.search(body):
            missing.append("does not source .env.local into its own shell")
        if missing:
            problems.append("  %s: %s" % (name, "; ".join(missing)))

    defaults = sorted({m for body in scripts.values() for m in PINNED_DEFAULT.findall(body or "")})
    print("PINNED " + " ".join(defaults))

    if problems:
        print("PROBLEMS")
        print("\n".join(problems))


if __name__ == "__main__":
    main()
