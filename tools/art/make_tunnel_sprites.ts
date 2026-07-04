/**
 * Generate the Sea Tunnel directional road sprites programmatically:
 * 9 pieces (8 directions + isolated) at 96x48, drawn as a glowing cyan
 * pressurised tube from the tile center toward each neighbour.
 *
 * Geometry (iso 2:1 diamond, center 48,24): cardinal dirs end at the diamond
 * edge midpoints, diagonal dirs at the corners. Opposite pairs are point-
 * symmetric about the center, so neighbouring tiles' half-segments always meet.
 *
 * Usage: tsx make_tunnel_sprites.ts   (writes tileset/epoch/src/extras/sea_tunnel_*.png)
 */
import fs from "fs";
import path from "path";
import { PNG } from "pngjs";

const scriptDir = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"));
const outDir = path.join(scriptDir, "..", "..", "tileset", "epoch", "src", "extras");
fs.mkdirSync(outDir, { recursive: true });

const W = 96, H = 48, CX = 48, CY = 24;
const ENDS: Record<string, [number, number]> = {
  n: [72, 12], e: [72, 36], s: [24, 36], w: [24, 12],
  ne: [96, 24], se: [48, 48], sw: [0, 24], nw: [48, 0],
};

// tube layers: [maxDist, r, g, b]
const LAYERS: [number, number, number, number][] = [
  [5.5, 16, 42, 52],    // dark casing
  [3.2, 0, 190, 230],   // cyan glow
  [1.4, 190, 255, 255], // hot core
];

function segDist(px: number, py: number, x1: number, y1: number, x2: number, y2: number): number {
  const dx = x2 - x1, dy = y2 - y1;
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / len2));
  const qx = x1 + t * dx, qy = y1 + t * dy;
  return Math.hypot(px - qx, py - qy);
}

function paint(img: InstanceType<typeof PNG>, dist: (x: number, y: number) => number): void {
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const d = dist(x + 0.5, y + 0.5);
    const i = (y * W + x) * 4;
    let color: [number, number, number] | null = null;
    for (const [maxD, r, g, b] of LAYERS) if (d <= maxD) color = [r, g, b];
    if (color) {
      img.data[i] = color[0]; img.data[i + 1] = color[1]; img.data[i + 2] = color[2];
      img.data[i + 3] = 255;
    } else if (d <= 6.5 && img.data[i + 3] === 0) {
      // soft rim
      img.data[i] = 10; img.data[i + 1] = 28; img.data[i + 2] = 36; img.data[i + 3] = 130;
    }
  }
}

function newImg(): InstanceType<typeof PNG> {
  const p = new PNG({ width: W, height: H });
  p.data = Buffer.alloc(W * H * 4);
  return p;
}

for (const [dir, [ex, ey]] of Object.entries(ENDS)) {
  const img = newImg();
  paint(img, (x, y) => Math.min(segDist(x, y, CX, CY, ex, ey), Math.hypot(x - CX, y - CY) - 1.2));
  fs.writeFileSync(path.join(outDir, `sea_tunnel_${dir}.png`), PNG.sync.write(img));
  console.log(`sea_tunnel_${dir}.png`);
}

// isolated: hub only (slightly larger dome)
{
  const img = newImg();
  paint(img, (x, y) => Math.hypot(x - CX, y - CY) - 2.2);
  fs.writeFileSync(path.join(outDir, "sea_tunnel_isolated.png"), PNG.sync.write(img));
  console.log("sea_tunnel_isolated.png");
}
console.log(`wrote 9 sprites -> ${outDir}`);
