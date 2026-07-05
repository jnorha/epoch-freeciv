#!/usr/bin/env bash
# Headless autogame smoke test for the epoch ruleset.
# Runs a short all-AI game on the epoch ruleset inside the freeciv-web container
# and asserts: the ruleset loads, our script.lua runs, our turn hook fires every
# turn, and there are no Lua errors. This is the seed of the Phase 3 CI test.
#
# Usage: ./scripts/epoch-smoke-test.sh [container_name] [num_turns]
#   Assumes the epoch ruleset is present in the container at
#   ~/freeciv/share/freeciv/epoch (baked in at image build, or docker-cp'd for
#   a fast iteration loop).

set -e
# Prevent Git Bash / MSYS from rewriting /tmp/... container paths into Windows
# paths when this runs on a Windows dev box. Harmless on Linux.
export MSYS_NO_PATHCONV=1
CONTAINER="${1:-freeciv-web}"
TURNS="${2:-4}"

docker exec -u docker "${CONTAINER}" sh -c "
cat > /tmp/epoch-smoke.serv <<EOF
rulesetdir epoch
set aifill 4
set topology \"\"
set wrap WRAPX
set nationset all
set generator FAIR
set size 3
set autotoggle enabled
set timeout -1
set endt ${TURNS}
set minp 0
set gameseed 42
set mapseed 42
start
EOF
timeout 180 \${HOME}/freeciv/bin/freeciv-web --Announce none --exit-on-end \
  --read /tmp/epoch-smoke.serv --saves /tmp --scenarios /tmp \
  > /tmp/epoch-smoke.out 2>&1 || true
"

OUT=$(docker exec "${CONTAINER}" sh -c 'cat /tmp/epoch-smoke.out')

fail() { echo "SMOKE TEST FAILED: $1"; echo "--- output tail ---"; echo "${OUT}" | tail -30; exit 1; }

echo "${OUT}" | grep -q 'Ruleset directory set to "epoch"' || fail "epoch ruleset did not load"
echo "${OUT}" | grep -q '\[EPOCH\] Epoch ruleset script loaded' || fail "epoch script.lua did not run"
HOOKS=$(echo "${OUT}" | grep -c 'turn_begin fired' || true)
[ "${HOOKS}" -ge "${TURNS}" ] || fail "turn hook fired ${HOOKS} times, expected >= ${TURNS}"
echo "${OUT}" | grep -aiE 'lua error|error in script|traceback|fatal' && fail "Lua/fatal errors present" || true

echo "SMOKE TEST PASSED: epoch ruleset loads, script runs, turn hook fired ${HOOKS}x, no Lua errors."
