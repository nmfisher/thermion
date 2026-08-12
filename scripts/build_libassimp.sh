#!/usr/bin/env bash
# Standalone libassimp build for fast iteration.
#
# Builds libz + libassimp from a Filament checkout in ~90 sec, without
# compiling any Filament library.  Useful for validating tnt overlay changes
# or the patcher before running a full platform build.
#
# Usage:
#   scripts/build_libassimp.sh <FILAMENT_BASE_DIR> [TARGET_DIR] [build_type]
#
#   FILAMENT_BASE_DIR   Path to the Filament checkout (required).
#   TARGET_DIR          Where to copy libassimp.a (default: out/libassimp-build).
#   build_type          "release" (default) or "debug".
#
# Examples:
#   scripts/build_libassimp.sh /Volumes/T7/projects/filament
#   scripts/build_libassimp.sh /Volumes/T7/projects/filament /tmp/assimp-out debug

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILAMENT_BASE_DIR="${1:?Usage: $0 <FILAMENT_BASE_DIR> [TARGET_DIR] [build_type]}"
TARGET_DIR="${2:-out/libassimp-build}"
BUILD_TYPE="${3:-release}"

# Normalise build-type string to CMake convention (first letter upper-case).
if [ "$BUILD_TYPE" = "debug" ]; then
    CMAKE_BUILD_TYPE="Debug"
    NINJA_DIR="cmake-debug"
elif [ "$BUILD_TYPE" = "release" ]; then
    CMAKE_BUILD_TYPE="Release"
    NINJA_DIR="cmake-release"
else
    echo "build_type must be 'release' or 'debug', got '$BUILD_TYPE'"
    exit 1
fi

echo "=== Building libassimp ($CMAKE_BUILD_TYPE) ==="
echo "  Filament:  $FILAMENT_BASE_DIR"
echo "  Target:    $TARGET_DIR"

# ------------------------------------------------------------------
# 1.  Build libz  (assimp depends on it)
# ------------------------------------------------------------------
echo ""
echo "--- libz ---"
LIBZ_DIR="$FILAMENT_BASE_DIR/third_party/libz"
mkdir -p "$FILAMENT_BASE_DIR/out/$NINJA_DIR/third_party/libz"
cd "$FILAMENT_BASE_DIR/out/$NINJA_DIR/third_party/libz"
if [ ! -f CMakeCache.txt ]; then
    cmake -G Ninja -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" "$LIBZ_DIR"
fi
ninja libz 2>/dev/null || ninja zlib 2>/dev/null || ninja

# ------------------------------------------------------------------
# 2.  Patch the tnt overlay
# ------------------------------------------------------------------
echo ""
echo "--- tnt overlay patch ---"
python3 "$SCRIPT_DIR/patch_libassimp_tnt.py" "$FILAMENT_BASE_DIR"

# ------------------------------------------------------------------
# 3.  Build libassimp
# ------------------------------------------------------------------
echo ""
echo "--- libassimp ---"
mkdir -p "$FILAMENT_BASE_DIR/out/$NINJA_DIR/third_party/libassimp"
cd "$FILAMENT_BASE_DIR/out/$NINJA_DIR/third_party/libassimp"
if [ ! -f CMakeCache.txt ]; then
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
        -DCMAKE_CXX_STANDARD=17 \
        -DASSIMP_BUILD_ASSIMP_TOOLS=OFF \
        -DASSIMP_BUILD_TESTS=OFF \
        -DASSIMP_BUILD_SAMPLES=OFF \
        -DASSIMP_WARNINGS_AS_ERRORS=OFF \
        "$FILAMENT_BASE_DIR/third_party/libassimp/tnt"
fi
ninja

# ------------------------------------------------------------------
# 4.  Copy the library
# ------------------------------------------------------------------
echo ""
echo "--- copy ---"
mkdir -p "$TARGET_DIR"
cp "libassimp.a" "$TARGET_DIR/libassimp.a"
echo "libassimp.a -> $TARGET_DIR/libassimp.a"
echo ""
echo "=== libassimp build complete ==="
