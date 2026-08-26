#!/usr/bin/env python3
"""Generate Qliq's app icon source (1024x1024 PNG).

Run with any Python that has Pillow installed:

    python3 scripts/make-icon.py

The output, Resources/AppIcon-Source.png, is the single source image that
`make icon` downsamples into Resources/AppIcon.icns. Keeping this script in the
repository means the icon is reproducible rather than an opaque binary.

Design: a rounded indigo squircle with a white waveform. Deliberately simple so
it stays legible at 16x16 in the menu bar.
"""

import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
MARGIN = 64
RADIUS = 224

TOP = (99, 91, 255)
BOTTOM = (53, 26, 176)


def vertical_gradient(size, top, bottom):
    gradient = Image.new("RGB", size)
    pixels = gradient.load()
    for y in range(size[1]):
        t = y / (size[1] - 1)
        pixels_row = tuple(
            round(top[channel] + (bottom[channel] - top[channel]) * t)
            for channel in range(3)
        )
        for x in range(size[0]):
            pixels[x, y] = pixels_row
    return gradient


def squircle_mask(size, margin, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        [margin, margin, size[0] - margin, size[1] - margin],
        radius=radius,
        fill=255,
    )
    return mask


def waveform(size, heights, bar_width, gap, fill):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    total_width = len(heights) * bar_width + (len(heights) - 1) * gap
    x = (size[0] - total_width) // 2
    center_y = size[1] // 2
    for height in heights:
        top = center_y - height // 2
        draw.rounded_rectangle(
            [x, top, x + bar_width, top + height],
            radius=bar_width // 2,
            fill=fill,
        )
        x += bar_width + gap
    return layer


def main():
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    gradient = vertical_gradient((SIZE, SIZE), TOP, BOTTOM).convert("RGBA")
    mask = squircle_mask((SIZE, SIZE), MARGIN, RADIUS)

    body = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    body.paste(gradient, (0, 0), mask)

    # Soft highlight along the upper edge for a little depth.
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.ellipse(
        [MARGIN + 60, MARGIN - 240, SIZE - MARGIN - 60, MARGIN + 300],
        fill=(255, 255, 255, 26),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(60))
    body = Image.alpha_composite(body, Image.composite(highlight, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), mask))

    bars = [168, 268, 392, 470, 392, 268, 168]
    body = Image.alpha_composite(
        body,
        waveform((SIZE, SIZE), bars, bar_width=56, gap=44, fill=(255, 255, 255, 255)),
    )

    out_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Resources")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "AppIcon-Source.png")
    body.save(out_path)
    print(f"wrote {out_path} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
