# Undersea Tile Improvements — Design Document

**Status:** Proposed design for backlog item 2.2 (undersea tunnels/mines) + the sea-improvement
tiers of 1.3 (Public Works) and 3.3 (solarpunk). Gated Helix→Lattice per `epoch-tech-tree.md`.
**Author:** Engine-gap evaluation (2026-07-03).
**Source material:** `data/civ2civ3/terrain.ruleset` (Oil Platform, Buoy — shipped precedents),
epoch `terrain.ruleset`, container `doc/README.effect`. Cross-refs `feature-ocean-cities.md`,
`feature-pw-placement.md`, `epoch-tech-tree.md` (Abyssal Engineering, Deep Habitation).

> **Engine basis — NO C patch (`[R][A]`, confirmed):**
> - **Ocean-built extras already ship in our base.** civ2civ3 has **Oil Platform**
>   (`causes = "Mine"`, built on Deep Ocean from ships — `terrain.ruleset:1355-1382`) and **Buoy**
>   (`causes = "Base"` on Oceanic — `:1712-1739`). So "extras on ocean tiles, built by sea units,
>   granting a production/utility effect" is a **proven, shipped pattern** — undersea mines are
>   essentially a re-skin/re-gate of Oil Platform.
> - The only unproven variant is an **undersea tunnel** = `causes = "Road"` on ocean (movement
>   corridor across the seafloor). No shipped ruleset does Road-cause on ocean → **S3 spike**
>   (recipe in `SESSION-HANDOFF.md` §5). Roads are `native_to`/movement-driven like any extra, so
>   the expectation is PASS; the spike confirms ocean roads actually grant the movement bonus.

---

## 1. The improvement set (extras) and their `causes`

Freeciv "extras" (the umbrella over Mine/Road/Base/Irrigation/pollution) are pure ruleset data
(`[extra_*]` sections with `causes`, build reqs, effects). The undersea set:

| Extra | `causes` | Tech gate | Built by | Effect | Precedent |
|---|---|---|---|---|---|
| **Undersea Mine** | `Mine` | Abyssal Engineering | undersea worker / sea unit | +shields on shelf/deep tile | **Oil Platform** (shipped) |
| **Sea Tunnel** | `Road` | Abyssal Engineering | undersea worker | movement corridor across ocean (link undersea cities / continents) | **S3 spike** (no shipped example) |
| **Buoy / Sensor** | `Base` | (early) | sea unit | vision / naval utility | **Buoy** (shipped) |
| **Kelp / Bio-Farm** | `Irrigation`-like or custom | Pressure Ecology | undersea worker | +food (makes undersea cities viable — see `feature-ocean-cities.md` §3) | Farmland pattern |
| **Solar/Tidal Array** | custom (effect-driven) | Lattice (Fusion Lattices) | worker | +energy/production; solarpunk tier | SolarPanel (design) |
| **Eco-Restoration** | pollution-clear | Lattice | worker | reverse pollution; solarpunk victory support | Cleanup pattern |

`causes` is what ties the extra to an engine behavior: `Mine`→shield bonus, `Road`→movement
bonus, `Base`→fortification/utility, pollution→disaster mechanics. Custom effects (solar array
energy) ride the effects system (`doc/README.effect`) rather than a built-in `causes`.

## 2. Build path — undersea worker + Public Works, both

Two ways to place these, sharing the same extras:
1. **Undersea Worker unit** (classic Freeciv path) — an ocean-native worker (like the Oil
   Platform's ship-built pattern) with build-extra orders. Simple, no new mechanics.
2. **Public Works** (`feature-pw-placement.md`) — the Surveyor's "Commission Works" user action
   places the context-appropriate undersea extra on a shelf/deep tile and debits the PW pool.
   This is the CtP2-flavored path.

Recommend shipping the **worker path first** (least risk, mirrors Oil Platform exactly), then
layering PW placement on the same extras. `EPOCH_CONFIG.pw.improvement_costs` already lists
`SeaTunnel = 40`.

## 3. The Sea Tunnel (the one novel piece — S3)

The Sea Tunnel is the only improvement without a shipped precedent, and the most interesting:
a `causes="Road"` extra buildable on ocean that grants movement, letting undersea units (and
tunnel-capable land units, à la CtP2's Tunnel) traverse the seafloor and link undersea cities to
the coast. Design:
- `[extra_sea_tunnel]`: `causes = "Road"`, `build_time`, `native_to` the ocean-capable classes,
  reqs `TerrainClass Oceanic` + `TechReq Abyssal Engineering`.
- **S3 asserts:** the extra places on an ocean tile via `edit.create_extra(tile,"Sea Tunnel")`
  AND a unit on that tile gets the road movement bonus. If Road-cause turns out inert on ocean
  (unlikely), fallback = a custom movement effect keyed on the extra (still no C).
- Gameplay: tunnels become the undersea rail network — strategic chokepoints, cuttable by enemy
  undersea units. High CtP2 nostalgia value.

## 4. Gating & era feel
Per `epoch-tech-tree.md` §7 the PW/improvement tiers escalate: Helix opens **sea tunnels/undersea
mines + bio-farms + eco-restoration**; Lattice adds **solar/fusion arrays + climate works**. Keep
each extra's `TechReq` aligned to those names (Pressure Ecology / Abyssal Engineering / Fusion
Lattices) so content lands against stable tech ids.

## 5. Acceptance checks
1. Undersea Mine (Oil Platform re-gate) builds on a shelf tile and adds shields — mirrors the
   shipped Oil Platform behavior under our tech gate.
2. **S3:** Sea Tunnel places on ocean and grants road-like movement to an ocean-native unit;
   ruleset loads clean; no Lua errors over a short autogame.
3. Bio-Farm on a shelf tile raises the adjacent undersea city's food enough to grow it (ties the
   ocean-city viability knob).
4. All undersea extras are gated so no pre-Helix civ can build them.

### 5a. Sea Tunnel shipped + S3 CLOSED (✅ 2026-07-03, develop)
Shipped the Sea Tunnel (the one piece without a shipped precedent). Two paired sections are
required for any `causes="Road"` extra:
- `[extra_sea_tunnel]` — `causes="Road"`, `reqs { Tech "Abyssal Engineering"; TerrainClass
  "Oceanic" }`, `native_to = "Sea", "Trireme", "Orbital"`, `flags="NativeTile"`, `build_time=4`.
- `[road_sea_tunnel]` — `extra="Sea Tunnel"`, **`move_cost=1`** (the fast-corridor benefit),
  `gui_type="Other"`.

> **⚠️ Gotcha (cost one debug cycle):** a `causes="Road"` extra with **no matching `[road_*]`
> section segfaults the server at ruleset load** (the parser prints
> *`extra "Sea Tunnel" has "Road" cause but no corresponding [road_*] section`* then crashes with
> SIGSEGV rather than exiting cleanly). Every road-cause extra needs its `[road_<tag>]` twin. Same
> pattern applies to `causes="Base"` → `[base_*]` and `causes="Mine"` (no section needed, `Mine`
> is a built-in cause). Fix was one-shot once the error line was read.

**S3 spike — PASS (empirically closes the last precedent-only spike).** `tile:create_extra("Sea
Tunnel")` on a **shallow Ocean** tile: `has_extra` false→true; `remove_extra` round-trips back to
false; and it also places on **Deep Ocean**. Zero Lua/engine errors. So a Road-cause extra is fully
valid + placeable on ocean terrain — the only ocean-specific uncertainty. The `move_cost=1` benefit
is **engine-standard, terrain-agnostic** road behavior (applied to native-class units on the tile
regardless of underlying terrain), so no further ocean-specific risk remains; a live move-cost
measurement is deferred to a play test. Real building is gated by the extra `reqs` (Abyssal
Engineering + Oceanic) to an ocean-capable `Workers`-flag unit (undersea worker — see §2, TODO).

### 5b. Bio-Farm shipped as a BUILDING (Aquaculture Bay), not a tile extra (✅ 2026-07-04)
Design pivot (user's call, and the cleaner one): the "+food undersea improvement" is a **building
that stacks on the Harbor**, not a tile extra. The shipped Harbor's food is `[effect_harbor]
Output_Add_Tile +1 Food` gated `TerrainFlag Sea (Tile)` + `Building "Harbour" (City)` — i.e. +1
food on *every* ocean tile the city works (the whole work radius), nothing "adjacent." So a
second such building is a two-line clone with no unit / extra / build-action / per-tile machinery.

Shipped **Aquaculture Bay** (`[building_aquaculture_bay]`, `reqs` = `Tech "Pressure Ecology"` +
`Building "Harbour" City` + `Sea Adjacent`) with `[effect_aquaculture_bay]` = another
`Output_Add_Tile +1 Food` on Sea tiles. It **stacks**: Harbor(+1) + Aquaculture(+1) = +2 food on
every ocean tile worked, on top of the tile's base 1 = 3 food/ocean tile.

**Empirical 3-way growth spike (Neither / Harbor / Harbor+Aquaculture):** over 44 turns,
Neither **stalled at 3**, both food-building cities reached **6**, and Aquaculture got there
**faster (t24 vs t32)**. Both food cities share a **size-6 ceiling because a non-food cap binds
first** (civ2civ3 Aqueduct/happiness), so raw size can't show the extra food beyond the growth-rate
gap. Takeaway: **the ocean-food chain removes food as the growth constraint; ultimate undersea size
is then set by the standard, buildable Aqueduct → Sewer + happiness ladder** (all available to
undersea cities). Aquaculture's value is faster growth + food headroom for late-game megacities,
exactly mirroring the land Granary → Supermarket food ladder. Building vs. tile-extra trade recorded
in `feature-ocean-cities.md` §5b (building = city-wide/zero-effort; extra = per-tile/PW-targetable).

**Deferred (rest of 2.2):** Undersea Mine (Oil Platform re-gate, needs an Offshore-Platform-style
shield effect); a Lattice-tier ocean-food building (Deep Habitation) if more headroom is wanted;
Buoy re-use; solarpunk arrays; the ocean-native undersea worker unit (only needed once *tile*
extras like Sea Tunnel are built in normal play rather than via Public Works).

## 6. Open questions
- **Sea Tunnel movement semantics:** does `causes="Road"` on ocean grant the road move bonus, or
  only visually connect? (S3 answers.) If only visual, use a movement effect.
- **Do undersea mines work on Deep Ocean/Trench, or only the shelf?** Oil Platform is Deep-Ocean;
  decide the depth rules alongside 1.4's ocean sub-types.
- **Solar/tidal array as extra vs. building:** tile-extra (placeable anywhere) vs. city building.
  Recommend extra for the solarpunk "gardened planet" tile-works feel.
