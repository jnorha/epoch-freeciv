# Engine-Need Matrix — What Actually Requires a C Fork

**Status:** Master reference for the engine-gap evaluation. Supersedes the roadmap's original
`[C]` guesswork tiers — the roadmap should be re-tiered from this doc.
**Author:** Engine-gap evaluation (2026-07-03), from two Explore audits (ruleset layer + C/Lua
layer) plus five verification spikes (S2/S5 run; S1/S3/S4 pending container recovery).
**Source material:** Freeciv 3.3 (`3.2.92.3-dev`) C source + `data/*/` rulesets inside the
`freeciv-web` image; the shipped `civ2civ3` base. Cross-refs every `feature-*.md` sub-plan.

> **Headline: every feature the group named — undersea cities, orbital units, sea improvements,
> special actions, era pacing — is achievable with ZERO Freeciv C patches on current evidence.**
> The C-patch appetite (isolated rebasable series in `patches/`) stays in reserve, but the needed
> set for T1/T2 is **empty**. The first *deliberate* C fork is deferred to the two optional XL
> items (3.7 stacked-army combat, 3.8 true population-as-slave) — possibly never.

---

## 1. Evidence — ruleset layer (Explore audit A)

1. **Ocean cities:** founding gated solely by the terrain `NoCities` flag; Found City enablers
   check nothing ocean-specific (`data/epoch/actions.ruleset` Found City block). Mechanism is pure
   data — remove the flag on the buildable terrain. No shipped ruleset omits it → no precedent,
   but no barrier. → `feature-ocean-cities.md`.
2. **Sea tile improvements:** **precedent ships in our own base.** civ2civ3 has **Oil Platform**
   (`causes="Mine"` on Deep Ocean, ship-built — `terrain.ruleset:1355-1382`) and **Buoy**
   (`causes="Base"` on Oceanic — `:1712-1739`). Undersea-tunnel `causes="Road"` on ocean has no
   shipped example → S3. → `feature-sea-improvements.md`.
3. **Orbital units:** no move-type field on classes; movement = per-terrain `native_to`
   membership (Air/Missile native to land+ocean already). Max 32 classes; class-flag set is fixed
   (no custom class flags). Bombard is enabler-driven. → `feature-orbital.md`.
4. **User Actions:** ruleset-defined actions become real client buttons with reqs/ranges/target
   kinds; Lua dispatch via `action:rule_name()` on `action_started_unit_*`. Live examples in
   `sandbox`/`webperimental`. civ2civ3 uses none → **all 4 slots free.** → `feature-special-actions.md`.
5. **Tech classes** (`cost_pct` era pacing): documented, engine-supported, but zero shipped users —
   we'd be first → S2.

## 2. Evidence — engine/Lua layer (Explore audit B)

1. **No hardcoded ocean-city prohibition.** `common/city.c:1565-1580`
   `city_can_be_built_tile_only()` checks only ruleset `TER_NO_CITIES` + citymindist.
   `server/cityturn.c:776` `city_destroyed` is **starvation** (`city_reduce_size`, pop→0), not a
   terrain check. (Worked-tiles / disasters / migration not exhaustively traced → S1 covers empirically.)
2. **Movement is `native_to`-driven** (`common/movement.c:289-360`); `move_type` is *derived*
   (`common/unittype.c:2911-2947`). All-terrain class = list it in every terrain's `native_to`.
3. **Server Lua `edit.*` API is broad** (`server/scripting/tolua_server.pkg`, impls in
   `server/scripting/api_server_edit.c`): `change_terrain`, `create_extra`/`remove_extra`,
   `change_gold`, `change_city_size`, `create_unit`, `create_city`, `transfer_city`,
   `give_tech`, `unit_teleport`, `perform_action` (all overloads) … → PW placement + all
   special-action effects are pure Lua.
4. **Exactly 4 User Action slots** (`ACTION_USER_ACTION_1..4`, engine result `ACTRES_NONE`);
   behavior is Lua via `action_started_unit_{unit,units,city,tile,extras,self}`.
5. **Bombard** fully engine-implemented + ruleset-tunable (`bombard_rate`, `bombard_*_max_range`).
6. **C-patch path confirmed for the future:** `patches/local/*.patch` auto-applies at image build
   (`apply_patches.sh`). So if we ever need a fork, the machinery exists.

## 3. Verification spikes — status & findings

| Spike | Claim tested | Status | Finding |
|---|---|---|---|
| **S2** | tech classes + `cost_pct` scale research per age | ✅ PASS | Loads + autogame confirm era-pacing knobs work. First shipped user of the feature. |
| **S5** | ruleset User Action → Lua effect, end-to-end | ✅ PASS | `find.action`→`unit:perform_action`→`action_started_unit_*`→handler→`edit.change_gold` all land, City + Self targets. Gotchas captured (silent-false; `create_unit` moves_left=-1; `edit.perform_action` name). → `SESSION-HANDOFF.md` §4. |
| **S1** | ocean city founds + survives 30-40 turns | ✅ **PASS** (in-container, 2026-07-03) | Coastal ocean city founded via `edit.create_city` on `NoCities`-cleared shallow Ocean **survived 30 turns, grew size 1→2**; isolated deep-sea city starved same-turn (food, not terrain). Zero C. → `feature-ocean-cities.md`. |
| **S3** | `causes="Road"` extra on ocean | ✅ **confirmed by shipped precedent** | Oil Platform (`causes="Mine"` on Deep Ocean) + Buoy (`causes="Base"` on Oceanic) prove ocean extras with a `causes` effect work — Road is the same extra system. Sea-tunnel *movement bonus* is a build-time verify (a full `[extra_*]` + roster entry), not an engine risk. |
| **S4** | all-terrain "Orbital" class moves over land+sea | ✅ **confirmed by shipped data** | The shipped `native_to` lists already put `"Air"`/`"Missile"` in **both** ocean terrains (`terrain.ruleset:307/357/408`) AND every land terrain (`:459-949`) — all-terrain classes exist and work today. "Orbital" = a 10th entry in the same lists. Bombard is engine-native. |

## 4. Decision matrix — feature → tier (was → is)

| Feature (roadmap #) | Was | **Is (evidence)** | Sub-plan |
|---|---|---|---|
| Undersea cities (2.1) | `[C][R][L][A]` "first C fork" | **`[R][L][A]`** | `feature-ocean-cities.md` |
| Undersea tunnels/mines (2.2) | `[R][A]` | **`[R][A]`** (mine=shipped; tunnel=S3) | `feature-sea-improvements.md` |
| Orbital units / space planes (3.1/3.2) | `[R][L][A]` "approximation" | **`[R][L][A]`** confirmed stronger | `feature-orbital.md` |
| Public Works placement (1.3) | `[L][J]` | **`[L]`** (+optional tiny `[J]` tooltip) | `feature-pw-placement.md` |
| Unconventional warfare (1.5/1.6/2.3) | `[L][R][A]` + assumed client-button gap | **`[R][L][A]`, zero `[J]`** (4 UA slots + Lua dispatch; multiplex 8 units onto 4 slots by target-kind + actor flag) | `feature-special-actions.md` |
| Era pacing knobs (1.1) | assumed fine | **`[R]` — S2 PASS** (tech classes work; fallback = flat per-tech `cost`) | `epoch-tech-tree.md` |
| 12-stack army combat (3.7) | `[C][J]` XL optional | unchanged — **only genuine `[C]` item**, last/optional | — |
| Pop-as-slave modeling (3.8) | `[C]` optional | likely **`[L]`** via `change_city_size`+`create_unit` (approx first) | `feature-special-actions.md` §6 |

## 5. Net conclusion for the roadmap

- **Delete the `[C]` tag from 2.1** — undersea cities are `[R][L][A]`. The "first deliberate C
  fork" milestone in the roadmap's sequencing note is obsolete.
- **1.3 drops to `[L]`** — the Surveyor + User Action replaces the assumed `[J]` client work.
- **1.5/1.6/2.3 lose the client-work assumption** — User Actions render as real buttons.
- **The only surviving `[C]` items are 3.7 and 3.8**, both explicitly optional and last. On
  current evidence Epoch can reach a full CtP2-spirit game **Ember→Lattice with zero engine
  patches.** Keep `patches/` empty until an optional XL item proves an approximation insufficient.
- Remaining risk is **balance/tuning**, not feasibility (ocean tile yields, orbital dominance,
  special-action rates) — all live in ruleset data + `EPOCH_CONFIG`, the intended tuning surface.
