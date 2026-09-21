#!/usr/bin/env python3
"""Writes workshop/art/320/<name>: every image the Workshop page shows, scaled
to 320 px wide. Steam's mobile layout is about that wide, and a wider [img]
makes the page scroll sideways there. The README keeps the full size originals
in workshop/art/; description.bbcode points at the 320 px copies.

Run by hand, not by sync (the outputs are committed). Needs Pillow.

Usage: python3 tools/gen-workshop-art.py
"""
import os
from PIL import Image, ImageSequence

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "workshop", "art")
OUT = os.path.join(ART, "320")
WIDTH = 320
NAMES = [
    "deadweight-animation.gif", "deadweight-animal.gif", "deadweight-zombie.gif",
    "deadweight-digital.png", "deadweight-digital-counter.png",
]


def scaled(im):
    h = max(1, round(im.height * WIDTH / im.width))
    return im.resize((WIDTH, h), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in NAMES:
        src = Image.open(os.path.join(ART, name))
        dst = os.path.join(OUT, name)
        if name.endswith(".gif"):
            frames, durations = [], []
            for fr in ImageSequence.Iterator(src):
                durations.append(fr.info.get("duration", 40))
                frames.append(scaled(fr.convert("RGBA")).convert("P", palette=Image.ADAPTIVE, colors=255))
            frames[0].save(dst, save_all=True, append_images=frames[1:], duration=durations,
                           loop=src.info.get("loop", 0), optimize=True, disposal=1)
        else:
            scaled(src.convert("RGBA")).save(dst, optimize=True)
        print("%s: %d bytes" % (name, os.path.getsize(dst)))


if __name__ == "__main__":
    main()
