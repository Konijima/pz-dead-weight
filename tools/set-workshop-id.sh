#!/usr/bin/env bash
# One command for after the Steam Workshop upload: records the item's id
# once, everywhere it belongs.
#
# Format proven on this machine from an item already uploaded
# (~/Zomboid/Workshop/CeroSec/workshop.txt): the game's uploader writes
# "id=<digits>" as the line right after "version=1", before "title=".
#
# workshop/workshop_id.txt (one line, digits) becomes the single source of
# truth. From it: the id= line of workshop/workshop.txt, the "Workshop ID:"
# line of the description (the {{WORKSHOP_ID}} token in
# description.bbcode, same pattern as {{GIF_URL}}), and the README's
# Install section (a marked span, so this script is idempotent).
#
#   tools/set-workshop-id.sh [ID] [--check] [--force]
#   ID defaults to the id= the game already wrote into the staged
#   workshop.txt under ${DEADWEIGHT_STAGE:-~/Zomboid/Workshop/DeadWeight}.
#   --check: print what would change, write nothing.
#   --force: accept an ID that differs from the one already recorded.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$(pwd)"
STAGE="${DEADWEIGHT_STAGE:-$HOME/Zomboid/Workshop/DeadWeight}"
WORKSHOP_TXT="$REPO/workshop/workshop.txt"
ID_FILE="$REPO/workshop/workshop_id.txt"
README="$REPO/README.md"

CHECK=0; FORCE=0; ID=""
for a in "$@"; do
  case "$a" in
    --check) CHECK=1 ;;
    --force) FORCE=1 ;;
    *) ID="$a" ;;
  esac
done

if [ -z "$ID" ]; then
  ID="$(grep -h '^id=' "$STAGE/workshop.txt" 2>/dev/null | head -1 | cut -d= -f2 || true)"
  [ -n "$ID" ] || { echo "no id given and none found in $STAGE/workshop.txt (upload first, or pass one)" >&2; exit 1; }
fi
[[ "$ID" =~ ^[0-9]+$ ]] || { echo "not a valid Workshop id (digits only): $ID" >&2; exit 1; }

EXISTING=""
[ -f "$ID_FILE" ] && EXISTING="$(cat "$ID_FILE")"

if [ "$EXISTING" = "$ID" ]; then
  echo "workshop id already set to $ID, nothing to change"
  exit 0
fi
if [ -n "$EXISTING" ] && [ "$FORCE" -ne 1 ]; then
  echo "refusing: workshop/workshop_id.txt already holds $EXISTING, got $ID (pass --force to override)" >&2
  exit 1
fi

if [ "$CHECK" -eq 1 ]; then
  echo "would set workshop id: ${EXISTING:-<none>} -> $ID"
  echo "would change: $ID_FILE, $WORKSHOP_TXT (id= line), workshop.txt description=, README.md"
  exit 0
fi

printf '%s\n' "$ID" > "$ID_FILE"

if grep -q '^id=' "$WORKSHOP_TXT"; then
  sed -i "s/^id=.*/id=$ID/" "$WORKSHOP_TXT"
else
  sed -i "/^version=1\$/a id=$ID" "$WORKSHOP_TXT"
fi

python3 "$REPO/tools/gen-workshop-txt.py"

LINK="https://steamcommunity.com/sharedfiles/filedetails/?id=$ID"
python3 "$REPO/tools/fill-readme-link.py" "$README" "$LINK"

echo "workshop id set to $ID"
echo "changed: $ID_FILE, $WORKSHOP_TXT, README.md"
echo "commit these before the next repack/push"
