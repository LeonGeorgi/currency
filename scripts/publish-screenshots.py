#!/usr/bin/env python3
"""Build a GitHub Pages screenshot artifact; generated images never belong in Git."""
import argparse
from html import escape
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {"en": "English", "de": "German", "ja": "Japanese", "es": "Spanish", "fr": "French"}
SCENES = {"overview-light": "Overview", "history": "History", "editing": "Editing", "overview-dark": "Dark mode"}
PRIMARY_LANGUAGE = "en"
START = "<!-- screenshots:start -->"
END = "<!-- screenshots:end -->"
PREVIEW_WIDTH = 320
BASE_URL = "https://leongeorgi.github.io/currency"


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
    return (f"screenshots/originals/{language}/{scene}.png",
            f"screenshots/previews/{language}/{scene}.jpg")


def preview(language, scene, base_url):
    original, thumbnail = paths(language, scene)
    alt = f"{LANGUAGES[language]} · {SCENES[scene]}"
    return f'<a href="{base_url}/{original}"><img src="{base_url}/{thumbnail}" alt="{alt}" width="180"></a>'


def gallery(base_url):
    lines = [
        START, "## Screenshots", "",
        "Captured automatically by native UI tests using fixed sample data. "
        "Only small JPEG previews (320 pixels wide) load here; click an image to open the full-resolution PNG. "
        "Images are hosted on GitHub Pages and are not stored in the Git repository.", "",
        "| " + " | ".join(SCENES.values()) + " |",
        "| " + " | ".join("---" for _ in SCENES) + " |",
        "| " + " | ".join(preview(PRIMARY_LANGUAGE, scene, base_url) for scene in SCENES) + " |", "",
        "| " + " | ".join(name for code, name in LANGUAGES.items() if code != PRIMARY_LANGUAGE) + " |",
        "| " + " | ".join("---" for code in LANGUAGES if code != PRIMARY_LANGUAGE) + " |",
        "| " + " | ".join(preview(code, "overview-light", base_url) for code in LANGUAGES if code != PRIMARY_LANGUAGE) + " |", "",
        "<details>", "<summary>All full-resolution originals (PNG)</summary>", "",
        "| Language | " + " | ".join(SCENES.values()) + " |",
        "| --- | " + " | ".join("---" for _ in SCENES) + " |",
    ]
    for code, language in LANGUAGES.items():
        links = [f"[{title}]({base_url}/{paths(code, scene)[0]})" for scene, title in SCENES.items()]
        lines.append("| " + language + " | " + " | ".join(links) + " |")
    lines.extend(["", "</details>", "", END])
    return "\n".join(lines)


def site_index():
    lines = [
        '<!doctype html><html lang="en"><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        '<title>Currencies · Screenshots</title>',
        '<style>html{font-family:system-ui;color-scheme:light dark}body{max-width:900px;margin:40px auto;padding:0 20px}'
        'section{display:flex;flex-wrap:wrap;gap:20px}figure{margin:0}img{border-radius:20px;width:180px;height:auto}'
        'figcaption{margin:8px 0 20px}</style>',
        '<h1>Currencies · Screenshots</h1><p>Click an image to open the full-resolution original.</p>',
    ]
    for code, language in LANGUAGES.items():
        lines.append(f'<h2>{escape(language)}</h2><section>')
        for scene, title in SCENES.items():
            original, thumbnail = paths(code, scene)
            lines.append(f'<figure><a href="{original}"><img src="{thumbnail}" loading="lazy" '
                         f'alt="{escape(language)} · {escape(title)}" width="180"></a>'
                         f'<figcaption>{escape(title)}</figcaption></figure>')
        lines.append('</section>')
    lines.append('</html>')
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("attachments", type=Path, nargs="?", help="xcresulttool export attachments directory")
    parser.add_argument("--output", type=Path, default=ROOT / "build/Screenshots/Site", help="Pages artifact directory")
    parser.add_argument("--base-url", default=BASE_URL, help="Public GitHub Pages base URL for README links")
    parser.add_argument("--update-readme", action="store_true", help="Explicitly regenerate README links when its structure or host changes")
    args = parser.parse_args()
    base_url = args.base_url.rstrip('/')
    url = urlsplit(base_url)
    if url.scheme != 'https' or not url.netloc or url.query or url.fragment or any(c in base_url for c in '<>"\'\n\r'):
        raise ValueError("Expected a public HTTPS base URL without query or fragment")
    if not args.attachments and not args.update_readme:
        parser.error("Provide an attachments directory or --update-readme")
    if args.update_readme:
        readme = ROOT / "README.md"
        text = readme.read_text()
        if text.count(START) != 1 or text.count(END) != 1 or text.index(START) >= text.index(END):
            raise ValueError("README must contain exactly one ordered screenshots marker pair")
        begin, rest = text.split(START)
        _, end = rest.split(END)
        readme.write_text(begin + gallery(base_url) + end)
    if not args.attachments:
        return
    found = collect(args.attachments)

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
        (stage / "screenshots/manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        (stage / "index.html").write_text(site_index())
        shutil.copytree(stage, args.output, dirs_exist_ok=True)

    print(f"Built {len(manifest)} original PNGs and {len(manifest)} JPEG previews in {args.output}.")
    print(f"README loads {sum(entry['previewBytes'] for entry in manifest if entry['language'] == PRIMARY_LANGUAGE or entry['scene'] == 'overview-light'):,} bytes of previews.")


if __name__ == "__main__":
    main()
