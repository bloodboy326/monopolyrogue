from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageFilter


OUTPUT_SIZE = 512
STATES = ["idle", "attack", "hit", "death"]


def key_distance(pixel: tuple[int, int, int, int], key: tuple[int, int, int]) -> float:
    r, g, b, _a = pixel
    return ((r - key[0]) ** 2 + (g - key[1]) ** 2 + (b - key[2]) ** 2) ** 0.5


def sample_key(image: Image.Image) -> tuple[int, int, int]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    known_keys = [(255, 0, 255), (0, 255, 0)]
    best_known = known_keys[0]
    best_count = 0
    for key in known_keys:
        count = 0
        step_x = max(1, width // 80)
        step_y = max(1, height // 80)
        for y in range(0, height, step_y):
            for x in range(0, width, step_x):
                if key_distance(rgba.getpixel((x, y)), key) < 56:
                    count += 1
        if count > best_count:
            best_count = count
            best_known = key
    if best_count > 16:
        return best_known

    samples = [
        rgba.getpixel((2, 2)),
        rgba.getpixel((width - 3, 2)),
        rgba.getpixel((2, height - 3)),
        rgba.getpixel((width - 3, height - 3)),
    ]
    r = round(sum(pixel[0] for pixel in samples) / len(samples))
    g = round(sum(pixel[1] for pixel in samples) / len(samples))
    b = round(sum(pixel[2] for pixel in samples) / len(samples))
    return r, g, b


def remove_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    key = sample_key(rgba)
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            pixel = pixels[x, y]
            distance = key_distance(pixel, key)
            chroma_like = False
            r, g, b, _a = pixel
            if key == (255, 0, 255):
                chroma_like = r > 85 and b > 85 and g < 95 and abs(r - b) < 95
            elif key == (0, 255, 0):
                chroma_like = g > 85 and r < 95 and b < 95
            if distance < 42 or chroma_like:
                pixels[x, y] = (pixel[0], pixel[1], pixel[2], 0)
            elif distance < 92:
                alpha = int(min(255, max(0, (distance - 42) / 50 * 255)))
                pixels[x, y] = (pixel[0], pixel[1], pixel[2], min(pixel[3], alpha))
    alpha = rgba.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    rgba.putalpha(alpha)
    return rgba


def keep_subject_components(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    width, height = alpha.size
    pixels = alpha.load()
    seen = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            index = y * width + x
            if seen[index] or pixels[x, y] < 16:
                continue
            stack = [(x, y)]
            seen[index] = 1
            component: list[tuple[int, int]] = []
            while stack:
                cx, cy = stack.pop()
                component.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    next_index = ny * width + nx
                    if seen[next_index] or pixels[nx, ny] < 16:
                        continue
                    seen[next_index] = 1
                    stack.append((nx, ny))
            components.append(component)
    if not components:
        return rgba
    largest = max(len(component) for component in components)
    keep_threshold = max(240, int(largest * 0.025))
    new_alpha = Image.new("L", (width, height), 0)
    new_pixels = new_alpha.load()
    for component in components:
        if len(component) < keep_threshold:
            continue
        for x, y in component:
            new_pixels[x, y] = pixels[x, y]
    rgba.putalpha(new_alpha)
    return rgba


def remove_edge_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    seen = bytearray(width * height)
    stack: list[tuple[int, int]] = []
    for x in range(width):
        stack.append((x, 0))
        stack.append((x, height - 1))
    for y in range(height):
        stack.append((0, y))
        stack.append((width - 1, y))

    def removable(x: int, y: int) -> bool:
        r, g, b, a = pixels[x, y]
        if a == 0:
            return True
        high = max(r, g, b)
        magenta_like = r > 45 and b > 45 and g < 80 and abs(r - b) < 95
        green_like = g > 45 and r < 80 and b < 80
        return magenta_like or green_like

    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= width or y >= height:
            continue
        index = y * width + x
        if seen[index] or not removable(x, y):
            continue
        seen[index] = 1
        r, g, b, _a = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return rgba


def normalize_sprite(image: Image.Image) -> Image.Image:
    rgba = keep_subject_components(remove_edge_background(remove_key(image)))
    bbox = rgba.getbbox()
    if bbox is None:
        return Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    left, top, right, bottom = bbox
    pad_x = round((right - left) * 0.08)
    pad_y = round((bottom - top) * 0.08)
    crop = rgba.crop(
        (
            max(0, left - pad_x),
            max(0, top - pad_y),
            min(rgba.size[0], right + pad_x),
            min(rgba.size[1], bottom + pad_y),
        )
    )
    scale = min(OUTPUT_SIZE * 0.90 / crop.size[0], OUTPUT_SIZE * 0.90 / crop.size[1])
    resized = crop.resize((max(1, round(crop.size[0] * scale)), max(1, round(crop.size[1] * scale))), Image.Resampling.LANCZOS)
    output = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    output.alpha_composite(resized, ((OUTPUT_SIZE - resized.size[0]) // 2, (OUTPUT_SIZE - resized.size[1]) // 2))
    return output


def process_sheet(sheet_path: Path, output_dir: Path, monster_key: str) -> None:
    sheet = Image.open(sheet_path).convert("RGBA")
    output_dir.mkdir(parents=True, exist_ok=True)
    sheet_dir = output_dir / "sheets"
    sheet_dir.mkdir(parents=True, exist_ok=True)
    (sheet_dir / f"{monster_key}_sheet.png").write_bytes(sheet_path.read_bytes())
    panel_width = sheet.size[0] // 4
    for index, state in enumerate(STATES):
        panel = sheet.crop((index * panel_width, 0, (index + 1) * panel_width if index < 3 else sheet.size[0], sheet.size[1]))
        normalize_sprite(panel).save(output_dir / f"{monster_key}_{state}.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("sheet")
    parser.add_argument("monster_key")
    parser.add_argument("--output-dir", default="assets/generated/enemies")
    args = parser.parse_args()
    process_sheet(Path(args.sheet), Path(args.output_dir), args.monster_key)


if __name__ == "__main__":
    main()
