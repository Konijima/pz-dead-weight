#!/usr/bin/env python3
"""Generates the two builds' translation files from the single source
src/translate/strings.json.

Proof (see docs/API-COMPAT.md "Translations"): the installed B42 client's
zombie/core/Translator.class builds translation paths as
"%s/media/lua/shared/Translate/%s/%s.json" and loads them with
org.json.JSONObject -- JSON only, no legacy .txt fallback found in the
bytecode. B41 has no such class and only ever read the Lua-table .txt
format, which is what this script still emits for the B41 tree.

B41_CHARSET: the charset each language's B41 .txt is encoded in. B41 is not
installed on this machine (see docs/API-COMPAT.md, "B41 encoding"), so this
table is UNPROVEN except where noted -- built from documented PZ B41 modding
knowledge (per-language legacy code pages), never guessed per string. Every
language not confirmed uses "utf-8" on purpose: a code page mismatch would
silently corrupt bytes, while UTF-8 can hold every string here and any wrong
guess only shows up as a mojibake bug report, not a crash -- so unverified
languages get the encoding that cannot lose data, and the table says so.
Encoding is always strict: a string that cannot fit its language's charset
raises instead of being silently replaced or dropped.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "translate" / "strings.json"

# Historical PZ B41 legacy code pages per language family (community modding
# knowledge, UNPROVEN here -- no B41 client on this machine to check against).
CP1252 = ("EN", "FR", "DE", "ES", "ES_CL", "ES_MX", "AR", "CA", "IT", "PT",
          "PTBR", "NL", "DA", "NO", "FI", "ID")
CP1250 = ("PL", "CS", "HU", "RO")
CP1251 = ("RU", "UA")
CP1254 = ("TR",)
# TH: PROVEN from the B42 client's own
# media/lua/shared/Translate/TH/language.txt ("charset = UTF-8,"). B41 is not
# installed to confirm TH used the same value historically, but it is the
# only language with any charset evidence at all, so it is kept as UTF-8
# rather than folded into the "unverified" default for a different reason.
# CH/CN/JP/KO: no single-byte code page can hold these scripts, and no
# vanilla B41 evidence exists on this machine, so UTF-8 (never lossy) is used
# and flagged UNPROVEN rather than guessing Big5/GBK/Shift-JIS/EUC-KR.
LANG_CHARSET = {}
for _l in CP1252:
    LANG_CHARSET[_l] = "cp1252"
for _l in CP1250:
    LANG_CHARSET[_l] = "cp1250"
for _l in CP1251:
    LANG_CHARSET[_l] = "cp1251"
for _l in CP1254:
    LANG_CHARSET[_l] = "cp1254"
for _l in ("TH", "CH", "CN", "JP", "KO"):
    LANG_CHARSET[_l] = "utf-8"

LANGS = tuple(sorted(LANG_CHARSET))


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
    codec = LANG_CHARSET[lang]
    try:
        encoded = text.encode(codec)
    except UnicodeEncodeError as exc:
        sys.exit(
            "gen-translate: %s cannot be encoded as %s for language %s: %s"
            % (SRC, codec, lang, exc)
        )
    out_path = out_dir / ("ContextMenu_%s.txt" % lang)
    out_path.write_bytes(encoded)


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
