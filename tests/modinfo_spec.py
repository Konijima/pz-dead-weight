#!/usr/bin/env python3
"""Guard on the two mod.info files: same id/name, every poster=/icon= file
exists next to its mod.info, no U+2014 (em dash) anywhere tracked, and every
rich text tag in description= lines is space delimited so the game's parser
(ISRichTextPanel.lua) never swallows a word glued to a tag."""
import re
import subprocess
import sys
from pathlib import Path

TAG_RE = re.compile(r"<[^<>]*>")


def description_lines(path):
    lines = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        if k.strip() == "description":
            lines.append(v)
    return lines


def check_description_spacing(path):
    problems = []
    lines = description_lines(path)
    for i, v in enumerate(lines):
        for m in TAG_RE.finditer(v):
            before = v[m.start() - 1] if m.start() > 0 else " "
            after = v[m.end()] if m.end() < len(v) else " "
            if before != " " or after != " ":
                problems.append(f"{path}: description line {i}: tag {m.group()!r} not space delimited")
    for i in range(len(lines) - 1):
        end = lines[i][-1:] if lines[i] else ""
        start = lines[i + 1][:1] if lines[i + 1] else ""
        if end and start and end != " " and start != " ":
            problems.append(
                f"{path}: description lines {i}/{i + 1}: concatenation glues {end!r} to {start!r}"
            )
    return problems

REPO = Path(__file__).resolve().parent.parent
fail = False


def parse_mod_info(path):
    keys = {}
    posters = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        k = k.strip()
        if k == "poster":
            posters.append(v.strip())
        elif k not in keys:
            keys[k] = v.strip()
    return keys, posters


root_keys, root_posters = parse_mod_info(REPO / "mod.info")
b42_keys, b42_posters = parse_mod_info(REPO / "42" / "mod.info")

if root_keys.get("id") != b42_keys.get("id"):
    print(f"FAIL: id mismatch: root={root_keys.get('id')!r} 42={b42_keys.get('id')!r}")
    fail = True

if root_keys.get("name") != b42_keys.get("name"):
    print(f"FAIL: name mismatch: root={root_keys.get('name')!r} 42={b42_keys.get('name')!r}")
    fail = True

for base, keys, posters in ((REPO, root_keys, root_posters), (REPO / "42", b42_keys, b42_posters)):
    for p in posters:
        if not (base / p).is_file():
            print(f"FAIL: missing poster file {base / p}")
            fail = True
    icon = keys.get("icon")
    if icon and not (base / icon).is_file():
        print(f"FAIL: missing icon file {base / icon}")
        fail = True

for base in (REPO / "mod.info", REPO / "42" / "mod.info"):
    for problem in check_description_spacing(base):
        print(f"FAIL: {problem}")
        fail = True

tracked = subprocess.run(["git", "-C", str(REPO), "ls-files"], capture_output=True, text=True, check=True).stdout.splitlines()
for rel in tracked:
    fp = REPO / rel
    if not fp.is_file():
        continue
    try:
        text = fp.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    if chr(0x2014) in text:
        print(f"FAIL: U+2014 (em dash) in {rel}")
        fail = True

if fail:
    sys.exit(1)
print("modinfo_spec: OK")
