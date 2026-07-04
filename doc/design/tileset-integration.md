# Tileset integration — getting Epoch sprites into freeciv-web

How a generated sprite (`tileset/epoch/src/…`) becomes a pixel the browser draws, what it costs,
and where animation fits. Written from a full trace of the running container (2026-07-04).

## 1. Architecture (how the web client draws a sprite)

```
freeciv/data/<tileset>/*.spec + *.png     ← desktop tileset source (grid of cells → tags)
        │  scripts/freeciv-img-extract/img-extract.py  (PIL; packs + emits JS)
        ▼
webapp/tileset/freeciv-web-tileset-<name>-<page>.png   ← packed atlas page(s)
webapp/javascript/2dcanvas/tileset_spec_<name>.js      ← var tileset = { "tag":[x,y,w,h,page], … }
        │  loaded by the client
        ▼
2dcanvas renderer (default; amplio2)  OR  webgl renderer (renderer_main.js)
```

- **Default renderer is `RENDERER_2DCANVAS`** (`civclient.js:56`), which uses **amplio2** via
  `tileset_spec_amplio2.js`. WebGL is opt-in.
- A sprite tag maps to `[x, y, w, h, page]` — pixel rect on packed atlas page `<page>`.
- **Tag conventions** (verified): terrain `t.l0.grassland1`; unit **`u.<type>_Idle`** (note the
  state suffix — see §4); roads `road.road_n`; resources `ts.oil`; effects `explode.unit_0…4`.
- The ruleset's `graphic = "u.workers"` (+ `graphic_alt`) is looked up as `u.workers_Idle`; if
  absent the alt is tried. (e.g. amplio2 has no `u.workers_Idle`, so it falls back to
  `u.engineers_Idle`.)
- Source tilesets live in the **freeciv C data dir inside the container**
  (`/docker/freeciv/freeciv/data/amplio2/`), *not* in this git repo — the packed webapp tileset is
  a build artifact under `/docker/freeciv-web/src/derived/webapp/` + `…/target/freeciv-web/`.

## 2. Resolution reality — amplio2 cells are small

amplio2 **unit cells are 64×48**; terrain cells 96×48. Our NB2 sprites are authored at 128px+ with
lots of detail, so dropping one into a 64×48 unit cell shrinks it to near-illegibility. Two ways
forward for art that actually reads:
- **Custom larger-cell tileset** (author our own `.spec` with, say, 128×96 unit cells), or
- the **WebGL/HD render path** (bigger sprites; the project's stated way to "beat the 2000 look").

Either way our art belongs in a **dedicated Epoch tileset**, not shoehorned into amplio2 at 64×48.

## 3. Two integration paths

### (A) Dev-preview injection — fast, ephemeral (proven 2026-07-04)
Blit a processed sprite directly into the **deployed** atlas at an existing tag's cell, in place.
Script: `tools/art/inject_dev_sprite.py` (runs in the container; PIL 9.4.0 is present). Proven by
overriding `u.engineers_Idle` (`[320,816,64,48,1]`) with `undersea_worker.png` in both
`…/src/derived/webapp/tileset/` and `…/target/freeciv-web/tileset/` — a hard-refresh of the game
then draws our sprite for the Undersea Worker (which falls back to `u.engineers`).
- **Pros:** instant visual check, no rebuild.
- **Cons:** ephemeral (any `img-extract`/webapp rebuild wipes it); clobbers the vanilla unit that
  owns the cell; capped at the cell's 64×48. **Preview only — not the shipping path.**

### (B) Repo-tracked custom tileset — the real path (TODO)
1. Fork/extend a tileset into the repo (e.g. `tileset/epoch/amplio2-epoch/`): copy the relevant
   amplio2 `.spec` + atlas `.png`, or start a fresh `epoch.tilespec` with larger unit cells.
2. Add our sprites as new grid cells + **new tags** (e.g. `u.undersea_worker_Idle`) in the `.spec`.
3. Wire the build to run `img-extract` against that source (`scripts/freeciv-img-extract/sync.sh
   -f <freeciv+overlay> -o <webapp>`) so the packed atlas + `tileset_spec_*.js` include our tags.
4. Point ruleset graphics at the new tags (`graphic = "u.undersea_worker"`), replacing the stock
   placeholder tags currently used.
5. Rebuild/redeploy the webapp; commit the source `.spec`/`.png` (packed output stays derived).

This is a build-system task (the tileset source isn't in-repo yet); it's the next real art step.

## 4. Animation — what freeciv supports

- **Frame-sequence animation EXISTS** in freeciv and is used for effects: explosions are
  `explode.unit_0 … explode.unit_4` (5×30×30 frames the client cycles). So the engine/renderer can
  play numbered frame sequences.
- **Units carry a state suffix** — every unit sprite is `u.<type>_Idle`. amplio2 populates **only
  `Idle`** (61 tags, **zero numbered frames**), so stock units are static single-frame. The
  `_<State>` slot is the natural hook for more states/animation.
- **CtP2-style idle animation is therefore possible but not free:** it needs (a) multi-frame
  sprites per unit (e.g. `u.undersea_worker_Idle_0…N`, easy to author — generate a few NB2 poses)
  **and** (b) client-side frame cycling in the 2dcanvas/webgl unit-draw path (a renderer
  enhancement — stock freeciv-web doesn't animate idle units). Track as its own feature.
- Cheapest first animation: a 2–3 frame idle "bob/breathe" cycled by a small tweak to the unit
  draw loop, reusing the explosion frame-cycling pattern.

## 5. Status — path (B) SHIPPED as an amplio2 extension (2026-07-04)

Implemented (see also `tools/art/README.md`):
- **Repo-tracked spec extension** (`tileset/epoch/web/epoch_units.{spec,png}` +
  `epoch_buildings.{spec,png}`), generated by `tools/art/make_sheet.ts` from manifests in
  `tools/art/sheets/*.json`. **Unit cells 96×80** (tile 96×48 — hexemplio's 126×82 unitextras is
  the shipped oversized precedent), building cells 128×128.
- **Packing**: the sheets are added to `spec_files["amplio2"]` in `img-extract.py` and overlaid
  into `freeciv/freeciv/data/amplio2/` by `install.sh` right before `sync-js-hand.sh` — same
  atlas, new tags, zero client tileset-selection work. Packing spilled amplio2 onto a **4th atlas
  page** → `tileset_image_count = 4` in `tileset_config_amplio2.js` (the refresh script warns if
  the page count drifts again).
- **Fast iteration**: `tools/art/refresh_tileset.sh` re-runs the extractor inside the running
  container and deploys atlas + `tileset_spec_amplio2.js` + config + patched client JS into both
  served webapp dirs — no image rebuild per art tweak.
- **Ruleset re-pointed**: Undersea Worker/Abyssal Founder/Weapon Platform → `u.<name>` (stock
  tags kept as `graphic_alt`); Abyssal Foundry/World-Tree Spire → `b.<name>`.
- **Client JS (fork)**, `2dcanvas/tilespec.js`:
  - `fill_unit_sprite_array`: unit cells ≠ 64×48 are centered from their actual w/h (keeping
    amplio2's +3px bias) and bottom-anchored to the stock baseline — fixes the global-offset trap.
  - `tileset_unit_type_graphic_tag`: **idle frame cycling** — when `<tag>_Idle_0` exists, cycles
    `<tag>_Idle_<Math.floor(Date.now()/500) % N>` (~2 Hz). Works because the 2dcanvas map redraws
    continuously (`update_map_canvas_check` on rAF + `MAPVIEW_REFRESH_INTERVAL`). Units without
    frame tags keep the static `_Idle`.
- **Animation art workflow** (first pair shipped for Weapon Platform + Undersea Worker):
  frame 2 via **NB2 edit** (`gen.ts --img <frame1_master> --prompt "identical sprite, only the
  lights/bubbles change"` → `fal-ai/nano-banana-2/edit`), then **process both frames with ONE
  shared `--crop` box** (union of their trim boxes — `--trim` prints the box) so scale/alignment
  match exactly; a differing bounding box (e.g. rising bubbles) otherwise changes the fit scale
  and the sprite "pops" between frames.
- **Readability gate**: `tools/art/preview_sheet.ts` renders the sprite at native size on real
  grass + ocean at 1×/3× — mandatory before a sprite enters a sheet manifest.

Remaining/future: batch more units through (all Helix/Lattice rosters); custom terrain (full
standalone `epoch` tileset — the §3 checklist above still applies when we go there); WebGL path
untouched (2dcanvas is the default renderer).
