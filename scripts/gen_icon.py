#!/usr/bin/env python3
"""Generate Tapir app icon in Flexoki style — a stylized tapir silhouette."""

from PIL import Image, ImageDraw, ImageFont
import math, os

SIZE = 1024
CENTER = SIZE // 2

def hex_to_rgb(h):
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

# Flexoki palette
BG      = hex_to_rgb("FFFCF0")
BG_WARM = hex_to_rgb("F2F0E5")
CYAN    = hex_to_rgb("24837B")
GREEN   = hex_to_rgb("66800B")
PURPLE  = hex_to_rgb("5E409D")
YELLOW  = hex_to_rgb("AD8301")
TEXT    = hex_to_rgb("100F0F")
BORDER  = hex_to_rgb("D5CDB6")

def draw_rounded_rect(draw, xy, radius, fill, outline=None, width=0):
    x0, y0, x1, y1 = xy
    r = radius
    draw.rounded_rectangle(xy, radius=r, fill=fill, outline=outline, width=width)

def make_icon():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded square background
    pad = 20
    draw_rounded_rect(draw, (pad, pad, SIZE - pad, SIZE - pad), 180, fill=BG)

    # Subtle inner border
    draw_rounded_rect(draw, (pad, pad, SIZE - pad, SIZE - pad), 180, fill=None, outline=BORDER, width=4)

    # Top accent line
    draw_rounded_rect(draw, (pad + 40, pad, SIZE - pad - 40, pad + 6), 3, fill=CYAN)

    # "TAPIR" text — centered, large, Menlo bold
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 200)
    except:
        font = ImageFont.load_default()

    text = "TAPIR"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2
    ty = (SIZE - th) // 2 - 20

    draw.text((tx, ty), text, fill=TEXT, font=font)

    # Subtle cyan underline below text
    line_y = ty + th + 30
    draw_rounded_rect(draw, (200, line_y, SIZE - 200, line_y + 6), 3, fill=CYAN)

    # Small decorative dots
    for i in range(5):
        dx = 340 + i * 70
        draw.ellipse((dx, line_y + 30, dx + 8, line_y + 38), fill=BORDER)
        (240, 440),
    return img


def save_sizes(img, output_dir):
    sizes = [1024, 512, 256, 128, 64, 32, 16]
    os.makedirs(output_dir, exist_ok=True)

    for s in sizes:
        resized = img.resize((s, s), Image.LANCZOS)
        resized.save(os.path.join(output_dir, f"app_icon_{s}.png"))
        print(f"  saved app_icon_{s}.png")

    # Also save Contents.json
    entries = []
    size_map = {
        16: [("16x16", "1x"), ("16x16", "2x")],
        32: [("16x16", "2x"), ("32x32", "1x")],
        64: [("32x32", "2x")],
        128: [("128x128", "1x")],
        256: [("128x128", "2x"), ("256x256", "1x")],
        512: [("256x256", "2x"), ("512x512", "1x")],
        1024: [("512x512", "2x")],
    }

    contents = {
        "images": [
            {"size": "16x16", "idiom": "mac", "filename": "app_icon_16.png", "scale": "1x"},
            {"size": "16x16", "idiom": "mac", "filename": "app_icon_32.png", "scale": "2x"},
            {"size": "32x32", "idiom": "mac", "filename": "app_icon_32.png", "scale": "1x"},
            {"size": "32x32", "idiom": "mac", "filename": "app_icon_64.png", "scale": "2x"},
            {"size": "128x128", "idiom": "mac", "filename": "app_icon_128.png", "scale": "1x"},
            {"size": "128x128", "idiom": "mac", "filename": "app_icon_256.png", "scale": "2x"},
            {"size": "256x256", "idiom": "mac", "filename": "app_icon_256.png", "scale": "1x"},
            {"size": "256x256", "idiom": "mac", "filename": "app_icon_512.png", "scale": "2x"},
            {"size": "512x512", "idiom": "mac", "filename": "app_icon_512.png", "scale": "1x"},
            {"size": "512x512", "idiom": "mac", "filename": "app_icon_1024.png", "scale": "2x"},
        ],
        "info": {"version": 1, "author": "xcode"}
    }

    import json
    with open(os.path.join(output_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print("  saved Contents.json")


def save_tauri_icons(img, output_dir):
    """Save icons in the format Tauri expects."""
    os.makedirs(output_dir, exist_ok=True)

    # Tauri icon requirements
    tauri_sizes = {
        "32x32.png": 32,
        "128x128.png": 128,
        "128x128@2x.png": 256,
        "icon.png": 512,
    }

    for name, size in tauri_sizes.items():
        resized = img.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(output_dir, name))
        print(f"  saved {name} ({size}x{size})")

    # Generate .icns for macOS
    try:
        import subprocess
        iconset_dir = os.path.join(output_dir, "icon.iconset")
        os.makedirs(iconset_dir, exist_ok=True)

        icns_sizes = [16, 32, 64, 128, 256, 512, 1024]
        for s in icns_sizes:
            resized = img.resize((s, s), Image.LANCZOS)
            if s <= 512:
                resized.save(os.path.join(iconset_dir, f"icon_{s}x{s}.png"))
            if s >= 32:
                half = s // 2
                resized.save(os.path.join(iconset_dir, f"icon_{half}x{half}@2x.png"))

        subprocess.run(
            ["iconutil", "-c", "icns", iconset_dir, "-o", os.path.join(output_dir, "icon.icns")],
            check=True,
        )
        print("  saved icon.icns")

        # Cleanup iconset
        import shutil
        shutil.rmtree(iconset_dir)
    except Exception as e:
        print(f"  warning: could not generate .icns: {e}")

    # Generate .ico for Windows (future cross-platform)
    try:
        ico_sizes = [16, 32, 48, 64, 128, 256]
        ico_images = [img.resize((s, s), Image.LANCZOS) for s in ico_sizes]
        ico_images[0].save(
            os.path.join(output_dir, "icon.ico"),
            format="ICO",
            sizes=[(s, s) for s in ico_sizes],
            append_images=ico_images[1:],
        )
        print("  saved icon.ico")
    except Exception as e:
        print(f"  warning: could not generate .ico: {e}")


if __name__ == "__main__":
    print("Generating Tapir icon...")
    icon = make_icon()

    # Tauri icons
    tauri_output = os.path.join(os.path.dirname(__file__), "..", "src-tauri", "icons")
    save_tauri_icons(icon, tauri_output)
    print("Done!")
