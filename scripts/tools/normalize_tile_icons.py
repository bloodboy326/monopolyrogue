from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


OUTPUT_SIZE = 512
TARGET_CARD_SIZE = 452


@dataclass(frozen=True)
class SheetSpec:
    filename: str
    tile_ids: list[str]


SHEETS = [
    SheetSpec("tile_icons_t001_t010_sheet.png", [f"T{i:03d}" for i in range(1, 11)]),
    SheetSpec("tile_icons_t011_t020_sheet.png", [f"T{i:03d}" for i in range(11, 21)]),
    SheetSpec("tile_icons_t021_t030_sheet.png", [f"T{i:03d}" for i in range(21, 31)]),
    SheetSpec("tile_icons_t031_t040_sheet.png", [f"T{i:03d}" for i in range(31, 41)]),
    SheetSpec("tile_icons_t041_t050_sheet.png", [f"T{i:03d}" for i in range(41, 51)]),
    SheetSpec("tile_icons_t051_t060_sheet.png", [f"T{i:03d}" for i in range(51, 61)]),
    SheetSpec("tile_icons_t061_t901_sheet.png", [f"T{i:03d}" for i in range(61, 66)] + ["T901"]),
]


def build_card_mask(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    mask = bytearray(width * height)
    for y in range(height):
        offset = y * width
        for x in range(width):
            r, g, b = pixels[x, y]
            high = max(r, g, b)
            low = min(r, g, b)
            saturation = high - low
            if (high > 58 and saturation > 24) or (high > 82 and saturation > 6):
                mask[offset + x] = 255
    return Image.frombytes("L", (width, height), bytes(mask)).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(5))


def connected_components(mask: Image.Image) -> list[tuple[int, int, int, int, int]]:
    width, height = mask.size
    pixels = mask.load()
    seen = bytearray(width * height)
    components: list[tuple[int, int, int, int, int]] = []

    for y in range(height):
        for x in range(width):
            index = y * width + x
            if seen[index] or pixels[x, y] < 128:
                continue
            stack = [(x, y)]
            seen[index] = 1
            min_x = max_x = x
            min_y = max_y = y
            area = 0
            while stack:
                cx, cy = stack.pop()
                area += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    next_index = ny * width + nx
                    if seen[next_index] or pixels[nx, ny] < 128:
                        continue
                    seen[next_index] = 1
                    stack.append((nx, ny))
            if area > 20000:
                components.append((min_x, min_y, max_x + 1, max_y + 1, area))
    return components


def sort_card_boxes(boxes: list[tuple[int, int, int, int, int]]) -> list[tuple[int, int, int, int, int]]:
    average_height = sum(box[3] - box[1] for box in boxes) / max(1, len(boxes))
    row_threshold = average_height * 0.45
    rows: list[list[tuple[int, int, int, int, int]]] = []

    for box in sorted(boxes, key=lambda item: (item[1] + item[3]) * 0.5):
        center_y = (box[1] + box[3]) * 0.5
        for row in rows:
            row_center = sum((item[1] + item[3]) * 0.5 for item in row) / len(row)
            if abs(center_y - row_center) <= row_threshold:
                row.append(box)
                break
        else:
            rows.append([box])

    sorted_boxes: list[tuple[int, int, int, int, int]] = []
    for row in rows:
        sorted_boxes.extend(sorted(row, key=lambda item: item[0]))
    return sorted_boxes


def make_background_transparent(crop: Image.Image, color_box: tuple[int, int, int, int], crop_box: tuple[int, int, int, int]) -> Image.Image:
    rgba = crop.convert("RGBA")
    pixels = rgba.load()
    crop_left, crop_top, _, _ = crop_box
    color_left, color_top, color_right, color_bottom = color_box
    width, height = rgba.size

    for y in range(height):
        global_y = crop_top + y
        for x in range(width):
            global_x = crop_left + x
            r, g, b, a = pixels[x, y]
            high = max(r, g, b)
            low = min(r, g, b)
            saturation = high - low
            inside_card = color_left <= global_x < color_right and color_top <= global_y < color_bottom
            if inside_card:
                continue
            if a > 0 and high >= 24 and saturation < 34:
                pixels[x, y] = (r, g, b, 0)
    return rgba


def bounded_crop_box(
    sheet_size: tuple[int, int],
    box: tuple[int, int, int, int, int],
    boxes: list[tuple[int, int, int, int, int]],
    pad: int,
) -> tuple[int, int, int, int]:
    left, top, right, bottom, _area = box
    sheet_width, sheet_height = sheet_size
    crop_left = max(0, left - pad)
    crop_top = max(0, top - pad)
    crop_right = min(sheet_width, right + pad)
    crop_bottom = min(sheet_height, bottom + pad)
    center_x = (left + right) * 0.5
    center_y = (top + bottom) * 0.5
    same_row_threshold = (bottom - top) * 0.6
    same_column_threshold = (right - left) * 0.6

    for other in boxes:
        if other == box:
            continue
        other_left, other_top, other_right, other_bottom, _other_area = other
        other_center_x = (other_left + other_right) * 0.5
        other_center_y = (other_top + other_bottom) * 0.5

        if abs(other_center_y - center_y) < same_row_threshold:
            if other_left >= right:
                crop_right = min(crop_right, int((right + other_left) * 0.5))
            elif other_right <= left:
                crop_left = max(crop_left, int((left + other_right) * 0.5))

        if abs(other_center_x - center_x) < same_column_threshold:
            if other_top >= bottom:
                crop_bottom = min(crop_bottom, int((bottom + other_top) * 0.5))
            elif other_bottom <= top:
                crop_top = max(crop_top, int((top + other_bottom) * 0.5))

    return crop_left, crop_top, crop_right, crop_bottom


def normalize_card(
    sheet: Image.Image,
    box: tuple[int, int, int, int, int],
    boxes: list[tuple[int, int, int, int, int]],
) -> Image.Image:
    left, top, right, bottom, _area = box
    card_width = right - left
    card_height = bottom - top
    pad = max(18, min(24, round(max(card_width, card_height) * 0.055)))
    crop_box = bounded_crop_box(sheet.size, box, boxes, pad)
    crop = sheet.crop(crop_box)
    crop = make_background_transparent(crop, (left, top, right, bottom), crop_box)

    scale = TARGET_CARD_SIZE / max(card_width, card_height)
    resized_size = (round(crop.size[0] * scale), round(crop.size[1] * scale))
    resized = crop.resize(resized_size, Image.Resampling.LANCZOS)

    color_center_x = ((left + right) * 0.5 - crop_box[0]) * scale
    color_center_y = ((top + bottom) * 0.5 - crop_box[1]) * scale
    paste_x = round(OUTPUT_SIZE * 0.5 - color_center_x)
    paste_y = round(OUTPUT_SIZE * 0.5 - color_center_y)

    output = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    output.alpha_composite(resized, (paste_x, paste_y))
    return output


def build_preview(icon_dir: Path, tile_ids: list[str]) -> None:
    columns = 8
    cell = 144
    label_height = 22
    rows = (len(tile_ids) + columns - 1) // columns
    preview = Image.new("RGBA", (columns * cell, rows * (cell + label_height)), (25, 27, 34, 255))
    draw = ImageDraw.Draw(preview)

    for index, tile_id in enumerate(tile_ids):
        icon = Image.open(icon_dir / f"{tile_id}.png").convert("RGBA")
        icon.thumbnail((120, 120), Image.Resampling.LANCZOS)
        x = (index % columns) * cell
        y = (index // columns) * (cell + label_height)
        preview.alpha_composite(icon, (x + (cell - icon.size[0]) // 2, y + 8))
        draw.text((x + 8, y + cell - 6), tile_id, fill=(235, 238, 245, 255))

    preview.save(icon_dir / "tile_icons_all_preview.png")


def apply_source_overrides(icon_dir: Path, tile_ids: list[str]) -> None:
    override_dir = icon_dir / "overrides"
    if not override_dir.exists():
        return

    for source_path in sorted(override_dir.glob("*_source.png")):
        tile_id = source_path.stem.removesuffix("_source")
        if tile_id not in tile_ids:
            continue
        source = Image.open(source_path).convert("RGBA")
        boxes = sort_card_boxes(connected_components(build_card_mask(source)))
        if not boxes:
            raise RuntimeError(f"{source_path}: no card component found")
        box = max(boxes, key=lambda item: item[4])
        normalize_card(source, box, [box]).save(icon_dir / f"{tile_id}.png")


def normalize_icons(icon_dir: Path) -> None:
    all_tile_ids: list[str] = []
    for spec in SHEETS:
        sheet_path = icon_dir / spec.filename
        sheet = Image.open(sheet_path).convert("RGBA")
        boxes = sort_card_boxes(connected_components(build_card_mask(sheet)))
        if len(boxes) != len(spec.tile_ids):
            raise RuntimeError(f"{spec.filename}: expected {len(spec.tile_ids)} cards, found {len(boxes)}")

        for tile_id, box in zip(spec.tile_ids, boxes):
            normalize_card(sheet, box, boxes).save(icon_dir / f"{tile_id}.png")
            all_tile_ids.append(tile_id)

    apply_source_overrides(icon_dir, all_tile_ids)
    build_preview(icon_dir, all_tile_ids)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--icon-dir", default="assets/generated/tile_icons")
    args = parser.parse_args()
    normalize_icons(Path(args.icon_dir))


if __name__ == "__main__":
    main()
