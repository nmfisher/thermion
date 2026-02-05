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

# Run release build
if [ "$BUILD_RELEASE" = true ]; then
  echo "Building Filament for macOS (release)..."
  ./build.sh -C -l -i -f -p desktop release || {
    echo "Error: Filament release build failed"
    exit 1
  }
fi

# Run debug build (with framegraph viewer/material debug server)
if [ "$BUILD_DEBUG" = true ]; then
  echo "Building Filament for macOS (debug)..."
  ./build.sh -c -l -i -f -t -d -p desktop debug || {
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

# Copy header files to thermion_dart (separate directories for release and debug)
# Headers go under filament/release/filament and filament/debug/filament
# so includes like <filament/SomeHeader.h> work correctly
if [ "$BUILD_RELEASE" = true ]; then
  echo "Copying Filament release header files to thermion_dart..."
  THERMION_INCLUDE_RELEASE="$SCRIPT_DIR/thermion_dart/native/include/filament/release/filament"

  # Clean and recreate release include directory
  rm -rf "$THERMION_INCLUDE_RELEASE"
  mkdir -p "$THERMION_INCLUDE_RELEASE"

  # Copy all headers from Filament's release include directory
  cd "$FILAMENT_BASE_DIR"
  cp -R out/release/filament/include/* "$THERMION_INCLUDE_RELEASE/" || {
    echo "Error: Failed to copy Filament release headers"
    exit 1
  }

  # Copy imageio headers (not included in main include dir)
  mkdir -p "$THERMION_INCLUDE_RELEASE/imageio"
  cp -R libs/imageio/include/* "$THERMION_INCLUDE_RELEASE/imageio/" || {
    echo "Error: Failed to copy imageio headers"
    exit 1
  }

  echo "Release headers copied to: $THERMION_INCLUDE_RELEASE"
fi

if [ "$BUILD_DEBUG" = true ]; then
  echo "Copying Filament debug header files to thermion_dart..."
  THERMION_INCLUDE_DEBUG="$SCRIPT_DIR/thermion_dart/native/include/filament/debug/filament"

  # Clean and recreate debug include directory
  rm -rf "$THERMION_INCLUDE_DEBUG"
  mkdir -p "$THERMION_INCLUDE_DEBUG"

  # Copy all headers from Filament's debug include directory
  cd "$FILAMENT_BASE_DIR"
  cp -R out/debug/filament/include/* "$THERMION_INCLUDE_DEBUG/" || {
    echo "Error: Failed to copy Filament debug headers"
    exit 1
  }

  # Copy imageio headers (not included in main include dir)
  mkdir -p "$THERMION_INCLUDE_DEBUG/imageio"
  cp -R libs/imageio/include/* "$THERMION_INCLUDE_DEBUG/imageio/" || {
    echo "Error: Failed to copy imageio headers"
    exit 1
  }

  echo "Debug headers copied to: $THERMION_INCLUDE_DEBUG"
fi

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
