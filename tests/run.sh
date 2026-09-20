#!/usr/bin/env bash
# Bench: mapX contact points, bandOf inclusivity, one-decimal format, prefs
# parser robustness, the HUD's UI manager lifecycle, the context menu option,
# the Info tab weight-word patch, facing the scale's column on foot or by
# menu, and JS/Lua parity on the animation sampler.
# Fails loud (missing lua5.1/lua/node, missing anim.js) rather than skipping
# silently.
set -euo pipefail
cd "$(dirname "$0")/.."

LUA=""
if command -v lua5.1 >/dev/null 2>&1; then LUA="lua5.1"
elif command -v lua >/dev/null 2>&1; then LUA="lua"
else echo "FAIL: no lua5.1 or lua on PATH" >&2; exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    echo "FAIL: node is required for the JS/Lua parity check" >&2
    exit 1
fi
if [ ! -f "docs/maquettes/v2/js/anim.js" ]; then
    echo "FAIL: docs/maquettes/v2/js/anim.js is missing, cannot check parity" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "FAIL: python3 is required for the geo check" >&2
    exit 1
fi
echo "-- geo generator drift check --"
python3 tools/gen-geo.py --check

echo "-- mod.info guard (id/name match, poster/icon files exist, no U+2014) --"
python3 tests/modinfo_spec.py

echo "-- translation bench (both builds, both langs) --"
python3 tests/translate_spec.py

echo "-- workshop.txt generator drift check --"
python3 tests/workshop_gen_spec.py

echo "-- changelog bench (version match, Unreleased exists, Steam note) --"
python3 tests/changelog_spec.py

echo "-- lua core bench ($LUA) --"
"$LUA" tests/core_spec.lua

echo "-- lua hud lifecycle bench ($LUA) --"
"$LUA" tests/hud_spec.lua

echo "-- lua context menu bench ($LUA) --"
"$LUA" tests/menu_spec.lua

echo "-- lua face-the-scale bench ($LUA) --"
"$LUA" tests/face_spec.lua

echo "-- lua occupancy bench ($LUA) --"
"$LUA" tests/occupancy_spec.lua

echo "-- lua char screen bench ($LUA) --"
"$LUA" tests/charscreen_spec.lua

echo "-- js/lua parity --"
node tests/parity_dump.js > tests/.parity_js.tsv
"$LUA" tests/parity_check.lua tests/.parity_js.tsv
rm -f tests/.parity_js.tsv

echo "ALL BENCH OK"
