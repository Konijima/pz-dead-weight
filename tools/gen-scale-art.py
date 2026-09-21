#!/usr/bin/env python3
"""Draws the Digital Scale's four faces into src/tiles/digital_scale_{S,E,N,W}.png.

Run by hand, NOT by sync.sh: the PNGs are the source art tools/gen-tiles.py
packs, and a hand refined PNG must not be overwritten on every sync. This
script is the reproducible first pass (a flat slab drawn in the game's own
isometric projection), so the art has no hidden dependency on extracted
vanilla sprites.

Projection, 2x tiles, frame 128x256, the tile's floor diamond is the bottom
64 rows (top corner (64,192), left (0,224), right (128,224), bottom (64,256)):
a point of the tile (u, v in 0..1, u grows right-down on screen, v grows
left-down) at height h pixels lands at
    x = 64 + (u - v) * 64,   y = 192 + (u + v) * 32 - h
The art sits at FLOOR level (no IsSurfaceOffset): on a counter the game lifts
the object by the counter's own surface height, see ISMoveableSpriteProps.

The LCD is drawn in the top plane's own coordinates, so it is a parallelogram
that follows the isometric plane, not a screen space rectangle. Its reader
stands on the edge the sprite faces (S: +v, E: +u, N: -v, W: -u) and its text
reads from there.

Usage: python3 tools/gen-scale-art.py
"""
import os
import random
from PIL import Image, ImageDraw, ImageFilter

SS = 4                      # supersampling, downscaled with a box filter
FRAME_W, FRAME_H = 128, 256
LO, HI = 0.33, 0.67         # footprint of the slab in the tile (0.34 tile square, a real bathroom scale is about 30 cm)
H = 5                       # slab thickness in 2x pixels (about 2.5/96 of a tile, 2.5 cm)
BEVEL = 0.018               # width of the silver rim line around the glass, tile units

# Look after the concept art Mathieu supplied (2026-09-21): black glass top,
# thin silver rim, brushed silver sides, two silver foot pads, an LCD at the
# far edge.
GLASS = (18, 21, 27, 255)
GLASS_LIT = (40, 45, 55, 255)    # far corner of the glass
GLASS_SHEEN = (48, 54, 66, 255)  # soft reflection band across the glass
RIM_FAR = (150, 152, 152, 255)   # silver frame, the two far edges
RIM_NEAR = (226, 228, 226, 255)  # silver frame, the two near edges (catch light)
LEFT_TOP, LEFT_BOT = (176, 178, 178, 255), (112, 114, 116, 255)     # the +v face
RIGHT_TOP, RIGHT_BOT = (128, 130, 132, 255), (74, 76, 80, 255)      # the +u face, in shade
PAD = (128, 132, 136, 255)
PAD_HI = (158, 162, 166, 255)
LCD = (150, 168, 140, 255)
LCD_BEZEL = (14, 16, 20, 255)
DIGIT = (36, 50, 36, 255)

# up (away from the reader) and right (reader's right hand) in (u, v), per facing
FACING = {
    "S": {"reader": (0, 1), "up": (0, -1), "right": (1, 0)},
    "E": {"reader": (1, 0), "up": (-1, 0), "right": (0, -1)},
    "N": {"reader": (0, -1), "up": (0, 1), "right": (-1, 0)},
    "W": {"reader": (-1, 0), "up": (1, 0), "right": (0, 1)},
}

# 3x5 pixel font, rows top to bottom
FONT = {
    "0": ["111", "101", "101", "101", "111"],
    "7": ["111", "001", "010", "010", "010"],
    "2": ["111", "001", "111", "100", "111"],
    "5": ["111", "100", "111", "001", "111"],
    ".": ["0", "0", "0", "0", "1"],
}
TEXT = "0.0"

LCD_W, LCD_D = 0.19, 0.08   # tile units, along the reader's right and up axes
LCD_MARGIN = 0.026          # from the far edge of the slab
PAD_X, PAD_W, PAD_LEN = 0.098, 0.05, 0.2   # pad centre offset, width, length


# The slab sits BACK_SHIFT tile fractions behind the tile centre (away from the
# reader): a counter is inset against its wall, so a slab centred in the tile
# ends up at the counter's front edge (seen in game, 2026-09-21). The plate
# centres in WeightScaleScales.lua carry the same shift.
BACK_SHIFT = 0.13
OFF = [0.0, 0.0]


def pt(u, v, h=0.0):
    u, v = u + OFF[0], v + OFF[1]
    return ((64 + (u - v) * 64) * SS, (192 + (u + v) * 32 - h) * SS)


def poly(d, pts, fill, outline=None):
    d.polygon([pt(*p) for p in pts], fill=fill)
    if outline:
        d.line([pt(*p) for p in pts + [pts[0]]], fill=outline, width=SS)


def local(face, right, up, h=H):
    """A point of the top plane at `right` (reader's right) and `up` (away from the reader) of the centre."""
    f = FACING[face]
    return (0.5 + f["right"][0] * right + f["up"][0] * up,
            0.5 + f["right"][1] * right + f["up"][1] * up, h)


def rect(face, r0, r1, u0, u1):
    return [local(face, r0, u0), local(face, r1, u0), local(face, r1, u1), local(face, r0, u1)]


def lerp(c0, c1, t):
    return tuple(int(round(c0[i] + (c1[i] - c0[i]) * t)) for i in range(4))


def strips(d, pts_fn, c0, c1, n):
    """Fill a shape in n slices whose colour runs c0 -> c1 (a cheap gradient).
    pts_fn(t0, t1) gives the polygon of the slice between t0 and t1."""
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        poly(d, pts_fn(t0, t1), lerp(c0, c1, (t0 + t1) / 2))


def draw_face(face):
    # No outline strokes: the game's own sprites shade edges with a darker or
    # lighter tone of the surface, never a black line (Mathieu, 2026-09-21).
    reader = FACING[face]["reader"]
    OFF[0], OFF[1] = -BACK_SHIFT * reader[0], -BACK_SHIFT * reader[1]
    img = Image.new("RGBA", (FRAME_W * SS, FRAME_H * SS), (0, 0, 0, 0))
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    grow = 0.05
    poly(sd, [(LO - grow, LO - grow, 0), (HI + grow, LO - grow, 0), (HI + grow, HI + grow, 0), (LO - grow, HI + grow, 0)],
         (0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SS * 1.6))
    d = ImageDraw.Draw(img)
    # the two visible sides, shaded top (chrome catch light) to bottom (in shade)
    strips(d, lambda t0, t1: [(LO, HI, H * (1 - t0)), (HI, HI, H * (1 - t0)), (HI, HI, H * (1 - t1)), (LO, HI, H * (1 - t1))],
           LEFT_TOP, LEFT_BOT, 6)
    strips(d, lambda t0, t1: [(HI, LO, H * (1 - t0)), (HI, HI, H * (1 - t0)), (HI, HI, H * (1 - t1)), (HI, LO, H * (1 - t1))],
           RIGHT_TOP, RIGHT_BOT, 6)
    # silver frame: dull on the far edges, bright on the two near edges
    poly(d, [(LO, LO, H), (HI, LO, H), (HI, HI, H), (LO, HI, H)], RIM_FAR)
    for a_, b_ in (((LO, HI), (HI, HI)), ((HI, LO), (HI, HI))):
        d.line([pt(a_[0], a_[1], H), pt(b_[0], b_[1], H)], fill=RIM_NEAR, width=SS)
    b = BEVEL
    lo, hi = LO + b, HI - b
    # the glass, lit from the far corner to the near corner
    strips(d, lambda t0, t1: [(lo + (hi - lo) * t0, lo, H), (lo + (hi - lo) * t1, lo, H),
                             (lo + (hi - lo) * t1, hi, H), (lo + (hi - lo) * t0, hi, H)],
           GLASS_LIT, GLASS, 8)
    half = 0.5 * (HI - LO) - b
    # a soft reflection band across the glass
    poly(d, [local(face, -half, half * 0.25), local(face, -half, half * 0.7),
             local(face, half * 0.3, -half), local(face, half * 0.75, -half)], GLASS_SHEEN)
    # two silver foot pads
    for side in (-1, 1):
        x0, x1 = side * PAD_X - PAD_W / 2, side * PAD_X + PAD_W / 2
        y0, y1 = -PAD_LEN / 2 - 0.02, PAD_LEN / 2 - 0.02
        poly(d, rect(face, x0, x1, y0, y1), PAD)
        poly(d, rect(face, x0, x1, (y0 + y1) / 2 + 0.006, y1), PAD_HI)
    # the LCD window and its digits, in the top plane, at the far edge
    top = 0.5 * (HI - LO) - LCD_MARGIN
    ur1 = top

    def lp(a, b_):
        return local(face, (a - 0.5) * LCD_W, ur1 - b_ * LCD_D)

    m = 0.012   # the dark bezel around the LCD
    poly(d, [local(face, -LCD_W / 2 - m, ur1 + m), local(face, LCD_W / 2 + m, ur1 + m),
             local(face, LCD_W / 2 + m, ur1 - LCD_D - m), local(face, -LCD_W / 2 - m, ur1 - LCD_D - m)], LCD_BEZEL)
    poly(d, [lp(0, 0), lp(1, 0), lp(1, 1), lp(0, 1)], LCD)
    cols = sum(len(FONT[c][0]) for c in TEXT) + (len(TEXT) - 1)   # glyph gaps of 1
    rows = 5
    padx, pady = 1.5, 1.0
    gw, gh = cols + 2 * padx, rows + 2 * pady
    x = padx
    for ch in TEXT:
        glyph = FONT[ch]
        for r, row in enumerate(glyph):
            for c, bit in enumerate(row):
                if bit == "1":
                    a0, a1 = (x + c) / gw, (x + c + 1) / gw
                    b0, b1 = (pady + r) / gh, (pady + r + 1) / gh
                    poly(d, [lp(a0, b0), lp(a1, b0), lp(a1, b1), lp(a0, b1)], DIGIT)
        x += len(glyph[0]) + 1
    out = Image.alpha_composite(shadow, img).resize((FRAME_W, FRAME_H), Image.BOX)
    return grain(out, face)


def grain(im, face):
    """A little fixed noise on opaque pixels, like the game's own tiles."""
    rnd = random.Random("dw-" + face)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a > 200:
                n = rnd.randint(-3, 3)
                px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)), a)
    return im


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "tiles")
    os.makedirs(out, exist_ok=True)
    for face in "SENW":
        draw_face(face).save(os.path.join(out, "digital_scale_%s.png" % face))
    print("wrote 4 faces to src/tiles")


if __name__ == "__main__":
    main()
