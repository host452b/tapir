#!/usr/bin/env python3
"""
generate pixel art T icon and mac app store preview images.
run from project root: python3 scripts/generate_assets.py
"""
from PIL import Image, ImageDraw, ImageFont
import os

# -- theme colors (from retro_theme.dart) --
BG_DEEP    = (8, 8, 26)
BG_PANEL   = (28, 28, 66)
NEON_CYAN  = (0, 229, 255)
NEON_GREEN = (0, 255, 136)
NEON_AMBER = (255, 184, 0)
NEON_MAG   = (255, 0, 128)
NEON_PURP  = (170, 85, 255)
TEXT_BRIGHT = (240, 240, 255)
GRID_COLOR  = (40, 25, 90)


def _lerp(a, b, t):
    return int(a + (b - a) * t)


def _lerp_color(c1, c2, t):
    return tuple(_lerp(c1[i], c2[i], t) for i in range(3))


def _blend_pixel(base, overlay, alpha):
    """blend overlay onto base with alpha (0-255)."""
    a = alpha / 255.0
    return tuple(min(255, int(base[i] * (1 - a) + overlay[i] * a)) for i in range(3))


def create_pixel_t_icon():
    """create a 32x32 pixel art T icon with retro-futurism neon style."""
    s = 32
    img = Image.new('RGBA', (s, s), (*BG_DEEP, 255))

    # radial gradient background
    cx, cy = s / 2, s / 2
    max_dist = (cx ** 2 + cy ** 2) ** 0.5
    for y in range(s):
        for x in range(s):
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            t = min(1.0, dist / max_dist)
            c = _lerp_color(BG_PANEL, BG_DEEP, t)
            img.putpixel((x, y), (*c, 255))

    # T dimensions
    bar_t, bar_b = 6, 11
    bar_l, bar_r = 5, 27
    stm_t, stm_b = bar_b, 26
    stm_l, stm_r = 13, 19

    # glow layer (2px halo around T, purple tint)
    glow_positions = set()
    for y in range(bar_t, bar_b):
        for x in range(bar_l, bar_r):
            glow_positions.add((x, y))
    for y in range(stm_t, stm_b):
        for x in range(stm_l, stm_r):
            glow_positions.add((x, y))

    for (px, py) in list(glow_positions):
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                nx, ny = px + dx, py + dy
                if 0 <= nx < s and 0 <= ny < s and (nx, ny) not in glow_positions:
                    d = max(abs(dx), abs(dy))
                    alpha = {1: 70, 2: 30}.get(d, 0)
                    if alpha > 0:
                        base = img.getpixel((nx, ny))[:3]
                        blended = _blend_pixel(base, NEON_PURP, alpha)
                        img.putpixel((nx, ny), (*blended, 255))

    # T body (white)
    for y in range(bar_t, bar_b):
        for x in range(bar_l, bar_r):
            img.putpixel((x, y), (*TEXT_BRIGHT, 255))
    for y in range(stm_t, stm_b):
        for x in range(stm_l, stm_r):
            img.putpixel((x, y), (*TEXT_BRIGHT, 255))

    # highlight edges (cyan on top and left)
    for x in range(bar_l, bar_r):
        img.putpixel((x, bar_t), (*NEON_CYAN, 255))
    for y in range(bar_t, bar_b):
        img.putpixel((bar_l, y), (*NEON_CYAN, 255))
    for y in range(stm_t, stm_b):
        img.putpixel((stm_l, y), (*_lerp_color(NEON_CYAN, TEXT_BRIGHT, 0.3), 255))

    # shadow edges (darker on bottom and right)
    shadow = (100, 100, 160)
    for x in range(bar_l, bar_r):
        img.putpixel((x, bar_b - 1), (*shadow, 255))
    for y in range(bar_t, bar_b):
        img.putpixel((bar_r - 1, y), (*shadow, 255))
    for y in range(stm_t, stm_b):
        img.putpixel((stm_r - 1, y), (*shadow, 255))
    for x in range(stm_l, stm_r):
        img.putpixel((x, stm_b - 1), (*shadow, 255))

    # corner accent pixels (cyan dots)
    corners = [
        [(2, 2), (3, 2), (2, 3)],
        [(29, 2), (28, 2), (29, 3)],
        [(2, 29), (3, 29), (2, 28)],
        [(29, 29), (28, 29), (29, 28)],
    ]
    for group in corners:
        for cx, cy in group:
            base = img.getpixel((cx, cy))[:3]
            blended = _blend_pixel(base, NEON_CYAN, 140)
            img.putpixel((cx, cy), (*blended, 255))

    # subtle scanline effect
    for y in range(0, s, 2):
        for x in range(s):
            px = img.getpixel((x, y))[:3]
            darker = tuple(max(0, c - 6) for c in px)
            img.putpixel((x, y), (*darker, 255))

    return img


def generate_icons(base_img, output_dir):
    """resize the base 32x32 to all required macos icon sizes."""
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    os.makedirs(output_dir, exist_ok=True)
    for sz in sizes:
        scaled = base_img.resize((sz, sz), Image.NEAREST)
        path = os.path.join(output_dir, f'app_icon_{sz}.png')
        scaled.save(path)
        print(f'  icon {sz}x{sz} -> {path}')


def _load_font(size):
    """try system monospace fonts, fallback to default."""
    candidates = [
        '/System/Library/Fonts/Menlo.ttc',
        '/System/Library/Fonts/SFMono-Regular.otf',
        '/System/Library/Fonts/Monaco.dfont',
        '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def _draw_gradient_bg(draw, w, h):
    """draw a purple gradient background with grid overlay."""
    for y in range(h):
        t = y / h
        r = _lerp(35, 10, t)
        g = _lerp(18, 8, t)
        b = _lerp(85, 42, t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    spacing = w // 24
    for x in range(0, w, spacing):
        draw.line([(x, 0), (x, h)], fill=GRID_COLOR, width=1)
    for y in range(0, h, spacing):
        draw.line([(0, y), (w, y)], fill=GRID_COLOR, width=1)


def _draw_corner_brackets(draw, w, h, pad, color, size=40, lw=3):
    """draw decorative corner brackets."""
    tl = (pad, pad)
    draw.line([tl, (tl[0], tl[1] + size)], fill=color, width=lw)
    draw.line([tl, (tl[0] + size, tl[1])], fill=color, width=lw)
    tr = (w - pad, pad)
    draw.line([tr, (tr[0], tr[1] + size)], fill=color, width=lw)
    draw.line([tr, (tr[0] - size, tr[1])], fill=color, width=lw)
    bl = (pad, h - pad)
    draw.line([bl, (bl[0], bl[1] - size)], fill=color, width=lw)
    draw.line([bl, (bl[0] + size, bl[1])], fill=color, width=lw)
    br = (w - pad, h - pad)
    draw.line([br, (br[0], br[1] - size)], fill=color, width=lw)
    draw.line([br, (br[0] - size, br[1])], fill=color, width=lw)


def create_store_screenshot(w, h, title, subtitle, bullets, accent, filename):
    """create a product preview screenshot for mac app store."""
    img = Image.new('RGB', (w, h))
    draw = ImageDraw.Draw(img)

    _draw_gradient_bg(draw, w, h)
    _draw_corner_brackets(draw, w, h, w // 20, accent, size=w // 25, lw=max(2, w // 500))

    f_hero = _load_font(w // 14)
    f_sub = _load_font(w // 28)
    f_body = _load_font(w // 42)
    f_brand = _load_font(w // 22)

    pad_x = w // 8
    y_pos = h // 5

    # accent bar above title
    draw.rectangle([pad_x, y_pos - 12, pad_x + w // 4, y_pos - 6], fill=accent)

    # title (white)
    draw.text((pad_x, y_pos), title, fill=TEXT_BRIGHT, font=f_hero)
    y_pos += f_hero.size + w // 40

    # subtitle (light purple)
    draw.text((pad_x, y_pos), subtitle, fill=(180, 170, 230), font=f_sub)
    y_pos += f_sub.size + w // 20

    # horizontal divider
    draw.line([(pad_x, y_pos), (w - pad_x, y_pos)], fill=(*accent, ), width=1)
    y_pos += w // 30

    # feature bullets
    for bullet in bullets:
        dot_y = y_pos + f_body.size // 2
        draw.rectangle([pad_x, dot_y - 4, pad_x + 8, dot_y + 4], fill=accent)
        draw.text((pad_x + 24, y_pos), bullet, fill=(225, 225, 245), font=f_body)
        y_pos += f_body.size + w // 50

    # brand + tagline at bottom
    brand_y = h - h // 7
    draw.text((pad_x, brand_y), 'TAPIR', fill=NEON_CYAN, font=f_brand)
    tag_x = pad_x + f_brand.getlength('TAPIR') + 20
    draw.text((tag_x, brand_y + f_brand.size // 4), 'keyboard automation tool',
              fill=(120, 120, 180), font=f_body)

    img.save(filename, quality=95)
    print(f'  screenshot -> {filename}')


def main():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(project_root)

    print('=== generating pixel art T icon ===')
    base = create_pixel_t_icon()
    icon_dir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    generate_icons(base, icon_dir)

    print('\n=== generating mac app store screenshots ===')
    ss_dir = 'app_store_assets'
    os.makedirs(ss_dir, exist_ok=True)

    screens = [
        {
            'title': 'SMART TARGETING',
            'subtitle': 'Discover & select any visible window by PID',
            'bullets': [
                'Scan all on-screen windows instantly',
                'Search by app name, window title, or PID',
                'View process hierarchy and child count',
                'One-click target selection with live preview',
            ],
            'accent': NEON_CYAN,
            'file': 'screenshot_1_target',
        },
        {
            'title': 'KEY AUTOMATION',
            'subtitle': 'Build sequences with KEY, TEXT, and COMBO modes',
            'bullets': [
                'Single key press with Cmd/Ctrl/Opt/Shift modifiers',
                'Type strings character by character',
                'Chain PREFIX key -> text -> SUFFIX key combos',
                'Drag-to-reorder, duplicate, and manage steps',
            ],
            'accent': NEON_PURP,
            'file': 'screenshot_2_keys',
        },
        {
            'title': 'LIVE CONTROL',
            'subtitle': 'Monitor every key event in real time',
            'bullets': [
                'Animated LED progress bar with interval cycle',
                'Infinite loop or finite N-cycle repeat mode',
                'Pause, resume, or stop at any time',
                'Timestamped event log for debugging',
            ],
            'accent': NEON_GREEN,
            'file': 'screenshot_3_control',
        },
        {
            'title': 'RETRO TERMINAL',
            'subtitle': '16-bit pixel art meets modern macOS automation',
            'bullets': [
                'Cyberpunk neon color palette with glow effects',
                'Monospace typography throughout the interface',
                'Native CGEvent API for zero-latency dispatch',
                'Built with Flutter + Swift, open source',
            ],
            'accent': NEON_MAG,
            'file': 'screenshot_4_design',
        },
        {
            'title': 'BUILT FOR macOS',
            'subtitle': 'Accessibility-first design with native integration',
            'bullets': [
                'Built-in permission check and grant flow',
                'CGEvent posted directly to target process',
                'Sandboxless architecture for full key access',
                'Works with any app: terminals, browsers, games',
            ],
            'accent': NEON_AMBER,
            'file': 'screenshot_5_system',
        },
    ]

    # mac app store sizes
    store_sizes = [(2880, 1800), (1440, 900)]

    for sc in screens:
        for w, h in store_sizes:
            suffix = f'{w}x{h}'
            path = os.path.join(ss_dir, f'{sc["file"]}_{suffix}.png')
            create_store_screenshot(
                w, h,
                sc['title'], sc['subtitle'],
                sc['bullets'], sc['accent'], path,
            )

    print('\n=== done ===')


if __name__ == '__main__':
    main()
