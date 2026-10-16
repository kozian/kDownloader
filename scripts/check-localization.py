#!/usr/bin/env python3
"""Checks App/Localizable.xcstrings against the strings the compiler extracted.

    xcodebuild … build            # produces *.stringsdata
    python3 scripts/check-localization.py [--derived-data .build/xcode]

Reports keys missing from the catalog, keys without a Russian translation,
catalog entries no longer used by the code, and Russian values that use words
the glossary (design.md of ui-polish-and-ytdlp-updates) rules out. Exits 1 when
anything is found. Command-line builds do not add keys to the catalog; only the
Xcode app does, so this check replaces that.
"""
import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "App", "Localizable.xcstrings")

# Russian words the glossary rules out, with the term to use instead.
FORBIDDEN = [
    (r"[Пп]лощадк", "сайт"),
    (r"\bЗагрузить\b", "Скачать"),
    (r"\b[Зз]агрузк[аеуо]\w*", "скачивание (папка «Загрузки» — системное имя)"),
    (r"\bЛог\b", "Журнал"),
    (r"дорожк\w* звука", "аудиодорожка"),
    (r"[Оо]ткрывается в QuickTime", "лучшая совместимость с Mac"),
]


def extracted_keys(derived_data):
    pattern = os.path.join(ROOT, derived_data, "Build/Intermediates.noindex/kDownloader.build/*/kDownloader.build/Objects-normal/*/*.stringsdata")
    files = glob.glob(pattern)
    if not files:
        sys.exit(f"no .stringsdata under {derived_data}; build the app first")
    keys = set()
    decoder = json.JSONDecoder()
    for path in files:
        data = open(path, encoding="utf-8").read()
        index = 0
        while index < len(data):
            while index < len(data) and data[index].isspace():
                index += 1
            if index >= len(data):
                break
            obj, index = decoder.raw_decode(data, index)
            for entries in obj.get("tables", {}).values():
                keys.update(entry["key"] for entry in entries)
    return keys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--derived-data", default=".build/xcode")
    args = parser.parse_args()

    keys = extracted_keys(args.derived_data)
    strings = json.load(open(CATALOG, encoding="utf-8"))["strings"]
    problems = []
    for key in sorted(keys - strings.keys()):
        problems.append(f"missing from catalog: {key!r}")
    for key, entry in sorted(strings.items()):
        if key not in keys:
            problems.append(f"no longer used: {key!r}")
            continue
        if entry.get("shouldTranslate") is False:
            continue
        value = entry.get("localizations", {}).get("ru", {}).get("stringUnit", {}).get("value")
        if not value:
            problems.append(f"no Russian translation: {key!r}")
            continue
        for pattern, instead in FORBIDDEN:
            if re.search(pattern, value):
                problems.append(f"glossary: {value!r} — use {instead}")
    for problem in problems:
        print(problem)
    print(f"{len(keys)} keys, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
