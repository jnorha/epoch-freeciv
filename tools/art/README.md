# Epoch art pipeline

Self-contained art-generation + sprite-processing toolchain for Epoch. Lives here so art can
be produced in-repo, alongside the content it illustrates.

## Setup (once)

```bash
cd tools/art
npm install                       # @fal-ai/client + pngjs + tsx (pure JS, no native builds)
cp .env.example .env              # then paste your keys (FAL_KEY required, RD_API_KEY optional)
```

`.env` and `node_modules/` are gitignored. Keys are shared with the Headwater project (same
fal.ai account).

## Generate (`gen.ts`)

Backends: **Nano Banana 2** (default, ~$0.08/image, best adherence, honours the `--anchor`
system prompt — use for sprites) and **Flux.1-schnell** (`--model flux`, ~$0.003/image,
Apache-2.0 — use for cheap concept art).

```bash
# Catalogued asset (auto-names + places the _nb2 master under tileset/epoch/src/…):
npm run gen -- --asset undersea_worker

# Raw prompt with a system anchor (unit | building | tile | concept):
npm run gen -- --anchor unit --prompt "a hovering recon drone, teal plating" \
  --out ../../tileset/epoch/src/units/recon_drone_nb2.png

# Cheap concept/establishing art (Flux):
npm run gen -- --model flux --anchor concept --prompt "a coastal solarpunk capital at dawn" \
  --out ../../art/concept/misc/capital.png
```

Anchors keep sprite backgrounds **flat pale-grey** so the processor can key them out cleanly.

## Process a sprite (`process_sprite.ts`)

Turns an NB2 master into a game-ready transparent sprite (pure `pngjs`, no `sharp`).

```bash
npm run process -- --in ../../tileset/epoch/src/units/undersea_worker_nb2.png \
  --remove-bg --trim --size 64x64 --pad 64x64 \
  --out ../../tileset/epoch/src/units/undersea_worker.png
```

Steps (each opt-in): `--remove-bg [tol]` · `--trim` · `--size WxH` / `--scale N` ·
`--method box|nearest` · `--despeckle [N]` · `--pad WxH`. Masters (`*_nb2.png`) are kept next
to the processed sprite — reprocess, don't regenerate.

## Layout

```
tools/art/
  gen.ts            generation (Flux + NB2, raw + catalog, system anchors)
  process_sprite.ts NB2 master → game-ready transparent sprite
  lib/io.ts         download / write helpers
tileset/epoch/src/  raw sprite sources (masters + processed) — pre-atlas
art/concept/        §1b concept-art library (cinematic, not game sprites)
```

Getting processed sprites into a live Freeciv-web tileset atlas (`.spec`/`.tilespec` packing)
is a separate step tracked in the roadmap — this pipeline produces the source sprites for it.

## IP

Flux.1-schnell is Apache-2.0 (outputs yours, commercial OK) — always use `fal-ai/flux/schnell`,
never `/dev`. Nano Banana 2 outputs are owned by the user per fal.ai TOS.
