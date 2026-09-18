#!/usr/bin/env bash
# Exits non zero if the live trees (what the game reads) have drifted from
# src/ (the single source). Run after tools/sync.sh, and in CI/review.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

diff -rq "src/lua/client/WeightScale" "media/lua/client/WeightScale" || fail=1
diff -rq "src/lua/client/WeightScale" "42/media/lua/client/WeightScale" || fail=1
diff -rq "src/textures" "media/textures/WeightScale" || fail=1
diff -rq "src/textures" "common/media/textures/WeightScale" || fail=1

if [ "$fail" -ne 0 ]; then
    echo "DRIFT: live trees do not match src/. Run tools/sync.sh." >&2
    exit 1
fi
echo "check-sync: OK, no drift."
