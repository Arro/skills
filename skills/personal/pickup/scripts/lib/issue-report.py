"""Gate and present one GitHub issue for /pickup.

Reads the issue payload from the ISSUE_JSON environment variable (the caller
already paid for the `gh issue view` round trip) and prints, in order: a header,
either a REFUSING line or the suggested branch/thread names, and the contract
the agent implements against. The final line is an "EXIT <code>" marker the
calling shell strips and turns into its own exit status.

usage: ISSUE_JSON=… issue-report.py <my-github-login>
"""

import json
import os
import re
import sys

STOPWORDS = {
    "a", "an", "the", "and", "or", "of", "for", "to", "in", "on", "with",
    "from", "by", "at", "as", "is", "are", "be", "it", "its", "this", "that",
    "then", "into", "per", "via",
}
BUG_LABELS = {"bug", "type:bug", "kind/bug"}
AGENT_BRIEF = re.compile(r"^##\s*Agent Brief", re.M)


def main() -> None:
    me = sys.argv[1]
    issue = json.loads(os.environ["ISSUE_JSON"])

    labels = [label["name"] for label in issue.get("labels") or []]
    assignees = [a["login"] for a in issue.get("assignees") or []]

    print("#%s  %s" % (issue["number"], issue["title"]))
    print(issue["url"])
    print("state: %s   labels: %s   assignees: %s" % (
        issue["state"], ", ".join(labels) or "(none)", ", ".join(assignees) or "(none)"))
    print()

    if issue["state"] != "OPEN":
        print("REFUSING: issue is %s, not OPEN." % issue["state"])
        print("EXIT 3")
        return

    if "ready-for-agent" not in labels:
        print("REFUSING: issue is not labeled 'ready-for-agent'.")
        print("Ask the user before starting work on it.")
        print("EXIT 4")
        return

    if assignees and me not in assignees:
        print("REFUSING: already assigned to %s — another agent or human is on it."
              % ", ".join(assignees))
        print("EXIT 5")
        return

    words = [w for w in re.split(r"[^a-z0-9]+", issue["title"].lower()) if w]
    meaningful = [w for w in words if w not in STOPWORDS] or words
    kind = "fix" if any(label.lower() in BUG_LABELS for label in labels) else "feat"

    print("SUGGESTED_BRANCH %s/%s-%s" % (kind, issue["number"], "-".join(meaningful[:5])))
    print("SUGGESTED_LABEL #%s %s" % (issue["number"], " ".join(meaningful[:5])))
    print()

    comments = issue.get("comments") or []
    briefs = [c for c in comments if AGENT_BRIEF.search(c.get("body", ""))]

    if briefs:
        latest = briefs[-1]
        print("=== CONTRACT: most recent '## Agent Brief' comment (%s) — "
              "the issue body below is context ===" % latest.get("createdAt", "unknown date"))
        print(latest["body"])
        print()
        print("=== ISSUE BODY (context only) ===")
    else:
        print("=== CONTRACT: issue body (no Agent Brief comment) ===")
    print(issue.get("body") or "(empty)")

    others = [c for c in comments if c not in briefs]
    if others:
        print()
        print("=== %d other comment(s) — context ===" % len(others))
        for comment in others:
            author = (comment.get("author") or {}).get("login", "unknown")
            print("--- %s @ %s ---" % (author, comment.get("createdAt", "")))
            print(comment.get("body", ""))

    print("EXIT 0")


if __name__ == "__main__":
    main()
