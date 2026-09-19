#!/usr/bin/env python3
"""Bench: translations are present, correctly encoded and round trip for
every language the game ships (B41 legacy .txt per its declared charset,
B42 UTF-8 .json, no BOM), land in the FILE the game actually loads for
their key's prefix, and EN/FR stay byte-for-byte unchanged.

Extended 2026-09-18 (root cause of the owner's bug report: the Info tab
showed the raw key "IGUI_WeightScale_Normal" instead of "Normal"):
IGUI_WeightScale_Normal was shipped inside ContextMenu.json/.txt, a file
zombie.core.Translator never reads for IGUI_ prefixed keys, so getText
never found it. This bench now checks tools/gen-translate.py's
PREFIX_TO_FILE against the CLIENT INSTALL itself, not only against our own
generator -- a bench that only agrees with our own code proved nothing.

Language list and B41 charset table live in tools/gen-translate.py
(LANGS, LANG_CHARSET, PREFIX_TO_FILE) -- this bench imports them rather
than duplicating, so a language or prefix added there is covered here
automatically."""
import json
import re
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
PREFIX_TO_FILE = gen_translate.PREFIX_TO_FILE

CLIENT_EN = Path(
    "~/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid"
    "/media/lua/shared/Translate/EN"
).expanduser()

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

groups = {}
for k in keys:
    prefix = k.split("_", 1)[0]
    check(prefix in PREFIX_TO_FILE, f"{k}: prefix {prefix!r} is in PREFIX_TO_FILE")
    groups.setdefault(prefix, set()).add(k)

# Check the prefix -> file mapping against the CLIENT INSTALL, not against
# our own generator: for each prefix we actually use, vanilla's EN folder
# must have a file of exactly that name, and it must hold at least one key
# with that prefix (proving the game loads THAT file for THAT prefix).
if CLIENT_EN.is_dir():
    for prefix, mapping in PREFIX_TO_FILE.items():
        if prefix not in groups:
            continue
        vanilla_path = CLIENT_EN / f"{mapping['b42_stem']}.json"
        check(vanilla_path.is_file(), f"client install has {vanilla_path.name} for prefix {prefix}")
        if vanilla_path.is_file():
            vanilla_keys = json.loads(vanilla_path.read_text(encoding="utf-8")).keys()
            check(
                any(vk.startswith(prefix + "_") for vk in vanilla_keys),
                f"{vanilla_path.name}: holds at least one vanilla {prefix}_ key",
            )
else:
    print(
        f"NOTICE: client install not found at {CLIENT_EN}, skipping "
        "prefix-to-file checks against the game itself",
        file=sys.stderr,
    )

# Every literal getText("...") key used in src/lua either belongs to this
# mod (defined in strings.json -- checked below for correct routing) or is
# a vanilla key this mod reuses on purpose (WORD_KEY's UI_trait_* bands,
# IGUI_char_Weight's build-detection probe): those are not ours to ship,
# but when the client install is present they must exist verbatim in the
# vanilla file for their own prefix, so a typo there can't ship a raw key
# either.
lua_dir = ROOT / "src/lua/client/WeightScale"
literal_gettext_keys = set()
for lua_file in lua_dir.glob("*.lua"):
    literal_gettext_keys.update(re.findall(r'getText\(\s*"([^"]+)"\s*\)', lua_file.read_text(encoding="utf-8")))
    literal_gettext_keys.update(re.findall(r'=\s*"(UI_trait_\w+|IGUI_\w+)"', lua_file.read_text(encoding="utf-8")))

for gt_key in literal_gettext_keys:
    if gt_key in keys:
        continue
    check("_" in gt_key, f"getText key {gt_key!r}: has a prefix")
    gt_prefix = gt_key.split("_", 1)[0]
    # UI_trait_* bands are vanilla's own file (UI.json), distinct from this
    # mod's own IGUI_/ContextMenu_ prefixes and their PREFIX_TO_FILE entries.
    vanilla_stem = "UI" if gt_prefix == "UI" else PREFIX_TO_FILE.get(gt_prefix, {}).get("b42_stem")
    if vanilla_stem and CLIENT_EN.is_dir():
        vanilla_path = CLIENT_EN / f"{vanilla_stem}.json"
        if vanilla_path.is_file():
            vanilla_data = json.loads(vanilla_path.read_text(encoding="utf-8"))
            check(gt_key in vanilla_data, f"vanilla key {gt_key!r} exists verbatim in {vanilla_path.name}")

# Per language, per prefix: the generated file exists with the RIGHT name
# (per PREFIX_TO_FILE), decodes correctly, and round trips every key of
# that prefix -- and no OTHER generated file exists for a prefix we do not
# use (the bug shipped an extra file under a name nothing loads).
for lang in LANGS:
    b41_dir = ROOT / "media/lua/shared/Translate" / lang
    b42_dir = ROOT / "42/media/lua/shared/Translate" / lang
    codec = LANG_CHARSET[lang]

    for prefix, group_keys in groups.items():
        mapping = PREFIX_TO_FILE[prefix]
        b41 = b41_dir / f"{mapping['b41_stem']}_{lang}.txt"
        b42 = b42_dir / f"{mapping['b42_stem']}.json"

        raw41 = b41.read_bytes() if b41.is_file() else b""
        check(b41.is_file(), f"{b41}: exists")
        try:
            text41 = raw41.decode(codec)
        except UnicodeDecodeError as exc:
            failures.append(f"{b41}: decodes as {codec} ({exc})")
            text41 = ""
        check(text41.startswith(f"{mapping['b41_table']}_{lang} = {{"), f"{b41}: header matches vanilla pattern")
        for k in group_keys:
            check(f'{k} = "{source[k][lang]}"' in text41, f"{b41}: {k} round trips through {codec}")

        raw42 = b42.read_bytes() if b42.is_file() else b""
        check(b42.is_file(), f"{b42}: exists")
        check(not raw42.startswith(b"\xef\xbb\xbf"), f"{b42}: no BOM")
        try:
            data42 = json.loads(raw42.decode("utf-8")) if raw42 else {}
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            failures.append(f"{b42}: valid UTF-8 JSON ({exc})")
            data42 = {}
        check(set(data42.keys()) == group_keys, f"{b42}: key set matches source for prefix {prefix}")
        for k in group_keys:
            check(data42.get(k) == source[k][lang], f"{b42}: {k} value matches source")

    # No stray generated file for a prefix outside the mapping: every stem
    # we could plausibly have generated is enumerated by PREFIX_TO_FILE, so
    # any other file under our own Translate/<lang> dirs is unexpected.
    allowed_b41 = {f"{m['b41_stem']}_{lang}.txt" for m in PREFIX_TO_FILE.values()}
    allowed_b42 = {f"{m['b42_stem']}.json" for m in PREFIX_TO_FILE.values()}
    if b41_dir.is_dir():
        for f in b41_dir.iterdir():
            check(f.name in allowed_b41, f"{f}: not a stray generated file (allowed: {sorted(allowed_b41)})")
    if b42_dir.is_dir():
        for f in b42_dir.iterdir():
            check(f.name in allowed_b42, f"{f}: not a stray generated file (allowed: {sorted(allowed_b42)})")

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
