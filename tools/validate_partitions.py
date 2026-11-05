#!/usr/bin/env python3
"""Validate the repository's ESP32 4 MiB partition layouts."""

from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLASH_SIZE = 0x400000
APP_ALIGNMENT = 0x10000
DATA_ALIGNMENT = 0x1000


def parse_size(value: str) -> int:
    value = value.strip().upper()
    if value.endswith("K"):
        return int(value[:-1], 0) * 1024
    if value.endswith("M"):
        return int(value[:-1], 0) * 1024 * 1024
    return int(value, 0)


def read_partitions(path: Path) -> list[dict]:
    rows = []
    with path.open(encoding="utf-8", newline="") as stream:
        for row in csv.reader(line for line in stream if not line.lstrip().startswith("#")):
            if not row or not any(cell.strip() for cell in row):
                continue
            if len(row) < 5:
                raise ValueError(f"{path}: expected at least 5 CSV columns: {row}")
            name, kind, subtype, offset_text, size_text = (cell.strip() for cell in row[:5])
            rows.append({
                "name": name,
                "type": kind,
                "subtype": subtype,
                "offset": int(offset_text, 0) if offset_text else None,
                "size": parse_size(size_text),
            })

    next_offset = 0
    for item in rows:
        alignment = APP_ALIGNMENT if item["type"] == "app" else DATA_ALIGNMENT
        if item["offset"] is None:
            item["offset"] = (next_offset + alignment - 1) // alignment * alignment
        if item["offset"] % alignment:
            raise ValueError(
                f"{path}: {item['name']} offset 0x{item['offset']:X} "
                f"is not aligned to 0x{alignment:X}"
            )
        if item["size"] <= 0:
            raise ValueError(f"{path}: {item['name']} has non-positive size")
        item["end"] = item["offset"] + item["size"]
        next_offset = item["end"]

    return sorted(rows, key=lambda item: item["offset"])


def validate(path: Path, expected_slot: int, expect_spiffs: bool) -> None:
    parts = read_partitions(path)
    names = [item["name"] for item in parts]
    if len(names) != len(set(names)):
        raise ValueError(f"{path}: duplicate partition names")

    for item in parts:
        if item["end"] > FLASH_SIZE:
            raise ValueError(
                f"{path}: {item['name']} ends at 0x{item['end']:X}, "
                f"beyond 4 MiB flash"
            )

    for previous, current in zip(parts, parts[1:]):
        if current["offset"] < previous["end"]:
            raise ValueError(
                f"{path}: overlap between {previous['name']} and {current['name']}"
            )

    by_name = {item["name"]: item for item in parts}
    required = {"nvs", "otadata", "app0", "app1"}
    if not required.issubset(by_name):
        raise ValueError(f"{path}: missing required partitions: {sorted(required - set(by_name))}")

    if by_name["nvs"]["offset"] != 0x9000 or by_name["nvs"]["size"] != 0x5000:
        raise ValueError(f"{path}: NVS must remain at 0x9000 with size 0x5000")
    if by_name["otadata"]["offset"] != 0xE000 or by_name["otadata"]["size"] != 0x2000:
        raise ValueError(f"{path}: otadata must remain at 0xE000 with size 0x2000")

    for name, subtype in (("app0", "ota_0"), ("app1", "ota_1")):
        item = by_name[name]
        if item["type"] != "app" or item["subtype"] != subtype:
            raise ValueError(f"{path}: {name} must be app/{subtype}")
        if item["size"] != expected_slot:
            raise ValueError(
                f"{path}: {name} size is 0x{item['size']:X}, "
                f"expected 0x{expected_slot:X}"
            )
        if item["offset"] % APP_ALIGNMENT:
            raise ValueError(f"{path}: {name} offset is not 64 KiB aligned")

    if by_name["app0"]["offset"] != 0x10000:
        raise ValueError(f"{path}: app0 must start at 0x10000")
    if by_name["app1"]["offset"] < by_name["app0"]["end"]:
        raise ValueError(f"{path}: app1 overlaps app0")

    has_spiffs = any(item["type"] == "data" and item["subtype"] == "spiffs" for item in parts)
    if has_spiffs != expect_spiffs:
        raise ValueError(f"{path}: unexpected SPIFFS presence: {has_spiffs}")

    print(
        f"OK {path.relative_to(ROOT)}: "
        f"OTA slots 0x{expected_slot:X} ({expected_slot / 1024:.0f} KiB), "
        f"app0=0x{by_name['app0']['offset']:X}, "
        f"app1=0x{by_name['app1']['offset']:X}, "
        f"flash end=0x{max(item['end'] for item in parts):X}"
    )


def main() -> int:
    try:
        validate(ROOT / "partitions" / "basic.csv", 0x140000, True)
        validate(ROOT / "partitions" / "extended.csv", 0x1F0000, False)
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
