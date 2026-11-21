#!/usr/bin/env python3
"""Resolve a Filament artifact URL through the shipped pin.

Prints the R2 URL for filament-<version>-<platform>-<variant>.zip, using the
content-addressed (hash-suffixed) key when thermion_dart/filament.libs.json
pins that platform/variant, else the legacy mutable key. Mirrors
resolveFilamentArtifact in thermion_dart/lib/src/hooks/filament_artifacts.dart
— keep the two in sync (the Dart side is unit-tested; this is for shell/CI
callers that cannot run Dart, e.g. the Makefile and curl-based CI steps).

Usage:
  filament-artifact-url.py <platform> <variant> [--version vX.Y.Z]
                           [--pin PATH] [--name-only]

Defaults: version from the repo's filament.version file; pin from
thermion_dart/filament.libs.json relative to the repo root. --name-only
prints just the zip base name (no URL).
"""

import argparse
import json
import re
import sys
from pathlib import Path

R2_BASE = "https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev"
HASH_LEN = 16
PLATFORMS = {
    "macos", "ios", "ios-simulator", "android",
    "linux", "linux-arm64", "windows", "web",
}

root = Path(__file__).resolve().parent.parent

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("platform", choices=sorted(PLATFORMS))
parser.add_argument("variant", choices=["release", "debug"])
parser.add_argument("--version", help="Filament tag (default: filament.version)")
parser.add_argument("--pin", type=Path,
                    default=root / "thermion_dart" / "filament.libs.json")
parser.add_argument("--name-only", action="store_true",
                    help="print the zip base name instead of the full URL")
args = parser.parse_args()

version = args.version
if version is None:
    _, version = (root / "filament.version").read_text().split()
if not re.fullmatch(r"v\d+\.\d+\.\d+", version):
    parser.error(f"Expected a Filament release tag, got {version!r}")

name = f"filament-{version}-{args.platform}-{args.variant}.zip"
try:
    pin = json.loads(args.pin.read_text())
except (OSError, ValueError):
    pin = {}  # missing/malformed pin -> legacy key (same fallback as the hook)

sha = pin.get(f"{args.platform}/{args.variant}") if isinstance(pin, dict) else None
if isinstance(sha, str) and re.fullmatch(r"[0-9a-fA-F]{64}", sha):
    name = (f"filament-{version}-{args.platform}-{args.variant}"
            f"-{sha.lower()[:HASH_LEN]}.zip")

print(name if args.name_only else f"{R2_BASE}/{name}")
