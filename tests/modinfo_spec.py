#!/usr/bin/env python3
"""Guard on the two mod.info files: same id/name, every poster=/icon= file
exists next to its mod.info, and no U+2014 (em dash) anywhere tracked."""
import subprocess
import sys
from pathlib import Path

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
