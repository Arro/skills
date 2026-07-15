# Assign each worktree its own dev-server port, deterministically, and stop the server when the thread ends

`/pickup` is built so multiple sessions can run in parallel, each in an isolated worktree under `$MAIN/.worktrees/<id>`. But nothing coordinated the **dev-server port**: two live worktrees would each start a server on the project's default port (e.g. `3000`) and the second would fail to bind — or worse, silently attach to the first. And nothing ever *stopped* those servers, so they leaked past the end of the thread and lingered on the machine.

We give every worktree its own **Worktree PORT**, derived deterministically, recorded in the worktree's environment, and torn down when the work is done.

## The constraint: `/pickup` doesn't start the server, and issue ids repeat across repos

Two facts shaped the design:

- **`/pickup` never starts the dev server itself.** It's started ad hoc during implementation or verification, by whatever tool or step needs it. So a port assignment is only useful if whoever *does* start the server picks it up automatically. The assignment has to live somewhere every start path already reads — the **environment** — not in a flag only one caller knows to pass.
- **Issue ids collide across codebases.** Issue `#15` exists in many repos at once. Any scheme keyed on the id alone piles every repo's low-numbered issues onto the same slots, so cross-codebase collisions on the *preferred* port would be common, not rare.

A third fact came from the machine itself: a working setup typically keeps a cluster of low ports permanently occupied by the always-on main-checkout servers of other projects. A worktree server must dodge those live ports, not just other worktrees.

## Decision

**Derivation.** The preferred port is

```
preferred = 3100 + (cksum("<slug>-<id>") mod 900)
```

- `<slug>` is the project slug from the project's `CLAUDE.md` (the same block `rename-thread` reads), so `<slug-a>-15` and `<slug-b>-15` map to different ports. Folding the slug in is what keeps the collision risk genuinely tiny.
- Hashing the `"<slug>-<id>"` string with `cksum` (deterministic across runs, unlike a salted `hash()`) folds GitHub numbers and Linear identifiers in identically — no special-casing.
- The band `3100–3999` is one **Worktree port band** shared by all projects, chosen to sit clear of the low ports a machine typically keeps occupied by always-on main-checkout servers. It ships as a global default in the skill; a project's `CLAUDE.md` *may* override `band_base`/`band_size`, but the default path needs zero per-project config.

**Bind-check-and-bump.** At assignment time `/pickup` checks whether the preferred port is actually bound (`lsof -iTCP:$port -sTCP:LISTEN`) and, if so, probes upward within the band. A real bind check — not a maintained registry — is the collision guard, because it catches *everything* at once: other live worktrees, the always-on main servers, and anything random. It cannot leak, because the "registry" is just what's currently listening.

**Injection.** The chosen port is written as `PORT` into the worktree's env file during worktree setup, alongside the `.env*` copy `/pickup` already does. The **canonical fact is "each worktree has a `PORT` in its environment"** — a single source of truth everything else keys off.

**Enforcement lives in the dev script, not in prose.** Real projects pin their dev port with a CLI flag (`next dev -p 3008`), and a port flag **beats** the `PORT` env var — so env injection alone is silently defeated exactly where it matters. The convention: dev scripts express their port as `${PORT:-<pinned default>}` (npm/pnpm run scripts through `sh`, so this works verbatim in `package.json`). The main checkout, where `PORT` is unset, keeps its pinned port and any reverse-proxy hostname mapped to it; a worktree inherits its assignment with no flag, no instruction, and nothing for an agent to remember mid-task. `/pickup` guards the gap: after assigning `PORT` it checks the project's dev script actually references it, and stops loudly — "this project pins its port; the assignment will be ignored" — rather than colliding silently.

**Multi-service projects** (a web server plus a job runner, say) need more than one port per worktree. `/pickup` stays generic: it writes only `PORT`, and the project declares any secondary port names in its `docs/agents/worktrees.md` (the per-project parameters file `/pickup` already reads), each derived from `PORT` at a fixed offset well clear of the band (e.g. `SOMETOOL_PORT = PORT + 10000`). Dev scripts reference them the same way (`${SOMETOOL_PORT:-<pinned default>}`).

**Browser verification in a worktree uses `localhost:$PORT` directly.** A project whose `CLAUDE.md` mandates browsing via a reverse-proxied hostname is describing its *main checkout* — the worktree's port has no such hostname, and following the hostname rule from a worktree means verifying against the wrong server's code.

**Shutdown.** A worktree's dev server is stopped in two places:
- **`/pickup` (primary):** as its last act — on success *or* bail-out — it stops whatever is listening on its `PORT`. A left-behind worktree must not mean a left-behind server.
- **`/wrapup` (backstop):** before `git worktree remove`, it kills anything still on that worktree's `PORT`, guaranteeing teardown is clean even if `/pickup` crashed or a later session restarted the server.

Both kill paths **verify the listening process's working directory is inside the worktree** before killing, so a mis-derived port can never take down an unrelated main-checkout server.

## Alternatives rejected

- **A maintained port registry** (`ports.json` with claim/release): guaranteed unique, but a stateful file that leaks entries when a session dies mid-run. The bind check gives the same guarantee with no state to leak.
- **Runtime free-port scan with no deterministic base:** zero bookkeeping, but the port isn't stable across restarts and is decided by the server-start tool rather than by `/pickup`. We keep a deterministic *preferred* port for stability and use scanning only as the bump fallback.
- **Per-project port bands:** extra config to maintain for almost no benefit once a real bind check exists; projects already "own" their normal dev port on the machine anyway. One global band, override allowed but never required.
- **Keying the port off the id alone:** collides across repos on common low issue numbers (see the constraint above). Folding in the slug fixes it.
- **Tracking the server PID instead of the port:** unreliable, because `/pickup` doesn't start the server and has no handle on it. The `PORT` the worktree owns is the durable handle.
- **A `CLAUDE.md`-documented start command as the enforcement mechanism:** prose an agent must remember to follow at the moment it starts a server, mid-implementation — and defeated outright by the hardcoded port flags real dev scripts carry. Instructions-as-enforcement was the weakest link; the `${PORT:-default}` script convention replaces it and the guard in `/pickup` catches projects that haven't adopted it.

## Invariants this creates

- Every picked-up worktree has a `PORT` in its env file, unique among *live* worktrees and clear of any port already in use on the machine.
- A project's dev scripts express every port they bind as `${PORT:-<pinned default>}` (or `${<NAME>_PORT:-…}` for secondary services) — never a bare hardcoded flag. `/pickup` refuses to proceed silently against a script that pins its port.
- `/pickup` leaves no dev server running when it exits — success or bail-out.
- `/wrapup` never removes a worktree while a server is still bound to its port.
- Both shutdown paths kill only processes whose working directory is inside the worktree, and cover secondary ports as well as `PORT`.
