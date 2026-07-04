#!/usr/bin/env python3
"""
Dev-preview: blit a processed sprite into the DEPLOYED freeciv-web atlas at an
existing tag's cell, so you can eyeball it in the running game without a rebuild.

    EPHEMERAL + PREVIEW ONLY. Any img-extract / webapp rebuild wipes it, and it
    overwrites the vanilla sprite that owns the cell. The shipping path is a
    repo-tracked custom tileset — see doc/design/tileset-integration.md §3(B).

Runs INSIDE the freeciv-web container (needs PIL + the deployed webapp):
    docker cp tileset/epoch/src/units/undersea_worker.png freeciv-web:/tmp/s.png
    docker cp tools/art/inject_dev_sprite.py freeciv-web:/tmp/inject.py
    docker exec -u root freeciv-web python3 /tmp/inject.py --tag u.engineers_Idle --sprite /tmp/s.png

Then hard-refresh the game (the atlas filename is stable, so bypass the cache).
"""
import argparse
import json
import os
import re
from PIL import Image

DERIVED = "/docker/freeciv-web/src/derived/webapp"
TARGET = "/docker/freeciv-web/target/freeciv-web"
TILESET = "amplio2"


def load_spec():
    spec = f"{DERIVED}/javascript/2dcanvas/tileset_spec_{TILESET}.js"
    obj = re.search(r"var tileset\s*=\s*(\{.*?\});", open(spec).read(), re.S).group(1)
    return json.loads(obj)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", required=True, help="existing tileset tag to overwrite, e.g. u.engineers_Idle")
    ap.add_argument("--sprite", required=True, help="processed transparent PNG to inject")
    args = ap.parse_args()

    coords = load_spec().get(args.tag)
    if not coords:
        raise SystemExit(f"tag {args.tag!r} not found in tileset_spec_{TILESET}.js")
    x, y, w, h, page = coords

    spr = Image.open(args.sprite).convert("RGBA")
    r = min(w / spr.width, h / spr.height)
    nw, nh = max(1, round(spr.width * r)), max(1, round(spr.height * r))
    spr = spr.resize((nw, nh), Image.LANCZOS)
    ox, oy = x + (w - nw) // 2, y + (h - nh) // 2

    for root in (DERIVED, TARGET):
        p = f"{root}/tileset/freeciv-web-tileset-{TILESET}-{page}.png"
        if not os.path.exists(p):
            print("skip (missing):", p)
            continue
        atlas = Image.open(p).convert("RGBA")
        atlas.paste((0, 0, 0, 0), (x, y, x + w, y + h))  # clear cell
        atlas.alpha_composite(spr, (ox, oy))
        atlas.save(p)
        print(f"patched {p}  cell=({x},{y},{w},{h}) sprite={nw}x{nh}")

    print("done — hard-refresh the game to see it.")


if __name__ == "__main__":
    main()
