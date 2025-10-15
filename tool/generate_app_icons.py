#!/usr/bin/env python3
"""
Utility script to render the HappenHub application icon into all required
Android/iOS launcher sizes directly from code (no external tooling).

The generated artwork matches the vector master located at
`assets/icons/app_icon.svg`.
"""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path
from typing import Iterable, Tuple

ROOT = Path(__file__).resolve().parents[1]
BASE_SIZE = 1024.0

Color = Tuple[float, float, float, float]


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def mix_color(color_a: Iterable[int], color_b: Iterable[int], t: float) -> Color:
    ca = list(color_a)
    cb = list(color_b)
    return tuple(lerp(ca[i], cb[i], t) for i in range(3)) + (255.0,)


def blend(dst: Color, src: Color) -> Color:
    sr, sg, sb, sa = src
    dr, dg, db, da = dst

    sa /= 255.0
    da /= 255.0
    out_a = sa + da * (1.0 - sa)
    if out_a == 0:
        return (0.0, 0.0, 0.0, 0.0)

    out_r = (sr * sa + dr * da * (1.0 - sa)) / out_a
    out_g = (sg * sa + dg * da * (1.0 - sa)) / out_a
    out_b = (sb * sa + db * da * (1.0 - sa)) / out_a
    return (out_r, out_g, out_b, out_a * 255.0)


def clamp_channel(channel: float) -> int:
    return int(max(0.0, min(255.0, round(channel))))


def in_rounded_square(sx: float, sy: float) -> bool:
    """Check whether a point lies inside the rounded-square background."""
    corner_radius = 200.0
    left, top = 96.0, 96.0
    right = left + 832.0
    bottom = top + 832.0

    if sx < left or sx > right or sy < top or sy > bottom:
        return False

    inside_x = left + corner_radius <= sx <= right - corner_radius
    inside_y = top + corner_radius <= sy <= bottom - corner_radius
    if inside_x or inside_y:
        return True

    cx = left + corner_radius if sx < left + corner_radius else right - corner_radius
    cy = top + corner_radius if sy < top + corner_radius else bottom - corner_radius
    return (sx - cx) ** 2 + (sy - cy) ** 2 <= corner_radius ** 2


def load_png_alpha(path: Path) -> Tuple[int, int, list[list[int]]]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Not a PNG file")
    offset = 8
    width = height = None
    raw = bytearray()
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        offset += 4
        chunk = data[offset : offset + 4]
        offset += 4
        payload = data[offset : offset + length]
        offset += length
        offset += 4  # CRC
        if chunk == b"IHDR":
            width, height, *_ = struct.unpack(">IIBBBBB", payload)
        elif chunk == b"IDAT":
            raw.extend(payload)
        elif chunk == b"IEND":
            break
    if width is None or height is None:
        raise ValueError("Invalid PNG (missing IHDR)")

    def paeth(a: int, b: int, c: int) -> int:
        p = a + b - c
        pa = abs(p - a)
        pb = abs(p - b)
        pc = abs(p - c)
        if pa <= pb and pa <= pc:
            return a
        if pb <= pc:
            return b
        return c

    decompressed = zlib.decompress(bytes(raw))
    stride = width * 4

    alpha: list[list[int]] = []
    offset = 0
    prev_row = bytearray(stride)

    for _ in range(height):
        filter_type = decompressed[offset]
        offset += 1
        raw_row = bytearray(decompressed[offset : offset + stride])
        offset += stride

        recon = bytearray(stride)
        if filter_type == 0:  # None
            recon[:] = raw_row
        elif filter_type == 1:  # Sub
            for i in range(stride):
                left = recon[i - 4] if i >= 4 else 0
                recon[i] = (raw_row[i] + left) & 0xFF
        elif filter_type == 2:  # Up
            for i in range(stride):
                up = prev_row[i]
                recon[i] = (raw_row[i] + up) & 0xFF
        elif filter_type == 3:  # Average
            for i in range(stride):
                left = recon[i - 4] if i >= 4 else 0
                up = prev_row[i]
                recon[i] = (raw_row[i] + ((left + up) >> 1)) & 0xFF
        elif filter_type == 4:  # Paeth
            for i in range(stride):
                left = recon[i - 4] if i >= 4 else 0
                up = prev_row[i]
                up_left = prev_row[i - 4] if i >= 4 else 0
                recon[i] = (raw_row[i] + paeth(left, up, up_left)) & 0xFF
        else:
            raise ValueError(f"Unsupported filter type {filter_type}")

        row_alpha = [recon[i + 3] for i in range(0, stride, 4)]
        alpha.append(row_alpha)
        prev_row = recon
    return width, height, alpha


def line_distance(
    sx: float,
    sy: float,
    p1: Tuple[float, float],
    p2: Tuple[float, float],
) -> float:
    x1, y1 = p1
    x2, y2 = p2
    vx, vy = x2 - x1, y2 - y1
    wx, wy = sx - x1, sy - y1
    length_sq = vx * vx + vy * vy
    if length_sq == 0:
        return math.hypot(sx - x1, sy - y1)
    t = max(0.0, min(1.0, (wx * vx + wy * vy) / length_sq))
    proj_x = x1 + t * vx
    proj_y = y1 + t * vy
    return math.hypot(sx - proj_x, sy - proj_y)


def encode_png(pixels: Iterable[Iterable[Color]], size: int) -> bytes:
    rows = bytearray()
    for row in pixels:
        rows.append(0)
        for r, g, b, a in row:
            rows.extend(
                (
                    clamp_channel(r),
                    clamp_channel(g),
                    clamp_channel(b),
                    clamp_channel(a),
                )
            )

    compressed = zlib.compress(bytes(rows), 9)

    def chunk(tag: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(tag + payload) & 0xFFFFFFFF
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", crc)
        )

    header = chunk(
        b"IHDR",
        struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0),
    )
    data = chunk(b"IDAT", compressed)
    end = chunk(b"IEND", b"")
    return b"\x89PNG\r\n\x1a\n" + header + data + end


def soft_rect(
    sx: float,
    sy: float,
    x0: float,
    y0: float,
    x1: float,
    y1: float,
    radius: float = 24.0,
) -> float:
    if x0 <= sx <= x1 and y0 <= sy <= y1:
        return 1.0

    # corner distance
    cx = x0 if sx < x0 else x1
    cy = y0 if sy < y0 else y1
    dx = sx - cx
    dy = sy - cy
    if dx * dx + dy * dy <= radius * radius:
        return 1.0
    return 0.0


def render_icon(size: int) -> bytes:
    ratio = size / BASE_SIZE

    bg_a = (0x15, 0x1A, 0x2B)
    bg_b = (0x2F, 0x25, 0x50)
    center = (512.0, 512.0)

    ring_inner = 264.0
    ring_outer = ring_inner + 26.0
    glow_radius = 380.0

    top_arc = ((280.0, 404.0), (796.0, 404.0))
    bottom_arc = ((296.0, 688.0), (760.0, 716.0))

    accent_center = (646.0, 646.0)
    accent_outer = 34.0
    accent_inner = 18.0

    left_outer_bounds = (344.0, 320.0, 424.0, 704.0)
    left_inner_bounds = (452.0, 320.0, 532.0, 704.0)
    left_bridge_bounds = (364.0, 472.0, 512.0, 528.0)

    right_outer_bounds = (600.0, 320.0, 680.0, 704.0)
    right_inner_bounds = (708.0, 320.0, 788.0, 704.0)
    right_bridge_bounds = (628.0, 472.0, 776.0, 528.0)

    connector_bounds = (520.0, 552.0, 620.0, 620.0)

    def gradient_color(
        start: Tuple[int, int, int], end: Tuple[int, int, int], t: float
    ) -> Color:
        return (
            lerp(start[0], end[0], t),
            lerp(start[1], end[1], t),
            lerp(start[2], end[2], t),
            255.0,
        )

    def make_row(y: int) -> list[Color]:
        row: list[Color] = []
        sy = y / ratio
        for x in range(size):
            sx = x / ratio

            if in_rounded_square(sx, sy):
                diag = (sx - 96.0 + sy - 96.0) / (2.0 * 832.0)
                diag = max(0.0, min(1.0, diag))
                radial = min(1.0, math.hypot(sx - center[0], sy - center[1]) / 720.0)
                mix = diag * 0.55 + radial * 0.45
                base = mix_color(bg_a, bg_b, mix)
            else:
                base = (0.0, 0.0, 0.0, 0.0)

            dist_center = math.hypot(sx - center[0], sy - center[1])
            if dist_center <= glow_radius:
                glow_t = max(0.0, 1.0 - dist_center / glow_radius)
                base = blend(base, (118.0, 140.0, 205.0, glow_t * 58.0))

            if ring_inner <= dist_center <= ring_outer:
                offset = (dist_center - ring_inner) / (ring_outer - ring_inner)
                strength = max(0.0, 1.0 - abs(offset - 0.5) * 1.9)
                ring = (110.0, 214.0, 233.0, 120.0 + strength * 70.0)
                base = blend(base, ring)

            if dist_center <= 312.0:
                halo = max(0.0, 1.0 - dist_center / 312.0)
                base = blend(base, (100.0, 240.0, 250.0, halo * 34.0))

            top_dist = line_distance(sx, sy, *top_arc)
            if top_dist < 22.0 and sy < 440.0:
                falloff = max(0.0, 1.0 - (top_dist / 22.0) ** 1.4)
                base = blend(base, (0x61, 0xCF, 0xE0, falloff * 52.0))

            bottom_dist = line_distance(sx, sy, *bottom_arc)
            if bottom_dist < 20.0 and sy > 640.0:
                falloff = max(0.0, 1.0 - (bottom_dist / 20.0) ** 1.4)
                base = blend(base, (0x7F, 0x7C, 0xFF, falloff * 46.0))

            left_t = max(0.0, min(1.0, (sy - 320.0) / 384.0))
            left_color = gradient_color((0x66, 0xF2, 0xE4), (0x3F, 0xC6, 0xD8), left_t)

            if soft_rect(sx, sy, *left_outer_bounds, radius=28.0) > 0.0:
                base = blend(base, left_color)
            if soft_rect(sx, sy, *left_inner_bounds, radius=28.0) > 0.0:
                base = blend(base, left_color)
            if soft_rect(sx, sy, *left_bridge_bounds, radius=22.0) > 0.0:
                bridge_color = gradient_color(
                    (0x7A, 0xF6, 0xEE), (0x4D, 0xCE, 0xE0), left_t
                )
                base = blend(base, bridge_color)

            right_t = max(0.0, min(1.0, (sy - 320.0) / 384.0))
            right_color = gradient_color((0xA6, 0x9B, 0xFF), (0x5F, 0x60, 0xFF), right_t)

            if soft_rect(sx, sy, *right_outer_bounds, radius=28.0) > 0.0:
                base = blend(base, right_color)
            if soft_rect(sx, sy, *right_inner_bounds, radius=28.0) > 0.0:
                base = blend(base, right_color)
            if soft_rect(sx, sy, *right_bridge_bounds, radius=22.0) > 0.0:
                bridge_color_r = gradient_color(
                    (0xBE, 0xB6, 0xFF), (0x72, 0x6B, 0xFF), right_t
                )
                base = blend(base, bridge_color_r)

            if soft_rect(sx, sy, *connector_bounds, radius=26.0) > 0.0:
                base = blend(base, (26.0, 39.0, 58.0, 220.0))
                base = blend(base, (118.0, 226.0, 228.0, 45.0))

            accent_dist = math.hypot(sx - accent_center[0], sy - accent_center[1])
            if accent_dist <= accent_outer:
                alpha = max(0.0, 1.0 - accent_dist / accent_outer)
                base = blend(base, (99.0, 241.0, 224.0, alpha * 38.0))
            if accent_dist <= accent_inner:
                alpha = max(0.0, 1.0 - accent_dist / accent_inner)
                base = blend(base, (99.0, 241.0, 224.0, alpha * 85.0 + 30.0))

            row.append(base)
        return row

    pixels = [make_row(y) for y in range(size)]
    return encode_png(pixels, size)


def write_icon(path: Path, size: int, png_bytes: bytes | None = None) -> None:
    if png_bytes is None:
        png_bytes = render_icon(size)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png_bytes)


def main() -> None:
    android_targets = {
        "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
        "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
        "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
        "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    ios_targets = {
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png": 20,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png": 40,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png": 60,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png": 29,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png": 58,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png": 87,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png": 40,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png": 80,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png": 120,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png": 120,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png": 180,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png": 76,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png": 152,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png": 167,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png": 1024,
    }

    for rel_path, size in android_targets.items():
        png_bytes = render_icon(size)
        write_icon(ROOT / rel_path, size, png_bytes)
        write_icon(
            ROOT / rel_path.replace("ic_launcher.png", "ic_launcher_foreground.png"),
            size,
            png_bytes,
        )
        # Generate round variants to mirror Flutter defaults
        round_path = ROOT / rel_path.replace("ic_launcher.png", "ic_launcher_round.png")
        write_icon(round_path, size)

    for rel_path, size in ios_targets.items():
        write_icon(ROOT / rel_path, size)

    write_icon(ROOT / "assets/icons/app_icon.png", 1024)
    print("✅ App icons regenerated.")


if __name__ == "__main__":
    main()
