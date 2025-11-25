#!/usr/bin/env python3
"""
Generate Play Store marketing assets from the in‑app icon.

Outputs:
  - store/play/icon_512.png (Play high‑res icon)
  - store/play/feature_graphic_1024x500.png (feature graphic)
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC_ICON = ROOT / 'assets' / 'icons' / 'app_icon.png'
OUT_DIR = ROOT / 'store' / 'play'
OUT_DIR.mkdir(parents=True, exist_ok=True)

def gen_icon_512():
    img = Image.open(SRC_ICON).convert('RGBA')
    out = img.resize((512, 512), Image.LANCZOS)
    (OUT_DIR / 'icon_512.png').write_bytes(b'')  # ensure created atomically
    out.save(OUT_DIR / 'icon_512.png', format='PNG')

def gen_feature_graphic():
    # Simple clean feature graphic using brand background + centered icon + title
    W, H = 1024, 500
    bg_top = (13, 15, 24)
    bg_bottom = (7, 9, 18)
    canvas = Image.new('RGBA', (W, H), bg_bottom + (255,))

    # vertical gradient
    grad = Image.linear_gradient('L').resize((W, H)).rotate(90)
    top_layer = Image.new('RGBA', (W, H), bg_top + (255,))
    canvas = Image.composite(top_layer, canvas, grad)

    icon = Image.open(SRC_ICON).convert('RGBA')
    # place icon at left third
    icon_h = int(H * 0.86)
    icon_w = icon_h
    icon = icon.resize((icon_w, icon_h), Image.LANCZOS)
    x = int(W * 0.08)
    y = (H - icon_h) // 2
    canvas.alpha_composite(icon, (x, y))

    # Title text on the right
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Avenir Next.ttc', 88)
    except Exception:
        font = ImageFont.load_default()
    title = 'HAPPEN HUB'
    tw = draw.textlength(title, font=font)
    tx = int(W * 0.48)
    ty = int(H * 0.32)
    draw.text((tx, ty), title, font=font, fill=(255, 255, 255, 255))

    canvas.save(OUT_DIR / 'feature_graphic_1024x500.png', format='PNG')

if __name__ == '__main__':
    gen_icon_512()
    gen_feature_graphic()
    print('Wrote:', OUT_DIR / 'icon_512.png')
    print('Wrote:', OUT_DIR / 'feature_graphic_1024x500.png')

