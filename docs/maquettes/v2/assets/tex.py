#!/usr/bin/env python3
"""Small helpers to bake weathered textures the way the mod would ship them."""
import random
from PIL import Image, ImageDraw, ImageFilter

random.seed(4213)


def surface(w, h, top, bottom):
    """Vertical two-tone base, baked into the texture (no runtime gradient)."""
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c + (255,)
    return im


def grain(im, amount=7, density=0.55):
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or random.random() > density:
                continue
            n = random.randint(-amount, amount)
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)),
                        max(0, min(255, b + n)), a)
    return im


def bevel(im, light=(255, 252, 240, 70), dark=(40, 34, 24, 90), inset=0):
    w, h = im.size
    d = ImageDraw.Draw(im, "RGBA")
    d.line([(inset, inset), (w - 1 - inset, inset)], fill=light)
    d.line([(inset, inset), (inset, h - 1 - inset)], fill=light)
    d.line([(inset, h - 1 - inset), (w - 1 - inset, h - 1 - inset)], fill=dark)
    d.line([(w - 1 - inset, inset), (w - 1 - inset, h - 1 - inset)], fill=dark)
    return im


def rim(im, colour=(28, 26, 22, 210)):
    w, h = im.size
    ImageDraw.Draw(im, "RGBA").rectangle([0, 0, w - 1, h - 1], outline=colour)
    return im


def soil(im, n=70, tint=(120, 108, 84), alpha=(5, 16)):
    """Broad, very low-contrast staining: patches, never confetti."""
    w, h = im.size
    stain = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(stain, "RGBA")
    for _ in range(n):
        x, y = random.randrange(w), random.randrange(h)
        rx, ry = random.randint(5, 22), random.randint(3, 10)
        d.ellipse([x - rx, y - ry, x + rx, y + ry],
                  fill=tint + (random.randint(*alpha),))
    im.alpha_composite(stain.filter(ImageFilter.GaussianBlur(3.5)))
    return im


def wear(im, n, colour, along="edges"):
    """Chipped enamel: short nicks hugging the rim, 1 px tall."""
    w, h = im.size
    d = ImageDraw.Draw(im, "RGBA")
    for _ in range(n):
        if along == "edges":
            if random.random() < 0.6:
                x = random.randrange(2, max(3, w - 6))
                y = random.choice([0, 1, h - 2, h - 1])
                d.rectangle([x, y, x + random.randint(1, 4), y], fill=colour)
            else:
                y = random.randrange(2, max(3, h - 4))
                x = random.choice([0, 1, w - 2, w - 1])
                d.rectangle([x, y, x, y + random.randint(1, 3)], fill=colour)
        else:
            x, y = random.randrange(w), random.randrange(h)
            d.rectangle([x, y, x + random.randint(1, 3), y], fill=colour)
    return im


def soften(im, radius=0.4):
    return im.filter(ImageFilter.GaussianBlur(radius))
