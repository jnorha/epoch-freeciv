#!/usr/bin/env bash
# Seed the epoch ruleset from civ2civ3 base.
# Run AFTER prepare_freeciv.sh has downloaded and compiled the freeciv C server.
# Usage: ./scripts/epoch-seed-ruleset.sh [--force]
#
# Only copies files that don't already exist in data/epoch/ (safe to re-run),
# unless --force is passed (overwrites everything).

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FREECIV_DATA="${HOME}/freeciv/share/freeciv"
SRC="${FREECIV_DATA}/civ2civ3"
DST="${DIR}/data/epoch"

if [ ! -d "${SRC}" ]; then
  echo "Error: civ2civ3 ruleset not found at ${SRC}" >&2
  echo "Run prepare_freeciv.sh and 'ninja install' first." >&2
  exit 1
fi

FORCE=0
if [ "$1" = "--force" ]; then FORCE=1; fi

echo "Seeding epoch ruleset from civ2civ3..."
for f in "${SRC}"/*.ruleset "${SRC}"/*.serv; do
  base=$(basename "$f")
  target="${DST}/${base}"
  if [ "${FORCE}" = "1" ] || [ ! -f "${target}" ]; then
    # Rename civ2civ3 references in server files
    sed "s/civ2civ3/epoch/g" "$f" > "${target}"
    echo "  wrote ${base}"
  else
    echo "  skip  ${base} (already exists; use --force to overwrite)"
  fi
done

# Copy nations directory if present
if [ -d "${SRC}/nations" ]; then
  if [ "${FORCE}" = "1" ] || [ ! -d "${DST}/nations" ]; then
    cp -r "${SRC}/nations" "${DST}/nations"
    echo "  wrote nations/"
  else
    echo "  skip  nations/ (already exists)"
  fi
fi

echo ""
echo "Done. Now edit data/epoch/*.ruleset to add Epoch-specific content."
echo "Our Lua systems are in data/epoch/script.lua (already present)."
