# publite2 server-pool tuning (and the idle process-leak fix)

**Status:** fixed at source 2026-07-02. Applies to Phase 0 platform hardening.

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

### Steady state after the fix
1 single + 1 multi + 1 initial pbem launcher ≈ 3 persistent servers (~160MB), churning at
most every 10 min instead of every 20s. Circuit-breaker cap of 6.

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
