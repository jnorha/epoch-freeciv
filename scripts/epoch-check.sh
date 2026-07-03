#!/usr/bin/env bash
# Epoch ruleset dev-iteration one-liner: sync the repo's data/epoch into the
# running container, then run fast load validation, then the headless autogame
# smoke test. Use this after editing anything in data/epoch/ to verify the
# change without a 20-minute image rebuild.
#
# Usage: ./scripts/epoch-check.sh [container_name]
#
# Layered on purpose: validation (seconds, load-only) fails fast on broken
# ruleset data before the heavier smoke test (runs actual turns) even starts.

set -e
export MSYS_NO_PATHCONV=1
CONTAINER="${1:-freeciv-web}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# On Git Bash/MSYS, docker is a native Windows binary and doesn't understand
# /c/... paths -- convert to a native C:/... path. No-op on Linux (no cygpath).
if command -v cygpath >/dev/null 2>&1; then REPO_ROOT="$(cygpath -m "${REPO_ROOT}")"; fi

echo "==> Syncing data/epoch into ${CONTAINER}..."
docker cp "${REPO_ROOT}/data/epoch/." "${CONTAINER}:/home/docker/freeciv/share/freeciv/epoch/"

echo "==> Validating ruleset load..."
"${REPO_ROOT}/scripts/epoch-validate-ruleset.sh" "${CONTAINER}"

echo "==> Running headless autogame smoke test..."
"${REPO_ROOT}/scripts/epoch-smoke-test.sh" "${CONTAINER}"

echo "==> All checks passed."
