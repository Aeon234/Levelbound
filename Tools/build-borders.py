"""Build Levelbound's Blizzard-style bar art from Forever's experience bar exports.

Usage:
    python Tools/build-borders.py blizzard <source-dir>

<source-dir> holds wow.export's 2x PNG exports of interface/hud/uiexperiencebar2xc60:
    ui-hud-experiencebar-frame-c60-2x.png                        frame, 2040 x 26
    ui-hud-experiencebar-divider-c60-2x.png                      divider, 8 x 14
    ui-hud-experiencebar-fill-reputation-faction-green-c60-2x.png fill, 2040 x 26

Writes, as uncompressed 32-bit TGA with power-of-two canvases:
    Media/Borders/BlizzardBorderWhite.tga         the frame at 2x on a 2048 x 32 canvas, drawn in three slices
    Media/Borders/BlizzardEnhancedBorderWhite.tga a backdrop edge file, eight 32 px slices
    Media/Borders/BlizzardDividerWhite.tga        the divider on an 8 x 16 canvas
    Media/Textures/BlizzardMask<Corner>.tga       32 x 32 alpha masks of the fill's beveled corners
    Media/Textures/LevelboundBlizzard.tga         the fill's two-tone profile as a 64 x 32 bar texture

The frame and divider are made white by dividing each channel by a reference color, the 99th percentile of their
opaque pixels, so tinting with that color draws the art as exported; the script prints both colors. The bar texture
is the fill's brightness, its light half at full white. Requires Python 3 and Pillow.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

FRAME = "ui-hud-experiencebar-frame-c60-2x.png"
DIVIDER = "ui-hud-experiencebar-divider-c60-2x.png"
FILL = "ui-hud-experiencebar-fill-reputation-faction-green-c60-2x.png"

SLICE = 32  # edge file slice size
CORNER = 13  # the frame's bevel fits a 13 px square at each corner
INSET = 2  # the fill starts 2 px inside the frame on every side, so the bar sits 1 UI unit inside it
BAND_SAMPLE = slice(16, 64)  # columns past the bevel that give the straight bands' profile
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


def edge_file(frame):
    """Eight slices, left to right: left, right, top, bottom, top-left, top-right, bottom-left, bottom-right; the top
    and bottom edges are stored turned a quarter counterclockwise, as backdrop edge files are."""
    height = frame.shape[0]
    top = frame[0:CORNER, BAND_SAMPLE].mean(axis=1)  # rows from the outer edge in
    bottom = frame[height - CORNER:height, BAND_SAMPLE].mean(axis=1)
    left = frame[height // 2, 0:CORNER]  # columns from the outer edge in

    def left_slice():
        piece = canvas(SLICE, SLICE)
        piece[:, 0:CORNER] = left[np.newaxis, :, :]

        return piece

    def top_strip():
        strip = canvas(SLICE, SLICE)
        strip[0:CORNER, :] = top[:, np.newaxis, :]

        return strip

    def bottom_strip():
        strip = canvas(SLICE, SLICE)
        strip[SLICE - CORNER:SLICE, :] = bottom[:, np.newaxis, :]

        return strip

    def top_left():
        piece = top_strip()
        piece[CORNER:, 0:CORNER] = left[np.newaxis, :, :]
        piece[0:CORNER, 0:CORNER] = frame[0:CORNER, 0:CORNER]

        return piece

    def bottom_left():
        piece = bottom_strip()
        piece[0:SLICE - CORNER, 0:CORNER] = left[np.newaxis, :, :]
        piece[SLICE - CORNER:SLICE, 0:CORNER] = frame[height - CORNER:height, 0:CORNER]

        return piece

    slices = [
        left_slice(),
        left_slice()[:, ::-1],
        np.rot90(top_strip(), 1),
        np.rot90(bottom_strip(), 1),
        top_left(),
        top_left()[:, ::-1],
        bottom_left(),
        bottom_left()[:, ::-1],
    ]

    return np.concatenate(slices, axis=1)


def corner_masks(fill):
    """The fill's top-left bevel, measured from the bar's corner, as a white alpha mask, and its mirror images for
    the other corners."""
    alpha = Image.fromarray(fill[INSET:INSET + CORNER, INSET:INSET + CORNER, 3].astype(np.uint8), "L")
    alpha = np.asarray(alpha.resize((SLICE, SLICE), Image.BILINEAR)).astype(np.float64)
    mask = canvas(SLICE, SLICE)
    mask[:, :, :3] = 255
    mask[:, :, 3] = alpha

    return {
        "TopLeft": mask,
        "TopRight": mask[:, ::-1],
        "BottomLeft": mask[::-1, :],
        "BottomRight": mask[::-1, ::-1],
    }


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
    save(edge_file(white_frame), "Media/Borders/BlizzardEnhancedBorderWhite.tga")

    marks = canvas(8, 16)
    marks[1:1 + divider.shape[0], 0:divider.shape[1]] = whiten(divider, divider_tint)
    save(marks, "Media/Borders/BlizzardDividerWhite.tga")

    for corner, mask in corner_masks(fill).items():
        save(mask, f"Media/Textures/BlizzardMask{corner}.tga")

    save(bar_texture(fill), "Media/Textures/LevelboundBlizzard.tga")

    print(f"frame: {frame.shape[1]} x {frame.shape[0]} px; default tint {hex_color(frame_tint)}")
    print(f"divider: {divider.shape[1]} x {divider.shape[0]} px at (0, 1); default tint {hex_color(divider_tint)}")


def main():
    if len(sys.argv) != 3 or sys.argv[1] != "blizzard":
        sys.exit(__doc__)

    blizzard(sys.argv[2])


if __name__ == "__main__":
    main()
