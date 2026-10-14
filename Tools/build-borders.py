"""Build Levelbound's Blizzard-style bar art from Forever's experience bar exports.

Usage:
    python Tools/build-borders.py blizzard <source-dir>
    python Tools/build-borders.py card <style-card.png>
    python Tools/build-borders.py icons <assets-dir>
    python Tools/build-borders.py pill

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

import sys
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


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "blizzard":
        blizzard(sys.argv[2])
    elif len(sys.argv) == 3 and sys.argv[1] == "card":
        card(sys.argv[2])
    elif len(sys.argv) == 3 and sys.argv[1] == "icons":
        icons(sys.argv[2])
    elif len(sys.argv) == 2 and sys.argv[1] == "pill":
        pill()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
