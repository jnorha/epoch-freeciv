# Public Works — Economy & Placement Design

**Status:** Proposed design for backlog item 1.3 (Public Works economy). Feeds 1.4 / 2.2 /
3.3 (every "spend-to-place" improvement: roads, mines, sea tunnels, solar tile-works).
**Author:** Engine-gap evaluation (2026-07-03).
**Source material:** `doc/design/epoch-lua-systems-draft.lua` (`EPOCH_CONFIG.pw`), the **S5
User-Action spike**, Agent B's `edit.*` API audit, container `doc/README.actions`.

> **Engine basis (no C patch):**
> - **Accrual + spend accounting** is pure Lua on `turn_begin` (proven pattern — our era
>   detection already runs there).
> - **Instant tile mutation** is `edit.create_extra(tile, "<Extra>")` / `edit.remove_extra`
>   (Agent B confirmed in `tolua_server.pkg`).
> - **The placement gesture** is a ruleset **User Action** with `target_kind = "tiles"`, which
>   S5 proved dispatches to a Lua handler via `action_started_unit_tile`. Shipped precedent:
>   `data/sandbox/actions.ruleset` User Action 2 ("Use Ancient Transportation Network") is a
>   tiles-targeted user action. So the whole loop — *click tile → Lua validates pool → extra
>   appears* — needs **zero engine work**.

CtP2's Public Works replaces per-tile worker micromanagement with a **national pool** that the
player spends to instantly place improvements anywhere in their territory. We reproduce the
*feel* (pooled national budget, instant placement) without touching the C engine.

---

## 1. The pool (accrual) — Lua on `turn_begin`

Per the "one tuning surface" tenet, all rates live in `EPOCH_CONFIG.pw` (already drafted):

```lua
-- per player, each turn:
pw_gain = Σ_cities( city_shield_output(c) * base_rate * gov_multiplier(player.government) )
EPOCH_STATE.pw[player.id] = EPOCH_STATE.pw[player.id] + floor(pw_gain)
```

- `base_rate = 0.10`, government multipliers 0.05 (Anarchy) → 0.18 (Ecotopia) — the late
  solarpunk govs are deliberately PW-rich (roadmap 1.7 tie-in).
- **Persistence across save/load:** Lua state is rebuilt on load, so the pool balance must be
  reconstructable or stored. Two options: (a) recompute nothing and accept a reset (bad), or
  (b) **stash the balance in a save-safe location.** Freeciv Lua state *can* be persisted via
  the `_freeciv_state_dump`/`code`+`table` save hooks (see `doc/README.lua`, the
  `save`/`load` script hooks used by civ2civ3 for its own tables). Use those hooks to
  serialize `EPOCH_STATE.pw` — the same mechanism we'll need for injunction timers and era
  state. **Design decision: one `EPOCH_STATE` table, one save/load hook, covers PW + special
  actions + eras.**

## 2. Placement (spend) — "Surveyor" unit + Commission Works user action

**Recommended gesture: a cheap civilian "Surveyor" unit as the pointing device**, rather than
any client work. The player moves the Surveyor and issues one User Action:

- Define `User Action 3` (or whichever slot §see special-actions doc coordination) with
  `user_action_3_target_kind = "tiles"`, `min_range = 0`, `max_range = 1`, `ui_name = "Commission Works"`.
- Enabler routes only the Surveyor (`UnitTypeFlag "PublicWorks"`) and requires the target tile
  be owned by the actor's player (`TileOwner`/`CityTile` reqs) and `MinMoveFrags 1`.
- Handler on `action_started_unit_tile`:

```lua
function epoch_commission_works(action, actor, target_tile)
  if action:rule_name() ~= "User Action 3" then return end
  -- server-authoritative validation (tenet #3): ownership, adjacency, tech, terrain-legality
  local kind = epoch_pw_pick_extra(actor, target_tile)      -- which improvement is legal here
  if kind == nil then return epoch_notify(actor.owner, "Nothing to build here.") end
  local cost = EPOCH_CONFIG.pw.improvement_costs[kind]
  if EPOCH_STATE.pw[actor.owner.id] < cost then
    return epoch_notify(actor.owner, "Insufficient Public Works.")
  end
  EPOCH_STATE.pw[actor.owner.id] = EPOCH_STATE.pw[actor.owner.id] - cost
  edit.create_extra(target_tile, kind)                       -- instant placement
  log.normal(string.format("[EPOCH][pw_spend] player=%d kind=%s cost=%d tile=(%d,%d) turn=%d",
    actor.owner.id, kind, cost, target_tile:x(), target_tile:y(), game.current_turn()))
end
signal.connect("action_started_unit_tile", "epoch_commission_works")
```

**Why a unit and not a client button?** The roadmap tags 1.3 `[L][J]` with a *fallback* of
"Public Works Crew worker units." The S5 spike collapses that: a User Action *is* a real client
button already rendered by the engine, and a Surveyor unit gives the player an on-map cursor
with **zero JS/JSP work**. So 1.3 drops from `[L][J]` to **`[L]`** — the optional `[J]` is only
a later tooltip showing the pool balance.

**Which extra gets placed** (`epoch_pw_pick_extra`): the Surveyor commissions the
context-appropriate improvement for the tile (Mine on hills/mountains, Irrigation/Farm on
flatland, SeaTunnel/undersea-mine on ocean — see `feature-sea-improvements.md`, SolarPanel in
the Lattice age). A held modifier / a second user-action slot can force a specific type if the
player wants a road vs. a mine on the same tile; simplest v1 = auto-pick + a chat override.

## 3. Chat-command fallback (no unit, no client work)

If the Surveyor gesture proves clunky, the identical runner is reachable via a chat command
(`/pw road 12 34`) parsed in a `chat` signal handler — same validation, same `edit.create_extra`.
Keep both wired; they share `epoch_pw_place(player, kind, tile)`.

## 4. Server authority & anti-cheat

Every spend path (unit action **or** chat) funnels through one server-side function that
re-validates ownership, pool balance, tech prerequisites, and terrain legality **before**
debiting or mutating. The client never asserts the cost or the legality — it only *requests*.
This satisfies tenet #3 and means a hacked client can't conjure improvements or overspend.

## 5. Acceptance checks

1. Over a 50-turn autogame, each AI player's `EPOCH_STATE.pw` grows per turn at the
   government-scaled rate; `[EPOCH][pw_spend]` lines appear when a scripted Surveyor commissions.
2. A Surveyor commissioning a Mine on a hills tile debits exactly `improvement_costs.Mine` and
   the Mine extra appears the same turn.
3. An over-budget request is refused with a notify and **no** debit, **no** extra.
4. Save → reload preserves the pool balance (via the `EPOCH_STATE` save/load hook).

## 6. Open questions

- **Unit vs. no-unit for v1:** ship the Surveyor first (least engine risk), evaluate feel.
- **Improvement selection UX:** auto-pick vs. explicit type choice — resolve during build; a
  second tiles-slot or a chat arg both work without engine changes.
- **PW as special-action currency?** `feature-special-actions.md` §8 asks whether infiltration
  ops spend gold or PW. Recommend gold for infiltration, PW only for construction-flavored ops.
