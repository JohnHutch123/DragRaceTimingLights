"""Draws the Drag Tree app icon and writes every size Delphi 12 asks for.

Run:  python make_icons.py      (needs Pillow: pip install pillow)
Output goes into the Android, iOS, macOS, Windows and Store folders next to
this script. Change the colours or layout below and run it again.
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
SS = 2048  # master drawing size (downscaled for every output)

AMBER = (255, 170, 20)
GREEN = (40, 235, 90)
RED_OFF = (70, 12, 12)
STAGE = (255, 236, 160)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def background(size):
    """Night sky fading to a dark track, with a faint glow behind the tree."""
    bg = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(bg)
    top, bottom = (18, 24, 48), (4, 5, 10)
    for y in range(size):
        d.line([(0, y), (size, y)], fill=lerp(top, bottom, y / size) + (255,))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    r = size * 0.36
    c = size / 2
    gd.ellipse([c - r, c - r * 1.15, c + r, c + r * 1.15], fill=(255, 150, 30, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.09))
    return Image.alpha_composite(bg, glow)


def bulb(layer, glow, cx, cy, r, colour, lit):
    d = ImageDraw.Draw(layer)
    # chrome visor ring
    ring = r * 1.18
    d.ellipse([cx - ring, cy - ring, cx + ring, cy + ring], fill=(120, 124, 132, 255))
    ring2 = r * 1.08
    d.ellipse([cx - ring2, cy - ring2, cx + ring2, cy + ring2], fill=(12, 12, 14, 255))
    if lit:
        # soft halo on the glow layer
        gd = ImageDraw.Draw(glow)
        h = r * 1.9
        gd.ellipse([cx - h, cy - h, cx + h, cy + h], fill=colour + (150,))
        # lens: bright centre fading to the colour at the rim
        steps = 24
        for i in range(steps):
            t = i / (steps - 1)
            rr = r * (1 - 0.85 * t)
            col = lerp(lerp(colour, (0, 0, 0), 0.30), lerp(colour, (255, 255, 230), 0.55), t ** 1.6)
            off = r * 0.12 * t
            d.ellipse([cx - rr - off, cy - rr - off, cx + rr - off, cy + rr - off], fill=col + (255,))
    else:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour + (255,))
        hl = r * 0.35
        d.ellipse([cx - r * 0.5 - hl, cy - r * 0.5 - hl, cx - r * 0.5 + hl, cy - r * 0.5 + hl],
                  fill=lerp(colour, (255, 255, 255), 0.15) + (255,))


def tree(size, scale=1.0):
    """The tree on a transparent layer: two lanes, stage bulbs, 3 ambers, green, red."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    u = size / 1024 * scale * 0.92  # design units are for a 1024 canvas
    cx, cy = size / 2, size / 2
    r = 54 * u          # main bulb radius
    pitch = 150 * u     # row spacing
    lane = 88 * u       # half distance between lane centres
    rows = 5
    hw = 170 * u                                  # housing half width
    hh = (170 + pitch / u * (rows - 1) + 95) * u  # housing height
    ht = cy - hh / 2                              # housing top
    hb = ht + hh                                  # housing bottom
    top = ht + 170 * u                            # first amber row

    d = ImageDraw.Draw(layer)
    if scale >= 0.85:  # pole under the housing (left off the small adaptive layer)
        d.rectangle([cx - 26 * u, hb - 20 * u, cx + 26 * u, size], fill=(48, 50, 56, 255))
    d.rounded_rectangle([cx - hw, ht, cx + hw, hb], radius=44 * u, fill=(150, 154, 162, 255))
    d.rounded_rectangle([cx - hw + 10 * u, ht + 10 * u, cx + hw - 10 * u, hb - 10 * u],
                        radius=36 * u, fill=(22, 23, 27, 255))
    # pre-stage and stage bulbs (two small ones per lane)
    sr = 20 * u
    for side in (-1, 1):
        for k in range(2):
            x = cx + side * lane + (k * 2 - 1) * 30 * u
            y = ht + 64 * u
            bulb(layer, glow, x, y, sr, STAGE, True)
    # main bulbs
    colours = [(AMBER, True)] * 3 + [(GREEN, True), (RED_OFF, False)]
    for i, (col, lit) in enumerate(colours):
        y = top + i * pitch
        for side in (-1, 1):
            bulb(layer, glow, cx + side * lane, y, r, col, lit)
    glow = glow.filter(ImageFilter.GaussianBlur(28 * u))
    out = Image.alpha_composite(glow, layer)
    # a little bloom over the housing so the lit bulbs look bright
    bloom = glow.copy()
    bloom.putalpha(bloom.getchannel("A").point(lambda a: a * 0.45))
    return Image.alpha_composite(out, bloom)


def rounded_mask(size, radius_frac, inset=0):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([inset, inset, size - 1 - inset, size - 1 - inset],
                                        radius=(size - 2 * inset) * radius_frac, fill=255)
    return m


def full_icon(size=SS):
    return Image.alpha_composite(background(size), tree(size))


def save(img, path, size, rgb=False):
    out = img.resize((size, size), Image.LANCZOS)
    if rgb:
        out = out.convert("RGB")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path, optimize=True)


def main():
    master = full_icon()

    # Rounded square used for Android legacy launcher icons and Windows
    rounded = master.copy()
    rounded.putalpha(ImageChops.multiply(master.getchannel("A"), rounded_mask(SS, 0.18)))

    # --- Android legacy launcher icons (Project Options > Icons > Android)
    for s in (36, 48, 72, 96, 144, 192):
        save(rounded, f"{HERE}/Android/LauncherIcon_{s}x{s}.png", s)

    # --- Android adaptive icon layers (Android 8+), 432 px = 108 dp at xxxhdpi
    fg = tree(SS, scale=0.72)
    save(fg, f"{HERE}/Android/Adaptive/ic_launcher_foreground.png", 432)
    save(background(SS), f"{HERE}/Android/Adaptive/ic_launcher_background.png", 432)
    mono = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    mono.putalpha(fg.getchannel("A").point(lambda a: 255 if a > 140 else 0))
    save(mono, f"{HERE}/Android/Adaptive/ic_launcher_monochrome.png", 432)

    # --- Google Play store listing icon: 512x512, square (Play rounds it)
    save(master, f"{HERE}/Store/PlayStore_512x512.png", 512, rgb=True)
    # Apple App Store icon: 1024x1024, square, no transparency
    save(master, f"{HERE}/Store/AppStore_1024x1024.png", 1024, rgb=True)

    # --- iOS (square, no transparency; iOS rounds the corners itself)
    ios = {
        "iPhone_AppIcon_120x120": 120, "iPhone_AppIcon_180x180": 180,
        "iPhone_Spotlight_80x80": 80, "iPhone_Spotlight_120x120": 120,
        "iPhone_Setting_58x58": 58, "iPhone_Setting_87x87": 87,
        "iPhone_Notification_40x40": 40, "iPhone_Notification_60x60": 60,
        "iPad_AppIcon_152x152": 152, "iPad_AppIcon_167x167": 167,
        "iPad_Spotlight_80x80": 80, "iPad_Setting_58x58": 58,
        "iPad_Notification_40x40": 40, "iOS_AppStore_1024x1024": 1024,
    }
    for name, s in ios.items():
        save(master, f"{HERE}/iOS/{name}.png", s, rgb=True)

    # --- macOS .icns: Big Sur style rounded tile with margin and shadow
    tile = 824 * SS // 1024
    t = master.resize((tile, tile), Image.LANCZOS)
    t.putalpha(rounded_mask(tile, 0.225))
    mac = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    off = (SS - tile) // 2
    shadow.paste((0, 0, 0, 110), (off, off + 20 * SS // 1024), t.getchannel("A"))
    shadow = shadow.filter(ImageFilter.GaussianBlur(20 * SS // 1024))
    mac = Image.alpha_composite(mac, shadow)
    mac.alpha_composite(t, (off, off))
    mac1024 = mac.resize((1024, 1024), Image.LANCZOS)
    os.makedirs(f"{HERE}/macOS", exist_ok=True)
    mac1024.save(f"{HERE}/macOS/DragTree.icns")
    mac1024.save(f"{HERE}/macOS/DragTree_1024x1024.png", optimize=True)

    # --- Windows .ico
    os.makedirs(f"{HERE}/Windows", exist_ok=True)
    rounded.resize((256, 256), Image.LANCZOS).save(
        f"{HERE}/Windows/DragTree.ico",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


if __name__ == "__main__":
    main()
