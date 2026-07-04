#!/usr/bin/env bash
# Fast tileset iteration WITHOUT a docker image rebuild:
#   1. copy tileset/epoch/web/* + the repo's img-extract.py into the running container
#   2. re-run the extractor there against the freeciv data dir
#   3. deploy the regenerated amplio2 atlas + tileset_spec_amplio2.js into both
#      served webapp dirs
# Then HARD-REFRESH the browser (atlas filename is stable; bypass cache).
#
# The permanent path is the image build: install.sh overlays tileset/epoch/web/
# into data/amplio2/ before sync-js-hand.sh runs (same inputs, same result).
set -e
export MSYS_NO_PATHCONV=1

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# docker cp on Windows/git-bash needs mixed-style host paths (C:/...)
if command -v cygpath >/dev/null 2>&1; then REPO="$(cygpath -m "${REPO}")"; fi
C=freeciv-web
DATA=/docker/freeciv/freeciv/data

echo "==> syncing epoch sheets/specs + img-extract into ${C}..."
for f in "${REPO}"/tileset/epoch/web/epoch_*.spec "${REPO}"/tileset/epoch/web/epoch_*.png; do
  docker cp "$f" "${C}:${DATA}/amplio2/$(basename "$f")"
done
docker cp "${REPO}/scripts/freeciv-img-extract/img-extract.py" "${C}:/tmp/img-extract.py"

echo "==> running img-extract in the container..."
docker exec -u root "${C}" sh -c '
  rm -rf /tmp/ts-out && mkdir -p /tmp/ts-out &&
  python3 /tmp/img-extract.py -f /docker/freeciv/freeciv -o /tmp/ts-out >/tmp/ts-out/extract.log 2>&1 ||
    { tail -20 /tmp/ts-out/extract.log; exit 1; }
  ls /tmp/ts-out/freeciv-web-tileset-amplio2-*.png
'

# tileset_config_amplio2.js ships tileset_image_count=4 (epoch sheets pushed
# packing onto a 4th page). If this drifts again, update the config to match.
EXPECTED_PAGES=4
PAGES=$(docker exec -u root "${C}" sh -c 'ls /tmp/ts-out/freeciv-web-tileset-amplio2-*.png | wc -l')
echo "==> amplio2 atlas pages: ${PAGES} (expected ${EXPECTED_PAGES})"
if [ "${PAGES}" != "${EXPECTED_PAGES}" ]; then
  echo "!!  page count changed — update tileset_image_count in"
  echo "!!  freeciv-web/src/main/webapp/javascript/2dcanvas/tileset_config_amplio2.js"
  echo "!!  and EXPECTED_PAGES in this script."
fi

echo "==> deploying atlas + spec + config + client js into both served webapp dirs..."
docker cp "${REPO}/freeciv-web/src/main/webapp/javascript/2dcanvas/tileset_config_amplio2.js" \
  "${C}:/tmp/ts-out/tileset_config_amplio2.js"
# our fork's 2dcanvas client changes (idle-frame cycling + oversized-cell centering)
docker cp "${REPO}/freeciv-web/src/main/webapp/javascript/2dcanvas/tilespec.js" \
  "${C}:/tmp/ts-out/tilespec.js"
docker exec -u root "${C}" sh -c '
  for d in /docker/freeciv-web/src/derived/webapp /docker/freeciv-web/target/freeciv-web; do
    cp /tmp/ts-out/freeciv-web-tileset-amplio2-*.png "${d}/tileset/" &&
    cp /tmp/ts-out/tileset_spec_amplio2.js "${d}/javascript/2dcanvas/" &&
    echo "  deployed -> ${d}"
  done
  # config + client js live in the non-derived webapp javascript dir
  for d in /docker/freeciv-web/src/main/webapp /docker/freeciv-web/target/freeciv-web; do
    [ -d "${d}/javascript/2dcanvas" ] &&
      cp /tmp/ts-out/tileset_config_amplio2.js "${d}/javascript/2dcanvas/" &&
      cp /tmp/ts-out/tilespec.js "${d}/javascript/2dcanvas/" &&
      echo "  config+js -> ${d}"
  done
'

echo "==> verifying epoch tags present in served spec..."
docker exec -u root "${C}" sh -c \
  'grep -oE "\"(u\.undersea_worker[^\"]*|u\.weapon_platform[^\"]*|b\.world_tree_spire)\":\[[0-9,]+\]" \
   /docker/freeciv-web/target/freeciv-web/javascript/2dcanvas/tileset_spec_amplio2.js' || {
  echo "!!  epoch tags NOT found in regenerated spec"; exit 1; }

echo "==> done. Hard-refresh the browser (Ctrl+Shift+R) to load the new atlas."
