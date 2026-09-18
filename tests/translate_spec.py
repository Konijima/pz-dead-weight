#!/usr/bin/env python3
"""Bench: translations are present and identical across all four generated
files (B41 .txt x2 langs, B42 .json x2 langs), the JSON parses, no BOM, and
FR accents survive each build's own encoding (B41 legacy .txt: ASCII, since
the shipped strings have none; B42 .json: UTF-8, matching the vanilla and
CeroSec files this was proven against -- see docs/API-COMPAT.md)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGS = ("EN", "FR")

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


with open(ROOT / "src/translate/strings.json", encoding="utf-8") as f:
    source = json.load(f)
keys = set(source.keys())
check(len(keys) > 0, "source has at least one key")

for build, sub in (("B41", "media"), ("B42", "42/media")):
    for lang in LANGS:
        if build == "B41":
            path = ROOT / sub / "lua/shared/Translate" / lang / f"ContextMenu_{lang}.txt"
            raw = path.read_bytes()
            check(not raw.startswith(b"\xef\xbb\xbf"), f"{path}: no BOM")
            text = raw.decode("ascii")
            found = {
                k for k in keys
                if f'{k} = "{source[k][lang]}"' in text
            }
            check(found == keys, f"{path}: all keys present with matching value ({found} vs {keys})")
        else:
            path = ROOT / sub / "lua/shared/Translate" / lang / "ContextMenu.json"
            raw = path.read_bytes()
            check(not raw.startswith(b"\xef\xbb\xbf"), f"{path}: no BOM")
            data = json.loads(raw.decode("utf-8"))
            check(set(data.keys()) == keys, f"{path}: key set matches source")
            for k in keys:
                check(data[k] == source[k][lang], f"{path}: {k} value matches source")

# FR accents intact: B42's JSON is UTF-8, always lossless for any FR string.
# B41's legacy .txt is written as plain ASCII (tools/gen-translate.py), which
# is only safe while every shipped FR string is ASCII, so flag it loudly the
# day that stops being true instead of silently mangling an accent.
for k, values in source.items():
    fr = values["FR"]
    check(fr.encode("utf-8").decode("utf-8") == fr, f"FR value for {k} round-trips through UTF-8 (B42)")
    check(fr.isascii(), f"FR value for {k} is ASCII, matching B41 .txt's declared encoding ({fr!r})")

if failures:
    for msg in failures:
        print("FAIL:", msg, file=sys.stderr)
    sys.exit(1)
print("translate_spec: OK, %d key(s) x %d lang(s) x 2 builds" % (len(keys), len(LANGS)))
