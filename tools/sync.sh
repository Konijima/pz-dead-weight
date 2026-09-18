#!/usr/bin/env bash
# Copies the single source under src/ into the two live trees the game
# actually loads. Run this after every edit under src/ and commit the
# generated trees too.
set -euo pipefail
cd "$(dirname "$0")/.."

LUA_SRC="src/lua/client/WeightScale"
TEX_SRC="src/textures"

B41_LUA="media/lua/client/WeightScale"
B42_LUA="42/media/lua/client/WeightScale"
B41_TEX="media/textures/WeightScale"
B42_TEX="common/media/textures/WeightScale"

rm -rf "$B41_LUA" "$B42_LUA" "$B41_TEX" "$B42_TEX"
mkdir -p "$B41_LUA" "$B42_LUA" "$B41_TEX" "$B42_TEX"

cp "$LUA_SRC"/*.lua "$B41_LUA"/
cp "$LUA_SRC"/*.lua "$B42_LUA"/
cp "$TEX_SRC"/*.png "$B41_TEX"/
cp "$TEX_SRC"/*.png "$B42_TEX"/

echo "synced $LUA_SRC -> $B41_LUA, $B42_LUA"
echo "synced $TEX_SRC -> $B41_TEX, $B42_TEX"
