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
- **DigitalOcean droplet — ephemeral, session-lifecycle model (decided 2026-07-02):** the group plays **synchronous sessions** (everyone on together for a few hours), not async/longturn. So instead of one always-on droplet, the target architecture is **on-demand droplets provisioned via the DO API** for the duration of a play session:
  - Spin up (DO API) when the group is ready to play → restore latest savegame/snapshot → group plays → auto-save + snapshot before teardown → spin down. Pay only for active play time.
  - Needs: DO API token, a small orchestration script (could be a local CLI the host runs, or a lightweight always-on trigger — TBD), snapshot/volume strategy for savegame persistence *between* sessions (the droplet is disposable; the game state is not), and safety nets (never destroy mid-session; confirm save succeeded before teardown).
  - This is an infra/DevOps design problem, not a game-mechanics one — stays with the main build thread rather than delegated to Fable 5.
  - Session lifecycle events (droplet created → game accepting connections → session ended → save confirmed → droplet destroyed) become their own clean addition to the game-telemetry plane (Phase 0.5).
  - **First step, done manually for now:** confirm Docker + the Epoch image deploy cleanly on a droplet at all (one droplet, created via DO web UI, SSH key added at creation for reliable access) before automating the lifecycle.
- **CI**: rebuild the image on ruleset/tileset/patch changes; run the test suite (Phase: Testing). GitHub Actions.
- **Backups**: automated savegame + DB snapshot off the droplet (games run long; losing one is a group-morale event).
- **Security hardening**: it's a public-facing server — firewall to needed ports, non-root containers, fail2ban/rate-limit on nginx, TLS via Caddy/Let's Encrypt, no secrets in the image.
  - **Port 22 exposure (open task, added 2026-07-02):** the droplet currently has plain-key SSH open on public port 22 for admin access (needed it to get in cleanly after Tailscale SSH failed on the prior droplet). Before this droplet handles real play sessions, restrict inbound 22: either (a) put it behind **Tailscale SSH** properly this time (fix the "no ED25519 host key known" issue by running `sudo tailscale up --ssh` on the box itself right after provisioning, then close 22 in the DO Cloud Firewall / ufw entirely, admin access only via tailnet), or (b) **Mosh** with UDP 60000-61000 open instead of raw 22 for interactive access, still fronted by a firewalled/allowlisted approach. Tailscale SSH is the better fit long-term since it also gives clean per-user identity for the ephemeral-droplet automation (Phase 0's DO-API lifecycle scripts can provision+verify over the tailnet without managing SSH keys per droplet). Do this *before* opening the droplet to real player traffic, not after.

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
| 1.3 | **Public Works economy** — Lua national PW pool fed by a tunable % of production; spend-to-place improvements via a **Surveyor unit + "Commission Works" User Action** (no client work). *(→ `doc/design/feature-pw-placement.md`)* | `[L]` ~~`[J]`~~ | L | 1.1 |
| 1.4 | **Ocean sub-types** (continental shelf / trench / rift terrains + resources) | `[R][A]` | M | 1.1 |
| 1.5 | **Unconventional-warfare Lua framework** — data-driven special-action registry `{cost,range,success-formula,effect-fn,counter-flag}` (Gap 4 core; the flavor no other 4X has). **4 User-Action slots multiplex the 8 units by target-kind + actor flag; injunctions persist as an Extra.** *(→ `doc/design/feature-special-actions.md`; S5 proved the dispatch)* | `[L]` | L | 1.1 |
| 1.6 | First special units on the framework: **Cleric (convert city), Lawyer (sue/injunction), Corporate Branch (franchise)** — render as real client buttons, **zero `[J]`** | `[L][R][A]` | M | 1.5 |
| 1.7 | **New governments** with slider-limit effects + special-unit gating (incl. spirit-aligned late govs, e.g. Technocracy/Ecotopia) | `[R]` | M | 1.1 |

### T2 — Depth (plays like CtP2)
| # | Item | Tier | Effort | Deps |
|---|------|------|--------|------|
| 2.1 | **Undersea cities** — remove `NoCities` on the shelf terrain + Helix-gated ocean-native founder unit. **NO C patch** (`city.c` has no ocean block; `cityturn.c` destroy = starvation, not terrain). *(→ `doc/design/feature-ocean-cities.md`; S1 confirmatory spike pending)* | ~~`[C]`~~ `[R][L][A]` | M | 1.4 |
| 2.2 | Undersea colonizer unit + **undersea tunnels/mines** (terrain extras — mine = shipped Oil Platform pattern; tunnel = `causes="Road"` S3) *(→ `doc/design/feature-sea-improvements.md`)* | `[R][A]` | M | 2.1 |
| 2.3 | Rest of unconventional roster: **Slaver/Abolitionist, Ecoterrorist, Subverter, Televangelist** (enslave/free approximated as captured-worker / city-size delta first) *(→ `feature-special-actions.md` §6)* | `[L][R][A]` | M | 1.5 |
| 2.4 | **Typed trade goods + trade routes** (Lua bookkeeping over caravan routes) | `[L][R]` | M | 1.1 |
| 2.5 | **Approximate stacked-army combat** — bombard/ranged flags, back-row artillery, flanking defense bonuses via effects (not a full 12-stack engine yet) | `[R][L]` | M | 1.2 |
| 2.6 | **Wonders pass 1** — original wonders with global/ongoing effects | `[R][L][A]` | M | 1.1 |

### T3 — Far-future payoff & polish (the Genetic→Diamond arc everyone remembers)
| # | Item | Tier | Effort | Deps |
|---|------|------|--------|------|
| 3.1 | **Diamond-age content breadth** — cyborgs, war walkers, plasma units, star cruisers, space planes; go *broad* here, it's the emotional payoff | `[R][A]` | L | 1.2 |
| 3.2 | **Orbital / space** as unit-class + effects (bombard-down **orbital weapon platforms**, space installations) — "Orbital" class native to every terrain; Bombard engine-native. NO real layer, NO C. *(→ `doc/design/feature-orbital.md`; S4 spike pending)* | `[R][L][A]` | M | 3.1 |
| 3.3 | **Solarpunk far-future tile improvements** & flavor (spirit-aligned addition) | `[R][A]` | M | 1.1 |
| 3.4 | **Victory conditions** — original endgame wonder (Gaia-Controller-style) + Lua win-check; keep conquest & space-race paths | `[L][R]` | M | 2.6 |
| 3.5 | **Full custom tileset** replacing placeholders — era units, ocean/undersea terrain, per-era city graphics, wonder art (see Phase 4) | `[A][J]` | XL | 1.2,1.4,3.1 |
| 3.6 | **Tuning pass** — surface every balance constant in one documented config; publish the tuning guide | `[R][L]` | M | most |
| 3.7 | *(Optional, only if the group misses it)* Faithful **12-unit stacked-army combat** engine fork | `[C][J]` | XL | 2.5 |
| 3.8 | *(Optional)* True population-as-slave-unit modeling if the approximation disappoints | `[C]` | L | 2.3 |

**Sequencing:** T1 gives a recognizably-CtP2 game with **zero** engine work. **Engine-gap
evaluation (2026-07-03) found NO feature in T1/T2 needs a C fork** — including undersea cities
(2.1), which was the assumed "first deliberate fork" and is now `[R][L][A]`. The only surviving
`[C]` items are 3.7 and 3.8, both explicitly last and optional. On current evidence Epoch reaches
a full Ember→Lattice game with `patches/` empty. **See `doc/design/engine-need-matrix.md` for the
full evidence + decision matrix, and the per-feature `doc/design/feature-*.md` sub-plans.**

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

- **2026-07-02** — Plan approved. Phase 0 topology committed (`data/epoch/`, `ops/` observability stack, `script.lua` skeleton, Dockerfile patched). Forked to `jnorha/epoch-freeciv`, pushed to `develop`. Hit Docker Desktop "no virtualization" error → root cause: WSL2 had no Linux distro installed. Ran `wsl --install -d Ubuntu`; reboot completed the install. Docker Desktop now connects cleanly (Docker 29.6.1 / Docker Desktop 4.80.0).
- **2026-07-02** — Existing DigitalOcean droplet identified: **palatine-ov1**, reachable via Tailscale (already connected on the dev box). Phase 0's "provision a droplet" step becomes "confirm palatine-ov1 specs are adequate" rather than starting from scratch. Tailscale SSH access to it is currently broken (`tailscale ssh` fails with "No ED25519 host key known" — looks like Tailscale SSH isn't enabled server-side; needs `sudo tailscale up --ssh` run on the droplet via the DO web console). Deferred until we're ready to actually deploy — not blocking local Docker work.
- **2026-07-02** — **Custom Epoch Docker image built successfully** (`freeciv/freeciv-web:latest`, 2.6GB) via `docker-compose build`. Verified `data/epoch/script.lua` is baked into the image at `~/freeciv/share/freeciv/epoch/`. Brought up via `docker-compose up -d`; all internal self-checks pass (nginx, Tomcat, freeciv-web, freeciv-proxy, WebSocket direct + via nginx, tileset generation). Confirmed `http://localhost:8080/` serves the real Freeciv-web client (HTTP 200). **Phase 0's local-build deliverable is met** — pending a manual in-browser playthrough to confirm the game server pipe end-to-end.
- **2026-07-02** — `palatine-ov1` Tailscale SSH connection hung indefinitely from both the dev box and the user's phone (Mosh also failed — likely UDP 60000-61000 blocked). Decided to recreate the droplet clean rather than debug (nothing of value on it). **Architecture decision:** confirmed via user Q&A that play will be **synchronous sessions**, not async/longturn — so the target is **ephemeral, DO-API-provisioned droplets** that live only for the duration of a session, not one always-on droplet. Immediate next step: recreate one droplet manually via the DO web UI (SSH key added at creation, not relying on Tailscale SSH for initial access) to prove Docker + the Epoch image deploy cleanly, before building the on-demand lifecycle automation.
- **2026-07-02** — Recreated as **`palatine-ov2`** (178.128.231.84): 2 vCPU / 3.8GB RAM (Premium Intel, ~$32/mo if run 24/7 — actual cost will be much lower given the ephemeral/session-only usage pattern), 116GB disk, Ubuntu 24.04 LTS. **Skipped DO's $6/mo automatic-backups add-on** — it backs up the whole droplet on a schedule, which doesn't fit a disposable-by-design box; the thing that actually needs to persist is savegame/DB state, which belongs on a Volume or Spaces bucket decoupled from the droplet's lifecycle (design item for the ephemeral-lifecycle work, not yet built). Plain SSH key auth confirmed working cleanly this time. **Docker installed** via the official `get.docker.com` convenience script — verified active (`docker ps` responds, daemon status `active`). Port 22 is open to the public internet for now; flagged as a pre-launch hardening task (see Security hardening section above) to lock down before real play sessions — either proper Tailscale SSH (fixing the prior "no ED25519 host key known" issue) or Mosh, either way closing raw port 22 in the firewall once admin access is confirmed working through the replacement.
- **2026-07-02** — **Cloned `jnorha/epoch-freeciv` (develop branch) to `/opt/epoch` on the droplet and built the image there** (`docker compose build`, ~20 min — dependency install → C server compile → freeciv-web JS/webpack build → image export, same shape as the local build). Build succeeded clean; `docker images` confirms `freeciv/freeciv-web:latest` (2.6GB). Brought up via `docker compose up -d`; all internal self-checks pass (nginx, Tomcat, freeciv-proxy, WebSocket direct + via nginx, tileset generation). **Confirmed publicly reachable: `http://178.128.231.84:8080/` returns HTTP 200 from outside the droplet.** This is Phase 0's droplet-deploy deliverable met — the platform now runs both locally and on DO. Remaining before real play: port 22 hardening (tracked above), and eventually the ephemeral DO-API lifecycle automation (this droplet was created manually and stays up persistently for now, which is fine for continued dev work).
- **2026-07-02** — **Phase 0.5 observability stack deployed on `palatine-ov2`.** Bound all obs ports to `127.0.0.1` (no new public attack surface — access via SSH tunnel, e.g. `ssh -L 3000:127.0.0.1:3000 ...`). Added **cAdvisor** for real per-container CPU/mem metrics (the original ops dashboard's CPU panel queried a metric nothing was exporting — fixed to use cAdvisor's `container_cpu_usage_seconds_total`, added a matching memory panel). Grafana admin password now required via `ops/.env`, no insecure default.
  - **Hit and fixed two real config bugs during deploy:** (1) OTel Collector's host port `8888` collided with the main game container's alt-Tomcat mapping → moved to `8889`. (2) The Loki exporter's `labels:` config block is invalid in collector v0.103.0's schema (crash-looped on every start) → replaced with the correct mechanism, a `resource/loki_labels` processor that sets the `loki.resource.labels` resource attribute. (3) Prometheus needs `--web.enable-remote-write-receiver` explicitly enabled for the OTel collector's `prometheusremotewrite` exporter to work (404 otherwise, not on by default) → added.
  - **Real infra finding, not simulated:** while bringing the obs stack up, the droplet hit **severe memory pressure — load average spiked to 53 on a 2-core box, SSH connections timed out during banner exchange.** Root cause: `freeciv-web` (Tomcat + MariaDB + the freeciv C server all in one container) alone uses **~2.84 GiB of the droplet's 3.8 GiB RAM**; the observability containers combined only add ~250MB, but that was enough to tip a fully-saturated box over the edge. **Immediate mitigation: added a 2GB swapfile** (`/swapfile`, persisted in `/etc/fstab`) — this is what let the box recover (load dropped from 53 → 1.08 within a couple minutes) instead of hard-locking. **Open sizing question for the ephemeral session-droplet design:** 4GB is likely too tight once real concurrent player games are running (each spawns its own `freeciv-web` server process — multiple were already visible in `ps` from earlier build/test activity) *plus* observability. Consider sizing actual session droplets at 8GB, or keeping the obs stack's footprint explicitly budgeted against whatever's left after the game reserves ~3GB. Revisit with real numbers once we run an actual multi-player session.
  - **Verified end-to-end:** all 5 Prometheus scrape targets report `up` (prometheus, loki, cadvisor, otel-collector — game-level `up` for freeciv-web pending app instrumentation), Grafana reachable via SSH tunnel (HTTP 302 → login), both pre-built dashboards (`epoch-ops`, `epoch-game`) provisioned and present.
- **2026-07-02 — First real incident: OOM killed Tomcat, silent 502 for ~3 minutes.** During the memory-pressure spike above, the kernel OOM killer fired at 01:42:17 and killed the `java` process (Tomcat) inside the `freeciv-web` container (confirmed via `dmesg`/`journalctl -k`: `Out of memory: Killed process ... (java)`). nginx stayed up and kept returning `502 Bad Gateway` (`connect() failed (111: Connection refused)` to `127.0.0.1:8080`) with no auto-recovery — nothing inside the container supervises Tomcat after the entrypoint script's one-time startup check. **This went undetected for several minutes** because we only had dashboards, not alert rules, and the container's startup-time self-check log looked identical to a healthy state at a glance. Fixed with `docker restart freeciv-web` — confirmed recovered (HTTP 200 externally, all internal checks pass, memory now at 2.9GB available vs. ~130MB during the crunch).
  - **Concrete lesson, not hypothetical:** this is exactly the failure mode Phase 0.5's "self-healing" goal was written for. **Immediate follow-up task, higher priority than further content work:** add a Grafana/Prometheus alert rule on `up{job="freeciv-web"}`-equivalent (once app-level instrumentation exists) or at minimum a simple external HTTP-health scrape + alert, so this class of failure pages instead of sitting silent. Also reinforces the sizing question above — this incident is direct evidence the box was actually memory-starved, not just theoretically tight.
- **2026-07-02 — ROOT CAUSE of the OOM found: a publite2 idle process leak, NOT the observability stack.** Paused the obs stack (config + volumes preserved in `ops/`; see below) and added a bounded 5MB `json-file` Docker log + a daily `scripts/epoch-log-wipe.sh` cron for basic troubleshooting. Then, while measuring the game container's idle RAM locally to inform droplet sizing, found the real problem: **an idle `freeciv-web` container ratchets up to `server_limit` (250) game-server processes — 255 procs / ~14GB RAM locally after 90 min idle.** publite2's pool manager over-spawns persistent per-port launchers because `--quitidle 20` churns the idle pool and the spawn logic counts *registered* servers (which lag). The obs stack didn't cause the OOM; it tipped an already-leaking box over. **Fixed** (`publite2/settings.ini.dist` capacities 1/1/0 + `server_limit` 250→6 circuit breaker; `init-freeciv-web.sh` `--quitidle` 20→600; removed the 5 auto-starting longturn games we don't use). Full diagnosis in `doc/design/publite2-pool-tuning.md`. Applied to source (commits) and live to both the local and droplet containers via file-edit + `docker restart`.
  - **Result / box-sizing conclusion:** local idle RAM **14.28GiB → ~0.5–0.8GB** (plateaus ~6 procs during startup overshoot, decays toward ~3). Droplet now **1.3GB used / 2.5GB free** on the 4GB box (was ~130MB free during the leak). **This largely resolves the earlier "need 8GB?" sizing worry — the 14GB was pure leak, not real usage.** A single freeciv game is lightweight; the fixed JVM/Tomcat cost dominates. Expectation: the 4GB droplet is comfortable for our synchronous private sessions, and has room for the observability stack (~250MB) too when we bring it back. **Still want a real number: RAM during an actual populated multiplayer game** — measure that in the first real session before finalizing droplet size. The 2GB swapfile stays as a cheap safety net but is no longer load-bearing.
- **2026-07-02 — Phase 0 → Phase 1 BRIDGE done: the `epoch` ruleset is live and our Lua harness is verified.** Until now the game ran stock Freeciv and our `script.lua` was dead code. Seeded `data/epoch/` from the build's civ2civ3 ruleset (all 11 `.ruleset` files + `parser.lua`) as our editable base, renamed to "Epoch (dev)". Rebuilt `data/epoch/script.lua` = **civ2civ3's real 363-line script preserved** (it has actual game logic — Ruins on city destruction, map labels — and, crucially, was the ground-truth reference for this build's Lua API) **+ a minimal verified Epoch section** (load banner + `turn_begin` hook). The earlier standalone `script.lua` skeleton was written against a *guessed* API (used callback-style `players:iterate(fn)`, etc., which would've failed) — it's preserved as `doc/design/epoch-lua-systems-draft.lua` and gets ported into `script.lua` **module by module, each verified against a running server**, rather than dropped in wholesale. Wired `rulesetdir epoch` into both pubscripts (it's a *command*, not a `set` — that mistake made the first smoke test silently run classic). Wrote `scripts/epoch-smoke-test.sh` (reusable headless autogame; seed of the Phase 3 CI test). **Smoke test PASSES:** ruleset loads as `epoch`, `[EPOCH]` banner prints, `turn_begin` fires turns 1–4 (years -4000..-3850), zero Lua errors — so `signal.connect` / `turn_begin(turn,year)` / `log.normal` are all confirmed working for this build. This is the green baseline for all Phase 1 content work.
- **2026-07-02 — Phase 1 begins: tech-tree design (Fable) + Slice 0 shipped.** Delegated the five-age tech tree to a Fable session → `doc/design/epoch-tech-tree.md`: 5 ages (Ember/Compass/Dynamo/Helix/Lattice), bucket-membership era detection, 87 existing techs bucketed + 28 new far-future techs (≤2 prereqs each), two `root_req` anchors hard-gating undersea/orbital, 5-slice build plan. **Verified all three load-bearing engine claims** (tech classes/`cost_pct`, `root_req` inheritance, `tech_researched` signal) against this build before implementing — all present. Also captured the full verified Lua signal set. **Implemented Slice 0** (`data/epoch/script.lua`): bucket-membership era detection over the existing tree, replacing the draft's tech-count placeholder, driven by `tech_researched` + a `turn_begin` rescan safety net. Verified in a 100-turn autogame: tech→age map matched all 87 names (0 unmatched), players entered the Compass Age on researching Invention (~turn 95), monotonic, zero Lua errors. Also built the ruleset-validation harness (`scripts/epoch-validate-ruleset.sh` — greps output since freeciv exits 0 even on load failure; `scripts/epoch-check.sh` = sync+validate+smoke one-liner). Next: Slice 1 (the two anchors + `root_req` hard-gate test — prove a granted future tech is *denied* without its anchor).
- **2026-07-02 — Paused Phase 0.5 observability stack** (`docker compose -f docker-compose.obs.yml down` on the droplet; config and named volumes `ops_prometheus-data`/`ops_loki-data`/`ops_grafana-data` all preserved for a clean restart later). Rationale: full OTel/Prom/Loki/Grafana was real overhead on a memory-tight box and we want to focus on game content next; basic troubleshooting is covered by the bounded Docker log for now. Stand it back up when ready (and re-measure footprint now that the leak is gone — it should fit comfortably).
- **2026-07-03 — Engine-gap evaluation complete: NO C fork needed for any T1/T2 feature.** Ran two Explore audits (shipped-ruleset expressiveness + C source / server Lua API inside the container) and verification spikes. **Findings** (full evidence + decision matrix in `doc/design/engine-need-matrix.md`): founding gated only by terrain `NoCities` (`city.c:1565-1580`); ocean-city destroy path is starvation not terrain (`cityturn.c:776`); movement is `native_to`-driven (`movement.c:289-360`) so an all-terrain "Orbital" class is pure data; 4 User-Action slots + `action_started_unit_*` Lua dispatch cover all special actions; `edit.*` API covers PW placement + all effects; Oil Platform/Buoy are shipped ocean-extra precedents; Bombard is engine-native. **Spikes:** S2 (tech classes/`cost_pct`) ✅, S5 (User Action → Lua effect, end-to-end) ✅ — both proven in-container; S1 (ocean city survival), S3 (undersea tunnel `causes="Road"`), S4 (orbital class) **pending** (blocked by the container incident below, not by any engine limit — recipes in `doc/SESSION-HANDOFF.md` §5). **Wrote 6 sub-plan docs** (`doc/design/`): `engine-need-matrix`, `feature-ocean-cities`, `feature-orbital`, `feature-sea-improvements`, `feature-special-actions`, `feature-pw-placement`. **Re-tiered above:** 2.1 loses `[C]` (→`[R][L][A]`); 1.3 loses `[J]` (→`[L]`); 1.5/1.6 lose the client-work assumption. Only surviving `[C]` = optional 3.7/3.8.
- **2026-07-03 — INCIDENT: publite2 leak recurred → wedged WSL2 → forced reboot. The 2026-07-02 "fix" was NOT effective.** The local `freeciv-web` container leaked to **260 freeciv processes** over ~19h (same pool leak as before). This blocked all new hand-run autogames at startup (looked like "hangs") and eventually wedged the container so hard that `docker restart`/`kill`/`rm -f`, `wsl --shutdown`, AND `Restart-Service WSLService` all failed → Windows reboot required. **Root cause (initially mis-diagnosed as `.dist`-vs-live — see correction below).** **Mitigation applied:** created `C:\Users\danjo\.wslconfig` (memory=12GB/swap=4GB) so a future leak can't take the 31GB host down again. Full recovery steps + preserved state in `doc/SESSION-HANDOFF.md`.
- **2026-07-03 — publite2 leak FIXED AT THE ROOT (both local + droplet).** The `.dist`-vs-live hypothesis was **wrong**: the live `settings.ini` was correct all along. Real bug in `publite2.py`: the spawn loops gated on **metaserver** server counts, which lag while servers boot and flap on `--quitidle` recycles; `Civlauncher` threads are immortal (`while 1:` respawn) and `server_list` was append-only, so every lag window permanently added a launcher on a new incrementing port, and `server_limit` was compared against the metaserver total (never the real launcher count) so it never engaged → unbounded ratchet (24 launchers/19h local; **73 on the droplet**). **Fix:** gate spawns on publite2's own live launcher list (per-type counts, dead threads pruned via `is_alive()`), enforce `server_limit` as `len(server_list) < limit`, and skip capacity-0 game types at startup. Semantics documented in `settings.ini.dist` (capacities = total launchers per type). **Verified:** steady state exactly 2 servers (6000 single/6001 multi) both local (456MiB) and droplet (73→2, HTTP 200); stable across `epoch-check.sh` and idle observation. Full write-up: `doc/design/publite2-pool-tuning.md` §"2026-07-03: the actual fix". (Droplet container hot-patched via `docker cp` + restart; next `docker compose build` there bakes it permanently.)
- **2026-07-03 — Phase 1 Slice 1 shipped: future-age anchors + `root_req` hard gate.** Added 5 advances to `techs.ruleset` — Networked Computing (III bridge), the two age anchors Genome Cartography (IV) and Molecular Assembly (V), and one leaf per future age (Cellular Rewriting IV, Metamaterials V) — with `root_req` on the leaves; extended `script.lua`'s `EPOCH_TECH_AGE`. **Verified in-container** (throwaway Lua probe + short autogame): era detection fires the new transitions (`… to=4 (helix)` on Genome Cartography, `… to=5 (lattice)` on Molecular Assembly); and the hard gate holds — a player holding Metamaterials' `req1`+`req2` but not the anchor has `can_research(Metamaterials)==false` (inherited `root_req=Genome Cartography` blocks acquisition by any means), flipping to `true` when the anchor is granted. **Key API finding:** `edit.give_tech` force-grants (bypasses `root_req`) so it's not a denial-test vector; `player:can_research` (`research_invention_state == TECH_PREREQS_KNOWN`) is the correct probe. Prereqs are Slice-1 skeletal; the full 28-tech graph lands in Slices 2–3. Next: **Slice 2 — full Helix (13 techs).**
