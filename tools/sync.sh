#!/usr/bin/env bash
# Copies the single source under src/ into the two live trees the game
# actually loads. Run this after every edit under src/ and commit the
# generated trees too.
set -euo pipefail
cd "$(dirname "$0")/.."

LUA_SRC="src/lua/client/WeightScale"
TEX_SRC="src/textures"
SND_SRC="src/sounds"
SCR_SRC="src/scripts"
TILES_SRC="src/tiles"
# Script files that only Build 42 may see: ItemType = base:moveable is B42
# syntax and the item's sprite lives in the B42 tile pack (untested on B41).
B42_ONLY_SCRIPTS="deadweight_items.txt"

# Server side Lua (loot and world spawn of the Digital Scale) is Build 42 only.
SRV_SRC="src/lua/server/WeightScale"
B42_SRV="42/media/lua/server/WeightScale"

B41_LUA="media/lua/client/WeightScale"
B42_LUA="42/media/lua/client/WeightScale"
B41_TEX="media/textures/WeightScale"
B42_TEX="common/media/textures/WeightScale"
B41_SND="media/sound/WeightScale"
B42_SND="common/media/sound/WeightScale"
B41_SCR="media/scripts"
B42_SCR="common/media/scripts"
B41_SBX="media/sandbox-options.txt"
B42_SBX="common/media/sandbox-options.txt"
B41_TR="media/lua/shared/Translate"
B42_TR="42/media/lua/shared/Translate"

rm -rf "$B42_SRV" "$B41_LUA" "$B42_LUA" "$B41_TEX" "$B42_TEX" "$B41_SND" "$B42_SND" "$B41_TR" "$B42_TR"
mkdir -p "$B42_SRV" "$B41_LUA" "$B42_LUA" "$B41_TEX" "$B42_TEX" "$B41_SND" "$B42_SND" "$B41_SCR" "$B42_SCR"

cp "$LUA_SRC"/*.lua "$B41_LUA"/
cp "$LUA_SRC"/*.lua "$B42_LUA"/
cp "$SRV_SRC"/*.lua "$B42_SRV"/
cp "$TEX_SRC"/*.png "$B41_TEX"/
cp "$TEX_SRC"/*.png "$B42_TEX"/
cp "$SND_SRC"/*.ogg "$B41_SND"/
cp "$SND_SRC"/*.ogg "$B42_SND"/
for f in "$SCR_SRC"/*.txt; do
    name="$(basename "$f")"
    cp "$f" "$B42_SCR"/
    case " $B42_ONLY_SCRIPTS " in *" $name "*) ;; *) cp "$f" "$B41_SCR"/ ;; esac
done

# One sandbox options file, read by CustomSandboxOptions.init from BOTH the
# version dir (media/ at the root for B41) and the common dir (B42), see
# docs/API-COMPAT.md "Sandbox option".
cp src/sandbox-options.txt "$B41_SBX"
cp src/sandbox-options.txt "$B42_SBX"

# Translations are generated, not copied verbatim: B41 reads the legacy
# Lua-table .txt, B42 reads JSON (see tools/gen-translate.py and
# docs/API-COMPAT.md "Translations" for the proof).
python3 tools/gen-translate.py

# The Digital Scale tile pack and tile definitions are generated too, B42 only
# (common/media/texturepacks/*.pack, common/media/*.tiles); the root tree is
# Build 41 and gets nothing. See tools/gen-tiles.py.
python3 tools/gen-tiles.py

echo "synced $LUA_SRC -> $B41_LUA, $B42_LUA"
echo "synced $TEX_SRC -> $B41_TEX, $B42_TEX"
echo "synced $SND_SRC -> $B41_SND, $B42_SND"
echo "synced $SCR_SRC -> $B41_SCR, $B42_SCR"
echo "synced src/sandbox-options.txt -> $B41_SBX, $B42_SBX"
echo "generated src/translate/strings.json -> $B41_TR (.txt), $B42_TR (.json)"
echo "generated $TILES_SRC/*.png -> common/media/texturepacks/DeadWeightDigital.pack, common/media/DeadWeightDigital.tiles"
