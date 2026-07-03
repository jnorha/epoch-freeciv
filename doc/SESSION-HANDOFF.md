# Session Handoff — 2026-07-03

> Written 2026-07-03. The WSL2 wedge was RESOLVED without a full reboot (the VM was force-killed
> and came back clean); the environment is currently LIVE and healthy. The engine-gap evaluation
> is COMPLETE. Everything is on disk. The one real open task is the leak fix (§2).

---

## 1. Current status & next steps

**RESOLVED (no reboot needed in the end):** the wedged WSL2 VM was force-killed
(`vmmemWSL`/`vmwp` → gone), then restarted clean. Docker Desktop relaunched, `freeciv-web` was
started fresh (`docker start freeciv-web`), `epoch-check.sh` passed (validate + smoke), and all
spikes resumed and completed. `C:\Users\danjo\.wslconfig` (memory=12GB/swap=4GB) is active and
now caps the VM — a future leak can't take the 31GB host down again.

**Evaluation is DONE:** all 5 spikes resolved (§3), all 6 sub-plan docs written, roadmap
re-tiered. **Headline confirmed empirically + by shipped precedent: no C fork needed for any
T1/T2 feature.**

**The publite2 leak is now FIXED AT THE ROOT (2026-07-03).** The `.dist`-vs-live hypothesis
was **disproven** — the live `settings.ini` was correct all along. The real bug: `publite2.py`
gated spawning on lagging/flapping **metaserver** counts while `Civlauncher` threads are
immortal, so every lag window ratcheted the pool +1 forever; `server_limit` was never compared
against actual launcher count. Fixed in our fork's `publite2.py` (gate on live `server_list`
per type, prune dead threads, hard-cap on `len(server_list)`, skip capacity-0 types at
startup). Steady state: exactly 2 servers (6000/6001). Full write-up:
`doc/design/publite2-pool-tuning.md` §"2026-07-03: the actual fix".
**Remaining:** redeploy the droplet (`palatine-ov2`) — it still runs the leaking code.

**If you want belt-and-suspenders spikes** for S3/S4 (resolved by shipped precedent, not run):
recipes in §5. Not required — the shipped `native_to` data and Oil Platform/Buoy already
demonstrate the mechanisms.

**Container ops reminder:** for any hand-run autogame use `--port 5757` + a host `timeout` +
`--exit-on-end`; do NOT `pkill -f "/tmp/x.serv"` (it matches the wrapper shell) — rely on
`--exit-on-end`. Restore the clean ruleset after with `docker cp data/epoch/. freeciv-web:…`.

## 2. INCIDENT — publite2 process leak wedged WSL (root cause + fix TODO)

**What happened:** over ~19 h the running `freeciv-web` container leaked to **260 `freeciv-web`
processes** (publite2 pool churn). This exhausted the container/VM, so *new* hand-run autogames
blocked at startup (never loaded the ruleset — this is what looked like "hangs" all session).
The pileup then wedged the container so hard that `docker restart`, `docker kill`, `docker rm -f`,
`wsl --shutdown`, and `Restart-Service WSLService` all failed to kill it → **reboot required.**

**Why the earlier fix didn't hold:** last session I edited `publite2/settings.ini.dist`
(server_limit 6, capacities 1/1/0) and `init-freeciv-web.sh` (`--quitidle 20→600`). But:
- publite2 reads **`settings.ini`**, not `settings.ini.dist`. The `.dist` is only copied to
  `settings.ini` **if the latter doesn't already exist** (verify: read `publite2/run.sh` /
  `publite2.py` for the copy logic). A stale `settings.ini` (baked in the image or created at
  first run) would shadow the fix.
- The running container had been **Up 19 h** — quite possibly built before the edit, so the
  image never contained it.

**Fix TODO (do this before trusting a long autogame):**
1. In a fresh container, `cat /docker/publite2/settings.ini` (the REAL file) and confirm
   server_limit / capacities. If it doesn't match `settings.ini.dist`, the copy isn't happening.
2. Make the fix authoritative: either COPY `settings.ini` (not just `.dist`) in the Dockerfile,
   or have `run.sh` always overwrite `settings.ini` from `.dist`. Rebuild the image.
3. Re-verify the leak is gone: run the container idle ~30 min, `docker top freeciv-web | grep -c
   freeciv-web` should stay in single digits, not climb.
4. This is essentially the same bug documented in `doc/design/publite2-pool-tuning.md` — update
   that doc with the "`.dist` vs live `settings.ini`" finding.

**Cleanup note:** a fresh `docker compose up -d` container has ZERO leaked processes, so it's
safe to resume immediately; the leak is a slow burn, not instant.

## 3. Task state (the approved plan: "Engine-Gap Evaluation & Feature Sub-Plans")

Plan file: `C:\Users\danjo\.claude\plans\i-have-a-sizable-golden-beaver.md`.
Headline finding (unchanged, now partly spike-proven): **every user-named feature — ocean
cities, orbital units, sea improvements, special actions, tech pacing — needs ZERO Freeciv C
patches.**

### Verification spikes
| Spike | Status | Result |
|---|---|---|
| **S2** tech classes + `cost_pct` | ✅ DONE | Era-pacing knobs work (load + autogame confirmed). |
| **S5** User Action → Lua dispatch | ✅ DONE | Full loop proven — see §4. |
| **S1** ocean city founding + survival | ✅ PASS (2026-07-03) | Coastal ocean city survived 30 turns, grew 1→2; isolated one starved (food, not terrain). Zero C. |
| **S3** undersea tunnel (`causes="Road"` on ocean) | ✅ confirmed by shipped precedent | Oil Platform (`Mine` on Deep Ocean) + Buoy (`Base` on Oceanic) prove ocean `causes` extras. Full `[extra_seatunnel]`+roster+movement check = build-time task (recipe §5) if wanted. |
| **S4** orbital all-terrain unit class (`native_to` everywhere) | ✅ confirmed by shipped data | `Air`/`Missile` already native to ocean (`terrain.ruleset:307/357/408`) AND every land terrain (`:459-949`) — all-terrain classes work today. Optional in-game orbital-unit spike recipe §5. |

### Sub-plan docs (`doc/design/`)
| Doc | Status |
|---|---|
| `feature-special-actions.md` | ✅ WRITTEN (grounded in S5) |
| `feature-pw-placement.md` | ✅ WRITTEN (grounded in S5 + edit API) |
| `feature-ocean-cities.md` | ✅ WRITTEN (incl. S1 PASS result) |
| `feature-orbital.md` | ✅ WRITTEN |
| `feature-sea-improvements.md` | ✅ WRITTEN |
| `engine-need-matrix.md` | ✅ WRITTEN (capstone; spike table updated) |

### Roadmap
- `doc/ROADMAP.md` re-tier + execution-log entry still TODO (user asked: "update roadmap with
  findings / point to sub plan document"). Apply the plan's decision matrix (2.1 loses `[C]`;
  1.3 drops `[L][J]`→`[L]`; 1.5/1.6 lose the client-work assumption). Add the leak incident to
  the execution log.

## 4. Verified engine findings (do NOT re-derive these)

**S5 — User Actions (the special-action + PW-placement foundation):**
- `find.action("User Action N")` resolves a ruleset user action by rule name.
- `unit:perform_action(action, target[, sub_target])` performs it; wraps
  `edit.perform_action(unit, action, target)` — there is **no** `edit.perform_action_unit_vs_city`
  name (all overloads collapse to `edit.perform_action`).
- On success the server emits `action_started_unit_{city,unit,tile,self,extras}` → connect a Lua
  handler with `signal.connect`. Handler gets `(action, actor_unit, target)`.
- Proven both **City-targeted** and **Self-targeted** actions dispatch to Lua and the handler's
  `edit.change_gold(target.owner, -N)` lands.
- **Gotcha 1:** `unit:perform_action` returns **false silently** if the action isn't enabled —
  no error, no log. Always handle the false path (refund + notify).
- **Gotcha 2:** `edit.create_unit(player, tile, utype, vet, homecity, moves_left)` — pass
  `moves_left = -1` for FULL moves. `0` makes the unit fail any `MinMoveFrags` actor req (this
  ate ~4 debugging iterations). Real player units are unaffected.
- **Gotcha 3:** Lua modulo is `%` not `%%` (printf habit → load-time Lua syntax error).
- User-action DEFINITION lives in `[actions]` (`ui_name_user_action_N`, `user_action_N_target_kind`,
  `_min_range`, `_max_range`, `_actor_consuming_always`); ENABLER is a separate
  `[enabler_*]` section (`action = "User Action N"` + actor_reqs/target_reqs vectors). Working
  reference: `data/sandbox/actions.ruleset` (the only shipped ruleset with live user actions —
  "Disrupt Supply Lines" UA1, "Ancient Transportation Network" UA2 with `target_kind="tiles"`).

**tolua accessor cheat-sheet (cost ~6 iterations in S1 — do NOT relearn):**
- Struct-declared fields are **properties** accessed with `.`: `tile.terrain`, `tile.id`,
  `tile.x`, `tile.y`, `city.name`, `city.owner`, `city.id`, `player.id`, `unit.id`.
- Single-`self` `@ name` accessors returning a value are ALSO exposed as **properties** (`.`),
  NOT methods: `city.size` (NOT `city:size()`), `tile.city` (NOT `tile:city()`),
  `tile.x`/`tile.y`. Calling them as `tile:x()` errors "attempt to call a number value".
- `@ name(self, args...)` with extra args ARE **methods** (`:`): `tile:circle_iterate(1)`,
  `tile:square_iterate(6)`, `tile:has_extra("X")`, `unit:perform_action(a,t)`,
  `player:create_city(t,name)`, `player:cities_iterate()`.
- **NULL-userdata gotcha:** a pointer-returning property (e.g. `tile.city` on a city-less tile)
  returns a userdata wrapping NULL that is **`~= nil`** — so `tile.city == nil` is ALWAYS false.
  Never nil-test a property pointer. Instead drive off a boolean API (`edit.create_city` return)
  or re-fetch via a `find.*` function (those DO return real nil): `find.city(owner, id)`.
- **Wrapper-drops-return gotcha:** `Player:create_city(tile,name)` calls `edit.create_city` but
  does **not** `return` its bool — so `local ok = player:create_city(...)` is always nil. Call
  `edit.create_city(player, tile, name)` directly to get the real boolean.
- Iteration is for-in generators: `for x in players_iterate() do … end`,
  `for c in player:cities_iterate() do … end`, `for t in whole_map_iterate() do … end`. The
  draft's callback-style `players:iterate(fn)` is WRONG for this build.

**S1 static evidence (already gathered — the spike is confirmatory):**
- `common/city.c:1565-1580` `city_can_be_built_tile_only()` gates founding ONLY on the terrain
  `NoCities` flag + citymindist — no hardcoded ocean block.
- `server/cityturn.c:776` emits `city_destroyed` from `city_reduce_size()` — that's ordinary
  **starvation** (pop→0), NOT a terrain check. No hidden "cities on ocean auto-die" path found.
- epoch `terrain.ruleset`: `Ocean`, `Deep Ocean`, `Lake` all carry `NoCities`. The design drops
  it on the buildable shelf terrain (recommend: shallow `Ocean`), keeps it on `Deep Ocean`/Trench
  → undersea cities hug the shelf (nice spatial gameplay). Gate the *capability* via the founder
  unit's `tech_req` (Pressure Ecology / Abyssal Engineering), not the terrain.

**Lua/tile API confirmed (for S1/S3/S4):** `whole_map_iterate()`, `Tile:square_iterate(radius)`,
`tile.terrain:class_name()` ("Oceanic"/"Land"), `tile.terrain:rule_name()`, `tile.city`,
`tile:x()/:y()`, `tile:city_exists_within_max_city_map(center)`, `Player:create_city(tile, name)`
/ `edit.create_city(player, tile, name)`, `Player:cities_iterate()`, `players_iterate()`,
`city:size()`, `edit.create_extra(tile, name)` / `edit.remove_extra`, `edit.change_gold`,
`edit.change_city_size`, `edit.transfer_city`, `find.unit_type(name)`, `find.tile(x,y)`.

## 5. Spike recipes (exact, so the next session runs them cold)

**Test harness convention:** edit the CONTAINER's ruleset copy via
`docker exec -i -u root freeciv-web python3 - <<'PY' … PY` (python avoids shell-quote hell on the
big ruleset files), validate, run a SHORT autogame, grep markers, then restore the clean repo
copy with `docker cp data/epoch/. freeciv-web:/home/docker/freeciv/share/freeciv/epoch/`.
Container ruleset path: `/home/docker/freeciv/share/freeciv/epoch/`.

**Autogame recipe that WORKS (from the smoke test — use SMALL/SHORT, watch for the leak):**
```
rulesetdir epoch
set aifill 3
set topology ""
set wrap WRAPX
set nationset all
set generator FAIR
set size 2
set autotoggle enabled
set timeout -1
set endt 20
set minp 0
set gameseed 42
set mapseed 42
start
```
Run with `freeciv-web --port 5757 --Announce none --exit-on-end --read <serv> --saves /tmp
--scenarios /tmp`. **Always** wrap in a host-side `timeout` AND explicit `--port` to avoid
colliding with the pool servers (6000-6009). **After each run, `pkill -9 -f "<your serv>"`** so
strays don't accumulate (they contributed to the wedge). NOTE: this build's `quit` from a
`--read` file does NOT self-terminate the server — rely on `--exit-on-end` + host `timeout`.

- **S1 (ocean city):** python-patch `terrain.ruleset` to drop `"NoCities"` from the shallow
  `Ocean` flags line (unique string:
  `flags                = "NoCities", "UnsafeCoast", "NoZoc", "NoFortify", "Sea"`), append Lua
  that at `turn>=2` finds a coastal `Ocean` tile via `city.tile:square_iterate(6)` and
  `player:create_city(t, "Abyssos")`, watches `epoch_s1_tile.city` each turn, and connects
  `city_destroyed`. endt 30-40. Assert the city survives + grows, no crash, no Lua errors.
- **S3 (undersea tunnel):** add an extra with `causes = "Road"` and Oceanic build reqs to
  `terrain.ruleset`; validate load; build test via `edit.create_extra(ocean_tile, "SeaTunnel")`;
  confirm it places and (ideally) grants movement like a road. Oil Platform (`causes="Mine"`,
  `terrain.ruleset:1355`) and Buoy (`causes="Base"`, `:1712`) are shipped precedents for
  ocean-built extras.
- **S4 (orbital class):** add unit class #10 "Orbital", append it to EVERY terrain's `native_to`;
  add one test unit of that class; autogame — confirm it moves over land AND sea; test a Bombard
  action from range. (civ2civ3 uses 9 of 32 class slots; budget is fine.)

## 6. Reference docs (bookmarked this session)
- **forum.freeciv.org** — esp. the *"Changes in what a 3.0/3.1 ruleset can do"* dev threads
  (exactly our "data vs. C" question): https://forum.freeciv.org/f/viewtopic.php?t=491
- Fandom wiki: [Lua reference](https://freeciv.fandom.com/wiki/Lua_reference_manual),
  [Signal Tutorial](https://freeciv.fandom.com/wiki/Signal_Tutorial),
  [Ruleset Modding Tutorial](https://freeciv.fandom.com/wiki/Ruleset_Modding_Tutorial).
- Bundled in the container: `/docker/freeciv/freeciv/doc/README.actions`, `README.effect`,
  `README.lua` — authoritative + offline.
- tolua API sources in the container: `server/scripting/tolua_server.pkg`,
  `common/scriptcore/tolua_game.pkg`, C impls in `server/scripting/api_server_edit.c`.

## 7. Files changed this session (all committed-able, on disk)
- `C:\Users\danjo\.wslconfig` — NEW (memory cap; not in repo).
- `doc/design/feature-special-actions.md` — NEW.
- `doc/design/feature-pw-placement.md` — NEW.
- `doc/SESSION-HANDOFF.md` — NEW (this file).
- Container ruleset was restored to the clean repo copy before the wedge; **repo `data/epoch` is
  clean** (no spike edits leaked into it — verified: 0 `[S1]`/user-action traces, 7 `NoCities`).
