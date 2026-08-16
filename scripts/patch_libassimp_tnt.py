#!/usr/bin/env python3
"""
Idempotently patches filament/third_party/libassimp/tnt/CMakeLists.txt so the
built libassimp supports what Thermion needs, on top of the OBJ + FBX import
that the `tnt` overlay ships with:

  * STL + PLY import  (enables the multi-format loader's STL/PLY paths)
  * FBX export        (enables Assimp::Exporter for FBX)

Why a patch is required
-----------------------
The `tnt` overlay hardcodes the feature set:
  - importer set via an `add_definitions(-DASSIMP_BUILD_NO_*_IMPORTER ...)` block
    (NOT option-driven, so it can't be steered with -D flags from our cmake call);
  - export is effectively off because the per-format exporter *sources* are not
    compiled, even though Exporter.cpp's registration table is. (The overlay sets
    `-DASSIMP_BUILD_NO_EXPORTER`, but assimp's real guard is
    `ASSIMP_BUILD_NO_EXPORT`; the ...EXPORTER macro is a no-op. Before Thermion's
    native/src/c_api/model_export.cpp referenced Assimp::Exporter, Exporter.o
    was never pulled from the archive; now that it is, the FBX exporter sources
    below must be compiled or the link fails.)

So to make export usable we (a) compile the exporter sources for FBX,
and (b) disable every *other* exporter via per-format `ASSIMP_BUILD_NO_*_EXPORTER`
defines, so Exporter.cpp's table only references symbols we actually compile.

Usage:  python3 patch_libassimp_tnt.py [FILAMENT_BASE_DIR]
If FILAMENT_BASE_DIR is not passed, the env var of the same name is used.

Safe to re-run: detects its own marker and exits early. Backs up the original
to CMakeLists.txt.bak.thermion on first run. Bails loudly if the expected
anchors are missing (i.e. the overlay layout changed upstream).
"""
import os
import sys
import shutil

MARKER = "# THERMION_ASSIMP_TNT_PATCH"

# Importer disables to REMOVE (enable these importers).
IMPORTER_ENABLE = [
    "-DASSIMP_BUILD_NO_STL_IMPORTER",
    "-DASSIMP_BUILD_NO_PLY_IMPORTER",
    "-DASSIMP_BUILD_NO_EXPORTER",  # no-op in assimp source, but drop it for clarity
]

# Per-format exporter disables to ADD. We enable export only for FBX (whose
# sources we compile below); every other exporter is disabled so Exporter.cpp's
# registration table references only resolvable symbols.
#
# glTF export is intentionally NOT enabled: the glTF exporter shares its asset
# model (glTF::Asset, AssetWriter, Accessor, ...) with the glTF importer, and
# that shared code is compiled out by ASSIMP_BUILD_NO_GLTF*_IMPORTER. Enabling
# glTF export would therefore require also enabling the full glTF importer
# (pointless here, since Filament loads glTF natively via gltfio).
EXPORTER_DISABLE_BLOCK = """add_definitions(
    -DASSIMP_BUILD_NO_COLLADA_EXPORTER
    -DASSIMP_BUILD_NO_X_EXPORTER
    -DASSIMP_BUILD_NO_STEP_EXPORTER
    -DASSIMP_BUILD_NO_OBJ_EXPORTER
    -DASSIMP_BUILD_NO_STL_EXPORTER
    -DASSIMP_BUILD_NO_PLY_EXPORTER
    -DASSIMP_BUILD_NO_3DS_EXPORTER
    -DASSIMP_BUILD_NO_ASSBIN_EXPORTER
    -DASSIMP_BUILD_NO_ASSXML_EXPORTER
    -DASSIMP_BUILD_NO_X3D_EXPORTER
    -DASSIMP_BUILD_NO_3MF_EXPORTER
    -DASSIMP_BUILD_NO_ASSJSON_EXPORTER
    -DASSIMP_BUILD_NO_GLTF_EXPORTER
)
"""

# Sources to ADD to set(SRCS ...).
#   STL/PLY importers; FBX exporter (self-contained, uses existing FBX infra).
NEW_SOURCES = [
    "    ${SRC_DIR}/code/STL/STLLoader.cpp",
    "    ${SRC_DIR}/code/Ply/PlyLoader.cpp",
    "    ${SRC_DIR}/code/Ply/PlyParser.cpp",
    "    ${SRC_DIR}/code/FBX/FBXExporter.cpp",
    "    ${SRC_DIR}/code/FBX/FBXExportNode.cpp",
    "    ${SRC_DIR}/code/FBX/FBXExportProperty.cpp",
]


def main() -> int:
    filament = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("FILAMENT_BASE_DIR")
    if not filament:
        print("patch_libassimp_tnt: pass FILAMENT_BASE_DIR (arg or env)", file=sys.stderr)
        return 1

    tnt = os.path.join(filament, "third_party", "libassimp", "tnt", "CMakeLists.txt")
    if not os.path.isfile(tnt):
        print(f"patch_libassimp_tnt: not found: {tnt}", file=sys.stderr)
        return 1

    with open(tnt, "r", encoding="utf-8") as f:
        text = f.read()

    if MARKER in text:
        print("patch_libassimp_tnt: already patched, skipping.")
        return 0

    # Sanity: confirm the anchors we depend on still exist.
    for anchor in ["ASSIMP_BUILD_NO_STL_IMPORTER", "set(SRCS", "add_library(${TARGET} STATIC"]:
        if anchor not in text:
            print(
                f"patch_libassimp_tnt: anchor {anchor!r} not found; "
                f"tnt overlay layout may have changed. Aborting without changes.",
                file=sys.stderr,
            )
            return 1

    shutil.copyfile(tnt, tnt + ".bak.thermion")
    print(f"patch_libassimp_tnt: backed up original to {tnt}.bak.thermion")

    # 1. Drop the importer disables we want to enable.
    lines = text.splitlines(keepends=True)
    out = []
    for line in lines:
        stripped = line.strip()
        if any(stripped == d for d in IMPORTER_ENABLE):
            continue  # removed
        out.append(line)
    text = "".join(out)

    # 2. Insert new sources immediately after `set(SRCS`.
    src_insert = "\n".join(NEW_SOURCES) + "\n"
    marker_comment = f"    {MARKER}: additional importers/exporters\n"
    if "set(SRCS\n" in text:
        text = text.replace("set(SRCS\n", "set(SRCS\n" + marker_comment + src_insert, 1)
    else:
        text = text.replace("set(SRCS", "set(SRCS\n" + marker_comment + src_insert, 1)

    # 3. Insert the per-format exporter-disable block right before add_library.
    export_block = f"    {MARKER}: disable exporters we don't ship sources for\n" + EXPORTER_DISABLE_BLOCK + "\n"
    text = text.replace(
        "add_library(${TARGET} STATIC",
        export_block + "add_library(${TARGET} STATIC",
        1,
    )

    with open(tnt, "w", encoding="utf-8") as f:
        f.write(text)

    print("patch_libassimp_tnt: enabled STL/PLY import + FBX export.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
