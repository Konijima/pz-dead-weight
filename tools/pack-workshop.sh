#!/usr/bin/env bash
# Assembles the Steam Workshop upload copy of Dead Weight under
# ~/Zomboid/Workshop/DeadWeight/, mirroring how CeroSec stages its own
# upload copy (see ~/Zomboid/mods/CeroSec/tools/workshop-sync.sh): the game
# scans ~/Zomboid/Workshop/*/Contents/mods/* as mods too, so this writes a
# plain COPY there, never a symlink (Build 42's ScriptManager loses script
# files through a symlinked mod folder).
#
# THE DOUBLE ID: while this staged copy exists, ~/Zomboid/mods/WeightScale
# (the merged repo, mod.info id=DeadWeight after this rework) and
# ~/Zomboid/Workshop/DeadWeight/Contents/mods/DeadWeight both declare the
# same id. PROVEN on this machine 2026-09-18 (mod info screen's Path row
# read /home/mathieu/Zomboid/Workshop/DeadWeight/Contents/mods/DeadWeight,
# Source "Workshop"): when both copies carry the same id, the game shows
# and LOADS the STAGED copy, not the repo copy. So after ANY change to the
# repo, rerun this script (or run it with --clean while developing straight
# from the repo, so only one copy exists) before testing in game, or the
# proof will be against stale content. CeroSec's discipline (stage only
# right before uploading, upload, --clean right after) still applies for
# the actual Workshop submission.
#
#   bash tools/pack-workshop.sh --check   list what would be staged, write nothing
#   bash tools/pack-workshop.sh           stage the copy for real
#   bash tools/pack-workshop.sh --clean   remove the staged copy
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$(pwd)"
WS="$HOME/Zomboid/Workshop/DeadWeight"
DEST="$WS/Contents/mods/DeadWeight"

# Only what the game needs to load the mod. No .git, src, tests, docs, tools.
SHIP=(mod.info poster.png poster2.png media 42 common)

usage() { echo "usage: $0 [--check|--clean]" >&2; exit 2; }

case "${1:-}" in
  --clean)
    rm -rf "$DEST"
    echo "removed $DEST"
    exit 0
    ;;
  --check)
    CHECK=1
    ;;
  "")
    CHECK=0
    ;;
  *)
    usage
    ;;
esac

echo "staging under: $WS"
for f in "${SHIP[@]}"; do
  if [ ! -e "$REPO/$f" ]; then
    echo "missing: $REPO/$f" >&2
    exit 1
  fi
  echo "  $f -> Contents/mods/DeadWeight/$f"
done
echo "  workshop/workshop.txt -> workshop.txt"
echo "  workshop/preview.png -> preview.png"

if [ "$CHECK" -eq 1 ]; then
  echo "(--check: nothing written)"
  exit 0
fi

python3 "$REPO/tools/gen-workshop-txt.py"

mkdir -p "$DEST"
rm -rf "${SHIP[@]/#/$DEST/}"
for f in "${SHIP[@]}"; do
  cp -r "$REPO/$f" "$DEST/$f"
done

# Steam writes its item id into the Workshop-side workshop.txt after the
# first upload; keep that line when the repo copy has none yet (this is a
# new item, so the repo's workshop.txt never carries one on purpose).
ID=$(grep -h '^id=' "$WS/workshop.txt" 2>/dev/null | head -1 || true)
cp "$REPO/workshop/workshop.txt" "$WS/workshop.txt"
cp "$REPO/workshop/preview.png" "$WS/preview.png"
if [ -n "$ID" ] && ! grep -q '^id=' "$WS/workshop.txt"; then
  printf '%s\n' "$ID" >> "$WS/workshop.txt"
  echo "kept Steam's $ID (copy it into $REPO/workshop/workshop.txt and commit)"
fi

echo "staged: $DEST"
echo "upload from the game (main menu, Workshop, Submit item), then:"
echo "  bash tools/pack-workshop.sh --clean"
