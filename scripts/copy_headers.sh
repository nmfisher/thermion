#!/bin/bash

# Copy Filament header files to thermion_dart/native/include/filament
# All shared headers go to the output directory.
# Only uberarchive.h differs between debug/release, copied to debug/ and release/ subdirs.

# Prevent macOS ._* resource fork files in copies and zips
export COPYFILE_DISABLE=1

# Save script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate arguments
if [ $# -lt 1 ]; then
  echo "Usage: $0 <FILAMENT_BASE_DIR> [options]"
  echo "Example: $0 /path/to/filament"
  echo "         $0 /path/to/filament --release"
  echo "         $0 /path/to/filament --debug"
  echo ""
  echo "Options:"
  echo "  --release       Copy release headers only"
  echo "  --debug         Copy debug headers only"
  echo "  (default)       Copy both release and debug headers"
  exit 1
fi

FILAMENT_BASE_DIR=$(cd "$1" && pwd)
OUTPUT_INCLUDE_DIR="$SCRIPT_DIR/../thermion_dart/native/include/filament"
shift 1

# Parse optional flags
BUILD_RELEASE=true
BUILD_DEBUG=true

for arg in "$@"; do
  case $arg in
    --release)
      BUILD_DEBUG=false
      ;;
    --debug)
      BUILD_RELEASE=false
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

# Validate FILAMENT_BASE_DIR exists
if [ ! -d "$FILAMENT_BASE_DIR" ]; then
  echo "Error: Filament base directory does not exist: $FILAMENT_BASE_DIR"
  exit 1
fi

# Determine header source directory (prefer release, fall back to debug)
if [ "$BUILD_RELEASE" = true ]; then
  HEADER_SOURCE="out/release/filament/include"
elif [ "$BUILD_DEBUG" = true ]; then
  HEADER_SOURCE="out/debug/filament/include"
fi

echo "Copying Filament header files to $OUTPUT_INCLUDE_DIR..."
rm -rf "$OUTPUT_INCLUDE_DIR"
mkdir -p "$OUTPUT_INCLUDE_DIR"
cd "$FILAMENT_BASE_DIR"
cp -R $HEADER_SOURCE/* "$OUTPUT_INCLUDE_DIR/" || {
  echo "Error: Failed to copy Filament headers"
  exit 1
}

# Copy imageio headers (not included in main include dir)
cp -R libs/imageio/include/* "$OUTPUT_INCLUDE_DIR/" || {
  echo "Error: Failed to copy imageio headers"
  exit 1
}

# Copy release-specific uberarchive.h
if [ "$BUILD_RELEASE" = true ]; then
  mkdir -p "$OUTPUT_INCLUDE_DIR/release/gltfio/materials"
  cp out/release/filament/include/gltfio/materials/uberarchive.h \
    "$OUTPUT_INCLUDE_DIR/release/gltfio/materials/" || {
    echo "Error: Failed to copy release uberarchive.h"
    exit 1
  }
fi

# Copy debug-specific uberarchive.h
if [ "$BUILD_DEBUG" = true ]; then
  mkdir -p "$OUTPUT_INCLUDE_DIR/debug/gltfio/materials"
  cp out/debug/filament/include/gltfio/materials/uberarchive.h \
    "$OUTPUT_INCLUDE_DIR/debug/gltfio/materials/" || {
    echo "Error: Failed to copy debug uberarchive.h"
    exit 1
  }
fi

# Copy bluevk + vulkan headers (used by Vulkan backend)
mkdir -p "$OUTPUT_INCLUDE_DIR"
cp -R "$FILAMENT_BASE_DIR/libs/bluevk/include/"* "$OUTPUT_INCLUDE_DIR/" || {
  echo "Error: Failed to copy bluevk headers"
  exit 1
}

# Copy source-tree utils/compiler.h (install tree strips UTILS_SHARED_LINKING)
if [ -f "$FILAMENT_BASE_DIR/libs/utils/include/utils/compiler.h" ]; then
  cp "$FILAMENT_BASE_DIR/libs/utils/include/utils/compiler.h" \
     "$OUTPUT_INCLUDE_DIR/utils/compiler.h"
fi

# Copy stb_image.h (third-party header used by TTexture.cpp)
mkdir -p "$OUTPUT_INCLUDE_DIR/third_party/stb"
cp "$FILAMENT_BASE_DIR/third_party/stb/stb_image.h" "$OUTPUT_INCLUDE_DIR/third_party/stb/" || {
  echo "Error: Failed to copy stb_image.h"
  exit 1
}

# Copy Assimp headers (for OBJ import support)
mkdir -p "$OUTPUT_INCLUDE_DIR/third_party/libassimp/include"
cp -R "$FILAMENT_BASE_DIR/third_party/libassimp/include/assimp" "$OUTPUT_INCLUDE_DIR/third_party/libassimp/include/" || {
  echo "Error: Failed to copy Assimp headers"
  exit 1
}

echo "Headers copied to: $OUTPUT_INCLUDE_DIR"
