#!/usr/bin/env python3
"""Print a CHANGELOG.md section as a Steam Workshop change note.

    python3 tools/changelog-steam.py            newest released section
    python3 tools/changelog-steam.py 1.0.0       that version's section
    python3 tools/changelog-steam.py unreleased  what is waiting under Unreleased

PROVEN on this machine (client install's decompiled
zombie/core/znet/SteamWorkshopItem.java and
media/lua/client/OptionScreens/WorkshopSubmitScreen.lua): the change note is
a plain in-memory string field (SteamWorkshopItem.changeNote), typed or
pasted into a multi-line ISTextEntryBox (setMultipleLine(true),
setMaxLines(512)) on the submit screen's changelog page, then sent straight
to Steam by item:submitUpdate(). It is never read from workshop.txt or any
other staged file, so nothing here writes into the staging folder. Nothing
in that code path parses BBCode, so this prints plain text with "-" bullets,
not [*] tags. No character limit is enforced client side; the UI's own cap
is the entry box's 512 lines. The first ever upload of a new item DOES take
a change note: Page7:setFields sees no item:getID() yet, calls item:create()
to get one, then immediately falls through to the same item:submitUpdate()
an update uses, carrying whatever was typed on the changelog page.

Writes the same text to workshop/changenote.txt (gitignored, like CeroSec's
tools/out/: a generated release artifact, not tracked).
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CHANGELOG = REPO / "CHANGELOG.md"
OUT = REPO / "workshop" / "changenote.txt"


def get_section(text, version=None):
    """Returns (heading, body) for the requested section: the named
    version, "Unreleased", or (default) the first non-Unreleased one."""
    sections = re.split(r"^## ", text, flags=re.M)[1:]
    for section in sections:
        head, _, body = section.partition("\n")
        head = head.strip()
        if version == "unreleased":
            if head.lower().startswith("unreleased"):
                return head, body.strip("\n")
        elif version:
            if head.split(" ", 1)[0] == version:
                return head, body.strip("\n")
        elif not head.lower().startswith("unreleased"):
            return head, body.strip("\n")
    return None, None


def render(head, body):
    lines = [head, ""]
    for line in body.split("\n"):
        if line.startswith("- "):
            lines.append("- " + line[2:].strip())
        elif line.startswith("  ") and lines and lines[-1].startswith("- "):
            lines[-1] += " " + line.strip()
        elif line.strip() == "":
            lines.append("")
        else:
            lines.append(line.strip())
    if not body.strip():
        lines.append("(nothing yet)")
    return "\n".join(lines).strip("\n") + "\n"


def main():
    version = sys.argv[1] if len(sys.argv) > 1 else None
    text = CHANGELOG.read_text(encoding="utf-8")
    head, body = get_section(text, version)
    if head is None:
        sys.exit(f"no section found for {version!r}")
    out = render(head, body)
    sys.stdout.write(out)
    OUT.write_text(out, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
