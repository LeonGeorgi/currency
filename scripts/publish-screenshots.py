#!/usr/bin/env python3
"""Publish native XCTest screenshots and small README thumbnails, without dependencies."""
import argparse
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {"de": "Deutsch", "en": "English", "ja": "日本語", "es": "Español", "fr": "Français"}
SCENES = {"overview-light": "Übersicht", "history": "Verlauf", "editing": "Bearbeiten", "overview-dark": "Dunkelmodus"}
START = "<!-- screenshots:start -->"
END = "<!-- screenshots:end -->"
PREVIEW_WIDTH = 320


def png_size(path):
    with path.open("rb") as image:
        header = image.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a native PNG screenshot: {path}")
    return struct.unpack(">II", header[16:24])


def collect(attachments):
    manifest = json.loads((attachments / "manifest.json").read_text())
    found = {}
    pattern = re.compile(r"(de|en|ja|es|fr)--(overview-light|overview-dark|history|editing)(?=[_.\s-]|$)")
    for test in manifest:
        for attachment in test["attachments"]:
            match = pattern.search(attachment["suggestedHumanReadableName"])
            if not match or attachment["isAssociatedWithFailure"]:
                continue
            key = match.groups()
            if key in found:
                raise ValueError(f"Duplicate screenshot: {key}")
            source = (attachments / attachment["exportedFileName"]).resolve()
            if not source.is_relative_to(attachments.resolve()):
                raise ValueError("Attachment path escapes the export directory")
            width, height = png_size(source)
            if width < 1000 or height <= width:
                raise ValueError(f"Expected a full-resolution portrait iPhone screenshot: {source}")
            found[key] = source
    expected = {(language, scene) for language in LANGUAGES for scene in SCENES}
    if set(found) != expected:
        raise ValueError(f"Incomplete screenshot set. Missing: {sorted(expected - found.keys())}")
    return found


def paths(language, scene):
    return (f"docs/screenshots/originals/{language}/{scene}.png",
            f"docs/screenshots/previews/{language}/{scene}.jpg")


def preview(language, scene):
    original, thumbnail = paths(language, scene)
    alt = f"{LANGUAGES[language]} · {SCENES[scene]}"
    return f'<a href="{original}"><img src="{thumbnail}" alt="{alt}" width="180"></a>'


def gallery():
    lines = [
        START, "## Screenshots", "",
        "Automatisch mit nativen UI-Tests erstellt, mit festen Beispieldaten. "
        "Hier werden nur verkleinerte JPEGs geladen (320 Pixel breit). "
        "Ein Klick öffnet das unverkleinerte PNG im Repository.", "",
        "| " + " | ".join(SCENES.values()) + " |",
        "| " + " | ".join("---" for _ in SCENES) + " |",
        "| " + " | ".join(preview("de", scene) for scene in SCENES) + " |", "",
        "| " + " | ".join(name for code, name in LANGUAGES.items() if code != "de") + " |",
        "| " + " | ".join("---" for code in LANGUAGES if code != "de") + " |",
        "| " + " | ".join(preview(code, "overview-light") for code in LANGUAGES if code != "de") + " |", "",
        "<details>", "<summary>Alle Originale in voller Auflösung (PNG)</summary>", "",
        "| Sprache | " + " | ".join(SCENES.values()) + " |",
        "| --- | " + " | ".join("---" for _ in SCENES) + " |",
    ]
    for code, language in LANGUAGES.items():
        links = [f"[{title}]({paths(code, scene)[0]})" for scene, title in SCENES.items()]
        lines.append("| " + language + " | " + " | ".join(links) + " |")
    lines.extend(["", "</details>", "", END])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("attachments", type=Path, help="xcresulttool export attachments directory")
    args = parser.parse_args()
    found = collect(args.attachments)
    readme = ROOT / "README.md"
    text = readme.read_text()
    if text.count(START) != 1 or text.count(END) != 1 or text.index(START) >= text.index(END):
        raise ValueError("README must contain exactly one ordered screenshots marker pair")

    # Validate and render the entire set before touching the published gallery.
    with tempfile.TemporaryDirectory(prefix="currency-screenshots-") as temporary:
        stage = Path(temporary)
        manifest = []
        for language in LANGUAGES:
            for scene in SCENES:
                source = found[language, scene]
                original, thumbnail = paths(language, scene)
                for destination in [stage / original, stage / thumbnail]:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, stage / original)
                subprocess.run(["sips", "--resampleWidth", str(PREVIEW_WIDTH), "--setProperty", "format", "jpeg",
                                "--setProperty", "formatOptions", "76", str(source), "--out", str(stage / thumbnail)],
                               check=True, stdout=subprocess.DEVNULL)
                width, height = png_size(source)
                manifest.append({"language": language, "scene": scene, "original": original, "preview": thumbnail,
                                 "width": width, "height": height, "previewWidth": PREVIEW_WIDTH,
                                 "originalBytes": source.stat().st_size, "previewBytes": (stage / thumbnail).stat().st_size})
        for entry in manifest:
            for key in ["original", "preview"]:
                destination = ROOT / entry[key]
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(stage / entry[key], destination)
        (ROOT / "docs/screenshots/manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

    begin, rest = text.split(START)
    _, end = rest.split(END)
    readme.write_text(begin + gallery() + end)
    print(f"Published {len(manifest)} original PNGs and {len(manifest)} JPEG previews.")
    print(f"README loads {sum(entry['previewBytes'] for entry in manifest if entry['language'] == 'de' or entry['scene'] == 'overview-light'):,} bytes of previews.")


if __name__ == "__main__":
    main()
