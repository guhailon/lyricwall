#!/usr/bin/env python3
"""Original icon + launch images for the LyricWall app (water + lyrics theme).
Gradient deep purple -> teal, star dust, sine water waves, big '歌词' type.
No other app's icon is copied.
"""
import math, random, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

PROJ = os.path.expanduser('~/workspace/lyricwall-ipa')
FONT = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'

TOP = (23, 17, 43)      # #17112b
MID = (43, 46, 110)
BOT = (13, 82, 94)      # #0D525E (mockup toolbar teal)
PINK = (233, 184, 221)  # #e9b8dd accent


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def base_image(w, h):
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        c = lerp(TOP, MID, t) if t < 0.55 else lerp(MID, BOT, (t - 0.55) / 0.45)
        d.line([(0, y), (w, y)], fill=c)
    return img


def add_stars(img, n, seed=7):
    rnd = random.Random(seed)
    w, h = img.size
    d = ImageDraw.Draw(img, 'RGBA')
    for _ in range(n):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h * 0.55)
        r = rnd.uniform(0.8, 2.6) * (w / 1024.0)
        a = rnd.randint(90, 220)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, a))
    return img


def add_waves(img, y0, amp, color, width, phase=0.0):
    w, h = img.size
    d = ImageDraw.Draw(img, 'RGBA')
    pts = []
    for x in range(0, w + 8, 8):
        y = y0 + amp * math.sin(x / w * math.pi * 2.2 + phase)
        pts.append((x, y))
    d.line(pts, fill=color + (150,), width=max(2, int(width)))
    return img


def add_text(img, text, size, y_frac, fill=(255, 255, 255), shadow=True):
    w, h = img.size
    font = ImageFont.truetype(FONT, size, index=0)
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x, y = (w - tw) // 2 - bbox[0], int(h * y_frac) - bbox[1]
    if shadow:
        d.text((x + size // 28, y + size // 22), text, font=font, fill=(5, 8, 30, 200))
    d.text((x, y), text, font=font, fill=fill + (255,))
    img.paste(Image.alpha_composite(img.convert('RGBA'), layer).convert('RGB'), (0, 0))
    return img


def make_icon(size):
    img = base_image(size, size)
    img = add_stars(img, 90)
    s = size / 1024.0
    img = add_waves(img, int(size * 0.68), int(26 * s), (255, 255, 255), max(3, int(7 * s)), 0.0)
    img = add_waves(img, int(size * 0.76), int(30 * s), PINK, max(3, int(6 * s)), 1.3)
    img = add_waves(img, int(size * 0.84), int(24 * s), (255, 255, 255), max(2, int(5 * s)), 2.6)
    img = add_text(img, '歌词', int(size * 0.34), 0.30)
    return img


def make_launch(w, h):
    img = base_image(w, h)
    img = add_stars(img, 110)
    s = min(w, h) / 780.0
    img = add_waves(img, int(h * 0.62), int(22 * s), (255, 255, 255), max(3, int(6 * s)), 0.0)
    img = add_waves(img, int(h * 0.68), int(26 * s), PINK, max(3, int(5 * s)), 1.3)
    img = add_waves(img, int(h * 0.74), int(20 * s), (255, 255, 255), max(2, int(4 * s)), 2.6)
    img = add_text(img, '歌词墙', int(w * 0.16), 0.42)
    return img


def main():
    os.makedirs(f'{PROJ}/icons', exist_ok=True)
    os.makedirs(f'{PROJ}/launch', exist_ok=True)
    master = make_icon(1024)
    for name, size in [
        ('AppIcon1024x1024', 1024), ('AppIcon60x60@3x', 180), ('AppIcon60x60@2x', 120),
        ('AppIcon76x76@2x', 152), ('AppIcon83.5x83.5@2x', 167),
        ('AppIcon29x29@3x', 87), ('AppIcon29x29@2x', 58),
        ('AppIcon40x40@3x', 120), ('AppIcon40x40@2x', 80),
    ]:
        im = master if size == 1024 else master.resize((size, size), Image.LANCZOS)
        im.save(f'{PROJ}/icons/{name}.png')
        print('icon', name, size)
    for name, (w, h) in [
        ('Default-568h@2x', (640, 1136)), ('Default-667h@2x', (750, 1334)),
        ('Default-736h@3x', (1242, 2208)), ('Default-1792h@2x', (828, 1792)),
        ('Default-2436h@3x', (1125, 2436)), ('Default-2688h@3x', (1242, 2688)),
    ]:
        make_launch(w, h).save(f'{PROJ}/launch/{name}.png')
        print('launch', name, w, h)


if __name__ == '__main__':
    main()
