#!/usr/bin/env python3
"""Generate alternate and pulsing HealthFit app icons from the primary icon."""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "HealthFit/HealthFit/HealthFit/Assets.xcassets"
SOURCE = ASSETS / "AppIcon.appiconset/AppIcon.png"
MASTER_SOURCE = ROOT / "scripts/app_icon_master.png"

YELLOW = (255, 214, 10)
RED = (255, 59, 48)
BROKEN_RED = (220, 45, 40)
GREEN_GLOW = (140, 255, 70)

PULSE_FRAMES = (
    {"scale": 1.0, "glow": 0.18, "ring": 0.0},
    {"scale": 1.05, "glow": 0.42, "ring": 0.55},
    {"scale": 1.1, "glow": 0.68, "ring": 1.0},
)


def is_heart_pixel(r: int, g: int, b: int, a: int) -> bool:
    if a < 40:
        return False
    return g > 90 and g > r + 20 and g > b + 10


def tint_icon(source: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    result = source.copy().convert("RGBA")
    pixels = result.load()
    width, height = result.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if not is_heart_pixel(r, g, b, a):
                continue

            intensity = min(1.0, max(0.35, g / 255.0))
            glow = min(1.0, (g - max(r, b)) / 180.0)
            mix = 0.55 + glow * 0.35
            pixels[x, y] = (
                int(color[0] * mix + r * (1 - mix) * intensity),
                int(color[1] * mix + g * (1 - mix) * intensity),
                int(color[2] * mix + b * (1 - mix) * intensity),
                a,
            )

    return result


def add_broken_effect(image: Image.Image) -> Image.Image:
    result = image.copy()
    draw = ImageDraw.Draw(result)
    width, height = result.size
    cx, cy = width // 2, int(height * 0.52)

    gap = int(width * 0.018)
    crack_points: list[tuple[float, float]] = []
    steps = 28
    for index in range(steps + 1):
        t = index / steps
        angle = -0.55 + t * 1.1
        radius = width * (0.16 + t * 0.14)
        x = cx + math.sin(angle) * radius
        y = cy + math.cos(angle) * radius * 0.95 - t * height * 0.04
        crack_points.append((x, y))

    if len(crack_points) >= 2:
        draw.line(crack_points, fill=(12, 12, 14, 255), width=max(4, width // 150), joint="curve")

    shard_shift = int(width * 0.03)
    left = result.crop((0, 0, cx - gap, height))
    right = result.crop((cx + gap, 0, width, height))
    composite = Image.new("RGBA", result.size, (0, 0, 0, 0))
    composite.paste(left, (-shard_shift, 2))
    composite.paste(right, (cx + gap + shard_shift, -2))
    return composite


def heart_mask(image: Image.Image) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    pixels = image.load()
    mask_pixels = mask.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if is_heart_pixel(r, g, b, a):
                mask_pixels[x, y] = min(255, a)
    return mask


def dilate_mask(mask: Image.Image, radius: int) -> Image.Image:
    size = max(3, radius * 2 + 1)
    return mask.filter(ImageFilter.MaxFilter(size))


def heart_center(image: Image.Image) -> tuple[int, int]:
    width, height = image.size
    mask = dilate_mask(heart_mask(image), radius=max(12, width // 70))
    bbox = mask.getbbox() or (0, 0, width, height)
    return (bbox[0] + bbox[2]) // 2, (bbox[1] + bbox[3]) // 2


def center_app_icon(image: Image.Image) -> Image.Image:
    """Shift the full icon so the heart sits in the middle of the canvas."""
    img = image.convert("RGBA")
    width, height = img.size
    content_cx, content_cy = heart_center(img)
    canvas_cx, canvas_cy = width // 2, height // 2
    offset = (canvas_cx - content_cx, canvas_cy - content_cy)
    if offset == (0, 0):
        return img

    background = img.getpixel((0, 0))
    canvas = Image.new("RGBA", (width, height), background)
    canvas.paste(img, offset, img)
    return canvas


def apply_pulse_frame(
    image: Image.Image,
    frame: dict[str, float],
    glow_color: tuple[int, int, int],
) -> Image.Image:
    width, height = image.size
    cx, cy = heart_center(image)
    base = Image.new("RGBA", image.size, image.getpixel((0, 0)))

    mask = heart_mask(image)
    bbox = mask.getbbox() or (0, 0, width, height)
    heart = Image.new("RGBA", image.size, (0, 0, 0, 0))
    heart.paste(image, mask=mask)

    scale = frame["scale"]
    scaled_size = (int(width * scale), int(height * scale))
    scaled_heart = heart.resize(scaled_size, Image.Resampling.LANCZOS)
    offset = (
        cx - scaled_size[0] // 2,
        cy - scaled_size[1] // 2,
    )
    base.paste(scaled_heart, offset, scaled_heart)

    glow_layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow_layer)
    glow_alpha = int(255 * frame["glow"])
    ring_alpha = int(180 * frame["ring"])
    for radius_factor, alpha_scale in ((0.34, 1.0), (0.42, 0.65), (0.5, 0.35)):
        radius = int(width * radius_factor * (0.96 + frame["ring"] * 0.08))
        color = (*glow_color, int(alpha_scale * glow_alpha))
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)

    if ring_alpha > 0:
        ring_radius = int(width * 0.46)
        draw.ellipse(
            (cx - ring_radius, cy - ring_radius, cx + ring_radius, cy + ring_radius),
            outline=(*glow_color, ring_alpha),
            width=max(4, width // 180),
        )

    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=width * 0.03))
    heart_layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    heart_layer.paste(scaled_heart, offset, scaled_heart)
    composed = Image.alpha_composite(base, glow_layer)
    composed = Image.alpha_composite(composed, heart_layer)
    return composed


def write_appiconset(name: str, image: Image.Image) -> None:
    folder = ASSETS / f"{name}.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    image.save(folder / f"{name}.png")
    contents = {
        "images": [
            {
                "filename": f"{name}.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def write_imageset(name: str, image: Image.Image) -> None:
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    image.save(folder / f"{name}.png")
    contents = {
        "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def generate_pulse_variants(base_name: str, image: Image.Image, glow_color: tuple[int, int, int]) -> list[str]:
    names: list[str] = []
    write_appiconset(base_name, apply_pulse_frame(image, PULSE_FRAMES[0], glow_color))
    names.append(base_name)

    for index in (1, 2):
        pulse_name = f"{base_name}Pulse{index}"
        write_appiconset(pulse_name, apply_pulse_frame(image, PULSE_FRAMES[index], glow_color))
        names.append(pulse_name)

    return names


def make_transparent_brand_heart(source: Image.Image) -> Image.Image:
    """Keep only the heart silhouette so UI glow rings stay visible behind it."""
    img = source.convert("RGBA")
    pixels = img.load()
    width, height = img.size

    green_mask = heart_mask(img)
    content_mask = dilate_mask(green_mask, radius=max(8, width // 90))
    content_pixels = content_mask.load()

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if content_pixels[x, y] == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue

            if is_heart_pixel(r, g, b, a):
                continue

            if r + g + b < 140:
                pixels[x, y] = (12, 12, 14, 255)
            else:
                pixels[x, y] = (0, 0, 0, 0)

    return center_brand_heart_content(img)


def center_brand_heart_content(image: Image.Image) -> Image.Image:
    """Center the heart artwork inside the square canvas for on-screen alignment."""
    img = image.convert("RGBA")
    alpha = img.split()[3]
    bbox = alpha.getbbox()
    if not bbox:
        return img

    target = img.size[0]
    cropped = img.crop(bbox)
    padding = int(max(cropped.size) * 0.06)
    content_side = max(cropped.size) + padding * 2
    scale = (target * 0.88) / content_side
    new_size = (
        max(1, int(cropped.width * scale)),
        max(1, int(cropped.height * scale)),
    )
    resized = cropped.resize(new_size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (target, target), (0, 0, 0, 0))
    canvas.paste(
        resized,
        ((target - new_size[0]) // 2, (target - new_size[1]) // 2),
        resized,
    )
    return canvas


def load_source_image() -> Image.Image:
    if MASTER_SOURCE.exists():
        return Image.open(MASTER_SOURCE).convert("RGBA")

    raw = Image.open(SOURCE).convert("RGBA")
    centered = center_app_icon(raw)
    MASTER_SOURCE.parent.mkdir(parents=True, exist_ok=True)
    centered.save(MASTER_SOURCE)
    return centered


def main() -> None:
    source = center_app_icon(load_source_image())
    alternate_names: list[str] = []

    write_imageset("BrandHeart", make_transparent_brand_heart(source))
    write_appiconset("AppIcon", apply_pulse_frame(source, PULSE_FRAMES[0], GREEN_GLOW))
    alternate_names.extend(generate_pulse_variants("AppIcon", source, GREEN_GLOW)[1:])

    yellow = tint_icon(source, YELLOW)
    red = tint_icon(source, RED)
    broken = add_broken_effect(tint_icon(source, BROKEN_RED))

    alternate_names.extend(generate_pulse_variants("AppIconYellow", yellow, YELLOW))
    alternate_names.extend(generate_pulse_variants("AppIconRed", red, RED))
    alternate_names.extend(generate_pulse_variants("AppIconBroken", broken, BROKEN_RED))

    plist_icons = {
        name: {
            "CFBundleIconFiles": [name],
            "UIPrerenderedIcon": False,
        }
        for name in alternate_names
        if name != "AppIcon"
    }

    print(f"Generated {len(alternate_names)} icon sets including pulse frames")
    print("Alternate icon keys:", ", ".join(sorted(plist_icons)))


if __name__ == "__main__":
    main()
