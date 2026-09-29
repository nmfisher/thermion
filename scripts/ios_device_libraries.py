#!/usr/bin/env python3
"""Extract iOS device libraries from XCFrameworks and validate packaged archives."""

import argparse
from pathlib import Path
import plistlib
import re
import shutil
import subprocess


def extract(source: Path, destination: Path) -> None:
    frameworks = sorted(source.glob("*.xcframework"))
    if not frameworks:
        raise ValueError(f"No XCFrameworks found in {source}")
    destination.mkdir(parents=True, exist_ok=True)
    for framework in frameworks:
        with (framework / "Info.plist").open("rb") as stream:
            metadata = plistlib.load(stream)
        matches = [
            library
            for library in metadata["AvailableLibraries"]
            if library["SupportedPlatform"] == "ios"
            and "SupportedPlatformVariant" not in library
            and "arm64" in library["SupportedArchitectures"]
        ]
        if len(matches) != 1:
            raise ValueError(
                f"{framework}: expected exactly one iOS device arm64 library, "
                f"found {len(matches)}"
            )
        library = matches[0]
        source_library = framework / library["LibraryIdentifier"] / library["LibraryPath"]
        shutil.copyfile(source_library, destination / f"{framework.stem}.a")


def validate(directory: Path) -> None:
    libraries = sorted(directory.glob("*.a"))
    if not libraries:
        raise ValueError(f"No static libraries found in {directory}")
    for library in libraries:
        architectures = subprocess.check_output(
            ["xcrun", "lipo", "-archs", str(library)], text=True
        ).split()
        if "arm64" not in architectures:
            raise ValueError(f"{library}: missing arm64 architecture")
        commands = subprocess.check_output(
            ["xcrun", "otool", "-l", "-arch", "arm64", str(library)], text=True
        )
        # Inspect all archive members, accepting modern iOS platform records
        # and the legacy device load command used by older deployment targets.
        build_commands = re.findall(
            r"^\s*cmd (LC_BUILD_VERSION|LC_VERSION_MIN_\S+)\s*$", commands, re.MULTILINE
        )
        platforms = re.findall(r"^\s*platform (\S+)\s*$", commands, re.MULTILINE)
        if (
            not build_commands
            or any(cmd not in ("LC_BUILD_VERSION", "LC_VERSION_MIN_IPHONEOS")
                   for cmd in build_commands)
            or len(platforms) != build_commands.count("LC_BUILD_VERSION")
            or any(platform not in ("2", "IOS") for platform in platforms)
        ):
            raise ValueError(f"{library}: arm64 is not an iOS device library")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    extract_parser = commands.add_parser("extract")
    extract_parser.add_argument("source", type=Path)
    extract_parser.add_argument("destination", type=Path)
    validate_parser = commands.add_parser("validate")
    validate_parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "extract":
            extract(args.source, args.destination)
        else:
            validate(args.directory)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Error: {error}\n")


if __name__ == "__main__":
    main()
