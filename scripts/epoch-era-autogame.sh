#!/usr/bin/env bash
# Epoch era-pacing autogame (Slice 4 verification). Boots the epoch ruleset,
# runs a long all-AI game, and extracts every [EPOCH][era_transition] telemetry
# line to measure when each of the five ages is first entered and how many turns
# each age spans. This is the "monotonic I->V transition + cost_pct pacing" test.
#
# sciencebox compresses the whole research timeline uniformly (scales all tech
# costs equally) so all 5 ages appear within a practical turn budget WITHOUT
# distorting the RELATIVE era spans the cost_pct classes are tuning. Raise TURNS
# / lower SCIENCEBOX to push further into the endgame.
#
# Usage: ./scripts/epoch-era-autogame.sh [container] [turns] [sciencebox] [aifill]
set -e
export MSYS_NO_PATHCONV=1
CONTAINER="${1:-freeciv-web}"
TURNS="${2:-250}"
SCIENCEBOX="${3:-40}"
AIFILL="${4:-6}"

docker exec -u docker "${CONTAINER}" sh -c "
cat > /tmp/epoch-era.serv <<EOF
rulesetdir epoch
set aifill ${AIFILL}
set topology \"\"
set wrap WRAPX
set nationset all
set generator FAIR
set size 6
set sciencebox ${SCIENCEBOX}
set autotoggle enabled
set timeout -1
set endt ${TURNS}
set minp 0
set gameseed 42
set mapseed 42
start
EOF
timeout 1500 \${HOME}/freeciv/bin/freeciv-web --Announce none --exit-on-end \
  --read /tmp/epoch-era.serv --saves /tmp --scenarios /tmp \
  > /tmp/epoch-era.out 2>&1 || true
"

OUT=$(docker exec "${CONTAINER}" sh -c 'cat /tmp/epoch-era.out')

# Guardrails: clean load + no Lua errors.
echo "${OUT}" | grep -q 'Ruleset directory set to "epoch"' || { echo "FAIL: ruleset did not load"; echo "${OUT}" | tail -20; exit 1; }
echo "${OUT}" | grep -aiE 'lua error|error in script|traceback' && { echo "FAIL: Lua errors present"; exit 1; } || true

echo "=== era_transition telemetry ==="
echo "${OUT}" | grep -a 'era_transition' | grep -av 'trigger=rescan' || echo "(none captured)"

echo ""
echo "=== per-age FIRST-ENTRY turn (earliest across all players) ==="
echo "${OUT}" | grep -a 'era_transition' | awk '
{
  to=""; turn=""; era="";
  for (i=1;i<=NF;i++){
    if ($i ~ /^to=/){ split($i,a,"="); to=a[2] }
    if ($i ~ /^turn=/){ split($i,a,"="); turn=a[2] }
    if ($i ~ /^\(/){ era=$i; gsub(/[()]/,"",era) }
  }
  if (to!="" && turn!=""){ if (first[to]=="" || turn+0 < first[to]+0){ first[to]=turn; name[to]=era } }
}
END{
  for (age=2; age<=5; age++){
    if (first[age]!="") printf "  Age %d (%-7s): first entered turn %s\n", age, name[age], first[age];
    else                printf "  Age %d: NOT REACHED in %s turns\n", age, "'"${TURNS}"'";
  }
  printf "\nSpans (earliest-entry deltas; Age I starts turn 1):\n";
  prev=1; pname="ember";
  for (age=2; age<=5; age++){
    if (first[age]!=""){ printf "  %-7s -> %-7s : %d turns\n", pname, name[age], first[age]-prev; prev=first[age]; pname=name[age] }
  }
}'
echo ""
echo "=== research pace: last turn reached ==="
echo "${OUT}" | grep -a 'turn_begin fired' | tail -1
