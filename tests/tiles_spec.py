#!/usr/bin/env python3
"""Bench: parses the generated Digital Scale tile files back with plain struct
(independent of tools/gen-tiles.py) and checks what the game's loaders demand
(IsoWorld.LoadTileDefinitions, TexturePackDevice.initMetaData): header,
version, one sheet of four tiles named deadweight_digital_01_0..3 facing
S/E/N/W, movable tabletop flags, NO solid flags (the scale must stay
walkable), pack entries in the 2x 128x256 frame, and a PNG that decodes to
the page size the entries fit in."""
import io
import struct
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TILES = ROOT / "common/media/DeadWeightDigital.tiles"
PACK = ROOT / "common/media/texturepacks/DeadWeightDigital.pack"
SHEET = "deadweight_digital_01"
FACES = ["S", "E", "N", "W"]

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


class Reader:
    def __init__(self, data):
        self.d, self.p = data, 0

    def i32(self):
        v = struct.unpack_from("<i", self.d, self.p)[0]
        self.p += 4
        return v

    def tstr(self):  # .tiles string: bytes up to '\n'
        e = self.d.index(b"\n", self.p)
        s = self.d[self.p:e].decode("utf-8")
        self.p = e + 1
        return s

    def pstr(self):  # .pack string: int32 length + bytes
        n = self.i32()
        s = self.d[self.p:self.p + n].decode("latin-1")
        self.p += n
        return s

    def raw(self, n):
        b = self.d[self.p:self.p + n]
        self.p += n
        return b


# ---- .tiles ----
r = Reader(TILES.read_bytes())
check(r.raw(4) == b"tdef", ".tiles magic is 'tdef'")
check(r.i32() == 1, ".tiles version is 1")
sheets = r.i32()
check(sheets == 1, f"one sheet, got {sheets}")
name, png = r.tstr(), r.tstr()
check(name == SHEET, f"sheet name {name!r}")
check(png == SHEET + ".png", f"png name {png!r}")
w, h, tsn, n = r.i32(), r.i32(), r.i32(), r.i32()
check(1 <= tsn <= 512, f"tileset number {tsn} in 1..512")
check(n == 4, f"4 tiles, got {n}")
check(w * h >= n, f"sheet grid {w}x{h} holds the tiles")
tiles = []
for _ in range(n):
    props = {}
    for _ in range(r.i32()):
        k = r.tstr()
        props[k] = r.tstr()
    tiles.append(props)
check(r.p == len(r.d), f".tiles has {len(r.d) - r.p} trailing bytes")

for i, (props, face) in enumerate(zip(tiles, FACES)):
    tag = f"{SHEET}_{i}"
    check(props.get("Facing") == face, f"{tag}: Facing {props.get('Facing')!r} != {face}")
    for flag in ("IsMoveAble", "IsTableTop", "BlocksPlacement", "CanScrap"):
        check(flag in props and props[flag] == "", f"{tag}: has flag {flag}")
    check(props.get("CustomName") == "Digital Scale", f"{tag}: CustomName")
    check(props.get("GroupName") == "DeadWeight", f"{tag}: GroupName is ours, not vanilla's Weighing")
    check(props.get("Surface") == "3", f"{tag}: Surface")
    check("IsSurfaceOffset" not in props, f"{tag}: art is at floor level, no IsSurfaceOffset")
    for solid in ("solid", "solidtrans", "collideN", "collideW"):
        check(solid not in props, f"{tag}: walkable, must not have {solid}")
    check(props.keys() == tiles[0].keys(), f"{tag}: same props as the other faces")

# ---- .pack ----
r = Reader(PACK.read_bytes())
check(r.raw(4) == b"PZPK", ".pack magic is 'PZPK'")
check(r.i32() == 1, ".pack version is 1")
pages = r.i32()
check(pages == 1, f"one page, got {pages}")
page_name = r.pstr()
check(page_name != "", "page has a name")
count, mask = r.i32(), r.i32()
check(count == 4, f"4 entries, got {count}")
entries = []
for _ in range(count):
    en = r.pstr()
    entries.append((en,) + struct.unpack_from("<8i", r.d, r.p))
    r.p += 32
png_len = r.i32()
png_bytes = r.raw(png_len)
check(r.p == len(r.d), f".pack has {len(r.d) - r.p} trailing bytes")
page = Image.open(io.BytesIO(png_bytes))
page.load()
check(page.mode == "RGBA", f"page PNG mode {page.mode}")
for i, (en, x, y, ew, eh, ox, oy, fw, fh) in enumerate(entries):
    check(en == f"{SHEET}_{i}", f"entry {i} named {en!r}")
    check((fw, fh) == (128, 256), f"{en}: frame {fw}x{fh} is the 2x 128x256")
    check(ew > 0 and eh > 0 and ox >= 0 and oy >= 0, f"{en}: positive size and offsets")
    check(ox + ew <= fw and oy + eh <= fh, f"{en}: trimmed rect sits inside the frame")
    check(x >= 0 and y >= 0 and x + ew <= page.width and y + eh <= page.height, f"{en}: rect inside the {page.size} page")
    if x + ew <= page.width and y + eh <= page.height:
        check(page.crop((x, y, x + ew, y + eh)).getchannel("A").getbbox() is not None, f"{en}: has visible pixels")
for a in range(len(entries)):
    for b in range(a + 1, len(entries)):
        A, B = entries[a], entries[b]
        overlap = A[1] < B[1] + B[3] and B[1] < A[1] + A[3] and A[2] < B[2] + B[4] and B[2] < A[2] + A[4]
        check(not overlap, f"{A[0]} and {B[0]} overlap on the page")

# the source art the pack was built from is the 2x frame, every face present
for f in FACES:
    src = Image.open(ROOT / f"src/tiles/digital_scale_{f}.png")
    check(src.size == (128, 256), f"src/tiles/digital_scale_{f}.png is {src.size}, needs 128x256")

if failures:
    for m in failures:
        print("FAIL:", m, file=sys.stderr)
    sys.exit(1)
print("tiles_spec: OK, %d tiles, %d entries, page %dx%d" % (n, count, page.width, page.height))
