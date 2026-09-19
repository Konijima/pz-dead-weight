#!/usr/bin/env python3
"""Guard on CHANGELOG.md: the top released version matches 42/mod.info's
modversion=, an Unreleased section exists, and tools/changelog-steam.py's
output for that version is non empty and holds no U+2014 (em dash)."""
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "tools"))
import importlib.util

spec = importlib.util.spec_from_file_location("changelog_steam", REPO / "tools" / "changelog-steam.py")
changelog_steam = importlib.util.module_from_spec(spec)
spec.loader.exec_module(changelog_steam)

fail = False

text = (REPO / "CHANGELOG.md").read_text(encoding="utf-8")
head, body = changelog_steam.get_section(text)
if head is None:
    print("FAIL: no released section found in CHANGELOG.md")
    fail = True
else:
    top_version = head.split(" ", 1)[0]
    mod_info = (REPO / "42" / "mod.info").read_text(encoding="utf-8")
    modversion = None
    for line in mod_info.splitlines():
        if line.startswith("modversion="):
            modversion = line.partition("=")[2].strip()
            break
    if modversion != top_version:
        print(f"FAIL: CHANGELOG.md top version {top_version!r} != 42/mod.info modversion={modversion!r}")
        fail = True

unreleased_head, _ = changelog_steam.get_section(text, "unreleased")
if unreleased_head is None:
    print("FAIL: no Unreleased section in CHANGELOG.md")
    fail = True

if head is not None:
    out = subprocess.run(
        [sys.executable, str(REPO / "tools" / "changelog-steam.py"), top_version],
        capture_output=True, text=True, check=True,
    ).stdout
    if not out.strip():
        print("FAIL: tools/changelog-steam.py produced empty output")
        fail = True
    if chr(0x2014) in out:
        print("FAIL: U+2014 (em dash) in tools/changelog-steam.py output")
        fail = True

if fail:
    sys.exit(1)
print("changelog_spec: OK")
