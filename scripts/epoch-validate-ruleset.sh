#!/usr/bin/env bash
# Fast ruleset-load validation for the epoch ruleset.
# Loads the ruleset in a headless server and quits immediately -- no game turns,
# so it's much faster than the full smoke test. Catches broken requirements,
# dangling references, parse errors, etc. at load time.
#
# IMPORTANT: freeciv exits 0 even when a ruleset FAILS to load -- it silently
# falls back to the classic ruleset and keeps running. So we must inspect the
# server output, never trust the exit code. This script keys on:
#   PASS  -> output contains 'Ruleset directory set to "epoch"'
#   FAIL  -> output contains 'Failed loading rulesets' (server fell back to classic)
#
# Usage: ./scripts/epoch-validate-ruleset.sh [container_name]
#   Validates the epoch ruleset currently present in the container at
#   ~/freeciv/share/freeciv/epoch. Use scripts/epoch-check.sh to sync the repo
#   copy in first.

set -e
export MSYS_NO_PATHCONV=1
CONTAINER="${1:-freeciv-web}"

docker exec -u docker "${CONTAINER}" sh -c '
printf "rulesetdir epoch\nquit\n" > /tmp/epoch-validate.serv
timeout 60 ${HOME}/freeciv/bin/freeciv-web --Announce none --read /tmp/epoch-validate.serv \
  > /tmp/epoch-validate.out 2>&1 || true
'

OUT=$(docker exec "${CONTAINER}" sh -c 'cat /tmp/epoch-validate.out')

if echo "${OUT}" | grep -aq 'Failed loading rulesets'; then
  echo "RULESET VALIDATION FAILED — epoch ruleset did not load (server fell back to classic):"
  echo "${OUT}" | grep -aiE 'couldn.t match|couldn.t load|error|invalid|unknown|failed|bad ' | head -30
  exit 1
fi

if ! echo "${OUT}" | grep -aq 'Ruleset directory set to "epoch"'; then
  echo "RULESET VALIDATION FAILED — no confirmation the epoch ruleset loaded. Raw tail:"
  echo "${OUT}" | tail -30
  exit 1
fi

# Surface non-fatal ruleset warnings (do not fail on them for now).
WARNINGS=$(echo "${OUT}" | grep -aiE 'warning' | grep -aiv 'no warning' || true)
if [ -n "${WARNINGS}" ]; then
  echo "RULESET VALIDATION PASSED (with warnings):"
  echo "${WARNINGS}" | head -20
else
  echo "RULESET VALIDATION PASSED — epoch ruleset loads clean, no warnings."
fi
