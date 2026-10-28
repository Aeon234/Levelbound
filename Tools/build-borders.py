"""Build Levelbound's Blizzard-style bar art from Forever's experience bar exports.

Usage:
    python Tools/build-borders.py blizzard <source-dir>
    python Tools/build-borders.py card <style-card.png>
    python Tools/build-borders.py icons <assets-dir>
    python Tools/build-borders.py pill
    python Tools/build-borders.py sidebar <svg-dir>

<source-dir> holds wow.export's 2x PNG exports of interface/hud/uiexperiencebar2xc60:
    ui-hud-experiencebar-frame-c60-2x.png                        frame, 2040 x 26
    ui-hud-experiencebar-divider-c60-2x.png                      divider, 8 x 14
    ui-hud-experiencebar-fill-reputation-faction-green-c60-2x.png fill, 2040 x 26
    ui-hud-experiencebar-frame-pip-c60-2x.png                    pip, 20 x 28
    ui-hud-experiencebar-frame-pip-mouseover-c60-2x.png          pip highlight, 24 x 28

Writes, as uncompressed 32-bit TGA with power-of-two canvases:
    Media/Borders/BlizzardBorderWhite.tga         the frame at 2x on a 2048 x 32 canvas, drawn in three slices
    Media/Borders/BlizzardDividerWhite.tga        the divider on an 8 x 16 canvas
    Media/Textures/BlizzardMask<Left|Right>.tga   32 x 64 alpha masks of the fill's beveled ends
    Media/Textures/LevelboundBlizzard.tga         the fill's two-tone profile as a 64 x 32 bar texture
    Media/Textures/MarkerPip-White.tga            the pip as a party marker, gray, at (0, 0) of a 32 x 32 canvas
    Media/Textures/MarkerPip-Highlight.tga        the pip's mouseover art unchanged, at (0, 0) of a 32 x 32 canvas

The frame and divider are made white by dividing each channel by a reference color, the 99th percentile of their
opaque pixels, so tinting with that color draws the art as exported; the script prints both colors. The bar texture
is the fill's brightness, its light half at full white, and the pip marker is the pip's brightness, its brightest
pixel at white, so a class color shades it. Requires Python 3 and Pillow.
"""

import math
import re
import sys
import xml.etree.ElementTree as ElementTree
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

FRAME = "ui-hud-experiencebar-frame-c60-2x.png"
DIVIDER = "ui-hud-experiencebar-divider-c60-2x.png"
FILL = "ui-hud-experiencebar-fill-reputation-faction-green-c60-2x.png"
PIP = "ui-hud-experiencebar-frame-pip-c60-2x.png"
PIP_HIGHLIGHT = "ui-hud-experiencebar-frame-pip-mouseover-c60-2x.png"

SLICE = 32  # mask width
CORNER = 13  # the frame's bevel fits a 13 px square at each corner
INSET = 2  # the fill starts 2 px inside the frame on every side, so the bar sits 1 UI unit inside it
OPAQUE = 200
PERCENTILE = 99


def load(directory, name):
    path = Path(directory) / name
    if not path.is_file():
        sys.exit(f"Missing {path}")

    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64)


def reference(image):
    """The 99th percentile of each color channel over the opaque pixels."""
    opaque = image[image[:, :, 3] >= OPAQUE][:, :3]

    return np.percentile(opaque, PERCENTILE, axis=0)


def whiten(image, tint):
    out = image.copy()
    out[:, :, :3] = np.clip(image[:, :, :3] / tint * 255, 0, 255)

    return out


def hex_color(tint):
    return "#" + "".join(f"{round(c):02X}" for c in tint)


def save(array, relative):
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.round(array).astype(np.uint8), "RGBA").save(path, compression=None)
    print(f"wrote {relative} ({array.shape[1]} x {array.shape[0]})")


def canvas(width, height):
    return np.zeros((height, width, 4))


def end_masks(fill):
    """The fill's beveled left end, over the bar's full height, as a white alpha mask, and its mirror image for the
    right end. A texture takes at most three masks, so each end's two corners share one mask; that suits only a bar of
    the art's own height."""
    rows = fill[:, CORNER + INSET, 3] >= 255
    top = int(np.argmax(rows))
    bottom = len(rows) - int(np.argmax(rows[::-1]))
    alpha = Image.fromarray(fill[top:bottom, INSET:INSET + CORNER, 3].astype(np.uint8), "L")
    alpha = np.asarray(alpha.resize((SLICE, 2 * SLICE), Image.BILINEAR)).astype(np.float64)
    mask = canvas(SLICE, 2 * SLICE)
    mask[:, :, :3] = 255
    mask[:, :, 3] = alpha

    return {"Left": mask, "Right": mask[:, ::-1]}


def bar_texture(fill):
    """The fill's opaque rows at its middle, as brightness (each pixel's strongest channel) with the light half at
    white, stretched to 64 x 32; the strongest channel keeps the dark half as bright, against the light one, as the
    saturated original."""
    column = fill[:, fill.shape[1] // 2]
    rows = column[column[:, 3] >= 255]
    brightness = rows[:, :3].max(axis=1)
    gray = np.clip(brightness / brightness.max() * 255, 0, 255)
    strip = np.repeat(gray[:, np.newaxis], 3, axis=1)
    strip = np.concatenate([strip, np.full((len(gray), 1), 255.0)], axis=1)
    image = Image.fromarray(np.round(strip[:, np.newaxis, :]).astype(np.uint8), "RGBA")

    return np.asarray(image.resize((64, 32), Image.BILINEAR)).astype(np.float64)


def grayscale(image):
    """Each pixel's strongest channel, scaled so the brightest opaque pixel is white; alpha kept."""
    out = image.copy()
    brightness = image[:, :, :3].max(axis=2)
    peak = brightness[image[:, :, 3] >= OPAQUE].max()
    out[:, :, :3] = np.clip(brightness / peak * 255, 0, 255)[:, :, np.newaxis]

    return out


def on_canvas(image, size):
    out = canvas(size, size)
    out[0:image.shape[0], 0:image.shape[1]] = image

    return out


def blizzard(directory):
    frame = load(directory, FRAME)
    divider = load(directory, DIVIDER)
    fill = load(directory, FILL)

    frame_tint = reference(frame)
    divider_tint = reference(divider)
    white_frame = whiten(frame, frame_tint)

    strip = canvas(2048, 32)
    strip[0:frame.shape[0], 0:frame.shape[1]] = white_frame
    save(strip, "Media/Borders/BlizzardBorderWhite.tga")

    marks = canvas(8, 16)
    marks[1:1 + divider.shape[0], 0:divider.shape[1]] = whiten(divider, divider_tint)
    save(marks, "Media/Borders/BlizzardDividerWhite.tga")

    for end, mask in end_masks(fill).items():
        save(mask, f"Media/Textures/BlizzardMask{end}.tga")

    save(bar_texture(fill), "Media/Textures/LevelboundBlizzard.tga")

    pip = load(directory, PIP)
    highlight = load(directory, PIP_HIGHLIGHT)
    save(on_canvas(grayscale(pip), SLICE), "Media/Textures/MarkerPip-White.tga")
    save(on_canvas(highlight, SLICE), "Media/Textures/MarkerPip-Highlight.tga")

    print(f"frame: {frame.shape[1]} x {frame.shape[0]} px; default tint {hex_color(frame_tint)}")
    print(f"divider: {divider.shape[1]} x {divider.shape[0]} px at (0, 1); default tint {hex_color(divider_tint)}")
    print(f"pip: {pip.shape[1]} x {pip.shape[0]} px; highlight {highlight.shape[1]} x {highlight.shape[0]} px")


CARD_FILL_ALPHA = 0.5  # the card interior's opacity against the art's own


def card(path):
    """Splits the starting-look card art into its frame and its interior, both at the art's own size for 9-slicing.

    Writes Media/Textures/StyleCardFrame.tga, the bronze band made white against its reference color with the black
    outline kept, and Media/Textures/StyleCardFill.tga, the black interior and its inner shadow at half their
    opacity. The interior is the black pixels reachable from the center without crossing the band.
    """
    art = np.asarray(Image.open(path).convert("RGBA")).astype(np.float64)
    height, width = art.shape[:2]
    black = (art[:, :, :3].max(axis=2) < 8) & (art[:, :, 3] > 0)
    inside = np.zeros((height, width), dtype=bool)
    queue = deque([(height // 2, width // 2)])

    while queue:
        y, x = queue.popleft()
        if not (0 <= y < height and 0 <= x < width) or inside[y, x] or not black[y, x]:
            continue
        inside[y, x] = True
        queue.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))

    fill = np.where(inside[:, :, np.newaxis], art, 0.0)
    fill[:, :, 3] *= CARD_FILL_ALPHA

    frame = np.where(inside[:, :, np.newaxis], 0.0, art)
    tint = reference(frame[frame[:, :, :3].max(axis=2) >= 8][np.newaxis, :, :])
    frame = whiten(frame, tint)

    save(frame, "Media/Textures/StyleCardFrame.tga")
    save(fill, "Media/Textures/StyleCardFill.tga")
    print(f"card: {width} x {height} px; frame default tint {hex_color(tint)}")


TOOLTIP_ICONS = {
    "levelbound-rested-moon-2026-10-13.png": "Media/Textures/TooltipRested.tga",
    "levelbound-quest-question-mark-2026-10-13.png": "Media/Textures/TooltipQuest.tga",
    "levelbound-pace-clock-2026-10-13.png": "Media/Textures/TooltipPace.tga",
    "levelbound-sharing-chat-arrow-2026-10-13.png": "Media/Textures/TooltipShare.tga",
}
ICON_SIZE = 64
ICON_MARGIN = 2  # transparent pixels kept on each side, so filtering never clips the mark


def icons(directory):
    """Scales the tooltip study icons to ICON_SIZE squares for inline tooltip textures.

    <assets-dir> is AeonDocs/design/assets, holding the four 1024 x 1024 study exports named in TOOLTIP_ICONS. Each mark
    is cropped to its opaque bounds, centered on a square, and resampled with premultiplied alpha so its edges keep
    their color; colors are kept, not made white.
    """
    for name, relative in TOOLTIP_ICONS.items():
        image = Image.open(Path(directory) / name).convert("RGBA")
        left, top, right, bottom = image.getchannel("A").getbbox()
        side = max(right - left, bottom - top)
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(image.crop((left, top, right, bottom)), ((side - (right - left)) // 2, (side - (bottom - top)) // 2))
        inner = ICON_SIZE - ICON_MARGIN * 2
        scaled = square.convert("RGBa").resize((inner, inner), Image.LANCZOS).convert("RGBA")
        out = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
        out.paste(scaled, (ICON_MARGIN, ICON_MARGIN))
        save(np.asarray(out).astype(np.float64), relative)


PILL_RADIUS = 64
PILL_SAMPLES = 4  # per axis, for each pixel's coverage of the disc


def pill():
    """Draws the Pill border style's end masks: each a white half disc filling a PILL_RADIUS x 2*PILL_RADIUS canvas,
    its flat side on the bar's side of the canvas, its edge antialiased by sampling each pixel's coverage, and the
    same half disc inverted, which hollows the outline's end caps.

    Writes Media/Textures/PillMaskLeft.tga (the disc's center on the canvas's right edge), PillMaskRight.tga (on its
    left edge), and PillHoleLeft.tga and PillHoleRight.tga, opaque outside the half disc. Drawn at half the bar's
    height wide and the bar's full height, each rounds one end.
    """
    width, height = PILL_RADIUS, PILL_RADIUS * 2
    offsets = (np.arange(PILL_SAMPLES) + 0.5) / PILL_SAMPLES
    xs = (np.arange(width)[:, np.newaxis] + offsets).reshape(-1)
    ys = (np.arange(height)[:, np.newaxis] + offsets).reshape(-1)
    inside = ((xs[np.newaxis, :] - width) ** 2 + (ys[:, np.newaxis] - PILL_RADIUS) ** 2) <= PILL_RADIUS ** 2
    coverage = inside.reshape(height, PILL_SAMPLES, width, PILL_SAMPLES).mean(axis=(1, 3))

    left = canvas(width, height)
    left[:, :, :3] = 255
    left[:, :, 3] = coverage * 255

    hole = left.copy()
    hole[:, :, 3] = 255 - left[:, :, 3]

    save(left, "Media/Textures/PillMaskLeft.tga")
    save(left[:, ::-1], "Media/Textures/PillMaskRight.tga")
    save(hole, "Media/Textures/PillHoleLeft.tga")
    save(hole[:, ::-1], "Media/Textures/PillHoleRight.tga")


SIDEBAR_SIZE = 64
SIDEBAR_SAMPLES = 4  # per axis, for each pixel's coverage of the stroke
SIDEBAR_ALPHA = 0.85  # the glyph's opacity, a step below the sidebar's white labels
SIDEBAR_STEPS = 24  # line segments per curve or arc
TOKEN = re.compile(r"[MmLlHhVvCcSsAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE]-?\d+)?")
ARGS = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "A": 7, "Z": 0}


def arc_points(start, rx, ry, rotation, large, sweep, end):
    """Points along an SVG endpoint arc, converted to its center form (SVG 1.1, appendix F.6.5)."""
    (x1, y1), (x2, y2) = start, end
    if rx == 0 or ry == 0 or (x1, y1) == (x2, y2):
        return [end]
    phi = math.radians(rotation)
    cos, sin = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    xp, yp = cos * dx + sin * dy, -sin * dx + cos * dy
    rx, ry = abs(rx), abs(ry)
    scale = (xp / rx) ** 2 + (yp / ry) ** 2
    if scale > 1:
        rx, ry = rx * math.sqrt(scale), ry * math.sqrt(scale)
    numerator = rx * rx * ry * ry - rx * rx * yp * yp - ry * ry * xp * xp
    factor = math.sqrt(max(0, numerator / (rx * rx * yp * yp + ry * ry * xp * xp)))
    if large == sweep:
        factor = -factor
    cxp, cyp = factor * rx * yp / ry, -factor * ry * xp / rx
    cx = cos * cxp - sin * cyp + (x1 + x2) / 2
    cy = sin * cxp + cos * cyp + (y1 + y2) / 2
    theta = math.atan2((yp - cyp) / ry, (xp - cxp) / rx)
    delta = math.atan2((-yp - cyp) / ry, (-xp - cxp) / rx) - theta
    if sweep and delta < 0:
        delta += 2 * math.pi
    elif not sweep and delta > 0:
        delta -= 2 * math.pi
    points = []
    for step in range(1, SIDEBAR_STEPS + 1):
        angle = theta + delta * step / SIDEBAR_STEPS
        ex, ey = rx * math.cos(angle), ry * math.sin(angle)
        points.append((cos * ex - sin * ey + cx, sin * ex + cos * ey + cy))

    return points


def path_segments(data):
    """Line segments approximating an SVG path's M, L, H, V, C, S, A and Z commands, absolute or relative."""
    tokens = TOKEN.findall(data)
    segments, index = [], 0
    current = start = (0.0, 0.0)
    command, control = None, None
    while index < len(tokens):
        if tokens[index].isalpha():
            command = tokens[index]
            index += 1
        upper, relative = command.upper(), command.islower()
        count = ARGS[upper]
        values = [float(token) for token in tokens[index:index + count]]
        index += count
        ox, oy = current if relative else (0.0, 0.0)
        points, next_control = [], None
        if upper == "M":
            current = start = (values[0] + ox, values[1] + oy)
            command = "l" if relative else "L"
            continue
        if upper == "Z":
            points = [start]
        elif upper == "L":
            points = [(values[0] + ox, values[1] + oy)]
        elif upper == "H":
            points = [(values[0] + ox, current[1])]
        elif upper == "V":
            points = [(current[0], values[0] + oy)]
        elif upper in ("C", "S"):
            if upper == "C":
                first = (values[0] + ox, values[1] + oy)
                rest = values[2:]
            else:
                first = (2 * current[0] - control[0], 2 * current[1] - control[1]) if control else current
                rest = values
            second = (rest[0] + ox, rest[1] + oy)
            end = (rest[2] + ox, rest[3] + oy)
            for step in range(1, SIDEBAR_STEPS + 1):
                t = step / SIDEBAR_STEPS
                u = 1 - t
                points.append(tuple(u ** 3 * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t ** 3 * p3
                    for p0, p1, p2, p3 in zip(current, first, second, end)))
            next_control = second
        elif upper == "A":
            points = arc_points(current, values[0], values[1], values[2], values[3] != 0, values[4] != 0,
                (values[5] + ox, values[6] + oy))
        for point in points:
            segments.append((current, point))
            current = point
        control = next_control
        if upper == "Z":
            current = start

    return segments


def svg_segments(path):
    """Every stroked shape of a sidebar glyph's SVG (circle, rect with rx, path) as line segments, in its units."""
    segments = []
    for element in ElementTree.parse(path).iter():
        tag = element.tag.rsplit("}", 1)[-1]
        number = lambda name: float(element.get(name, 0))
        if tag == "circle":
            cx, cy, r = number("cx"), number("cy"), number("r")
            segments += path_segments(f"M{cx + r} {cy}A{r} {r} 0 1 1 {cx - r} {cy}A{r} {r} 0 1 1 {cx + r} {cy}")
        elif tag == "rect":
            x, y, w, h, r = number("x"), number("y"), number("width"), number("height"), number("rx")
            segments += path_segments(f"M{x + r} {y}H{x + w - r}A{r} {r} 0 0 1 {x + w} {y + r}V{y + h - r}"
                f"A{r} {r} 0 0 1 {x + w - r} {y + h}H{x + r}A{r} {r} 0 0 1 {x} {y + h - r}V{y + r}"
                f"A{r} {r} 0 0 1 {x + r} {y}Z")
        elif tag == "path":
            segments += path_segments(element.get("d"))

    return segments


def sidebar(directory):
    """Draws the settings sidebar's page icons from their SVG glyphs.

    <svg-dir> is AeonDocs/design/assets/xp-addon/sidebar-icons, holding one 24-unit SVG per page, stroked with round
    caps and joins. Each is drawn white at SIDEBAR_ALPHA on a SIDEBAR_SIZE square: a pixel's alpha is the share of its
    samples within half the stroke width of any segment. Writes Media/Textures/Sidebar<Name>.tga for <Name>.svg.
    """
    files = sorted(Path(directory).glob("*.svg"))
    if not files:
        sys.exit(f"No SVG files in {directory}")
    offsets = (np.arange(SIDEBAR_SAMPLES) + 0.5) / SIDEBAR_SAMPLES
    axis = (np.arange(SIDEBAR_SIZE)[:, np.newaxis] + offsets).reshape(-1)
    xs, ys = np.meshgrid(axis, axis)
    for path in files:
        root = ElementTree.parse(path).getroot()
        scale = SIDEBAR_SIZE / float(root.get("viewBox").split()[2])
        half = float(root.get("stroke-width")) * scale / 2
        nearest = np.full(xs.shape, np.inf)
        for (ax, ay), (bx, by) in svg_segments(path):
            ax, ay, bx, by = ax * scale, ay * scale, bx * scale, by * scale
            vx, vy = bx - ax, by - ay
            length = vx * vx + vy * vy
            t = np.zeros(xs.shape) if length == 0 else np.clip(((xs - ax) * vx + (ys - ay) * vy) / length, 0, 1)
            nearest = np.minimum(nearest, np.hypot(xs - ax - t * vx, ys - ay - t * vy))
        coverage = (nearest <= half).reshape(SIDEBAR_SIZE, SIDEBAR_SAMPLES, SIDEBAR_SIZE, SIDEBAR_SAMPLES)
        image = canvas(SIDEBAR_SIZE, SIDEBAR_SIZE)
        image[:, :, :3] = 255
        image[:, :, 3] = coverage.mean(axis=(1, 3)) * 255 * SIDEBAR_ALPHA
        save(image, f"Media/Textures/Sidebar{path.stem}.tga")


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "blizzard":
        blizzard(sys.argv[2])
    elif len(sys.argv) == 3 and sys.argv[1] == "card":
        card(sys.argv[2])
    elif len(sys.argv) == 3 and sys.argv[1] == "icons":
        icons(sys.argv[2])
    elif len(sys.argv) == 2 and sys.argv[1] == "pill":
        pill()
    elif len(sys.argv) == 3 and sys.argv[1] == "sidebar":
        sidebar(sys.argv[2])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
