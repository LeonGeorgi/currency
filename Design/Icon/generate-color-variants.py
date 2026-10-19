#!/usr/bin/env python3
"""Recolor the layered Icon Composer source without changing its geometry."""
import copy
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Currency/AppIcon.icon"
DESTINATION = ROOT / "Currency/AppIcons"

# Apple's iOS 26 default light palette; UI colors use dynamic SwiftUI APIs.
# https://developer.apple.com/design/human-interface-guidelines/color
PALETTE = {
    "Red": (255, 56, 60), "Orange": (255, 141, 40), "Yellow": (255, 204, 0),
    "Green": (52, 199, 89), "Mint": (0, 200, 179), "Teal": (0, 195, 208),
    "Cyan": (0, 192, 232), "Blue": (0, 136, 255), "Indigo": (97, 85, 245),
    "Purple": (203, 48, 224), "Pink": (255, 45, 85), "Brown": (172, 127, 94),
    "Gray": (142, 142, 147),
}


def blend(rgb, white):
    return "#" + "".join(f"{round(c * (1 - white) + 255 * white):02X}" for c in rgb)


def generate():
    original = json.loads((SOURCE / "icon.json").read_text())
    for name, rgb in PALETTE.items():
        destination = DESTINATION / f"AppIcon-{name}.icon"
        (destination / "Assets").mkdir(parents=True, exist_ok=True)
        document = copy.deepcopy(original)
        components = ",".join(f"{c / 255:.5f}" for c in rgb)
        document["fill"]["automatic-gradient"] = f"extended-srgb:{components},1.00000"
        fills = {"01-Euro-Coin.svg": blend(rgb, 0.38), "02-Euro.svg": "#FFFFFF",
                 "03-Dollar-Coin.svg": blend(rgb, 0.94), "04-Dollar.svg": blend(tuple(c * 0.65 for c in rgb), 0)}
        for group in document["groups"]:
            for layer in group["layers"]:
                image = layer["image-name"]
                source = (SOURCE / "Assets" / image).read_text()
                source = re.sub(r'fill="#[0-9A-Fa-f]{6}"', f'fill="{fills[image]}"', source)
                layer["image-name"] = f"{name}-{image}"
                (destination / "Assets" / layer["image-name"]).write_text(source)
        (destination / "icon.json").write_text(json.dumps(document, indent=2) + "\n")


if __name__ == "__main__":
    generate()
