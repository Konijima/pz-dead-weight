#!/usr/bin/env python3
"""Regenerates the description= lines of workshop/workshop.txt from
workshop/description.bbcode, the hand edited source, so the two never
drift. description.bbcode is copied line for line into one description=
per line (a blank line becomes a bare "description="); the single line
`[img]{{GIF_URL}}[/img]` is filled in from workshop/gif_url.txt when that
file holds a URL, and dropped entirely (not left with an empty [img][/img])
when it is empty. `{{WORKSHOP_ID}}` is filled in from
workshop/workshop_id.txt when that file holds a digits id, and otherwise
left as the "set after upload" placeholder text (never dropped: unlike the
gif, that line always makes sense). Everything else in workshop.txt (the
header comments, version=, title=, tags=, visibility=, id= if
tools/set-workshop-id.sh has written one) is left untouched: only the
contiguous block of description= lines is replaced.

Used by tools/pack-workshop.sh before staging, and importable from the
bench (tests/) to check workshop.txt is not stale.
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BBCODE = REPO / "workshop" / "description.bbcode"
GIF_URL = REPO / "workshop" / "gif_url.txt"
WORKSHOP_ID = REPO / "workshop" / "workshop_id.txt"
WORKSHOP_TXT = REPO / "workshop" / "workshop.txt"

GIF_TOKEN = "[img]{{GIF_URL}}[/img]"
WORKSHOP_ID_TOKEN = "{{WORKSHOP_ID}}"
WORKSHOP_ID_PLACEHOLDER = "[i]set after upload[/i]"


def gen_description_lines(bbcode_path=BBCODE, gif_url_path=GIF_URL, workshop_id_path=WORKSHOP_ID):
    """Returns the list of "description=..." lines workshop.txt should
    carry, built from description.bbcode, gif_url.txt and workshop_id.txt."""
    gif_url = ""
    if gif_url_path.is_file():
        gif_url = gif_url_path.read_text(encoding="utf-8").strip()

    workshop_id = ""
    if workshop_id_path.is_file():
        workshop_id = workshop_id_path.read_text(encoding="utf-8").strip()

    lines = bbcode_path.read_text(encoding="utf-8").splitlines()
    out = []
    for line in lines:
        if line.strip() == GIF_TOKEN:
            if not gif_url:
                continue  # no URL yet: drop the line, never ship an empty [img][/img]
            line = line.replace("{{GIF_URL}}", gif_url)
        if WORKSHOP_ID_TOKEN in line:
            line = line.replace(WORKSHOP_ID_TOKEN, workshop_id or WORKSHOP_ID_PLACEHOLDER)
        out.append(f"description={line}")
    return out


def apply(workshop_txt_path=WORKSHOP_TXT, bbcode_path=BBCODE, gif_url_path=GIF_URL, workshop_id_path=WORKSHOP_ID):
    """Replaces the contiguous description= block in workshop_txt_path
    with the generated lines, leaving every other line as is. Returns the
    new text."""
    new_desc = gen_description_lines(bbcode_path, gif_url_path, workshop_id_path)
    original = workshop_txt_path.read_text(encoding="utf-8").splitlines()

    start = None
    end = None
    for i, line in enumerate(original):
        if line.startswith("description="):
            if start is None:
                start = i
            end = i
    if start is None:
        raise SystemExit(f"no description= line found in {workshop_txt_path}")

    new_lines = original[:start] + new_desc + original[end + 1:]
    return "\n".join(new_lines) + "\n"


def main():
    text = apply()
    WORKSHOP_TXT.write_text(text, encoding="utf-8")
    print(f"wrote {WORKSHOP_TXT}")


if __name__ == "__main__":
    sys.exit(main())
