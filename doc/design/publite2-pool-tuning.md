# publite2 server-pool tuning (and the idle process-leak fix)

**Status:** ~~fixed at source 2026-07-02~~ **REOPENED and fixed FOR REAL 2026-07-03** — the
2026-07-02 tuning reduced the leak *rate* but not the *mechanism*; the pool ratcheted to 24
launchers in ~19h and (pre-tuning) to 260, wedging WSL2 so hard a VM force-kill was needed.
See **"2026-07-03: the actual fix"** at the bottom. The 07-02 analysis below is kept for
history; its "Startup overshoot (known, bounded, acceptable)" section was **wrong** — that
overshoot was the unbounded ratchet itself.

## Symptom

An idle `freeciv-web` container grows its memory footprint without bound until it hits a
hard ceiling. Observed:

- **Local (16GB box):** 255 live `freeciv-web --debug` game-server processes after ~90 min
  idle, ~54MB RSS each ≈ **14GB RAM**. Docker reported the container at 94% of a 15GB limit.
- **Droplet (`palatine-ov2`, 4GB):** climbing ~1 process/minute; **this is the real root
  cause of the 2026-07-02 OOM incident** that killed Tomcat and caused the silent 502 —
  the observability stack didn't cause the OOM, it just tipped an already-leaking box over
  the edge. The leak had been running in the background the whole time.

Processes have monotonically increasing distinct ports (6062, 6070, 6074 … 6210) and are all
alive (state `S`), i.e. genuine accumulation, not port reuse. Count plateaus at
`server_limit` (250).

## Mechanism

Three upstream freeciv-web pieces interact badly on a **low-traffic / idle** server:

1. **`init-freeciv-web.sh:53`** launches every non-longturn pool server with `--quitidle 20`
   — an idle server (no players connected) quits after 20 seconds. A *pool* server waiting
   for players is "idle" from the moment it starts, so the whole ready-pool churns on a
   ~20s cycle.
2. **`civlauncher.py` `run()` — `while 1:`** each launcher is a *persistent per-port
   respawner*: when its server exits (quitidle, or game end), it sleeps 5s and starts a new
   one on the **same** port. So launchers never go away on their own.
3. **`publite2.py` `check()`** every `metachecker_interval` (40s) reads the metaserver's
   count of *available* servers and, while `single < server_capacity_single` (etc.), spawns
   a **new** `Civlauncher` on a **new** port (`port += 1`). It does *not* account for the
   fact that existing launchers already self-respawn.

Put together: quitidle makes the idle pool constantly dip below capacity → publite2 keeps
adding new persistent launchers → old launchers keep respawning their own ports too →
process count ratchets up to `server_limit`.

On a busy public pubserver this never manifests because real players consume pool servers
(moving them out of the "available" count for a legitimate reason) faster than they churn.
Our private/synchronous-session use case has long idle stretches, which is exactly the
pathological case. **This is a design mismatch between the public-pubserver model and our
private-server model**, not a one-line bug.

## Fix

Two coordinated changes, both matched to our "small private server, synchronous sessions"
model rather than a public pubserver:

### 1. `publite2/settings.ini.dist` — minimal pool + hard circuit breaker
- `server_capacity_single = 1` (was 2) — we don't need a big ready-pool of solo games.
- `server_capacity_multi = 1` (was 1, unchanged) — one ready multiplayer game is what a
  session needs; bump later if the group wants concurrent games.
- `server_capacity_pbem = 0` (was 1) — we don't use play-by-email.
- `server_limit = 6` (was 250) — the load-bearing change: a hard ceiling on total game
  servers. Even if the spawn logic misbehaves, worst-case RAM is ~6 × 54MB ≈ 325MB instead
  of 14GB. Raise this deliberately if we ever want many concurrent games.

### 2. `publite2/init-freeciv-web.sh` — stop the idle churn
- `--quitidle 20` → `--quitidle 600` (10 min). Idle pool servers persist instead of
  churning every 20s, so the metaserver's available-count stays stable at capacity and
  publite2 stops over-spawning. Genuinely abandoned games still clean up after 10 min.
  `--exit-on-end` still fires immediately on game completion regardless, so finished games
  don't linger.

### 3. Removed the auto-starting longturn game pool
`publite2.py` globs `pubscript_longturn_*.serv` and starts one persistent (never-quitidle)
game per file. Upstream ships 5 sample longturn configs → 5 permanent servers we never use.
We chose **synchronous sessions, not async/longturn** (see ROADMAP execution log), so these
are pure dead weight. Deleted `publite2/pubscript_longturn_*.serv` and
`publite2/longturn_*.ruleset` from the fork. (If a future upstream merge re-adds them,
delete again — publite2 globs the directory unconditionally, so removing the files is the
simplest off switch.)

### Startup overshoot (known, bounded, acceptable)
publite2 gates spawning on the metaserver's count of *registered* available servers, which
lags while freshly-spawned servers boot (C server + proxy take a few seconds each). So
during the first minute or two it over-provisions a handful of extra pool servers before the
registered count catches up and spawning stops. This is bounded (settles, doesn't run away)
and self-corrects as the extras quitidle after 10 min. Not worth a deeper publite2 patch for
our low-traffic use case.

### Steady state after the fix
~1 single + 1 multi + 1 initial pbem + brief startup overshoot, no longturn — a few hundred
MB idle instead of 14GB. Circuit-breaker cap of 6 on the pooled types.

## Deployment note

Both files are **baked into the image at build time** (`settings.ini` is generated from
`.dist` during install; `init-freeciv-web.sh` is COPYd in), so the durable fix lands on the
next `docker compose build`. For an already-running container, the live files can be edited
in place and the container restarted (`docker restart`, which preserves the container FS)
for immediate effect without a 20-min rebuild.

## Follow-ups / open questions
- If we later want multiple concurrent games in one session, raise `server_capacity_multi`
  **and** `server_limit` together.
- Worth reporting the idle-overspawn upstream, but low priority — our fork's tuning fully
  addresses our use case.
- When the observability stack comes back, a `freeciv-web` process-count metric with an
  alert threshold (say > 8) would catch any regression of this immediately.

---

## 2026-07-03: the actual fix (the 07-02 tuning was not sufficient)

**What happened:** ~19h after the tuning above, the local container had ratcheted to **24
launchers** (ports 6000–6023) despite `server_limit = 6` in the *live, verified-correct*
`settings.ini`. The pileup eventually wedged the container beyond `docker kill`, wedged WSL2
beyond `wsl --shutdown`, and required force-killing the WSL VM. The tuning had only slowed
the ratchet (600s churn window instead of 20s); the mechanism was intact.

**Why `server_limit` never engaged — the real bug in `publite2.py`:** the spawn loops gated
on `self.total`/`self.single`/`self.multi`, which are overwritten every 40s cycle **from the
metaserver** — a lagging, flapping external count of *available pregame* servers:

- A freshly spawned server takes seconds to boot and register → during that window the
  metaserver count is low → publite2 spawns another launcher on the next port.
- Every `--quitidle` recycle deregisters/re-registers a server → another lag window each
  10 minutes, forever → +1 launcher each time.
- `Civlauncher.run()` is `while 1:` — **immortal**; every launcher ever created respawns its
  server forever and `server_list` was append-only. Extras never "self-correct away"
  (the 07-02 "startup overshoot… self-corrects" claim above was wrong: quitidle kills the
  *server process*, and its immortal launcher instantly respawns it — launchers never die).
- `server_limit` was compared against the metaserver total, **never** against the actual
  launcher count. The only `len(server_list)` check (`fork_bomb_preventer`) requires the
  metaserver to report **zero** servers — unreachable during a slow ratchet.

**The fix (in our fork's `publite2.py`):**
1. Spawn loops now gate on **publite2's own live launcher list** — per-type counts from
   `server_list`, with dead threads pruned (`is_alive()`) — not on metaserver counts. The
   metaserver numbers remain for status display only.
2. `server_limit` is now enforced as `len(server_list) < server_limit` — a real hard cap on
   actual launcher processes.
3. Startup no longer spawns launchers for game types with capacity 0 (previously an
   unconditional one-per-type, which is why an unused pbem server always ran).
4. **Semantic change, documented in `settings.ini.dist`:** capacities now mean *total
   launchers per type*, not *available pregame servers*. For our private one-game-at-a-time
   server this is exactly right: steady state is **exactly 2 processes** (1 singleplayer +
   1 multiplayer), 456MiB container RSS at idle.

**Verified:** post-fix restart → exactly 2 servers (6000/6001), "Skipping pbem (capacity 0)"
logged, `epoch-check.sh` (ruleset validate + autogame smoke) passes, count stable across the
smoke test's transient server and across 14+ min of idle uptime (past the first
`--quitidle 600` window) with zero new ports. (Notably, at 600s the idle servers did not even
recycle during observation — no churn at all. Regardless, the spawn gate is now structural:
it counts live launcher threads, so metaserver registration flaps can no longer ratchet the
pool whenever recycles do occur.)

**Deployment:** `publite2.py` + `settings.ini.dist` are COPYd into the image at build; the fix
was also `docker cp`'d into the running local container. **The droplet (`palatine-ov2`) still
runs the leaking code — redeploy (git pull + `docker compose build`) before the next session,
or at minimum `docker cp` the fixed `publite2.py` there and restart.**
