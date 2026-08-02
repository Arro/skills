---
name: upgrade-deps
description: Upgrade a pnpm project's dependencies — apply and commit minor/patch bumps, then assess each major against a six-month stability rule and apply the ones you approve.
disable-model-invocation: true
---

# Upgrade Deps

Keep the project on the latest of everything — with one exception: a major version younger than **six months** is too fresh to trust, so hold it until it has aged. Six months is the default bar; the human can move it when invoking.

Minor and patch bumps are applied and committed without asking. Majors are assessed and presented — **never apply a major the human hasn't approved**.

## Preconditions

- **pnpm only.** `pnpm-lock.yaml` must exist. If the project uses another package manager, stop and say so — don't translate the workflow.
- **Clean working tree.** The upgrade commits must contain nothing but the upgrade. If the tree is dirty, stop and ask the human to commit or stash first.
- **Workspace?** If `pnpm-workspace.yaml` exists, add `-r` to `pnpm outdated` and `pnpm up`. Deps on the `catalog:` protocol have their real specs in the `catalog`/`catalogs` section of `pnpm-workspace.yaml` — bumps to those happen there, not in `package.json`.

## 1. Survey

Run `pnpm outdated` (`-r` in a workspace). Exit code 1 with a table means outdated deps exist — that's the normal case, not a failure. (If pnpm instead errors about a store-location or pnpm-version mismatch, `rm -rf node_modules && pnpm install` — deleting first avoids the interactive purge prompt — then retry.)

Eyeball the table the way a cautious human would, and flag anything odd in the final report: a deprecated package, a version scheme change (semver → calver), a package that has been renamed or absorbed, a jump so large it suggests the dep is effectively a different library.

Split the rows: **same-major bumps** (minor/patch) versus **major bumps**. Two placements need care:

- A **0.x dep** whose bump sits in the minor position (`0.34.x` → `0.35.x`) belongs in the **major** pile — under 0.x semver that position is the breaking boundary. Its six-month clock runs from the `0.(x+1).0` release.
- A **prerelease pin** (`5.0.0-beta.31`) is a deliberate opt-in — leave it alone entirely and note it in the report.

## 2. Minor/patch sweep

Run `pnpm up` (`-r` in a workspace). It respects the ranges in `package.json` and rewrites the specs within them (`^4.0.0` → `^4.1.2`), so for caret-ranged deps this is the whole sweep.

Deps with **exact or tilde specs don't move** under `pnpm up` — the range *is* the pin. For each such dep still behind within its own major: find the newest in-major version (`pnpm view <pkg> versions --json`), edit the spec in `package.json` (or the catalog) by hand **preserving the pin style** — exact stays exact, tilde stays tilde — then `pnpm install` (plain, not with `CI=true` — CI mode implies a frozen lockfile and will refuse your spec edits). The pin style is a policy choice someone made; an upgrade doesn't get to change policy.

Then diff `package.json` and audit what `pnpm up` wrote, because it takes liberties beyond versions:

- It may **rewrite a pin prefix without changing the version** (`=4.0.488` → `^4.0.488`) — restore the original style.
- `pnpm.overrides` (and `resolutions`) pin versions that shadow the specs — bump them **in sync** with the matching dep, or the override silently keeps the old version.

Then verify: run whatever checks the repo declares in its `package.json` scripts — typecheck, tests, lint, build. Fix trivial fallout and include those fixes in the commit — a linter's minor bump often demands a config opt-in or reformats something, and that fallout belongs with the upgrade that caused it. If a single package's bump breaks something non-trivially, revert **that package** to where it was, finish the sweep without it, and list it in the report.

Commit the upgrade files plus any fallout fixes the checks demanded. Message: `chore: upgrade dependencies (minor/patch)` — or match the repo's evident commit convention.

## 3. Assess majors — change nothing yet

Group related packages into **families** that must move together: `react`/`react-dom`/`@types/react`, a `@types/*` package with its runtime package, a tool and its plugin ecosystem, scoped sets published from one monorepo (`@tanstack/*`). Two families follow different rules than "latest eligible":

- **`@types/node` tracks the Node runtime**, not the newest types. Find the runtime major (`.nvmrc`, `engines`, CI config, deploy target) and hold the types at it; only move when the runtime moves.
- A **deprecated package** (shown in the survey) isn't an upgrade decision at all — replacing it is its own piece of work. Flag it and move on.

Assess per family:

- **Pick the target major.** From `pnpm view <pkg> time --json`, find the highest major line whose first stable release (`x.0.0`) is at least six months old. That may be an intermediate major: on v4 with a month-old v6 and a two-year-old v5, the target is v5. If every major above current is younger than the bar, the family is **held** — note the date it becomes eligible.
- **Research the target.** Read the changelog / release notes / migration guide between current and target (find them via `pnpm view <pkg> homepage repository`). List what actually breaks.
- **Check against this codebase.** Grep for usage of each affected API. Also check that the rest of the dependency tree accepts the target — `pnpm view <pkg>@<version> peerDependencies` on the neighbours that depend on it.
- **Verdict**: **safe** (nothing breaking touches this codebase), **migration** (touches code — name the sites and the work), or **risky** (unclear blast radius, ecosystem not ready, or a genuine rewrite).

Present one table: family, current → target, target's age, verdict, one-line notes — plus the held families with eligibility dates. Then **stop and ask which to apply**.

## 4. Apply approved majors

One family at a time, each its own commit:

- `pnpm add <pkg>@^<target-version>` for every member of the family, matching the existing pin style (`--save-exact` for pinned deps). Don't use `pnpm up -L` — it goes to *latest*, which may be a younger major than the chosen target.
- Do the migration work the assessment named.
- Run the repo's checks. If the family won't go green with reasonable effort, revert it (`git checkout -- <upgrade files>` + `pnpm install`), and report what blocked it.
- Approved families sometimes interact — one family's breakage is actually caused by another still pending. Keep every commit green anyway: a clearly-marked temporary workaround is fine, so long as a later family's commit removes it and the final state carries none.
- Commit: `chore: upgrade <family> to v<X>`.

## 5. Report

Summarize: the minor/patch sweep, each major applied, each family held (with its eligibility date), anything reverted or blocked (with why), and any oddities from the survey. Commits stay local — pushing is the human's call.
