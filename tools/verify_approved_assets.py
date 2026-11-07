#!/usr/bin/env python3
"""Verify shipped approved art against the catalog and integration manifests.

Run from any directory: python3 tools/verify_approved_assets.py
Optional: --repo-root PATH --report PATH
Uses only the Python standard library and files tracked in this repository.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys


class Audit:
    def __init__(self, root: Path) -> None:
        self.root = root.resolve()
        self.game = self.root / "game"
        self.failures: list[str] = []
        self.checks = 0
        self.files: dict[Path, tuple[str, list[int]]] = {}

    def check(self, condition: bool, message: str) -> None:
        self.checks += 1
        if not condition:
            self.failures.append(message)

    def load_json(self, path: Path) -> dict:
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            self.check(False, f"{path.relative_to(self.root)}: {error}")
            return {}

    def inspect_png(self, path: Path, sha256: str, size: list[int] | None = None) -> None:
        label = str(path.relative_to(self.root))
        if path not in self.files:
            try:
                data = path.read_bytes()
                valid_header = (
                    len(data) >= 33
                    and data[:8] == b"\x89PNG\r\n\x1a\n"
                    and data[8:16] == b"\x00\x00\x00\rIHDR"
                )
                self.check(valid_header, f"{label}: valid PNG IHDR required")
                if not valid_header:
                    return
                width, height, depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", data[16:29])
                self.check(depth == 8 and color_type == 6, f"{label}: expected 8-bit RGBA master")
                self.files[path] = (hashlib.sha256(data).hexdigest(), [width, height])
            except OSError as error:
                self.check(False, f"{label}: {error}")
                return
        actual_hash, actual_size = self.files[path]
        self.check(bool(sha256) and actual_hash == sha256, f"{label}: SHA-256 mismatch")
        if size is not None:
            self.check(actual_size == size, f"{label}: dimensions {actual_size} != {size}")

    def resource_path(self, value: str) -> Path | None:
        if not value.startswith("res://"):
            self.check(False, f"Invalid resource path: {value}")
            return None
        path = (self.game / value[6:]).resolve()
        if not path.is_relative_to(self.game):
            self.check(False, f"Resource leaves the game directory: {value}")
            return None
        return path

    def run(self) -> dict:
        catalog = self.load_json(self.game / "data/assets.json").get("assets", {})
        approved = {key: value for key, value in catalog.items() if value.get("approved")}
        self.check(len(approved) >= 45, "Expected at least 45 approved catalog IDs")
        for asset_id, entry in approved.items():
            path = self.resource_path(entry.get("file", ""))
            if path is None:
                continue
            self.inspect_png(path, entry.get("sha256", ""), entry.get("source_size"))
            if "crop" in entry:
                crop = entry["crop"]
                size = entry.get("source_size", [])
                valid = len(crop) == 4 and len(size) == 2
                if valid:
                    x, y, width, height = crop
                    valid = min(x, y) >= 0 and min(width, height) > 0 and x + width <= size[0] and y + height <= size[1]
                self.check(valid, f"{asset_id}: crop must fit the source canvas")

        buildings = self.game / "assets/buildings/approved-v001"
        integration = self.load_json(buildings / "integration-manifest.json")
        originals = self.load_json(buildings / "source-manifest.json")
        source_entries = {entry["file"]: entry for entry in originals.get("assets", [])}
        building_assets = integration.get("assets", [])
        self.check(integration.get("original_pngs_unchanged") is True, "Building master integrity declaration missing")
        self.check(len(building_assets) == 24, "Expected 24 building/foundation masters")
        for asset in building_assets:
            asset_id, filename = asset["id"], asset["file"]
            source = source_entries.get(filename, {})
            self.check(source.get("sha256") == asset.get("sha256"), f"{asset_id}: source/integration hash differs")
            self.check(source.get("status") == asset.get("source_status"), f"{asset_id}: original source audit status lost")
            self.check(asset.get("integration_approved") is True, f"{asset_id}: integration approval missing")
            self.inspect_png(buildings / filename, asset.get("sha256", ""), source.get("dimensions_px"))
            expected = "res://" + (buildings / filename).relative_to(self.game).as_posix()
            self.check(catalog.get(asset_id, {}).get("file") == expected, f"{asset_id}: catalog points outside integrated set")

        menu = self.game / "assets/ui/building-menu-integrated-v004"
        menu_source = self.load_json(menu / "source-manifest.json")
        menu_assets = [entry for entry in menu_source.get("files", []) if entry["path"].startswith(("exports/", "planned/"))]
        self.check(len(menu_assets) == 8, "Expected eight integrated menu buttons")
        for asset in menu_assets:
            self.inspect_png(menu / Path(asset["path"]).name, asset["sha256"], [asset["width"], asset["height"]])
        self.check(not any("gold" in entry.get("file", "").lower() for entry in catalog.values()), "Unapproved gold must not enter the runtime catalog")
        self.check(not (menu / "gold-line.png").exists() and not (menu / "gold").exists(), "Gold artwork must not be imported with buttons")

        side = self.game / "assets/ui/facility-side-v001"
        side_assets = self.load_json(side / "source-manifest.json").get("assets", [])
        self.check(len(side_assets) == 6, "Expected six approved facility side tiles")
        for asset in side_assets:
            self.inspect_png(side / asset["name"], asset["sha256"], asset["size"])

        resources = self.game / "assets/ui/resources-approved-v001"
        resident = self.load_json(resources / "resident-source-manifest.json")
        self.check(resident.get("status") == "approved-final", "Resident source must remain approved-final")
        self.inspect_png(resources / "resident.png", resident.get("sha256", ""), resident.get("size"))
        for asset_id in ("UI-RESIDENT", "UI-SEED"):
            self.check(asset_id in approved, f"{asset_id}: approved resource icon missing")

        return {
            "checks": self.checks,
            "approved_catalog_ids": len(approved),
            "unique_png_masters": len(self.files),
            "building_foundation_masters": len(building_assets),
            "menu_buttons": len(menu_assets),
            "facility_side_tiles": len(side_assets),
            "failures": self.failures,
        }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", type=Path, help="Also write the JSON result to this path")
    args = parser.parse_args()
    result = Audit(args.repo_root).run()
    output = json.dumps(result, ensure_ascii=False, indent=2)
    print(output)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output + "\n", encoding="utf-8")
    return 1 if result["failures"] else 0


if __name__ == "__main__":
    sys.exit(main())
