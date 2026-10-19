#!/usr/bin/env python3
"""Export the settings banner assets with Apple's Icon Composer renderer."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "Currency/Appearance.xcassets"
developer = Path(subprocess.check_output(["xcode-select", "--print-path"], text=True).strip())
renderer = developer.parent / "Applications/Icon Composer.app/Contents/Executables/ictool"
info = {"author": "xcode", "version": 1}
CATALOG.mkdir(parents=True, exist_ok=True)
(CATALOG / "Contents.json").write_text(json.dumps({"info": info}, indent=2) + "\n")
icons = [("Original", ROOT / "Currency/AppIcon.icon")]
icons += [(path.stem.removeprefix("AppIcon-"), path) for path in sorted((ROOT / "Currency/AppIcons").glob("*.icon"))]
for name, source in icons:
    folder = CATALOG / f"AppIconPreview-{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    images = []
    for rendition in ["Default", "Dark"]:
        filename = f"{rendition}.png"
        subprocess.run([str(renderer), str(source), "--export-image", "--output-file", str(folder / filename),
                        "--platform", "iOS", "--rendition", rendition,
                        "--width", "128", "--height", "128", "--scale", "3"], check=True, capture_output=True)
        image = {"idiom": "universal", "filename": filename, "scale": "3x"}
        if rendition == "Dark":
            image["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
        images.append(image)
    (folder / "Contents.json").write_text(json.dumps({"images": images, "info": info}, indent=2) + "\n")
    print(f"Rendered {name} (light and dark)", flush=True)
