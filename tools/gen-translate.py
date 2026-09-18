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
# CH/CN/JP: no single-byte code page can hold these scripts, and CP1250/1251/
# 1254/TH were, at the time this comment was first written, the only ones
# with any B41 evidence, so UTF-8 (never lossy) was used here too.
# PROVEN BY WORKSHOP SAMPLES (2026-09-18, see docs/API-COMPAT.md
# "B41 encoding"): every root `media/lua/shared/Translate/<LANG>/*.txt` found
# under installed B41-era Workshop items on this machine (excluding files
# under `42/` or `common/`, which are B42-side even when they share the
# legacy .txt format) was byte-inspected. JP (3/3), CH (5/5) and CN (12/12)
# decode cleanly and legibly as UTF-8 with no BOM, confirming this bucket for
# those three languages. RU (10/10) and PL (10/10) decode cleanly only under
# their assigned CP1251/CP1250; TR (4/5, the fifth was ASCII-only) only under
# CP1254 -- confirming CP1251/CP1250/CP1254 above.
LANG_CHARSET = {}
for _l in CP1252:
    LANG_CHARSET[_l] = "cp1252"
for _l in CP1250:
    LANG_CHARSET[_l] = "cp1250"
for _l in CP1251:
    LANG_CHARSET[_l] = "cp1251"
for _l in CP1254:
    LANG_CHARSET[_l] = "cp1254"
for _l in ("TH", "CH", "CN", "JP"):
    LANG_CHARSET[_l] = "utf-8"
# KO: corrected 2026-09-18, PROVEN BY WORKSHOP SAMPLES -- was "utf-8" here,
# but 8 of 10 root Translate/KO/*.txt files found under installed B41-era
# Workshop items on this machine start with the UTF-16LE BOM (FF FE) and
# decode cleanly as Korean text under "utf-16-le"; the other 2 are
# ASCII-only files, consistent but not distinguishing. Python's "utf-16"
# codec writes the same little-endian bytes with a leading BOM on encode and
# auto-detects the BOM on decode, matching the sampled files.
LANG_CHARSET["KO"] = "utf-16"

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
