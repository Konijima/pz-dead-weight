#!/usr/bin/env python3
"""Fills the README's Install section with the Workshop link, between the
`<!-- workshop-link:start -->` / `<!-- workshop-link:end -->` markers, so
tools/set-workshop-id.sh can rerun this safely: it only ever replaces the
text between the markers, never the markers themselves.

Usage: fill-readme-link.py README.md <link>
"""
import re
import sys
from pathlib import Path

MARKER_RE = re.compile(r"(<!-- workshop-link:start -->).*?(<!-- workshop-link:end -->)", re.S)


def main():
    readme_path, link = Path(sys.argv[1]), sys.argv[2]
    text = readme_path.read_text(encoding="utf-8")
    replacement = f"[Dead Weight on the Steam Workshop]({link})."
    new_text, count = MARKER_RE.subn(rf"\1{replacement}\2", text)
    if count == 0:
        raise SystemExit(f"no workshop-link markers found in {readme_path}")
    readme_path.write_text(new_text, encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
