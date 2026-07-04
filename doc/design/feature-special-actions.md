# Special-Action Framework — Design Document

**Status:** Proposed design for backlog items 1.5 (unconventional-warfare Lua framework),
1.6 (first special units), 2.3 (rest of the roster). Governs the "flavor no other 4X has."
**Author:** Engine-gap evaluation (2026-07-03), grounded in the **S5 verification spike** (below).
**Source material:** `data/epoch/actions.ruleset`, container `doc/README.actions`, the Freeciv
["Changes in what a 3.x ruleset can do"](https://forum.freeciv.org/f/viewtopic.php?t=491)
forum threads, [Signal Tutorial](https://freeciv.fandom.com/wiki/Signal_Tutorial), and
`data/sandbox/actions.ruleset` (the only shipped ruleset with live User Actions).

> **Engine-claim verification — S5 spike, PASS (2026-07-03 against this build):**
> A ruleset-defined **User Action** (`ui_name_user_action_1`, target_kind + range + enabler)
> was driven end-to-end: `find.action("User Action 1")` → `unit:perform_action(action, target)`
> returned **true**, and the server emitted `action_started_unit_city` / `action_started_unit_self`,
> which invoked our Lua handler, which ran `edit.change_gold(target.owner, -25)` — the drain
> landed. **Both City-targeted and Self-targeted actions dispatched to Lua.** Zero C patches.
> This is the whole framework proven in miniature: *ruleset button → Lua effect.*
>
> **Gotchas the spike surfaced (bake these into the framework):**
> 1. `unit:perform_action` returns **false silently** if the action isn't enabled for that
>    actor/target — there is no error, no log. Every action's failure path must be handled
>    in Lua (refund + notify), because the engine won't tell you *why* it declined.
> 2. A unit spawned by `edit.create_unit(..., moves_left)` with `moves_left = 0` fails any
>    `MinMoveFrags` actor requirement. Scripted triggers must pass **`-1`** (full moves).
>    Real player-driven actions are unaffected (units have their own moves).
> 3. There is **no** `edit.perform_action_unit_vs_city` name — the tolua bindings collapse
>    every overload to `edit.perform_action(unit, action, target[, sub_target])`, wrapped as
>    `unit:perform_action(action, target, sub_target)`. Use the wrapper.

---

> **CORRECTION (2026-07-04, from the shipped PW build):** `target_kind` must be
> **`"Tile"`** (singular, capitalized), NOT `"tiles"`. `"tiles"` does not parse in this
> build — it silently falls back to the `Unit` default, so a tile-targeted `perform_action`
> returns false with zero diagnostics. **Slot 3 is already LIVE**: the Public Works "Field
> Operation" (User Action 3, `target_kind="Tile"`) ships in `actions.ruleset`, routed to the
> Surveyor by `UnitTypeFlag PublicWorks`. When special-actions is built, add the Ecoterrorist/
> Corporate-Branch enablers to the SAME slot and multiplex in the Lua handler by actor unit
> type (the PW handler already early-returns unless the actor has the `PublicWorks` flag).

## 1. The constraint: exactly 4 User Action slots

`gen_headers/enums/actions_enums.def` defines exactly `ACTION_USER_ACTION_1..4`. Their engine
result is `ACTRES_NONE` — the engine performs *no* built-in effect; it only (a) renders the
button with your `ui_name`, (b) enforces your enabler requirements + range, and (c) emits the
`action_started_unit_<targetkind>` signal. **All behavior is Lua.** civ2civ3 (our base) uses
zero user actions, so **all 4 slots are ours.**

We have **8 planned special units** (Cleric, Lawyer, Corporate Branch, Slaver, Abolitionist,
Ecoterrorist, Subverter, Televangelist) with more implied by "spirit-of-CtP2." 8 concepts > 4
slots. The framework's core job is to **multiplex many concepts onto 4 slots.**

## 2. Multiplex architecture: slot = target kind, unit type = effect selector

The `action_started` signal is *already* split by target kind
(`action_started_unit_city`, `_unit_unit`, `_unit_tile`, `_unit_self`, `_unit_extras`).
So we allocate **one slot per target kind** and let the Lua handler switch on the actor's
`UnitTypeFlag` to pick the concrete effect. A given unit type has exactly one matching enabler,
so a selected unit only ever sees the one button relevant to it — the generic slot label is
disambiguated by the unit the player has in hand.

| Slot | target_kind | signal | ui_name (generic, flavorful) | Units routed here |
|------|-------------|--------|------------------------------|-------------------|
| **User Action 1** | `City`  | `action_started_unit_city` | "Civic Operation" | Cleric (convert), Corporate Branch (franchise), Televangelist (mass sermon), Slaver (raid city pop) |
| **User Action 2** | `Unit`  | `action_started_unit_unit` | "Covert Operation" | Subverter (bribe/incite), Abolitionist (free a captured worker), Slaver (capture a worker) |
| **User Action 3** | `Tile` | `action_started_unit_tile` | "Field Operation" | Ecoterrorist (sabotage improvement / seed pollution), Corporate Branch (resource tap) |
| **User Action 4** | `Self`  | `action_started_unit_self` | "Legal Injunction" | Lawyer (place injunction — see §4) |

Routing inside a handler (pattern, from the S5-proven shape):

```lua
function epoch_civic_op(action, actor, target_city)
  if action:rule_name() ~= "User Action 1" then return end
  local reg = EPOCH_SPECIAL[actor.utype:rule_name()]   -- registry lookup by actor unit type
  if reg == nil then return end                         -- some other UA1 user; ignore
  epoch_run_special(reg, actor, target_city)            -- shared cost/success/effect/telemetry
end
signal.connect("action_started_unit_city", "epoch_civic_op")
```

## 3. The registry (backlog 1.5) — one data table, one runner

Per the roadmap's "one tuning surface" tenet, every special action is a row in a single Lua
table (the group rebalances here, no engine rebuild):

```lua
EPOCH_SPECIAL = {
  ["Cleric"] = {
    slot = 1, target = "City",
    cost = 120,                       -- gold (or PW) spent on attempt
    success = function(actor, tgt)    -- return 0..1 probability
      return epoch_clamp(0.35 + 0.05 * actor.veteran_level - 0.03 * tgt:size(), 0.05, 0.9)
    end,
    effect = function(actor, tgt)     -- server-authoritative mutation on success
      edit.transfer_city(tgt, actor.owner, 0, true, true, true, true)
    end,
    counter = "Injunction",           -- blocked if this Extra is on the target tile (§4)
    consuming = true,                 -- actor_consuming_always -> unit spent on use
    telemetry = "convert_city",
  },
  ["Corporate Branch"] = { slot = 1, target = "City", cost = 80,  ... , telemetry = "franchise" },
  ["Televangelist"]    = { slot = 1, target = "City", cost = 60,  ... , telemetry = "mass_sermon" },
  ["Subverter"]        = { slot = 2, target = "Unit", cost = 100, ... , telemetry = "bribe_unit" },
  ["Ecoterrorist"]     = { slot = 3, target = "tiles", cost = 90, ... , telemetry = "sabotage_tile" },
  -- Slaver / Abolitionist / Lawyer below
}
```

**`epoch_run_special(reg, actor, target)`** is the shared runner (validated **server-side** per
tenet #3 — never trust a client request):
1. **Guard** — re-check the actor still exists, has moves, can afford `reg.cost`; check the
   `reg.counter` Extra on the target tile (§4). Any fail → notify actor's player, **no charge**.
2. **Charge** — `edit.change_gold(actor.owner, -reg.cost)` (or PW pool debit).
3. **Roll** — `rng() < reg.success(actor, target)` using the engine's seeded RNG for MP determinism.
4. **Apply** — on success call `reg.effect`; on failure apply the miss outcome (unit lost / caught).
5. **Consume** — if `reg.consuming`, the enabler's `actor_consuming_always = TRUE` already spends
   the unit; otherwise decrement moves.
6. **Telemetry** — `log.normal(string.format("[EPOCH][special_action] action=%s actor_type=%s actor=%d target=%s success=%s cost=%d turn=%d", ...))`.
   Feeds the balance-tuning loop (roadmap Phase 0.5: "Cleric convert firing 4× more than any other action → tune it").

## 4. Counter-actions / injunctions (the Lawyer) — persist as an Extra, not a Lua table

CtP2's Lawyer places an **injunction** that blocks an opponent's special actions. Freeciv Lua
in-memory tables **do not survive save/load** (Lua state is rebuilt on load). For a
save-safe, synchronous-MP-safe status we place an invisible **`Injunction` Extra** on the
target city tile:

- Define an `Injunction` extra (category `Base`, no graphics, `Hidden`) in `terrain.ruleset`.
- Lawyer's action (`User Action 4`, target Self on its own tile / or City) → `edit.create_extra(tile, "Injunction")` + record an expiry turn in a parallel Lua table keyed by tile index (the *timer* can be Lua; the *fact* is the Extra, so it survives saves).
- Every special-action runner checks `target.tile:has_extra("Injunction")` in its guard step and aborts if present.
- `turn_begin` sweeps expired injunctions: `edit.remove_extra(tile, "Injunction")`.

This gives us the counter-flag the 1.5 schema calls for with **zero new engine state** and
correct save/reload behavior — a genuinely better design than an in-memory registry.

## 5. Enabler structure (copy from sandbox, gate by tech + government + flag)

Each unit type gets one enabler on its slot, gated to route only that unit and to enforce the
CtP2 preconditions. Shape verified against `data/sandbox/actions.ruleset` "Disrupt Supply Lines":

```
[enabler_cleric_convert]
action      = "User Action 1"
actor_reqs  =
    { "type",         "name",        "range",  "present"
      "UnitTypeFlag", "SpecCleric",  "Local",  TRUE     ; routes ONLY Clerics to this enabler
      "MinMoveFrags",  1,            "Local",  TRUE
      "DiplRel",       "War",        "Local",  FALSE    ; can't convert cities you're at war with
    }
target_reqs =
    { "type",     "name",   "range",  "present"
      "CityTile", "Center", "Tile",   TRUE
    }
```

- Route selector = a per-unit `UnitTypeFlag` (`SpecCleric`, `SpecSubverter`, …). Freeciv's
  unit-type flag budget is ample for 8 units. This is what makes one generic slot serve
  several unit types without collision — the flag makes each enabler match exactly one type.
- **Tech gating** happens on the *unit* (its `tech_req` in `units.ruleset`), not the action,
  so the button simply doesn't exist until the unit is buildable. Governments gate via a
  `Gov` actor_req where a government forbids/enables a unit's operations (roadmap 1.7).
- `user_action_N_actor_consuming_always = TRUE` for one-shot infiltrators; `FALSE` for repeatable
  operatives (Corporate Branch franchising many cities over time).

## 6. Enslave / free approximation (2.3) — no C patch

Roadmap 2.3 explicitly allows approximating enslave/free before any 3.8 C fork:
- **Slaver (city raid):** on success, `edit.change_city_size(tgt, -1)` + `actor.owner:create_unit(actor.tile, find.unit_type("Worker"), 0, nil, -1)` — a captured worker, exactly the roadmap's "captured-worker / city-size delta." (`create_unit` moves gotcha from the S5 box applies.)
- **Abolitionist (free):** target an enemy-owned Worker unit (slot 2) → `edit.unit_teleport`/transfer to the freeing player, or disband + city-size credit to a nearby friendly city.
- True population-as-slave-unit modeling (3.8, `[C]`) stays optional; this approximation is the T2 path and needs only `edit.*`.

## 7. Acceptance checks (feature-level, per roadmap success criteria)

1. Selecting a Cleric adjacent to/at a target city shows the "Civic Operation" button; using it
   flips the city's owner and emits `[EPOCH][special_action] action=convert_city success=true`.
2. A Lawyer injunction on that city makes a subsequent Cleric attempt abort with a notify and
   **no gold charged** — verified after a save/reload (Extra persists).
3. A headless autogame with scripted Cleric + Lawyer units runs 50+ turns, zero Lua errors,
   telemetry lines present for every attempt (success and failure).
4. All 8 units route to exactly one slot each; no slot's handler fires for the wrong unit type.

## 8. Open questions for the build

- **PW vs gold cost:** do special actions spend gold or the Public Works pool (`feature-pw-placement.md`)?
  Recommend **gold** for infiltration (universally available), **PW** only for construction-flavored
  ops (Corporate resource tap). Decide alongside the PW model.
- **Success visibility:** show the pre-roll odds in the button tooltip? Needs a small `[J]` client
  read of a Lua-exposed value, or a chat-command "assess" fallback (no client work). Defer to T3.5 polish.
- **UA-slot label wording:** the 4 generic labels are a UX compromise of the 4-slot cap. If the
  group finds them confusing, the fallback is chat-command-issued operations (`/cleric convert <city>`),
  which the same runner services — zero extra slots. Keep both paths in mind.
