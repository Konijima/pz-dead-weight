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
diff -rq "src/sounds" "media/sound/WeightScale" || fail=1
diff -rq "src/sounds" "common/media/sound/WeightScale" || fail=1

diff -q "src/sandbox-options.txt" "media/sandbox-options.txt" || fail=1
diff -q "src/sandbox-options.txt" "common/media/sandbox-options.txt" || fail=1

# Translations are generated (src/translate/strings.json -> B41 .txt, B42
# .json, see tools/gen-translate.py), so regenerate into a temp tree and
# diff that against what is committed rather than comparing to a src/ copy.
TR_TMP="$(mktemp -d)"
trap 'rm -rf "$TR_TMP"' EXIT
python3 tools/gen-translate.py "$TR_TMP"
diff -rq "$TR_TMP/media/lua/shared/Translate" "media/lua/shared/Translate" || fail=1
diff -rq "$TR_TMP/42/media/lua/shared/Translate" "42/media/lua/shared/Translate" || fail=1

# media/scripts and common/media/scripts also hold a .gitkeep (and, on
# common/, other mods' nothing -- this mod owns only its own file), so these
# two are compared file by file rather than whole-directory.
for f in src/scripts/*.txt; do
    name="$(basename "$f")"
    diff -q "$f" "media/scripts/$name" || fail=1
    diff -q "$f" "common/media/scripts/$name" || fail=1
done

if [ "$fail" -ne 0 ]; then
    echo "DRIFT: live trees do not match src/. Run tools/sync.sh." >&2
    exit 1
fi
echo "check-sync: OK, no drift."
