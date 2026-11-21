#!/usr/bin/env python3
"""Generate the published Dart constant from the repository's Filament pin."""

import argparse
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--check", action="store_true", help="Fail if the constant is stale")
args = parser.parse_args()

root = Path(__file__).resolve().parent.parent
_, version = (root / "filament.version").read_text().split()
if not re.fullmatch(r"v\d+\.\d+\.\d+", version):
    parser.error(f"Expected a Filament release tag, got {version!r}")

target = root / "thermion_dart/lib/filament_version.dart"
content = f"""// Generated from filament.version by scripts/generate-filament-version.py.
// Do not edit by hand.

/// The Filament release bundled with this version of Thermion.
///
/// Compile custom materials with `matc` from this release. Material packages
/// from an incompatible compiler can cause Filament to abort when loading them.
const String filamentVersion = '{version}';
"""
if args.check:
    if not target.exists() or target.read_text() != content:
        parser.exit(1, "Filament version constant is stale. Run python3 scripts/generate-filament-version.py\n")
else:
    target.write_text(content)
