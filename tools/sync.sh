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

B41_LUA="media/lua/client/WeightScale"
B42_LUA="42/media/lua/client/WeightScale"
B41_TEX="media/textures/WeightScale"
B42_TEX="common/media/textures/WeightScale"
B41_SND="media/sound/WeightScale"
B42_SND="common/media/sound/WeightScale"
B41_SCR="media/scripts"
B42_SCR="common/media/scripts"

rm -rf "$B41_LUA" "$B42_LUA" "$B41_TEX" "$B42_TEX" "$B41_SND" "$B42_SND"
mkdir -p "$B41_LUA" "$B42_LUA" "$B41_TEX" "$B42_TEX" "$B41_SND" "$B42_SND" "$B41_SCR" "$B42_SCR"

cp "$LUA_SRC"/*.lua "$B41_LUA"/
cp "$LUA_SRC"/*.lua "$B42_LUA"/
cp "$TEX_SRC"/*.png "$B41_TEX"/
cp "$TEX_SRC"/*.png "$B42_TEX"/
cp "$SND_SRC"/*.ogg "$B41_SND"/
cp "$SND_SRC"/*.ogg "$B42_SND"/
cp "$SCR_SRC"/*.txt "$B41_SCR"/
cp "$SCR_SRC"/*.txt "$B42_SCR"/

echo "synced $LUA_SRC -> $B41_LUA, $B42_LUA"
echo "synced $TEX_SRC -> $B41_TEX, $B42_TEX"
echo "synced $SND_SRC -> $B41_SND, $B42_SND"
echo "synced $SCR_SRC -> $B41_SCR, $B42_SCR"
