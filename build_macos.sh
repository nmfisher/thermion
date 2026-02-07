#!/bin/bash

# Prevent macOS ._* resource fork files in copies and zips
export COPYFILE_DISABLE=1

# Save script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR> [options]"
  echo "Example: $0 /path/to/filament v1.69.0 /path/to/output"
  echo "         $0 /path/to/filament v1.69.0 /path/to/output --clean"
  echo "         $0 /path/to/filament v1.69.0 /path/to/output --release"
  echo ""
  echo "Options:"
  echo "  --clean         Remove existing target directories before building"
  echo "  --release       Build release only"
  echo "  --debug         Build debug only"
  echo "  (default)       Build both release and debug"
  exit 1
fi

FILAMENT_BASE_DIR=$1
FILAMENT_VERSION=$2
OUTPUT_BASE_DIR=$3
shift 3

# Parse optional flags
CLEAN_FLAG=""
BUILD_RELEASE=true
BUILD_DEBUG=true

for arg in "$@"; do
  case $arg in
    --clean)
      CLEAN_FLAG="--clean"
      ;;
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

# Validate OUTPUT_BASE_DIR exists
if [ ! -d "$OUTPUT_BASE_DIR" ]; then
  echo "Error: Output base directory does not exist: $OUTPUT_BASE_DIR"
  exit 1
fi

# Validate FILAMENT_BASE_DIR exists
if [ ! -d "$FILAMENT_BASE_DIR" ]; then
  echo "Error: Filament base directory does not exist: $FILAMENT_BASE_DIR"
  exit 1
fi

# Validate build.sh exists in FILAMENT_BASE_DIR
if [ ! -f "$FILAMENT_BASE_DIR/build.sh" ]; then
  echo "Error: build.sh not found in: $FILAMENT_BASE_DIR"
  exit 1
fi

# Check if target directories already exist
TARGET_RELEASE_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/macos/release"
TARGET_DEBUG_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/macos/debug"

if [ "$BUILD_RELEASE" = true ] && [ -d "$TARGET_RELEASE_DIR" ]; then
  if [ "$CLEAN_FLAG" = "--clean" ]; then
    echo "Removing existing release target directory..."
    rm -rf "$TARGET_RELEASE_DIR"
  else
    echo "Error: Release target directory already exists: $TARGET_RELEASE_DIR"
    echo "Please remove it first or use --clean to rebuild."
    exit 1
  fi
fi

if [ "$BUILD_DEBUG" = true ] && [ -d "$TARGET_DEBUG_DIR" ]; then
  if [ "$CLEAN_FLAG" = "--clean" ]; then
    echo "Removing existing debug target directory..."
    rm -rf "$TARGET_DEBUG_DIR"
  else
    echo "Error: Debug target directory already exists: $TARGET_DEBUG_DIR"
    echo "Please remove it first or use --clean to rebuild."
    exit 1
  fi
fi


# Change to Filament directory and checkout branch
cd "$FILAMENT_BASE_DIR" || exit 1
git stash
git reset --hard
echo "Checking out branch: thermion-custom-build"
git checkout thermion-custom-build || {
  echo "Error: Failed to checkout branch: thermion-custom-build"
  exit 1
}

# Patch Filament's build.sh to skip samples (add -DFILAMENT_SKIP_SAMPLES=ON to cmake commands)
echo "Patching Filament build.sh to skip samples..."
sed -i.bak 's|\${architectures} \\$|\${architectures} -DFILAMENT_SKIP_SAMPLES=ON \\|g' build.sh

# Run release build
if [ "$BUILD_RELEASE" = true ]; then
  echo "Building Filament for macOS (release)..."
  ./build.sh -l -i -f -p desktop release || {
    echo "Error: Filament release build failed"
    exit 1
  }
fi

# Run debug build (with framegraph viewer/material debug server)
if [ "$BUILD_DEBUG" = true ]; then
  echo "Building Filament for macOS (debug)..."
  ./build.sh -l -i -f -t -d -p desktop debug || {
    echo "Error: Filament debug build failed"
    exit 1
  }
fi

# Build third-party libraries for release
if [ "$BUILD_RELEASE" = true ]; then
  # Build libz for release
  echo "Building libz (release)..."
  cd "$FILAMENT_BASE_DIR"
  cd out/cmake-release/third_party
  rm -rf libz
  mkdir -p libz && cd libz
  cmake -G Ninja -DCMAKE_BUILD_TYPE=Release "$FILAMENT_BASE_DIR/third_party/libz"
  ninja

  # Build imageio for release
  echo "Building imageio (release)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-release/third_party"
  mkdir -p imageio && cd imageio
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_STANDARD=17 \
          -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
          -DZ_HAVE_UNISTD_H=1 \
          -DUSE_ZLIB=1 \
          -DIMPORT_EXECUTABLES_DIR=out \
          -DCMAKE_CXX_FLAGS="-I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
          "$FILAMENT_BASE_DIR/libs/imageio"
  ninja

  # Build tinyexr for release
  echo "Building tinyexr (release)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-release/third_party"
  mkdir -p tinyexr && cd tinyexr
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 \
          -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
          -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
          -DCMAKE_CXX_FLAGS="-Wno-poison-system-directories -Wno-switch-default -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
          "$FILAMENT_BASE_DIR/third_party/tinyexr"
  ninja
fi

# Build third-party libraries for debug
if [ "$BUILD_DEBUG" = true ]; then
  # Build libz for debug
  echo "Building libz (debug)..."
  cd "$FILAMENT_BASE_DIR"
  git checkout -- third_party/libz/zconf.h
  cd out/cmake-debug/third_party
  mkdir -p libz && cd libz
  cmake -G Ninja -DCMAKE_BUILD_TYPE=Debug "$FILAMENT_BASE_DIR/third_party/libz"
  ninja

  # Build imageio for debug
  echo "Building imageio (debug)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-debug/third_party"
  mkdir -p imageio && cd imageio
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Debug \
          -DCMAKE_CXX_STANDARD=17 \
          -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
          -DZ_HAVE_UNISTD_H=1 \
          -DUSE_ZLIB=1 \
          -DIMPORT_EXECUTABLES_DIR=out \
          -DCMAKE_CXX_FLAGS="-I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
          "$FILAMENT_BASE_DIR/libs/imageio"
  ninja

  # Build tinyexr for debug
  echo "Building tinyexr (debug)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-debug/third_party"
  mkdir -p tinyexr && cd tinyexr
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_STANDARD=17 \
          -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
          -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
          -DCMAKE_CXX_FLAGS="-Wno-poison-system-directories -Wno-switch-default -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
          "$FILAMENT_BASE_DIR/third_party/tinyexr"
  ninja
fi

# Create target directories and copy libs
echo "Copying libraries..."

if [ "$BUILD_RELEASE" = true ]; then
  mkdir -p "$TARGET_RELEASE_DIR" || {
    echo "Error: Failed to create target directory: $TARGET_RELEASE_DIR"
    exit 1
  }
fi
if [ "$BUILD_DEBUG" = true ]; then
  mkdir -p "$TARGET_DEBUG_DIR" || {
    echo "Error: Failed to create target directory: $TARGET_DEBUG_DIR"
    exit 1
  }
fi

# Copy release libraries
if [ "$BUILD_RELEASE" = true ]; then
  echo "Copying release libraries..."
  cd "$FILAMENT_BASE_DIR"
  cp out/release/filament/lib/universal/*.a "$TARGET_RELEASE_DIR/" || {
    echo "Error: Failed to copy release libraries"
    exit 1
  }
fi

# Copy release third-party libraries
if [ "$BUILD_RELEASE" = true ]; then
  echo "Copying release third-party libraries..."
  cd "$FILAMENT_BASE_DIR"
  cp out/cmake-release/third_party/libz/*.a "$TARGET_RELEASE_DIR/" || echo "Warning: No libz libraries found"
  cp out/cmake-release/third_party/imageio/*.a "$TARGET_RELEASE_DIR/" || {
    echo "Error: Failed to copy imageio libraries"
    exit 1
  }
  cp out/cmake-release/third_party/tinyexr/*.a "$TARGET_RELEASE_DIR/" || {
    echo "Error: Failed to copy tinyexr libraries"
    exit 1
  }
fi

# Copy debug libraries
if [ "$BUILD_DEBUG" = true ]; then
  echo "Copying debug libraries..."
  cd "$FILAMENT_BASE_DIR"
  cp out/debug/filament/lib/universal/*.a "$TARGET_DEBUG_DIR/" || {
    echo "Error: Failed to copy debug libraries"
    exit 1
  }

  # Copy debug third-party libraries
  echo "Copying debug third-party libraries..."
  cd "$FILAMENT_BASE_DIR"
  cp out/cmake-debug/third_party/libz/*.a "$TARGET_DEBUG_DIR/" || echo "Warning: No libz libraries found"
  cp out/cmake-debug/third_party/imageio/*.a "$TARGET_DEBUG_DIR/" || {
    echo "Error: Failed to copy imageio libraries"
    exit 1
  }
  cp out/cmake-debug/third_party/tinyexr/*.a "$TARGET_DEBUG_DIR/" || {
    echo "Error: Failed to copy tinyexr libraries"
    exit 1
  }
fi

# Copy header files to thermion_dart
# All shared headers go to native/include/filament/
# Only uberarchive.h differs between debug/release, copied to debug/ and release/ subdirs
THERMION_INCLUDE="$SCRIPT_DIR/thermion_dart/native/include/filament"

if [ "$BUILD_RELEASE" = true ]; then
  HEADER_SOURCE="out/release/filament/include"
elif [ "$BUILD_DEBUG" = true ]; then
  HEADER_SOURCE="out/debug/filament/include"
fi

echo "Copying Filament header files to thermion_dart..."
rm -rf "$THERMION_INCLUDE"
mkdir -p "$THERMION_INCLUDE"
cd "$FILAMENT_BASE_DIR"
cp -R $HEADER_SOURCE/* "$THERMION_INCLUDE/" || {
  echo "Error: Failed to copy Filament headers"
  exit 1
}

# Copy imageio headers (not included in main include dir)
mkdir -p "$THERMION_INCLUDE/imageio"
cp -R libs/imageio/include/* "$THERMION_INCLUDE/imageio/" || {
  echo "Error: Failed to copy imageio headers"
  exit 1
}

# Copy release-specific uberarchive.h
if [ "$BUILD_RELEASE" = true ]; then
  mkdir -p "$THERMION_INCLUDE/release/gltfio/materials"
  cp out/release/filament/include/gltfio/materials/uberarchive.h \
    "$THERMION_INCLUDE/release/gltfio/materials/" || {
    echo "Error: Failed to copy release uberarchive.h"
    exit 1
  }
fi

# Copy debug-specific uberarchive.h
if [ "$BUILD_DEBUG" = true ]; then
  mkdir -p "$THERMION_INCLUDE/debug/gltfio/materials"
  cp out/debug/filament/include/gltfio/materials/uberarchive.h \
    "$THERMION_INCLUDE/debug/gltfio/materials/" || {
    echo "Error: Failed to copy debug uberarchive.h"
    exit 1
  }
fi

# Copy stb_image.h (third-party header used by TTexture.cpp)
mkdir -p "$THERMION_INCLUDE/third_party/stb"
cp "$FILAMENT_BASE_DIR/third_party/stb/stb_image.h" "$THERMION_INCLUDE/third_party/stb/" || {
  echo "Error: Failed to copy stb_image.h"
  exit 1
}

echo "Headers copied to: $THERMION_INCLUDE"

# Create zip files
if [ "$BUILD_RELEASE" = true ]; then
  echo "Creating release zip..."
  cd "$TARGET_RELEASE_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-macos-release.zip" . || {
    echo "Error: Failed to create release zip"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  echo "Creating debug zip..."
  cd "$TARGET_DEBUG_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-macos-debug.zip" . || {
    echo "Error: Failed to create debug zip"
    exit 1
  }
fi

echo "Build completed successfully!"
if [ "$BUILD_RELEASE" = true ]; then
  echo "Release libraries: $TARGET_RELEASE_DIR"
  echo "Release zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-macos-release.zip"
fi
if [ "$BUILD_DEBUG" = true ]; then
  echo "Debug libraries: $TARGET_DEBUG_DIR"
  echo "Debug zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-macos-debug.zip"
fi
