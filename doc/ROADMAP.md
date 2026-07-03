# Program Roadmap — "CtP2-on-Freeciv-web" (working codename: **Epoch**)

> This is the canonical, shared roadmap for the project — checked into the repo so it's
> visible to anyone working on it. Originally drafted 2026-07-02. Update it as decisions
> change; don't let it drift from reality.

## Context

You and your friends loved **Call to Power 2** (Activision, 2000) — above all its *era arc*, playing one continuous civilization from the stone age into a far future of cyborgs, orbital platforms, and undersea cities. CtP2 only did IPX/LAN multiplayer, which no longer works over the modern internet, so the group can't play it anymore.

**Goal:** a browser-playable 4X game that recreates the *CtP2 experience* on top of **Freeciv-web**, shipped as a custom Docker image self-hosted on a DigitalOcean droplet, so the friend group can play multiplayer over the WAN. It must also keep solid normal-Civ 4X play. Explicit design priorities: **modular, easily extensible, and easy to tune** (data-driven, not hardcoded). This is *not* a light content skin on stock Freeciv — it introduces new systems, deep tech trees where later choices are rooted in earlier ones, new governments, and spirit-aligned mechanics (orbital weapon platforms, solarpunk tile improvements).

**Decisions locked (from planning Q&A):**
- **Fidelity:** Spirit-of-CtP2, modernized — bring over as much as is realistic, with genuinely new systems, not a thin layer.
- **Engine appetite:** Fork & patch the Freeciv C server where a feature genuinely requires it (default still ruleset/Lua-first for upgradability).
- **Observability:** Self-hosted **OpenTelemetry → Prometheus + Loki + Grafana**.
- **Workspace:** Local `C:/ummon/epoch`, a **public GitHub fork of `freeciv/freeciv-web`** edited directly; our content lives inside the fork.

**Substrate (verified).** Freeciv-web = four components: the **Freeciv C server** (engine, patched for WebSocket/JSON), the **freeciv-web** Java/JSP + JS/HTML5-canvas/WebGL client (Tomcat + nginx, Maven), **freeciv-proxy** (Python WS↔socket bridge), and **Publite2** (Python server-instance launcher). Game content is data-driven via **rulesets** (`.ruleset` section files + Lua) and **tilesets** (PNG spritesheets + JS). It builds/runs via `docker-compose`.

**Licensing posture (important, parallels the Lancer-3PL discipline in the sibling `headwater` project).** Freeciv/Freeciv-web is **GPL/AGPL** — hosting a *modified* server obligates us to publish source. That's fine; the repo is public by design. **CtP2 is proprietary Activision IP** — we reimplement *mechanics* only. No CtP2 art, names, text, tech-tree strings, or unit names may be copied. All names/art in Epoch are original. Confirm the product name avoids "Call to Power" and Activision trademarks.

---

## Guiding architecture doctrine

1. **Ruleset/Lua-first; fork the C server only when a feature provably can't be expressed in data.** Every C change is an isolated, rebasable patch in a maintained series against upstream `master`, so we can still pull Freeciv updates. Health metric: *keep the C-patch surface small and documented.*
2. **One tuning surface.** All balance constants (era pacing, Public-Works rates, special-action costs/success formulas, government slider limits) live in ruleset data + a single documented Lua config table. The group can rebalance without an engine rebuild.
3. **Server is authoritative.** Any Lua that mutates tiles/economy on a client request (Public Works, special actions) must validate server-side — never trust the client. This is both a correctness and an anti-cheat requirement.
4. **Content is drop-in.** Rulesets and tileset spritesheets follow one manifest convention so new eras/units/art are additive.

---

## Phase 0 — Workspace, fork & reproducible build *(Step 1)*

- **Fork** `freeciv/freeciv-web` → your GitHub (public). Clone to `C:/ummon/epoch`. Add upstream remote for future rebases.
- Establish repo topology inside the fork:
  - `data/epoch/` — our ruleset dir, cloned from **`civ2civ3`** (solid 4X base) as the starting point.
  - `data/epoch/script.lua` — our Lua systems (Public Works, special-action registry, victory checks).
  - `patches/` — the rebasable C-patch series (empty at first).
  - `tileset/epoch/` — our spritesheet manifest + PNGs.
  - `tools/art/` — ported art-gen pipeline (see Phase 4).
  - `ops/` — docker-compose overlay, observability stack, deploy scripts.
- **Get stock freeciv-web building and running locally via Docker first** (`docker-compose up -d`, verify `http://localhost:8080`) *before* touching content — establishes a known-good baseline.
- **DigitalOcean droplet**: provision, install Docker, deploy the image; confirm the friend group can reach it and play a stock multiplayer game over the WAN (auth-light, persistent games, savegame handling via Publite2). This proves the whole pipe end-to-end before we invest in content.
- **CI**: rebuild the image on ruleset/tileset/patch changes; run the test suite (Phase: Testing). GitHub Actions.
- **Backups**: automated savegame + DB snapshot off the droplet (games run long; losing one is a group-morale event).
- **Security hardening**: it's a public-facing server — firewall to needed ports, non-root containers, fail2ban/rate-limit on nginx, TLS via Caddy/Let's Encrypt, no secrets in the image.

**Deliverable:** the group can log into *our* hosted stock Freeciv-web and finish a game. Nothing CtP2 yet — but the platform is proven.

---

## Phase 0.5 — Observability foundation *(Step 1.5 — build this early, not last)*

Instrument from the very first custom build so every later feature emits telemetry by default.

- **Stack** (compose overlay in `ops/`, self-hosted beside the game): **OpenTelemetry Collector → Prometheus (metrics) + Loki (logs) + Grafana (dashboards/alerts)**. Optional Tempo for traces if we add cross-service spans.
- **Two telemetry planes:**
  1. **Ops plane** — container health, CPU/mem, nginx request rates/latency/5xx, proxy WebSocket connection counts & drops, server-instance lifecycle from Publite2, crash/restart events.
  2. **Game plane** (the interesting one) — structured events for turns processed, per-turn duration, player join/leave, desync/protocol errors, savegame load failures, Lua script errors, AI turn timings, and *gameplay* events (special-action attempts/success, PW spend, era transitions, victory triggers). These feed both ops *and* balance analytics.
- **Logging conventions (define on day one):** structured JSON, correlation id = game-id + turn, severity levels, a stable event-name taxonomy. Documented in `ops/observability/README.md` so new features log consistently.
- **Self-healing / feedback loop:** Grafana alert rules on the signals above → route to (a) auto-remediation where safe (restart a wedged server instance, reap zombie games) and (b) a triage feed that informs bug-fixing *and* balance tuning (e.g. "Cleric convert success is firing 4× more than any other action" → tune it). Detections are treated as inputs to the working process, versioned in-repo.

**Deliverable:** a Grafana dashboard showing live game + ops health, alerting wired, log/metric conventions documented. Everything built afterward plugs into this.

---

## Phase 1 — Review & prioritized backlog *(Step 2 — done; captured here)*

The CtP2→Freeciv gap analysis is complete (delegated to Fable 5). **Tier tags:** `[R]` ruleset data · `[L]` +Lua · `[C]` C engine patch · `[J]` client/JS/JSP · `[A]` art/tileset. Effort S/M/L/XL. Ordered **High→Low by CtP2-feeling per unit of effort.**

**The one structural decision that governs everything:** Freeciv has no true stacked Z-layers. We model CtP2's three "altitudes" as **terrain classes + unit classes on the single existing map**, *not* physical layers — undersea = special deep-ocean terrains only sub/undersea-city units can use; orbital = a unit class + effects. This keeps ~90% of the feel for a fraction of the cost and preserves upstream-mergeability. (We have appetite to fork; we still don't fork the *map engine* — that fight is never worth it.)

### T1 — Core CtP2 identity (recognizably CtP2, mostly no C fork)
| # | Item | Tier | Effort | Deps |
|---|------|------|--------|------|
| 1.1 | **Five-age tech tree** grafted from civ2civ3 + augmented2 future branches; era labels; deep dependencies so late choices root in early ones; gate everything by tech | `[R]` | L | 0.x |
| 1.2 | **Era unit rosters** Ancient→Renaissance→Modern→Genetic→Diamond (stats + gating), placeholder art first | `[R][A]` | L | 1.1 |
| 1.3 | **Public Works economy** — Lua national PW pool fed by a tunable % of production; spend-to-place improvements with a light client affordance (Gap 1). *Fallback:* ship as "Public Works Crew" worker units and defer true PW if UX gets ugly | `[L][J]` | L | 1.1 |
| 1.4 | **Ocean sub-types** (continental shelf / trench / rift terrains + resources) | `[R][A]` | M | 1.1 |
| 1.5 | **Unconventional-warfare Lua framework** — data-driven special-action registry `{cost,range,success-formula,effect-fn,counter-flag}` (Gap 4 core; the flavor no other 4X has) | `[L]` | L | 1.1 |
| 1.6 | First special units on the framework: **Cleric (convert city), Lawyer (sue/injunction), Corporate Branch (franchise)** | `[L][R][A]` | M | 1.5 |
| 1.7 | **New governments** with slider-limit effects + special-unit gating (incl. spirit-aligned late govs, e.g. Technocracy/Ecotopia) | `[R]` | M | 1.1 |

### T2 — Depth (plays like CtP2)
| # | Item | Tier | Effort | Deps |
|---|------|------|--------|------|
| 2.1 | **Undersea cities** — small, isolated **C patch** to found/hold cities on designated ocean terrain (Gap 2). *First deliberate fork.* | `[C][R][L][A]` | M | 1.4 |
| 2.2 | Undersea colonizer unit + **undersea tunnels/mines** (terrain extras) | `[R][A]` | M | 2.1 |
| 2.3 | Rest of unconventional roster: **Slaver/Abolitionist, Ecoterrorist, Subverter, Televangelist** (enslave/free approximated as captured-worker / city-size delta first) | `[L][R][A]` | M | 1.5 |
| 2.4 | **Typed trade goods + trade routes** (Lua bookkeeping over caravan routes) | `[L][R]` | M | 1.1 |
| 2.5 | **Approximate stacked-army combat** — bombard/ranged flags, back-row artillery, flanking defense bonuses via effects (not a full 12-stack engine yet) | `[R][L]` | M | 1.2 |
| 2.6 | **Wonders pass 1** — original wonders with global/ongoing effects | `[R][L][A]` | M | 1.1 |

### T3 — Far-future payoff & polish (the Genetic→Diamond arc everyone remembers)
| # | Item | Tier | Effort | Deps |
|---|------|------|--------|------|
| 3.1 | **Diamond-age content breadth** — cyborgs, war walkers, plasma units, star cruisers, space planes; go *broad* here, it's the emotional payoff | `[R][A]` | L | 1.2 |
| 3.2 | **Orbital / space** as unit-class + effects (bombard-down **orbital weapon platforms**, space installations) — approximation, never a real layer (Gap 3) | `[R][L][A]` | M | 3.1 |
| 3.3 | **Solarpunk far-future tile improvements** & flavor (spirit-aligned addition) | `[R][A]` | M | 1.1 |
| 3.4 | **Victory conditions** — original endgame wonder (Gaia-Controller-style) + Lua win-check; keep conquest & space-race paths | `[L][R]` | M | 2.6 |
| 3.5 | **Full custom tileset** replacing placeholders — era units, ocean/undersea terrain, per-era city graphics, wonder art (see Phase 4) | `[A][J]` | XL | 1.2,1.4,3.1 |
| 3.6 | **Tuning pass** — surface every balance constant in one documented config; publish the tuning guide | `[R][L]` | M | most |
| 3.7 | *(Optional, only if the group misses it)* Faithful **12-unit stacked-army combat** engine fork | `[C][J]` | XL | 2.5 |
| 3.8 | *(Optional)* True population-as-slave-unit modeling if the approximation disappoints | `[C]` | L | 2.3 |

**Sequencing:** T1 gives a recognizably-CtP2 game with (at most) trivial engine work. The first *deliberate* C fork is the bounded ocean-city patch (2.1). The two XL engine items (3.7, 3.8) are explicitly last and optional — approximations are likely "good enough" for a friends' game.

**Delegate to Fable 5 during the build** the genuinely hard design docs before implementing them: the **Public-Works economy model** (1.3), the **special-action framework schema & success formulas** (1.5), the **five-age tech-tree dependency graph** (1.1), the **ocean-city C-patch design** (2.1), and **combat approximation math** (2.5). These are the "significant game functions / unit interactions / 2000-to-modern bridging" items.

---

## Phase 2 — Build *(Step 3)*

Work the backlog top-down (T1 → T3). For each item:
1. If it's a flagged complex-design item, **produce the design doc first (Fable 5)** → commit under `doc/design/`.
2. Implement as data/Lua/patch/art per its tier tags.
3. **Write tests as you go** (see Testing) — no item is "done" without them.
4. **Document interactions & known issues** in `doc/design/<item>.md`: what it touches, edge cases, balance knobs, open questions. This is the running "interactions & issues" log.
5. Emit telemetry (Phase 0.5 conventions) so the feature is observable from first play.
6. Ship to the droplet; the group playtests; feed observations + telemetry back into tuning.

**Save-game / migration discipline:** ruleset changes break in-progress saves. Adopt a ruleset-version stamp, a policy of "don't change ruleset mid-campaign," and a documented upgrade path so a long group game doesn't get bricked by a content update.

---

## Phase 3 — Testing (continuous, not a phase at the end)

- **Ruleset validation**: `freeciv-ruledit`/sanity checks in CI so every ruleset change is verified loadable and internally consistent (tech reqs, effect refs, unit graphics tags).
- **Lua unit tests**: pure-logic tests for the special-action registry (cost/success/effect math), Public-Works accounting, victory checks — run headless in CI.
- **Server integration/smoke**: scripted headless game (autogame) that boots the `epoch` ruleset, runs N turns with AI, and asserts no Lua errors / no crashes / expected events fire. Catches ruleset+engine regressions.
- **C-patch tests**: each patch (starting with ocean-city founding) gets a targeted test proving the new capability and that it doesn't break stock behavior.
- **Deploy smoke test**: post-deploy check that the droplet accepts a connection and starts a game (wired to observability alerting).
- **Playtest loop**: structured feedback from the group's games, correlated with game-plane telemetry, driving the tuning backlog.

---

## Phase 4 — Art & assets *(Step 4)*

- **Reuse the proven pipeline** from the sibling `headwater` project: **fal.ai** (Nano-Banana-2 for detailed masters, Flux.1-schnell for concept) + **Retro Diffusion** for direct pixel sprites, plus `process_sprite.ts` (bg-removal/trim/downscale/quantize) and a palette manifest. Port a trimmed `tools/art/` toolchain into this repo; keep `FAL_KEY`/`RD_API_KEY` in a gitignored `.env`.
- **Resolution target — match-or-beat CtP2:** author unit sprites at **128px base** (CtP2 ran ~48–64px at 1024×768). Freeciv-web HD/WebGL tilesets already exceed CtP2; authoring at 2× keeps art crisp on high-DPI browsers — this is how we *beat* the 2000 look.
- **Asset categories, in dependency order:** (1) unit sprites per era (largest — 5 ages × full roster incl. unconventional & Diamond-age); (2) ocean/undersea terrain (blocks 1.4/2.x); (3) **city graphics by era** (the city visibly evolving Ancient→Diamond is a huge chunk of CtP2's feel — do at least Ancient/Modern/Diamond sets); (4) wonder illustrations (cheap, high flavor — UI art not tile art); (5) special-action & era UI chrome (PW slider, action buttons, era-transition framing). **Solarpunk aesthetic** for the far-future tier.
- **IP:** RD outputs (TOS grants full rights) and Flux.1-schnell (Apache-2.0) are commercial-clean. Never reproduce CtP2 assets. Placeholder-first (T1/T2), polish in T3.5.
- **Manifest convention:** one spritesheet-manifest so new era content is drop-in; each art drop is `[A]` + a small `[J]` spritesheet-wiring change.

---

## Additional steps beyond the original ask

- **Licensing/legal section** (above) — AGPL publish obligation + CtP2 IP firewall.
- **Security hardening** of the public droplet (Phase 0).
- **Backups & save-game migration** discipline (Phases 0 & 2).
- **Server-authoritative validation / anti-cheat** for Lua economy mutations (doctrine).
- **Observability built early, with a game-telemetry plane** feeding balance analytics, not just ops (Phase 0.5).
- **CI + ruleset validation + headless autogame smoke tests** (Phase 3).
- **Structured playtest→tuning feedback loop** with the friend group (Phases 2–3).
- **Naming/trademark check** before any public marketing.

---

## Verification (how we know each layer works)

- **Platform:** `docker-compose up -d` locally serves stock freeciv-web at `:8080`; droplet reachable; two people finish a WAN multiplayer game. *(Phase 0)*
- **Observability:** Grafana shows live game + ops metrics; kill a server instance → alert fires → auto-remediation restarts it. *(Phase 0.5)*
- **Content:** `epoch` ruleset loads clean in CI; headless autogame runs 100+ turns AI-only with zero Lua errors; era transitions, PW spend, and each special action fire the expected telemetry events. *(Phases 2–3)*
- **Feature-level:** each backlog item's design doc lists its own acceptance check (e.g. Cleric convert flips a target city's allegiance and is blocked by an active Lawyer injunction).
- **End-to-end:** the group plays a full campaign from Ancient to Diamond age, founds an undersea city, deploys an orbital weapon platform, and reaches an original victory — over the WAN, on our hosted image.

---

## Open items to confirm before/early in execution
- Product **codename** (placeholder "Epoch") — must avoid Activision trademarks.
- ~~GitHub org/account for the public fork~~ — **done**: https://github.com/jnorha/epoch-freeciv
- DigitalOcean droplet size (start small; multiplayer for a handful of friends is light) and region.
- Whether `FAL_KEY`/`RD_API_KEY` from the `headwater` setup are reused or new keys are provisioned.

---

## Execution log

- **2026-07-02** — Plan approved. Phase 0 topology committed (`data/epoch/`, `ops/` observability stack, `script.lua` skeleton, Dockerfile patched). Forked to `jnorha/epoch-freeciv`, pushed to `develop`. Hit Docker Desktop "no virtualization" error → root cause: WSL2 had no Linux distro installed. Ran `wsl --install -d Ubuntu`; reboot pending to complete.
