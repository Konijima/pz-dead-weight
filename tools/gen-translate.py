#!/usr/bin/env python3
"""Generates the two builds' translation files from the single source
src/translate/strings.json.

Proof (see docs/API-COMPAT.md "Translations"): the installed B42 client's
zombie/core/Translator.class builds translation paths as
"%s/media/lua/shared/Translate/%s/%s.json" and loads them with
org.json.JSONObject -- JSON only, no legacy .txt fallback found in the
bytecode. B41 has no such class and only ever read the Lua-table .txt
format, which is what this script still emits for the B41 tree.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "translate" / "strings.json"
LANGS = ("EN", "FR")


def load_strings():
    with open(SRC, encoding="utf-8") as f:
        return json.load(f)


def gen_b41_txt(strings, lang, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    lines = ["ContextMenu_%s = {" % lang, ""]
    for key, values in strings.items():
        lines.append('    %s = "%s",' % (key, values[lang]))
        lines.append("")
    lines.append("}")
    text = "\r\n".join(lines) + "\r\n"
    out_path = out_dir / ("ContextMenu_%s.txt" % lang)
    out_path.write_text(text, encoding="ascii", newline="")


def gen_b42_json(strings, lang, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    data = {key: values[lang] for key, values in strings.items()}
    text = json.dumps(data, indent=4, ensure_ascii=False) + "\n"
    out_path = out_dir / "ContextMenu.json"
    out_path.write_text(text, encoding="utf-8")


def generate(base_dir):
    strings = load_strings()
    for lang in LANGS:
        gen_b41_txt(strings, lang, base_dir / "media/lua/shared/Translate" / lang)
        gen_b42_json(strings, lang, base_dir / "42/media/lua/shared/Translate" / lang)


if __name__ == "__main__":
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT
    generate(target)
