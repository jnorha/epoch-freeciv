# Undersea Cities — Design Document

**Status:** Proposed design for backlog items 2.1 (undersea cities) + 1.4 (ocean sub-types).
Gated by the Helix age (Pressure Ecology → Abyssal Engineering) per `epoch-tech-tree.md` §5.
**Author:** Engine-gap evaluation (2026-07-03).
**Source material:** Freeciv C source (`common/city.c`, `server/cityturn.c`), epoch
`terrain.ruleset`, `data/civ2civ3/terrain.ruleset` (Oil Platform / Buoy precedents),
container `doc/README.actions`. Cross-refs `epoch-tech-tree.md`, `feature-sea-improvements.md`,
`feature-pw-placement.md`.

> **Engine basis — NO C patch (was tagged `[C]` "first deliberate fork"; downgraded to `[R][L][A]`):**
> - `common/city.c:1565-1580` `city_can_be_built_tile_only()` gates founding **only** on the
>   terrain `NoCities` flag + `citymindist`. There is **no** hardcoded ocean prohibition — the
>   engine's own comments elsewhere even anticipate "sea units build ocean cities."
> - `server/cityturn.c:776` emits `city_destroyed` from `city_reduce_size()` — that fires on
>   **starvation** (population reaching 0), **not** on terrain. A grep of the server turn/city
>   code found no "city on ocean auto-dies" path. So an ocean city is expected to persist exactly
>   like a land city as long as it can feed itself.
> - **S1 spike — ✅ PASS (2026-07-03, in-container).** Dropped `NoCities` on shallow Ocean;
>   `edit.create_city` founded a **coastal** ocean city (tile 7,1) that **survived all 30 turns
>   and grew size 1 → 2**, zero Lua/engine errors. **Crucial secondary finding:** an *isolated*
>   deep-sea city (founded on the first open-ocean tile, no adjacent land) was **destroyed the
>   same turn** — it starved (`cityturn.c:776` path) for lack of workable food tiles. So the
>   engine fully permits ocean cities; **viability is a food problem** (§3), not a prohibition.
>   Confirms this feature needs ZERO C patches. (Tooling gotchas hit en route are logged in
>   `doc/SESSION-HANDOFF.md` §4 — tolua property-vs-method, NULL-userdata `~= nil`, and the
>   `Player:create_city` wrapper dropping `edit.create_city`'s bool return.)

CtP2's undersea cities are one of the group's most-loved late-game features. We reproduce them
as **ordinary Freeciv cities on ocean terrain that has had its `NoCities` flag removed**, with the
*capability* gated by tech (via the founder unit), not hardcoded anywhere.

---

## 1. Which terrain becomes buildable (ties into 1.4 ocean sub-types)

epoch `terrain.ruleset` today: `Ocean`, `Deep Ocean`, `Lake` all carry `NoCities`. The design
creates a depth gradient so undersea cities **hug the continental shelf** (a real spatial
constraint, not "cities anywhere in the sea"):

| Terrain | `NoCities`? | Cities? | Role |
|---|---|---|---|
| **Ocean** (shallow / "Continental Shelf") | **removed** | ✅ yes | The buildable seafloor. Coastal, shallow — where undersea colonies go. |
| **Deep Ocean** (+ future "Trench" / "Rift" sub-types, item 1.4) | kept | ❌ no | Too deep for habitation; still hosts undersea **mines/tunnels/buoys** (extras — see `feature-sea-improvements.md`). |
| **Lake** | kept | ❌ no | Inland water stays city-free (keeps lakes as terrain features, not real estate). |

This is the entire "engine change" for founding: **one flag removed from one terrain.** Item 1.4's
shelf/trench/rift sub-types layer resource variety on top and decide which deep terrains (if any)
ever become buildable in the Lattice age (Deep Habitation megacities, item 3.x).

## 2. Gating the *capability* by tech — the founder unit, not the terrain

If we only removed `NoCities`, an Ember-age Settler could found on the shelf turn 1 — wrong. The
capability is gated on the **founder unit**, whose `tech_req` is the Helix undersea line:

- **"Abyssal Founder"** (working name) — an ocean-native colonizer unit.
  - `tech_req = "Abyssal Engineering"` (per tech-tree §5: "undersea cities/tunnels/mines").
    Optionally a cheaper coastal-only variant at Pressure Ecology first.
  - Its `UnitClass` must be **native to the Ocean terrain** (a sea/submarine class) so it can
    reach the shelf. Movement in Freeciv 3.3 is `native_to`-driven (`common/movement.c:289-360`),
    so this is a `native_terrain`/class-membership setting, not code.
  - Carries the **Found City** action; the existing Found City enabler already permits founding on
    any non-`NoCities` tile, so no enabler change is needed beyond ensuring the actor class/reqs
    line up (verify the enabler's `actor_reqs` don't implicitly require a land class).
- Land Settlers keep `tech_req`/class that can't enter ocean → they *can't* found undersea, so the
  Ember-age exploit can't happen. The gate is entirely "who can stand on the shelf and Found."

**Why a dedicated unit (not just letting Settlers into the sea):** it's cleaner tech-gating, gives
the Helix age a tangible new build, and matches CtP2's dedicated undersea colonizer.

## 3. Post-founding survival (the part to prove empirically)

Static evidence says an ocean city behaves like any city. The concerns to confirm in S1 and
tune in the ruleset:
- **Food/tiles:** the city works its surrounding ocean tiles. Ocean tiles yield food/trade
  (esp. with Harbor); a shelf city ringed by ocean should sustain size 1-3 easily, more with
  undersea improvements (`feature-sea-improvements.md`) and a Harbor-equivalent. If shelf tiles
  are too poor, undersea cities starve — tune ocean tile output / require an early undersea
  improvement. **This is the main balance knob, not an engine risk.**
- **citymindist:** ocean cities obey the same spacing as land — fine.
- **Defense / capture:** an undersea city can be attacked/captured by sea/undersea units per
  normal rules; ensure at least one defensible undersea unit exists by the time cities do.
- **Disasters / migration / borders:** Agent B did not exhaustively trace these for ocean tiles.
  S1's 30-40-turn watch (city survives, grows, no Lua/engine error) covers them empirically.

## 4. Content & art (`[A]`)
- Founder unit sprite + undersea city graphics (biosphere-dome look per tech-tree "biosphere
  dome / undersea core" buildings). Placeholder-first per the art plan; NB2/RD pipeline.
- The shelf terrain can reuse the shallow-ocean tile with a subtle "developed shelf" overlay when
  a city sits on it; not blocking.

## 5. Acceptance checks
1. Load: epoch ruleset with `NoCities` removed from shallow Ocean loads clean (no fallback to classic).
2. A land Settler **cannot** found on the shelf (wrong class/tech); an Abyssal Founder **can**.
3. Scripted/played: found a shelf city → it survives 30+ turns, grows past size 1, works ocean
   tiles, emits no Lua/engine errors, and can be captured by an enemy undersea unit.
4. `citymindist` is respected between an undersea city and adjacent land cities.

## 6. Open questions
- **One buildable terrain or a distinct "Continental Shelf" terrain?** Recommend reusing shallow
  `Ocean` (fewer terrains, less art) unless item 1.4's resource design wants a separate shelf type.
- **Deep Habitation (Lattice) megacities:** do any *deep* terrains ever become buildable, or do
  undersea cities just grow larger via buildings? Defer to the 3.x far-future pass.
- **Harbor-equivalent for undersea cities:** likely a required early building for food viability;
  design alongside `feature-sea-improvements.md` and the Helix building set.
