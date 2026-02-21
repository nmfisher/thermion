#!/bin/bash

# Creates android release/debug zip files from an existing Filament out directory.
# Usage: ./zip_android.sh <OUT_DIR> <FILAMENT_VERSION> <OUTPUT_DIR>
# Example: ./zip_android.sh /tmp/out v1.69.1 /tmp
#
# NOTE: imageio/tinyexr must have been cross-compiled for each Android arch
# (placed at out/cmake-android-{release,debug}-{arch}/third_party/{imageio,tinyexr}/).
# The host-compiled versions at out/cmake-{release,debug}/ are NOT compatible.

if [ $# -lt 3 ]; then
  echo "Usage: $0 <OUT_DIR> <FILAMENT_VERSION> <OUTPUT_DIR>"
  echo "  OUT_DIR: path to Filament's out/ directory"
  echo "  FILAMENT_VERSION: e.g. v1.69.1"
  echo "  OUTPUT_DIR: where to write the zip files"
  exit 1
fi

OUT_DIR="$1"
FILAMENT_VERSION="$2"
OUTPUT_DIR="$3"

ARCHS="arm64-v8a armeabi-v7a x86_64 x86"

abi_to_cmake_arch() {
  case "$1" in
    arm64-v8a)   echo "aarch64" ;;
    armeabi-v7a) echo "arm7" ;;
    x86_64)      echo "x86_64" ;;
    x86)         echo "x86" ;;
  esac
}

for BUILD_TYPE in release debug; do
  STAGE_DIR=$(mktemp -d)
  echo "=== $BUILD_TYPE ==="

  for ARCH in $ARCHS; do
    CMAKE_ARCH=$(abi_to_cmake_arch "$ARCH")
    mkdir -p "$STAGE_DIR/$ARCH"

    # Copy main Filament libraries
    SRC="$OUT_DIR/android-${BUILD_TYPE}/filament/lib/$ARCH"
    if [ -d "$SRC" ]; then
      for lib in "$SRC"/*.a; do
        case "$(basename "$lib")" in
          *zstd*) echo "Skipping $(basename "$lib") (bundled in Filament)" ;;
          *) cp "$lib" "$STAGE_DIR/$ARCH/" ;;
        esac
      done
    else
      echo "WARNING: $SRC not found"
    fi

    # Copy imageio (cross-compiled per-arch)
    IMAGEIO_SRC="$OUT_DIR/cmake-android-${BUILD_TYPE}-${CMAKE_ARCH}/third_party/imageio/libimageio.a"
    if [ -f "$IMAGEIO_SRC" ]; then
      echo "Found imageio at $IMAGEIO_SRC"
      cp "$IMAGEIO_SRC" "$STAGE_DIR/$ARCH/"
    else
      echo "WARNING: libimageio.a not found for $ARCH at $IMAGEIO_SRC"
    fi

    # Copy tinyexr (cross-compiled per-arch)
    TINYEXR_SRC="$OUT_DIR/cmake-android-${BUILD_TYPE}-${CMAKE_ARCH}/third_party/tinyexr/libtinyexr.a"
    if [ -f "$TINYEXR_SRC" ]; then
      echo "Found tinyexr at $TINYEXR_SRC"
      cp "$TINYEXR_SRC" "$STAGE_DIR/$ARCH/"
    else
      echo "WARNING: libtinyexr.a not found for $ARCH at $TINYEXR_SRC"
    fi

    echo "$ARCH: $(ls "$STAGE_DIR/$ARCH/" | wc -l) libraries"
  done

  ZIP_FILE="$OUTPUT_DIR/filament-${FILAMENT_VERSION}-android-${BUILD_TYPE}.zip"
  cd "$STAGE_DIR"
  zip -r "$ZIP_FILE" . || {
    echo "Error: Failed to create $ZIP_FILE"
    exit 1
  }
  echo "Created: $ZIP_FILE"
  rm -rf "$STAGE_DIR"
done
