/**
 * Readability gate: composite a processed sprite at NATIVE size onto real map
 * backgrounds, at 1× and 3× (nearest), into one contact-sheet PNG for eyeballing.
 *
 * This is the "no green blobs" check — every sprite must pass it (by human eye)
 * before it goes into a sheet manifest.
 *
 * Panels: [grass 1×] [ocean 1×] over [grass 3×] [ocean 3×].
 * Grass = real amplio2 grassland tile fixture (fixtures/grass_96x48.png), tiled.
 * Ocean = flat deep-sea blue (#002E89, the ruleset ocean color).
 *
 * Usage:
 *   npm run preview -- --sprite ../../tileset/epoch/src/units/undersea_worker_96.png
 *   (writes <sprite>_preview.png next to the input; --out to override)
 */
import fs from "fs";
import path from "path";
import { PNG } from "pngjs";

const args = process.argv.slice(2);
const arg = (n: string) => {
  const i = args.indexOf(`--${n}`);
  return i !== -1 ? args[i + 1] : undefined;
};
const spritePath = arg("sprite");
if (!spritePath) { console.error("--sprite <png> required"); process.exit(1); }
const inPath = path.isAbsolute(spritePath) ? spritePath : path.join(process.cwd(), spritePath);
const outPath = arg("out") ?? inPath.replace(/\.png$/, "_preview.png");
const scriptDir = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"));

type Img = InstanceType<typeof PNG>;
const newImg = (w: number, h: number): Img => {
  const p = new PNG({ width: w, height: h });
  p.data = Buffer.alloc(w * h * 4);
  return p;
};

const sprite = PNG.sync.read(fs.readFileSync(inPath));
const grass = PNG.sync.read(fs.readFileSync(path.join(scriptDir, "fixtures", "grass_96x48.png")));

const PAD = 8;
const panelW = Math.max(sprite.width + 2 * PAD, 2 * grass.width);
const panelH = Math.max(sprite.height + 2 * PAD, 2 * grass.height);

function fillOcean(img: Img, x0: number, y0: number, w: number, h: number): void {
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) {
    const i = (y * img.width + x) * 4;
    img.data[i] = 0x00; img.data[i + 1] = 0x2e; img.data[i + 2] = 0x89; img.data[i + 3] = 255;
  }
}
function tileGrass(img: Img, x0: number, y0: number, w: number, h: number): void {
  // Base green first — the fixture is an iso diamond with transparent corners,
  // so tiling it rectangularly leaves gaps; fill them with the tile's own green.
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) {
    const i = (y * img.width + x) * 4;
    img.data[i] = 0x2b; img.data[i + 1] = 0x77; img.data[i + 2] = 0x2b; img.data[i + 3] = 255;
  }
  for (let ty = 0; ty < h; ty += grass.height) for (let tx = 0; tx < w; tx += grass.width) {
    const cw = Math.min(grass.width, w - tx), ch = Math.min(grass.height, h - ty);
    for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
      const si = (y * grass.width + x) * 4;
      if (grass.data[si + 3] === 0) continue; // keep base green under diamond corners
      const di = ((y0 + ty + y) * img.width + (x0 + tx + x)) * 4;
      img.data[di] = grass.data[si]; img.data[di + 1] = grass.data[si + 1];
      img.data[di + 2] = grass.data[si + 2]; img.data[di + 3] = 255;
    }
  }
}
function compositeSprite(img: Img, cx: number, cy: number): void {
  const x0 = cx - (sprite.width >> 1), y0 = cy - (sprite.height >> 1);
  for (let y = 0; y < sprite.height; y++) for (let x = 0; x < sprite.width; x++) {
    const si = (y * sprite.width + x) * 4, a = sprite.data[si + 3];
    if (a === 0) continue;
    const di = ((y0 + y) * img.width + (x0 + x)) * 4;
    const na = a / 255;
    for (let c = 0; c < 3; c++) img.data[di + c] = Math.round(sprite.data[si + c] * na + img.data[di + c] * (1 - na));
    img.data[di + 3] = 255;
  }
}
function upscale3x(src: Img, sx: number, sy: number, w: number, h: number, dst: Img, dx: number, dy: number): void {
  for (let y = 0; y < h * 3; y++) for (let x = 0; x < w * 3; x++) {
    const si = ((sy + Math.floor(y / 3)) * src.width + (sx + Math.floor(x / 3))) * 4;
    const di = ((dy + y) * dst.width + (dx + x)) * 4;
    for (let c = 0; c < 4; c++) dst.data[di + c] = src.data[si + c];
  }
}

// 1× strip: two panels side by side
const strip = newImg(panelW * 2, panelH);
tileGrass(strip, 0, 0, panelW, panelH);
fillOcean(strip, panelW, 0, panelW, panelH);
compositeSprite(strip, panelW >> 1, panelH >> 1);
compositeSprite(strip, panelW + (panelW >> 1), panelH >> 1);

// final sheet: 1× strip on top, 3× strip below
const sheet = newImg(panelW * 2 * 3, panelH + PAD + panelH * 3);
// top strip centered
PNG.bitblt(strip, sheet, 0, 0, strip.width, strip.height, (sheet.width - strip.width) >> 1, 0);
upscale3x(strip, 0, 0, strip.width, panelH, sheet, 0, panelH + PAD);

fs.writeFileSync(outPath, PNG.sync.write(sheet));
console.log(`gate sheet: ${outPath} (${sheet.width}x${sheet.height}) — eyeball 1x for map readability`);
