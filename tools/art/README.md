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
`--method box|nearest` · `--despeckle [N]` · `--pad WxH` · `--contrast N` · `--outline`.
Masters (`*_nb2.png`) are kept next to the processed sprite — reprocess, don't regenerate.

## Readability gate (MANDATORY before a sprite enters a sheet)

```bash
npm run preview -- --sprite ../../tileset/epoch/src/units/undersea_worker_96.png
```

Writes `<sprite>_preview.png`: the sprite at **native size** on real grass + deep-ocean
panels (1× and 3×). Eyeball the 1× row — if the silhouette doesn't read there, it will not
read on the map. Fix by regenerating with bolder prompts (below), or add `--outline` /
`--contrast 12` in processing. No sprite ships on vibes; it ships on this sheet.

**Authoring standard (target cells: units 96×80, buildings 128×128):**
- Prompt for **bold silhouette, high contrast, minimal fine detail** — the anchor prompts
  in `gen.ts` cover the flat background; add subject phrasing like "chunky readable
  shapes" for units that gate poorly.
- One subject, centered; no ground shadow (the map tile provides grounding).
- Team/palette: keep a strong hue identity per unit — it's what survives 96px.

## Sheets → game (`make_sheet.ts` + `refresh_tileset.sh`)

Sprites enter the game via sheet manifests (`sheets/*.json`) → `npm run sheet -- --manifest
sheets/epoch_units.json` → `tileset/epoch/web/epoch_*.{png,spec}`. Those are packed into the
amplio2 web atlas by `scripts/freeciv-img-extract` (spec list includes them; `install.sh`
overlays them into the freeciv data dir at image build). For a running container, skip the
rebuild: `./refresh_tileset.sh` re-runs the extractor in-container and deploys atlas + spec +
config; then hard-refresh the browser. Unit tags are `u.<name>_Idle` (+`_Idle_0/_1/...` for
animation frames); building tags are plain `b.<name>`.

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
