/**
 * Post-process an NB2 master render into a game-ready sprite.
 *
 * Pipeline (each step opt-in, run in this order):
 *   --remove-bg [tol]   flood-fill from the edges, turning the near-uniform flat
 *                       background transparent (tolerance = max RGB distance, default 40)
 *   --trim              crop to the non-transparent bounding box (prints the box)
 *   --crop X,Y,WxH      crop to an explicit box INSTEAD of --trim — use ONE shared
 *                       box (union of the frames' trim boxes) for all animation
 *                       frames so their scale/alignment matches exactly
 *   --size WxH          downscale to fit within WxH, preserving aspect ratio
 *   --scale N           alternative to --size: exact 1/N downscale
 *   --method box|nearest  downscale sampling (default box)
 *   --despeckle [N]     drop isolated opaque islands smaller than N px (default 6)
 *   --outline           draw a 1px dark rim around the silhouette (map-scale pop)
 *   --contrast N        linear contrast boost on opaque pixels (e.g. 12; 0-50 sane)
 *   --pad WxH           center the result on a transparent WxH canvas
 *
 * Usage:
 *   npm run process -- --in tileset/epoch/src/units/undersea_worker_nb2.png \
 *     --remove-bg --trim --size 64x64 --pad 64x64 --out tileset/epoch/src/units/undersea_worker.png
 *
 * Default --out strips a trailing `_nb2` (game-ready name next to the master).
 */
import fs from "fs";
import path from "path";
import { PNG } from "pngjs";

const args = process.argv.slice(2);
function arg(name: string): string | undefined {
  const i = args.indexOf(`--${name}`);
  if (i === -1) return undefined;
  const next = args[i + 1];
  return next && !next.startsWith("--") ? next : undefined;
}
function flag(name: string): boolean {
  return args.includes(`--${name}`);
}
function parseWxH(s: string): { w: number; h: number } {
  const m = s.match(/^(\d+)x(\d+)$/i);
  if (!m) { console.error(`Expected WxH, got "${s}"`); process.exit(1); }
  return { w: Number(m[1]), h: Number(m[2]) };
}

const inArg = arg("in");
if (!inArg) { console.error("--in <png> required"); process.exit(1); }
const inPath = path.isAbsolute(inArg) ? inArg : path.join(process.cwd(), inArg);
const outArg = arg("out");
const outPath = outArg
  ? (path.isAbsolute(outArg) ? outArg : path.join(process.cwd(), outArg))
  : inPath.replace(/_nb2(?=\.png$)/, "").replace(/\.png$/, inPath.includes("_nb2") ? ".png" : "_processed.png");

const removeBg = flag("remove-bg");
const bgTol = arg("remove-bg") ? Number(arg("remove-bg")) : 40;
const doTrim = flag("trim");
const cropArg = arg("crop"); // "X,Y,WxH"
const sizeArg = arg("size");
const scaleArg = arg("scale") ? Number(arg("scale")) : undefined;
const method = (arg("method") ?? "box") as "box" | "nearest";
const padArg = arg("pad");
const doDespeckle = flag("despeckle");
const despeckleMin = arg("despeckle") ? Number(arg("despeckle")) : 6;
const doOutline = flag("outline");
const contrastArg = arg("contrast") ? Number(arg("contrast")) : 0;

type Img = InstanceType<typeof PNG>;
function newImg(width: number, height: number): Img {
  const png = new PNG({ width, height });
  png.data = Buffer.alloc(width * height * 4);
  return png;
}

/** Flood-fill from every edge pixel, clearing pixels within tol of the corner color. */
function floodRemoveBg(img: Img, tol: number): void {
  const { width, height, data } = img;
  const tolSq = tol * tol;
  const visited = new Uint8Array(width * height);
  const queue: number[] = [];
  const seed = (x: number, y: number) => {
    const p = y * width + x;
    if (!visited[p]) { visited[p] = 1; queue.push(p); }
  };
  for (let x = 0; x < width; x++) { seed(x, 0); seed(x, height - 1); }
  for (let y = 0; y < height; y++) { seed(0, y); seed(width - 1, y); }
  const corners = [0, (width - 1) * 4, (height - 1) * width * 4, (width * height - 1) * 4];
  const bg = [0, 1, 2].map((c) => corners.reduce((s, i) => s + data[i + c], 0) / 4);
  const near = (i: number) => {
    const dr = data[i] - bg[0], dg = data[i + 1] - bg[1], db = data[i + 2] - bg[2];
    return dr * dr + dg * dg + db * db <= tolSq;
  };
  let cleared = 0;
  while (queue.length > 0) {
    const p = queue.pop()!;
    const i = p * 4;
    if (!near(i)) continue;
    data[i + 3] = 0; cleared++;
    const x = p % width, y = (p - x) / width;
    for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]] as const) {
      if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
      const np = ny * width + nx;
      if (!visited[np]) { visited[np] = 1; queue.push(np); }
    }
  }
  console.log(`remove-bg: cleared ${cleared} px (tol ${tol})`);
}

function trim(img: Img): Img {
  const { width, height, data } = img;
  let minX = width, minY = height, maxX = -1, maxY = -1;
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    if (data[(y * width + x) * 4 + 3] > 0) {
      if (x < minX) minX = x; if (x > maxX) maxX = x;
      if (y < minY) minY = y; if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) { console.error("trim: image is fully transparent"); process.exit(1); }
  const w = maxX - minX + 1, h = maxY - minY + 1;
  const dst = newImg(w, h);
  PNG.bitblt(img, dst, minX, minY, w, h, 0, 0);
  console.log(`trim: ${width}×${height} → ${w}×${h}  (box: --crop ${minX},${minY},${w}x${h})`);
  return dst;
}

/** Crop to an explicit box (shared across animation frames for stable alignment). */
function cropBox(img: Img, spec: string): Img {
  const m = spec.match(/^(\d+),(\d+),(\d+)x(\d+)$/i);
  if (!m) { console.error(`--crop expects X,Y,WxH, got "${spec}"`); process.exit(1); }
  const [x, y, w, h] = [Number(m[1]), Number(m[2]), Number(m[3]), Number(m[4])];
  if (x + w > img.width || y + h > img.height) {
    console.error(`--crop box exceeds image ${img.width}×${img.height}`); process.exit(1);
  }
  const dst = newImg(w, h);
  PNG.bitblt(img, dst, x, y, w, h, 0, 0);
  console.log(`crop: ${img.width}×${img.height} → ${w}×${h} @ ${x},${y}`);
  return dst;
}

function downscale(img: Img, dstW: number, dstH: number): Img {
  const { width, height, data } = img;
  const dst = newImg(dstW, dstH);
  for (let y = 0; y < dstH; y++) {
    const sy0 = Math.floor((y * height) / dstH);
    const sy1 = Math.max(sy0 + 1, Math.floor(((y + 1) * height) / dstH));
    for (let x = 0; x < dstW; x++) {
      const sx0 = Math.floor((x * width) / dstW);
      const sx1 = Math.max(sx0 + 1, Math.floor(((x + 1) * width) / dstW));
      const di = (y * dstW + x) * 4;
      if (method === "nearest") {
        const si = (Math.min(sy0 + ((sy1 - sy0) >> 1), height - 1) * width + Math.min(sx0 + ((sx1 - sx0) >> 1), width - 1)) * 4;
        dst.data[di] = data[si]; dst.data[di + 1] = data[si + 1];
        dst.data[di + 2] = data[si + 2]; dst.data[di + 3] = data[si + 3] >= 128 ? 255 : 0;
        continue;
      }
      let r = 0, g = 0, b = 0, a = 0, n = 0;
      for (let sy = sy0; sy < sy1; sy++) for (let sx = sx0; sx < sx1; sx++) {
        const si = (sy * width + sx) * 4;
        const pa = data[si + 3];
        r += data[si] * pa; g += data[si + 1] * pa; b += data[si + 2] * pa; a += pa; n++;
      }
      if (a === 0) { dst.data[di + 3] = 0; }
      else {
        dst.data[di] = Math.round(r / a); dst.data[di + 1] = Math.round(g / a);
        dst.data[di + 2] = Math.round(b / a); dst.data[di + 3] = a / n >= 128 ? 255 : 0;
      }
    }
  }
  console.log(`downscale (${method}): ${width}×${height} → ${dstW}×${dstH}`);
  return dst;
}

function despeckle(img: Img, minSize: number): void {
  const { width, height, data } = img;
  const label = new Int32Array(width * height).fill(-1);
  let cleared = 0;
  for (let p0 = 0; p0 < width * height; p0++) {
    if (label[p0] !== -1 || data[p0 * 4 + 3] === 0) continue;
    const stack = [p0], members = [p0];
    label[p0] = p0;
    while (stack.length > 0) {
      const p = stack.pop()!;
      const x = p % width, y = (p - x) / width;
      for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]] as const) {
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        const np = ny * width + nx;
        if (label[np] === -1 && data[np * 4 + 3] > 0) { label[np] = p0; stack.push(np); members.push(np); }
      }
    }
    if (members.length < minSize) { for (const p of members) data[p * 4 + 3] = 0; cleared += members.length; }
  }
  console.log(`despeckle: cleared ${cleared} px in islands < ${minSize}`);
}

/** Draw a 1px dark rim on transparent pixels 4-adjacent to opaque ones. */
function outline(img: Img): void {
  const { width, height, data } = img;
  const rim: number[] = [];
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const p = y * width + x;
    if (data[p * 4 + 3] > 0) continue;
    for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]] as const) {
      if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
      if (data[(ny * width + nx) * 4 + 3] > 0) { rim.push(p); break; }
    }
  }
  for (const p of rim) {
    data[p * 4] = 18; data[p * 4 + 1] = 18; data[p * 4 + 2] = 24; data[p * 4 + 3] = 255;
  }
  console.log(`outline: rimmed ${rim.length} px`);
}

/** Linear contrast on opaque pixels: factor derived from amount (0-50 sane). */
function contrast(img: Img, amount: number): void {
  const f = (259 * (amount + 255)) / (255 * (259 - amount));
  const { data } = img;
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    for (let c = 0; c < 3; c++) {
      data[i + c] = Math.max(0, Math.min(255, Math.round(f * (data[i + c] - 128) + 128)));
    }
  }
  console.log(`contrast: +${amount}`);
}

function pad(img: Img, w: number, h: number): Img {
  if (img.width > w || img.height > h) {
    console.error(`pad: content ${img.width}×${img.height} exceeds canvas ${w}×${h}`); process.exit(1);
  }
  const dst = newImg(w, h);
  PNG.bitblt(img, dst, 0, 0, img.width, img.height, Math.floor((w - img.width) / 2), Math.floor((h - img.height) / 2));
  console.log(`pad: centered on ${w}×${h}`);
  return dst;
}

let img: Img = PNG.sync.read(fs.readFileSync(inPath));
console.log(`in: ${path.relative(process.cwd(), inPath)} (${img.width}×${img.height})`);
if (removeBg) floodRemoveBg(img, bgTol);
if (cropArg) img = cropBox(img, cropArg);
else if (doTrim) img = trim(img);
if (sizeArg) {
  const { w, h } = parseWxH(sizeArg);
  const scale = Math.min(w / img.width, h / img.height);
  img = downscale(img, Math.max(1, Math.round(img.width * scale)), Math.max(1, Math.round(img.height * scale)));
} else if (scaleArg && scaleArg > 1) {
  img = downscale(img, Math.max(1, Math.round(img.width / scaleArg)), Math.max(1, Math.round(img.height / scaleArg)));
}
if (doDespeckle) despeckle(img, despeckleMin);
if (padArg) { const { w, h } = parseWxH(padArg); img = pad(img, w, h); }
// contrast/outline run after pad so the rim has canvas margin to land on
if (contrastArg > 0) contrast(img, contrastArg);
if (doOutline) outline(img);
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, PNG.sync.write(img));
console.log(`out: ${path.relative(process.cwd(), outPath)} (${img.width}×${img.height})`);
