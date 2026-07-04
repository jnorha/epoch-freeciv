/**
 * Shared I/O helpers for the Epoch art-gen scripts.
 */
import fs from "fs";
import path from "path";

/** Create all directories in the path if they don't exist. */
export function ensureDir(dir: string): void {
  fs.mkdirSync(dir, { recursive: true });
}

/** Write a buffer to disk, creating parent dirs as needed. */
export function writeFile(filePath: string, buf: Buffer): void {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, buf);
}

/** Download a URL to a file on disk (native fetch, Node 18+). */
export async function downloadToFile(url: string, filePath: string): Promise<void> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Download failed ${res.status}: ${url}`);
  const buf = Buffer.from(await res.arrayBuffer());
  writeFile(filePath, buf);
}
