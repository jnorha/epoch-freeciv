# Epoch — Concept Art Library

Reference/establishing art for Epoch's design. **Concept art only** — these are §1b
cinematic illustrations that guide design and communicate the feel; they are *not* the
in-game Freeciv tileset sprites (that is a separate, later effort under `tileset/epoch/`).

## Generation method

Generated with **Flux.1-schnell via fal.ai** (Apache-2.0 outputs, commercial use OK,
~$0.003/image). The generator pipeline is not yet ported into Epoch's toolchain, so these
were produced by running Headwater's working `gen-concept` script (shared fal.ai key) with
raw prompts and outputting here:

```bash
# run from C:\ummon\headwater (has the toolchain + FAL_KEY)
npm run gen-concept -- --prompt "<STYLE> <subject>" --size landscape_16_9 \
  --out C:/ummon/epoch/art/concept/diamond_age/<name>.png
```

**Shared style anchor** (prepended to every prompt for a cohesive set):

> Solarpunk far-future concept art for a 4X strategy game, painterly detailed cinematic
> digital illustration, optimistic retrofuturism, cohesive key art:

To iterate on a single piece, re-run with the same `--out` (add `--seed N` to reproduce, or
`--model nano-banana-2` for a higher-fidelity hero render at ~$0.08/image).

## `diamond_age/` — the Lattice (Diamond) age set

| File | Subject | Ties to |
|---|---|---|
| `undersea_megacity.png` | Continental-shelf city, biosphere domes, kelp farms, tunnels | Undersea cities (2.1/2.2), the water-city growth path |
| `verdant_engine.png` | The Verdant Engine — planetary terraforming megastructure | Wonder (Planetary Stewardship) |
| `ascendant_nexus.png` | The Ascendant Nexus — distributed AI mind / data-cathedral | Wonder (Ascendant Intelligence) |
| `skyhook_terminus.png` | Skyhook Terminus — orbital elevator from a coastal city | Wonder (Skyhook Tethers) |
| `world_tree_spire.png` | World-Tree Spire — kilometre-tall living megatree arcology | Wonder (Living Architecture) |
| `stewardship_gov.png` | Solarpunk society in harmony with nature | Government: Stewardship |
| `synthesis_gov.png` | AI-governed technocratic city, drones, data | Government: Synthesis |
| `orbital_platform.png` | Orbital weapon platform + space planes over Earth | Orbital units (3.2) |

## IP

Flux.1-schnell is Apache-2.0 — outputs are ours, commercial use allowed. Always use
`fal-ai/flux/schnell` (not `/dev`, which is non-commercial). Training-data risk is
industry-wide background noise, not specific to this backend.
