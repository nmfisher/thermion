#!/bin/bash

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

FILAMENT_BASE_DIR=$(cd "$1" && pwd)
FILAMENT_VERSION=$2
OUTPUT_BASE_DIR=$(cd "$3" && pwd)
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
TARGET_RELEASE_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/android/release"
TARGET_DEBUG_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/android/debug"

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

# Change to Filament directory and checkout tag
cd "$FILAMENT_BASE_DIR" || exit 1
git stash
git reset --hard
echo "Checking out tag: $FILAMENT_VERSION"
git checkout "${FILAMENT_VERSION}" || {
  echo "Error: Failed to checkout tag: $FILAMENT_VERSION"
  exit 1
}

# Patch Filament's build.sh to skip samples (add -DFILAMENT_SKIP_SAMPLES=ON to cmake commands)
echo "Patching Filament build.sh to skip samples..."
sed -i.bak 's|\${architectures} \\$|\${architectures} -DFILAMENT_SKIP_SAMPLES=ON \\|g' build.sh

# Set compiler to clang (Filament requires clang, rejects GCC)
export CC=clang
export CXX=clang++

# Run release build
if [ "$BUILD_RELEASE" = true ]; then
  echo "Building Filament for Android (release)..."
  ./build.sh -i -f -p android release || {
    echo "Error: Filament release build failed"
    exit 1
  }
fi

# Run debug build
if [ "$BUILD_DEBUG" = true ]; then
  echo "Building Filament for Android (debug)..."
  ./build.sh -i -f -t -d -p android debug || {
    echo "Error: Filament debug build failed"
    exit 1
  }
fi

# Android architectures
ARCHS="arm64-v8a armeabi-v7a x86_64 x86"

# Create target directories and copy libraries
echo "Copying libraries..."

if [ "$BUILD_RELEASE" = true ]; then
  mkdir -p "$TARGET_RELEASE_DIR" || {
    echo "Error: Failed to create target directory: $TARGET_RELEASE_DIR"
    exit 1
  }

  # Copy release libraries for each architecture
  echo "Copying release libraries..."
  for ARCH in $ARCHS; do
    mkdir -p "$TARGET_RELEASE_DIR/$ARCH" || {
      echo "Error: Failed to create directory: $TARGET_RELEASE_DIR/$ARCH"
      exit 1
    }
    cp out/android-release/filament/lib/$ARCH/*.a "$TARGET_RELEASE_DIR/$ARCH/" 2>/dev/null || {
      echo "Warning: No release libraries found for $ARCH"
    }
  done

  # Build and copy third-party libraries for release
  echo "Building third-party libraries for release..."
  ./build.sh -i -f -p android release zstd || {
    echo "Warning: zstd release build failed"
  }
  ./build.sh -i -f -p android release tinyexr || {
    echo "Warning: tinyexr release build failed"
  }
  ./build.sh -i -f -p android release imageio || {
    echo "Warning: imageio release build failed"
  }

  for ARCH in $ARCHS; do
    for LIB in libimageio.a libtinyexr.a; do
      cp out/android-release/filament/lib/$ARCH/$LIB "$TARGET_RELEASE_DIR/$ARCH/" 2>/dev/null || {
        echo "Warning: Failed to copy $LIB for $ARCH (release)"
      }
    done
  done
fi

if [ "$BUILD_DEBUG" = true ]; then
  mkdir -p "$TARGET_DEBUG_DIR" || {
    echo "Error: Failed to create target directory: $TARGET_DEBUG_DIR"
    exit 1
  }

  # Copy debug libraries for each architecture
  echo "Copying debug libraries..."
  for ARCH in $ARCHS; do
    mkdir -p "$TARGET_DEBUG_DIR/$ARCH" || {
      echo "Error: Failed to create directory: $TARGET_DEBUG_DIR/$ARCH"
      exit 1
    }
    cp out/android-debug/filament/lib/$ARCH/*.a "$TARGET_DEBUG_DIR/$ARCH/" 2>/dev/null || {
      echo "Warning: No debug libraries found for $ARCH"
    }
  done

  # Build and copy third-party libraries for debug
  echo "Building third-party libraries for debug..."
  ./build.sh -i -f -p android debug zstd || {
    echo "Warning: zstd debug build failed"
  }
  ./build.sh -i -f -p android debug tinyexr || {
    echo "Warning: tinyexr debug build failed"
  }
  ./build.sh -i -f -p android debug imageio || {
    echo "Warning: imageio debug build failed"
  }

  for ARCH in $ARCHS; do
    for LIB in libimageio.a libtinyexr.a; do
      cp out/android-debug/filament/lib/$ARCH/$LIB "$TARGET_DEBUG_DIR/$ARCH/" 2>/dev/null || {
        echo "Warning: Failed to copy $LIB for $ARCH (debug)"
      }
    done
  done
fi

# Copy header files to thermion_dart
# All shared headers go to native/include/filament/
# Only uberarchive.h differs between debug/release, copied to debug/ and release/ subdirs
THERMION_INCLUDE="$SCRIPT_DIR/../thermion_dart/native/include/filament"

if [ "$BUILD_RELEASE" = true ]; then
  HEADER_SOURCE="out/android-release/filament/include"
elif [ "$BUILD_DEBUG" = true ]; then
  HEADER_SOURCE="out/android-debug/filament/include"
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
  cp out/android-release/filament/include/gltfio/materials/uberarchive.h \
    "$THERMION_INCLUDE/release/gltfio/materials/" || {
    echo "Error: Failed to copy release uberarchive.h"
    exit 1
  }
fi

# Copy debug-specific uberarchive.h
if [ "$BUILD_DEBUG" = true ]; then
  mkdir -p "$THERMION_INCLUDE/debug/gltfio/materials"
  cp out/android-debug/filament/include/gltfio/materials/uberarchive.h \
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
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-android-release.zip" . || {
    echo "Error: Failed to create release zip"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  echo "Creating debug zip..."
  cd "$TARGET_DEBUG_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-android-debug.zip" . || {
    echo "Error: Failed to create debug zip"
    exit 1
  }
fi

echo "Build completed successfully!"
if [ "$BUILD_RELEASE" = true ]; then
  echo "Release libraries: $TARGET_RELEASE_DIR"
  echo "Release zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-android-release.zip"
fi
if [ "$BUILD_DEBUG" = true ]; then
  echo "Debug libraries: $TARGET_DEBUG_DIR"
  echo "Debug zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-android-debug.zip"
fi
