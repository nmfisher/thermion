"""Stage a matching macOS Filament SSS build and optionally run GPU acceptance.

python3 tool/sss_local.py /path/to/filament-sss --test
Build out/sss first, as described in docs/screen-space-subsurface-scattering.md.
The temporary native-hook override is restored even when tests fail.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("filament", type=Path)
parser.add_argument("--test", action="store_true")
args = parser.parse_args()
engine = args.filament.resolve()
build = engine / "out/sss"
stage = engine / "stage"
header = build / "libs/gltfio/materials/uberarchive.h"
if not header.exists():
    parser.error("Build the matching engine and uberarchive in out/sss first")
stage.mkdir(exist_ok=True)
for archive in build.rglob("*.a"):
    shutil.copy2(archive, stage / archive.name)
for directory in [engine / "filament/include", engine / "filament/backend/include",
                  *sorted((engine / "libs").glob("*/include"))]:
    shutil.copytree(directory, stage / "include", dirs_exist_ok=True)
# Combined archives contain the transitive objects expected by Thermion's hook.
for name in ["filamat", "geometry"]:
    shutil.copy2(build / f"libs/{name}/lib{name}_combined.a", stage / f"lib{name}.a")
subprocess.run(["/usr/bin/libtool", "-static", "-o", str(stage / "libgltfio_core.a"),
                str(build / "libs/gltfio/libgltfio_core.a"),
                str(build / "third_party/meshoptimizer/tnt/libmeshoptimizer.a")], check=True)
destination = stage / "include/gltfio/materials"
destination.mkdir(parents=True, exist_ok=True)
shutil.copy2(header, destination / header.name)
print(f"Matching libraries and headers staged in {stage}", flush=True)

if args.test:
    package = Path(__file__).resolve().parent.parent
    pubspec = package / "pubspec.yaml"
    original = pubspec.read_bytes()
    if b"\nhooks:" in original:
        parser.error("Remove the existing local hooks block before using --test")
    try:
        pubspec.write_bytes(original + (
            "\nhooks:\n  user_defines:\n    thermion_dart:\n"
            f"      filament_path: {json.dumps(str(stage))}\n").encode())
        subprocess.run(["dart", "test", "test/subsurface_scattering_tests.dart",
                        "test/sss_visual_demo_test.dart", "test/all_materials_smoke_test.dart",
                        "--concurrency=1"], cwd=package, check=True)
    finally:
        pubspec.write_bytes(original)
