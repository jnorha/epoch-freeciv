/**
 * Epoch art generator — fal.ai backends.
 *
 * BACKENDS
 *   --model nano-banana-2  Google Nano Banana 2 (default; ~$0.08/image, best prompt
 *                          adherence + honours --anchor system prompt). Use for sprites.
 *   --model flux           Flux.1-schnell (~$0.003/image, Apache-2.0). Use for cheap
 *                          concept/establishing art.
 *
 * MODES
 *   Catalog:   npm run gen -- --asset undersea_worker
 *   Raw:       npm run gen -- --prompt "..." --out ../../tileset/epoch/src/x.png
 *
 * ANCHORS (NB2 system prompt — shapes the whole render)
 *   --anchor unit       single game unit, 3/4 top-down, flat background (for keying)
 *   --anchor building   single structure/wonder, isometric, flat background
 *   --anchor tile       seamless top-down terrain texture
 *   --anchor concept    cinematic establishing art (default when not a sprite asset)
 *
 * FLAGS
 *   --size <preset|WxH|ratio>  Flux image_size preset / NB2 aspect ratio (default per anchor)
 *   --resolution <0.5K|1K|2K|4K>  NB2 output resolution (default 2K for sprites)
 *   --thinking <minimal|high>  NB2 reasoning (default high)
 *   --num N   --seed N   --out <path>
 *
 * IP: Flux.1-schnell is Apache-2.0. Nano Banana 2 outputs are owned by the user per fal.ai TOS.
 */
import path from "path";
import fs from "fs";
import { fal } from "@fal-ai/client";
import { downloadToFile } from "./lib/io.js";

// ---------------------------------------------------------------------------
// System anchors — the house style. Keep sprite backgrounds FLAT so the
// process_sprite flood-fill can key them out cleanly.
// ---------------------------------------------------------------------------

const ANCHOR = {
  unit:
    "You generate a single game-unit sprite for a sci-fi 4X strategy game in the spirit of " +
    "Call to Power 2: one subject only, centered, full body, three-quarter top-down view, " +
    "clean readable silhouette, crisp detailed painterly game-art rendering, dramatic but even " +
    "lighting. Place it on a COMPLETELY FLAT solid pale-grey background with NO scenery, NO " +
    "ground plane, NO cast shadow, NO gradient. No text, no watermark, no border, no frame.",
  building:
    "You generate a single building/wonder sprite for a sci-fi 4X strategy game in the spirit " +
    "of Call to Power 2: one structure only, centered, isometric three-quarter view, detailed " +
    "painterly game-art rendering, solarpunk retrofuturism. Place it on a COMPLETELY FLAT solid " +
    "pale-grey background with NO scenery, NO ground, NO cast shadow, NO gradient. No text, no " +
    "watermark, no border.",
  tile:
    "You generate a seamless top-down terrain tile texture for a 4X strategy game map: flat " +
    "overhead orthographic view, even lighting, tileable, no perspective, no objects casting " +
    "long shadows, no text, no border.",
  concept:
    "Solarpunk far-future concept art for a 4X strategy game, painterly detailed cinematic " +
    "digital illustration, optimistic retrofuturism, cohesive key art.",
} as const;
type AnchorName = keyof typeof ANCHOR;

// ---------------------------------------------------------------------------
// Catalog — reproducible named assets. subject is appended to the anchor.
// outDir is relative to this script dir.
// ---------------------------------------------------------------------------

interface Asset {
  anchor: AnchorName;
  subject: string;
  outDir: string;
  aspect?: string; // NB2 aspect / Flux size; default per anchor
}

const CATALOG: Record<string, Asset> = {
  // --- Diamond-age units ---
  undersea_worker: {
    anchor: "unit",
    subject:
      "an ocean-native engineering submersible unit, a compact rounded bio-mechanical diving " +
      "rig with manipulator arms and kelp-cultivation tools, teal and brass plating, glowing " +
      "portholes",
    outDir: "../../tileset/epoch/src/units",
  },
  abyssal_founder: {
    anchor: "unit",
    subject:
      "an undersea colony-founding submarine, a bulbous pressurised vessel carrying a folded " +
      "biosphere-dome kit, teal and pale-clay hull, warm interior lights",
    outDir: "../../tileset/epoch/src/units",
  },
  weapon_platform: {
    anchor: "unit",
    subject:
      "a hovering orbital weapon platform, a sleek angular drone with railgun batteries and " +
      "solar fins, charcoal and amber, faint energy glow, no pilot",
    outDir: "../../tileset/epoch/src/units",
  },
  cyborg_infantry: {
    anchor: "unit",
    subject:
      "a single cyborg infantry soldier, augmented human in teal-steel powered armor with " +
      "glowing amber cybernetic lines, compact rifle, bold chunky silhouette",
    outDir: "../../tileset/epoch/src/units",
  },
  chimera_soldier: {
    anchor: "unit",
    subject:
      "a single bio-engineered chimera soldier, organic bone-and-sinew armor in moss green " +
      "and ivory, one clawed arm and one bio-rifle, feral crouched stance, bold silhouette",
    outDir: "../../tileset/epoch/src/units",
  },
  combat_drone: {
    anchor: "unit",
    subject:
      "a small hovering quad-rotor combat drone gunship, gunmetal grey with a single red " +
      "sensor eye and underslung cannon, compact chunky silhouette",
    outDir: "../../tileset/epoch/src/units",
  },
  pressure_sub: {
    anchor: "unit",
    subject:
      "a deep-pressure attack submarine, dark teal angular reinforced hull, glowing cyan " +
      "intake vents and torpedo tubes, predatory silhouette",
    outDir: "../../tileset/epoch/src/units",
  },
  war_walker: {
    anchor: "unit",
    subject:
      "a heavy bipedal war-walker mech, charcoal and amber plating, shoulder missile racks " +
      "and twin arm cannons, wide stomping stance, very chunky readable silhouette",
    outDir: "../../tileset/epoch/src/units",
  },
  plasma_trooper: {
    anchor: "unit",
    subject:
      "a single heavy plasma trooper, bulky sealed armor in slate blue with white-hot plasma " +
      "rifle and glowing blue energy cells, bold chunky silhouette",
    outDir: "../../tileset/epoch/src/units",
  },
  synthetic_legion: {
    anchor: "unit",
    subject:
      "a humanoid synthetic legionnaire robot soldier, chrome-white armored chassis with cyan " +
      "glowing joints and faceplate, tall halberd-like energy weapon, clean bold silhouette",
    outDir: "../../tileset/epoch/src/units",
  },
  plasma_cruiser: {
    anchor: "unit",
    subject:
      "a sleek naval plasma cruiser warship, long dark hull with twin glowing blue plasma " +
      "lance turrets and fin arrays, wake at the bow, bold silhouette",
    outDir: "../../tileset/epoch/src/units",
  },
  space_plane: {
    anchor: "unit",
    subject:
      "a sleek orbital spaceplane, white and amber delta-wing craft with glowing engine " +
      "trail, banking slightly, elegant bold silhouette",
    outDir: "../../tileset/epoch/src/units",
  },
  orbital_interceptor: {
    anchor: "unit",
    subject:
      "an angular orbital interceptor fighter, dark gunmetal with crimson accents and " +
      "forward-swept wings, twin railguns, aggressive bold silhouette",
    outDir: "../../tileset/epoch/src/units",
  },
  // --- Diamond-age buildings/wonders ---
  abyssal_foundry: {
    anchor: "building",
    subject:
      "a seafloor fusion foundry building, domed industrial structure with glowing intake " +
      "vents and pipework, teal and gunmetal, warm forge light",
    outDir: "../../tileset/epoch/src/buildings",
  },
  world_tree_spire: {
    anchor: "building",
    subject:
      "a colossal living-megatree arcology wonder, a single kilometres-tall tree whose canopy " +
      "holds glass habitats and hanging gardens, warm golden light",
    outDir: "../../tileset/epoch/src/buildings",
    aspect: "3:4",
  },
};

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);
const flag = (n: string) => args.includes(`--${n}`);
const arg = (n: string) => {
  const i = args.indexOf(`--${n}`);
  return i !== -1 ? args[i + 1] : undefined;
};

const assetId = arg("asset");
const rawPrompt = arg("prompt");
const imgArg = arg("img"); // NB2 edit mode: reference image whose content is preserved
const rawOut = arg("out");
const modelArg = (arg("model") ?? "nano-banana-2").toLowerCase();
const anchorArg = arg("anchor") as AnchorName | undefined;
const sizeArg = arg("size");
const seedArg = arg("seed") ? Number(arg("seed")) : undefined;
const numArg = arg("num") ? Number(arg("num")) : 1;
const resolutionArg = (arg("resolution") ?? "2K") as "0.5K" | "1K" | "2K" | "4K";
const thinkingArg = (arg("thinking") ?? "high") as "minimal" | "high";

const scriptDir = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"));

function initFal(): void {
  const key = process.env.FAL_KEY;
  if (!key) throw new Error("FAL_KEY not set — add it to tools/art/.env");
  fal.config({ credentials: key });
}

const SIZE_TO_ASPECT: Record<string, string> = {
  square_hd: "1:1", square: "1:1", portrait_4_3: "3:4", portrait_16_9: "9:16",
  landscape_4_3: "4:3", landscape_16_9: "16:9",
};
function toAspect(s: string): string {
  if (/^\d+:\d+$/.test(s)) return s;
  if (/^\d+x\d+$/.test(s)) { const [w, h] = s.split("x").map(Number); return `${w}:${h}`; }
  return SIZE_TO_ASPECT[s] ?? "1:1";
}
function toFluxSize(s: string): unknown {
  if (/^\d+x\d+$/.test(s)) { const [w, h] = s.split("x").map(Number); return { width: w, height: h }; }
  return s;
}

async function uploadLocalImage(filePath: string): Promise<string> {
  const abs = path.isAbsolute(filePath) ? filePath : path.join(process.cwd(), filePath);
  const buf = fs.readFileSync(abs);
  const blob = new Blob([buf], { type: "image/png" });
  return await fal.storage.upload(blob as File);
}

/** NB2 edit: keep the reference image's content, apply only the prompted change.
 *  Used for animation frames ("identical sprite, only the lights differ"). */
async function genNB2Edit(prompt: string, imgPath: string, out: string): Promise<void> {
  console.log(`Nano Banana 2 EDIT (${path.basename(imgPath)}): ${prompt.slice(0, 80)}…`);
  const url = await uploadLocalImage(imgPath);
  const result = (await fal.subscribe("fal-ai/nano-banana-2/edit", {
    input: {
      prompt, image_urls: [url], resolution: resolutionArg, num_images: numArg,
      thinking_level: thinkingArg, safety_tolerance: "6",
      ...(seedArg !== undefined && { seed: seedArg }),
    },
    logs: false,
  })) as { data: { images: { url: string; width: number; height: number }[] } };
  await writeAll(result.data.images, out);
}

async function genNB2(prompt: string, system: string, aspect: string, out: string): Promise<void> {
  console.log(`Nano Banana 2: ${prompt.slice(0, 90)}…`);
  console.log(`  aspect ${aspect} | ${resolutionArg} | thinking ${thinkingArg} | num ${numArg}${seedArg !== undefined ? ` | seed ${seedArg}` : ""}`);
  const result = (await fal.subscribe("fal-ai/nano-banana-2", {
    input: {
      prompt, aspect_ratio: aspect, resolution: resolutionArg, num_images: numArg,
      thinking_level: thinkingArg, safety_tolerance: "6",
      ...(seedArg !== undefined && { seed: seedArg }),
      ...({ system_prompt: system } as Record<string, unknown>),
    },
    logs: false,
  })) as { data: { images: { url: string; width: number; height: number }[] } };
  await writeAll(result.data.images, out);
}

async function genFlux(prompt: string, size: string, out: string): Promise<void> {
  console.log(`Flux.1-schnell: ${prompt.slice(0, 90)}…`);
  const result = (await fal.subscribe("fal-ai/flux/schnell", {
    input: {
      prompt, image_size: toFluxSize(size), num_images: numArg, num_inference_steps: 4,
      ...(seedArg !== undefined && { seed: seedArg }), enable_safety_checker: false,
    },
    logs: false,
  })) as { data: { images: { url: string; width: number; height: number }[]; seed: number } };
  console.log(`  seed ${result.data.seed}`);
  await writeAll(result.data.images, out);
}

async function writeAll(images: { url: string; width: number; height: number }[], out: string): Promise<void> {
  for (let i = 0; i < images.length; i++) {
    const fp = images.length > 1 ? out.replace(/\.png$/, `_${i}.png`) : out;
    await downloadToFile(images[i].url, fp);
    console.log(`  Wrote: ${fp} (${images[i].width}×${images[i].height})`);
  }
}

async function main(): Promise<void> {
  initFal();
  let prompt: string, system: string, out: string, defaultSize: string;

  if (assetId) {
    const a = CATALOG[assetId];
    if (!a) { console.error(`Unknown asset "${assetId}". Known: ${Object.keys(CATALOG).join(", ")}`); process.exit(1); }
    system = ANCHOR[a.anchor];
    prompt = a.subject;
    defaultSize = a.aspect ?? (a.anchor === "concept" ? "landscape_16_9" : "1:1");
    const dir = path.isAbsolute(a.outDir) ? a.outDir : path.join(scriptDir, a.outDir);
    out = rawOut ? (path.isAbsolute(rawOut) ? rawOut : path.join(process.cwd(), rawOut))
                 : path.join(dir, `${assetId}_nb2.png`);
  } else if (rawPrompt) {
    if (!rawOut) { console.error("--out <path> required in raw mode"); process.exit(1); }
    const anchor = anchorArg ?? "concept";
    system = ANCHOR[anchor];
    // In concept/raw mode the anchor is prepended to the prompt (Flux has no system
    // prompt). Edit mode (--img) sends the prompt untouched — the instruction IS the edit.
    prompt = imgArg ? rawPrompt!
      : anchor === "concept" ? `${ANCHOR.concept} ${rawPrompt}` : rawPrompt!;
    defaultSize = anchor === "concept" ? "landscape_16_9" : "1:1";
    out = path.isAbsolute(rawOut) ? rawOut : path.join(process.cwd(), rawOut);
  } else {
    console.error("Usage:\n  npm run gen -- --asset <id> [--model flux]\n  npm run gen -- --prompt \"...\" --anchor <unit|building|tile|concept> --out <path>");
    process.exit(1);
  }

  fs.mkdirSync(path.dirname(out), { recursive: true });
  const size = sizeArg ?? defaultSize;
  if (imgArg) await genNB2Edit(prompt, imgArg, out);
  else if (modelArg === "nano-banana-2") await genNB2(prompt, system, toAspect(size), out);
  else await genFlux(prompt, size, out);
}

main().catch((e) => { console.error(e instanceof Error ? e.message : e); process.exit(1); });
