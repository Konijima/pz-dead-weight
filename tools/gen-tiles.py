#!/usr/bin/env python3
"""Generates the Build 42 tile pack of the Digital Scale furniture from the
hand edited faces in src/tiles/:

  common/media/texturepacks/DeadWeightDigital.pack   (PZPK texture pack)
  common/media/DeadWeightDigital.tiles               (binary tdef tile definitions)
  common/media/tileDepthTextureAssignments.txt       (depth map of each face, see DEPTH_ASSIGN)

Never hand edit the two outputs. Edit src/tiles/digital_scale_{S,E,N,W}.png (the
game's 2x frame, 128x256 RGBA) or TILE_PROPS below and rerun (tools/sync.sh does).

Formats, proven against the decompiled game (all ints int32 little endian):

  .tiles   IsoWorld.LoadTileDefinitions: 'tdef', version 1, sheet count; per
           sheet: name\\n, png name\\n, wTiles, hTiles, tilesetNumber (1..512),
           nTiles; per tile: nProps, then (key\\n, value\\n) pairs. Sprites are
           named <sheet>_<index>. Cross checked against a real mod
           (FoodDrying, Workshop 3747396551).
  .pack    TexturePackDevice.initMetaData/readPage: 'PZPK', version 1, page
           count; per page: name, entry count, mask flag, per entry name plus 8
           int32 (x, y, w, h, ox, oy, frameW, frameH), then PNG length and the
           PNG bytes. Strings are int32 length + bytes.

Where the game finds them: mod.info `pack=DeadWeightDigital` is looked up as
media/texturepacks/DeadWeightDigital.pack, `tiledef=DeadWeightDigital <N>` as
media/DeadWeightDigital.tiles, in the mod's common/ dir and its version dir
(ZomboidFileSystem.loadMod indexes both), see docs/API-COMPAT.md.

`--check` regenerates into a temp dir and exits non zero if the committed
files drifted. The pack's PNG blob is compared by decoded pixels, not bytes,
so a different zlib does not read as drift.
"""
import io
import os
import struct
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "src", "tiles")
PACK_REL = os.path.join("common", "media", "texturepacks", "DeadWeightDigital.pack")
TILES_REL = os.path.join("common", "media", "DeadWeightDigital.tiles")
DEPTH_REL = os.path.join("common", "media", "tileDepthTextureAssignments.txt")
# A sprite with no depth map gets the game's whole tile box (TileDepthTextureManager
# default), so a survivor standing on the slab is hidden behind it. The vanilla
# "Floor" preset depth map (preset_depthmaps_01_0) is a flat plane at floor level:
# the slab is 2.5 cm high, so a person or an animal always draws over it.
# TileDepthTextureAssignments reads it from the mod's common/media dir.
DEPTH_ASSIGN = "preset_depthmaps_01_0"

SHEET = "deadweight_digital_01"
PAGE_NAME = "DeadWeightDigital0"  # fixed, like FoodDrying's "<pack>0"
# Index 0..3 = S, E, N, W (sprite deadweight_digital_01_<index>).
FACES = ["S", "E", "N", "W"]
FRAME_W, FRAME_H = 128, 256  # the game's 2x tile frame
PAGE_MAX_W = 256
PAD = 2  # gap between packed faces so bilinear sampling never bleeds

# Modelled on vanilla location_community_medical_01_136 (Microscope), a movable
# tabletop object that also stands on the floor. No solid/solidtrans: walkable.
# GroupName differs from vanilla's "Weighing" so the two never merge into one
# No IsSurfaceOffset: the art sits at floor level and the game lifts a tabletop
# object by the counter's own height (ISMoveableSpriteProps); IsSurfaceOffset
# would subtract Surface and sink it on the floor. Surface=3 is the slab top in
# 1x pixels (about 3/96 tile, Occupants plateTop), where items snap when dropped on it.
# movable group; the display name key is "<GroupName>_<CustomName>" in
# Moveables.json (DeadWeight_Digital_Scale). Noffset and friends are added by
# the loader itself from the sprite order (at most 3, well inside -96..96).
TILE_PROPS = {
    "BlocksPlacement": "",
    "CanScrap": "",
    "CustomName": "Digital Scale",
    "GroupName": "DeadWeight",
    "IsMoveAble": "",
    "IsTableTop": "",
    "Material": "Electric",
    "Material2": "SmallMetalPlates",
    "PickUpWeight": "5",
    "Surface": "3",
}


def i32(v):
    return struct.pack("<i", v)


def pstr(s):
    b = s.encode("latin-1")
    return i32(len(b)) + b


def tstr(s):
    return s.encode("utf-8") + b"\n"


def load_faces():
    faces = []
    for f in FACES:
        path = os.path.join(SRC_DIR, "digital_scale_%s.png" % f)
        im = Image.open(path).convert("RGBA")
        if im.size != (FRAME_W, FRAME_H):
            sys.exit("gen-tiles: %s is %s, must be %dx%d" % (path, im.size, FRAME_W, FRAME_H))
        bbox = im.getchannel("A").getbbox()
        if bbox is None:
            sys.exit("gen-tiles: %s is fully transparent" % path)
        faces.append((im.crop(bbox), bbox[0], bbox[1]))
    return faces


def _pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


def build_pack(faces):
    # Shelf packing, in face order, rows capped at PAGE_MAX_W.
    x = y = row_h = page_w = 0
    placed = []
    for im, ox, oy in faces:
        if x and x + im.width > PAGE_MAX_W:
            x, y, row_h = 0, y + row_h + PAD, 0
        placed.append((x, y))
        x += im.width + PAD
        row_h = max(row_h, im.height)
        page_w = max(page_w, x - PAD)
    page_h = y + row_h
    # Power of two page, at least 256x256 like the vanilla and the bulk of the
    # Workshop packs. A tight 190x29 page showed each face as a squashed window
    # over the whole page in game (2026-09-21); a padded page is the suspected fix.
    page_w, page_h = max(256, _pow2(page_w)), max(256, _pow2(page_h))
    page = Image.new("RGBA", (page_w, page_h), (0, 0, 0, 0))
    for (im, ox, oy), (px, py) in zip(faces, placed):
        page.paste(im, (px, py))
    buf = io.BytesIO()
    page.save(buf, format="PNG", optimize=False, compress_level=9)
    png = buf.getvalue()

    out = [b"PZPK", i32(1), i32(1), pstr(PAGE_NAME), i32(len(faces)), i32(1)]
    for idx, ((im, ox, oy), (px, py)) in enumerate(zip(faces, placed)):
        out.append(pstr("%s_%d" % (SHEET, idx)))
        for v in (px, py, im.width, im.height, ox, oy, FRAME_W, FRAME_H):
            out.append(i32(v))
    out.append(i32(len(png)))
    out.append(png)
    return b"".join(out)


def build_tiles():
    out = [b"tdef", i32(1), i32(1)]
    out += [tstr(SHEET), tstr(SHEET + ".png"), i32(len(FACES)), i32(1), i32(1), i32(len(FACES))]
    for face in FACES:
        props = dict(TILE_PROPS, Facing=face)
        out.append(i32(len(props)))
        for k in sorted(props):
            out += [tstr(k), tstr(props[k])]
    return b"".join(out)


def build_depth():
    lines = ["tileDepthTextureAssignments", "{", "    VERSION = 1,"]
    for i in range(len(FACES)):
        lines.append("    %s_%d = %s," % (SHEET, i, DEPTH_ASSIGN))
    lines.append("}")
    return ("\n".join(lines) + "\n").encode("utf-8")


def generate(base_dir):
    faces = load_faces()
    pack_path = os.path.join(base_dir, PACK_REL)
    tiles_path = os.path.join(base_dir, TILES_REL)
    os.makedirs(os.path.dirname(pack_path), exist_ok=True)
    with open(pack_path, "wb") as f:
        f.write(build_pack(faces))
    with open(tiles_path, "wb") as f:
        f.write(build_tiles())
    depth_path = os.path.join(base_dir, DEPTH_REL)
    with open(depth_path, "wb") as f:
        f.write(build_depth())
    return pack_path, tiles_path, depth_path


def split_pack(data):
    """(everything before the PNG length, decoded PNG pixels or None)."""
    pos = 12  # 'PZPK', version, page count
    n = struct.unpack_from("<i", data, pos)[0]
    pos += 4 + n
    entries = struct.unpack_from("<i", data, pos)[0]
    pos += 8
    for _ in range(entries):
        n = struct.unpack_from("<i", data, pos)[0]
        pos += 4 + n + 32
    length = struct.unpack_from("<i", data, pos)[0]
    png = data[pos + 4:pos + 4 + length]
    return data[:pos], Image.open(io.BytesIO(png)).convert("RGBA")


def same_pack(a, b):
    if a == b:
        return True
    try:
        ha, ia = split_pack(a)
        hb, ib = split_pack(b)
    except Exception:
        return False
    return ha == hb and ia.size == ib.size and ia.tobytes() == ib.tobytes()


def main():
    if "--check" not in sys.argv:
        for p in generate(ROOT):
            print("wrote " + os.path.relpath(p, ROOT))
        return
    with tempfile.TemporaryDirectory() as tmp:
        pack_new, tiles_new, depth_new = generate(tmp)
        bad = []
        for new, rel, same in (
            (pack_new, PACK_REL, same_pack),
            (tiles_new, TILES_REL, lambda a, b: a == b),
            (depth_new, DEPTH_REL, lambda a, b: a == b),
        ):
            live = os.path.join(ROOT, rel)
            if not os.path.isfile(live):
                bad.append(rel + " is missing")
                continue
            with open(new, "rb") as f1, open(live, "rb") as f2:
                if not same(f1.read(), f2.read()):
                    bad.append(rel + " does not match src/tiles (rerun without --check)")
        if bad:
            for b in bad:
                print("DRIFT: " + b, file=sys.stderr)
            sys.exit(1)
    print("gen-tiles: OK, no drift.")


if __name__ == "__main__":
    main()
