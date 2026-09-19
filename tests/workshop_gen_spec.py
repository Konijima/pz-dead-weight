#!/usr/bin/env python3
"""Guard on workshop/workshop.txt: its description= block must equal what
tools/gen-workshop-txt.py produces from description.bbcode + gif_url.txt
(so the two never drift by hand edit), and no [img][/img] pair anywhere in
the tracked workshop material may carry an empty URL."""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "tools"))
import importlib.util

spec = importlib.util.spec_from_file_location("gen_workshop_txt", REPO / "tools" / "gen-workshop-txt.py")
gen_workshop_txt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen_workshop_txt)

WORKSHOP_TXT = REPO / "workshop" / "workshop.txt"
BBCODE = REPO / "workshop" / "description.bbcode"

EMPTY_IMG_RE = re.compile(r"\[img\]\s*\[/img\]")

fail = False

actual_desc = [
    line for line in WORKSHOP_TXT.read_text(encoding="utf-8").splitlines()
    if line.startswith("description=")
]
expected_desc = gen_workshop_txt.gen_description_lines()

if actual_desc != expected_desc:
    print("FAIL: workshop/workshop.txt description= lines are stale; run tools/gen-workshop-txt.py")
    fail = True

for path in (WORKSHOP_TXT, BBCODE):
    text = path.read_text(encoding="utf-8")
    if EMPTY_IMG_RE.search(text):
        print(f"FAIL: {path} has an [img][/img] tag with an empty URL")
        fail = True

if fail:
    sys.exit(1)
print("workshop_gen_spec: OK")
