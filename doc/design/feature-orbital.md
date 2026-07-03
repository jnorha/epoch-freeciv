# Orbital Units & Weapon Platforms — Design Document

**Status:** Proposed design for backlog items 3.1/3.2 (orbital units, space planes, weapon
platforms). Hard-gated to the Lattice age (Orbital Logistics → Orbital Foundries → Orbital
Ordnance) per `epoch-tech-tree.md` §5/§6.
**Author:** Engine-gap evaluation (2026-07-03).
**Source material:** Freeciv C (`common/movement.c`, `common/unittype.c`), epoch `units.ruleset` /
`game.ruleset` (unit classes), `data/*/actions.ruleset` (Bombard), container `doc/README.actions`.
Cross-refs `epoch-tech-tree.md`, `feature-special-actions.md`.

> **Engine basis — NO C patch (was assumed to maybe need one; `[R][L][A]`, confirmed STRONGER):**
> - **Movement is `native_to`-driven, not a hardcoded move-type.** `common/movement.c:289-360`
>   moves a unit based on whether its `UnitClass` is native to the target terrain; `move_type`
>   (Land/Sea/Air/Both) is *derived* from that native set (`common/unittype.c:2911-2947`). So an
>   **all-terrain "Orbital" class = a UnitClass listed in EVERY terrain's `native_to`.** The
>   Air/Missile classes already ship native to land+ocean — orbital just extends that to all.
> - **Class budget is fine:** max 32 unit classes; civ2civ3 (our base) uses **9**. Plenty of room.
> - **Bombard is fully engine-implemented and ruleset-tunable** — `bombard_rate`, per-variant
>   `bombard_*_max_range`, enabler-driven. Weapon platforms that strike ground from range need
>   **zero** new combat code.
> - **S4 spike (PENDING — confirmatory):** add class #10 "Orbital", append it to every terrain's
>   `native_to`, one test unit → autogame movement over land+sea, Bombard from range. Recipe in
>   `SESSION-HANDOFF.md` §5. No engine limitation stands in the way; the spike just proves the
>   config.

CtP2's far-future orbital layer (space planes, weapon platforms, orbital bombardment) is a
signature end-game feel. Freeciv has no literal orbital Z-layer, and we deliberately chose **not**
to fork one (too costly — Fable 5 mapping decision). Instead we model "orbital" as a **unit class
that is native everywhere**, which reads in-game as units that range freely over the whole map —
exactly the orbital fantasy without a second map.

---

## 1. The "Orbital" unit class

Add one `[unit_class]` — `Orbital` — with:
- Membership in **every terrain's `native_to`** (land, all ocean/lake, glacier, etc.). This is the
  all-terrain reach.
- Class flags for the orbital feel: **`Unreachable`** (can't be attacked by ordinary ground/sea
  units — only by other orbital/anti-orbital units, mirroring how you can't hit high-altitude
  craft with infantry), **`DoesntOccupyTile`** (doesn't ZoC / block the tile like a ground unit),
  and appropriate `damage`/`hp_loss` behavior. (Class flag set is fixed in the engine — pick from
  the existing flags; `Unreachable` + `Missile`/`Air`-like flags cover the fantasy.)
- Fuel decision (§3).

Every orbital unit type sets `class = "Orbital"`. That single class change is the whole
"orbital layer."

## 2. The orbital roster (units)

Per `epoch-tech-tree.md` §6 the Lattice unit row includes "star-cruisers/space-planes, orbital
platforms." Concrete types:

| Unit | Tech gate | Role |
|---|---|---|
| **Space Plane** | Orbital Logistics | fast all-terrain recon/transport; the mobile orbital unit |
| **Weapon Platform** | **Orbital Ordnance** (hard-gated Lattice) | stationary/slow; **Bombard** ground targets from range; the CtP2 orbital bombardment piece |
| **Orbital Interceptor** | Orbital Foundries | anti-orbital — one of the few things that can hit `Unreachable` orbital units (counter-play) |
| **Orbital Station** (building/unit) | Orbital Foundries | support/production node; see tech-tree "orbital station/foundry" buildings |

Tech gating is on each unit's `tech_req`, so the orbital layer simply doesn't exist until the
Lattice orbital line is researched — preserving the era arc.

## 3. Fuel vs. permanent — recommendation

Two ways to bound orbital dominance:
- **Fuel (Air/Missile-like):** units must return to a base/carrier each N turns or are lost.
  Strong balance lever, high micro.
- **Permanent + upkeep:** units persist but cost heavy shield/energy upkeep and are vulnerable to
  Orbital Interceptors.

**Recommend permanent + upkeep + interceptor counter-play** for the weapon platform (a platform
that must scurry home is un-fun), and **optionally fuel for the Space Plane** (keeps recon from
being free omniscience). Both are `unittype.ruleset` fields — no engine work; tune in play.

## 4. Orbital bombardment — Bombard action

Weapon Platforms strike ground using the engine's **Bombard** action (damages units in/around a
target tile without the platform moving in or dying):
- Enable a Bombard action enabler for `actor_reqs { UnitClass "Orbital" ... }` targeting tiles/cities.
- Tune `bombard_rate` and `bombard_max_range` for orbital reach (long range = the orbital feel).
- Hard-gate the *capability* via the unit's Orbital Ordnance `tech_req`, not the action.
- Optionally pair with a **User Action** ("Orbital Strike") if we want a distinct button/effect
  beyond vanilla Bombard (e.g. a Lua after-effect like terrain scorch / pollution) — the S5
  framework (`feature-special-actions.md`) supports exactly this. Budget: user-action slots are
  shared; coordinate with the special-action allocation.

## 5. Acceptance checks
1. Load: Orbital class + orbital units load clean; class count ≤ 32.
2. **S4:** an Orbital unit moves over land AND ocean AND glacier in one game; it is **not**
   attackable by a normal ground unit (`Unreachable`), and IS attackable by an Orbital Interceptor.
3. A Weapon Platform Bombards a ground stack from `bombard_max_range` without entering the tile.
4. No orbital unit is buildable before its Lattice `tech_req`.

## 6. Open questions
- **Exact class flags:** confirm the best existing flags for "high-altitude, all-terrain,
  hard-to-hit" from the fixed class-flag set during S4 (Unreachable + which others).
- **Transport interactions:** can a Space Plane carry ground units across ocean (a mobile bridge)?
  Powerful — decide during balance; it's a `cargo`/transport-class setting.
- **Vision:** orbital units likely grant wide vision — tune `vision_radius_sq`; watch for
  "free global map" degenerating scouting.
- **Orbital Strike as Bombard vs. User Action:** vanilla Bombard first; add a Lua User Action only
  if we want a bespoke after-effect. Coordinate slot usage with `feature-special-actions.md`.
