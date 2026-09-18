#!/usr/bin/env python3
"""Bench: translations are present, correctly encoded and round trip for
every language the game ships (B41 legacy .txt per its declared charset,
B42 UTF-8 .json, no BOM), and EN/FR stay byte-for-byte unchanged.

Language list and B41 charset table live in tools/gen-translate.py
(LANGS, LANG_CHARSET) -- this bench imports them rather than duplicating,
so a language added there is covered here automatically."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import importlib.util
spec = importlib.util.spec_from_file_location("gen_translate", ROOT / "tools/gen-translate.py")
gen_translate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen_translate)
LANGS = gen_translate.LANGS
LANG_CHARSET = gen_translate.LANG_CHARSET

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


with open(ROOT / "src/translate/strings.json", encoding="utf-8") as f:
    source = json.load(f)
keys = set(source.keys())
check(len(keys) > 0, "source has at least one key")

# every key has every language, no silent fallback to EN.
for k, values in source.items():
    check(set(values) == set(LANGS), f"{k}: has exactly LANGS ({set(values) ^ set(LANGS)})")

for lang in LANGS:
    b41 = ROOT / "media/lua/shared/Translate" / lang / f"ContextMenu_{lang}.txt"
    b42 = ROOT / "42/media/lua/shared/Translate" / lang / "ContextMenu.json"
    codec = LANG_CHARSET[lang]

    raw41 = b41.read_bytes()
    try:
        text41 = raw41.decode(codec)
    except UnicodeDecodeError as exc:
        failures.append(f"{b41}: decodes as {codec} ({exc})")
        text41 = ""
    check(text41.startswith(f"ContextMenu_{lang} = {{"), f"{b41}: header matches vanilla pattern")
    for k in keys:
        check(f'{k} = "{source[k][lang]}"' in text41, f"{b41}: {k} round trips through {codec}")

    raw42 = b42.read_bytes()
    check(not raw42.startswith(b"\xef\xbb\xbf"), f"{b42}: no BOM")
    try:
        data42 = json.loads(raw42.decode("utf-8"))
    except UnicodeDecodeError as exc:
        failures.append(f"{b42}: valid UTF-8 ({exc})")
        data42 = {}
    check(set(data42.keys()) == keys, f"{b42}: key set matches source")
    for k in keys:
        check(data42.get(k) == source[k][lang], f"{b42}: {k} value matches source")

# EN and FR unchanged byte for byte at the source (the per-language loop
# above already proves both round trip through their generated files).
check(source["ContextMenu_WeightScale_StepOn"]["EN"] == "Step on Scale", "EN StepOn unchanged")
check(source["ContextMenu_WeightScale_StepOn"]["FR"] == "Monter sur la balance", "FR StepOn unchanged")
check(source["IGUI_WeightScale_Normal"]["EN"] == "Normal", "EN Normal unchanged")
check(source["IGUI_WeightScale_Normal"]["FR"] == "Normal", "FR Normal unchanged")

if failures:
    for msg in failures:
        print("FAIL:", msg, file=sys.stderr)
    sys.exit(1)
print("translate_spec: OK, %d key(s) x %d lang(s) x 2 builds" % (len(keys), len(LANGS)))
