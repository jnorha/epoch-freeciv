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

## 6. Open questions
- **Sea Tunnel movement semantics:** does `causes="Road"` on ocean grant the road move bonus, or
  only visually connect? (S3 answers.) If only visual, use a movement effect.
- **Do undersea mines work on Deep Ocean/Trench, or only the shelf?** Oil Platform is Deep-Ocean;
  decide the depth rules alongside 1.4's ocean sub-types.
- **Solar/tidal array as extra vs. building:** tile-extra (placeable anywhere) vs. city building.
  Recommend extra for the solarpunk "gardened planet" tile-works feel.
