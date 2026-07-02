# Epoch Ruleset

Custom ruleset for the Epoch project — a CtP2-spirit 4X game built on Freeciv-web.

## Derivation

Seeded from `civ2civ3` (run `scripts/epoch-seed-ruleset.sh` after `prepare_freeciv.sh` to populate
the base `.ruleset` files; then our customizations layer on top).

## File structure (once seeded)

```
epoch.serv            # server start config; selects this ruleset
script.lua            # Lua systems: PW pool, special-action registry, victory checks
techs.ruleset         # Five-age tech tree (Ancient → Renaissance → Modern → Genetic → Diamond)
units.ruleset         # Era unit rosters incl. unconventional warfare units
buildings.ruleset     # Improvements + Wonders
terrain.ruleset       # Surface + ocean sub-types (shelf / trench / rift)
governments.ruleset   # Governments with slider limits + special-unit gating
effects.ruleset       # Global effect definitions
cities.ruleset
game.ruleset
nations/              # Playable civilizations
```

## Tuning surface

All balance constants are in `script.lua` under `EPOCH_CONFIG`. Change them; no recompile needed.
