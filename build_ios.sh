#!/bin/bash

# Save script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate arguments
if [ $# -ne 3 ]; then
  echo "Usage: $0 <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR>"
  echo "Example: $0 /path/to/filament v1.69.0 /path/to/output"
  exit 1
fi

FILAMENT_BASE_DIR=$1
FILAMENT_VERSION=$2
OUTPUT_BASE_DIR=$3

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

# Check if target directories already exist (fail if exists)
TARGET_RELEASE_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/ios/release"
TARGET_DEBUG_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/ios/debug"

if [ -d "$TARGET_RELEASE_DIR" ] || [ -d "$TARGET_DEBUG_DIR" ]; then
  echo "Error: Target directory already exists."
  echo "Please remove it first if you want to rebuild."
  exit 1
fi

# Change to Filament directory and checkout tag
cd "$FILAMENT_BASE_DIR" || exit 1
echo "Checking out tag: $FILAMENT_VERSION"
git checkout "${FILAMENT_VERSION}" || {
  echo "Error: Failed to checkout tag: $FILAMENT_VERSION"
  exit 1
}

# Run release build
echo "Building Filament for iOS (release)..."
./build.sh -l -i -f -p ios release || {
  echo "Error: Filament release build failed"
  exit 1
}

# Run debug build
echo "Building Filament for iOS (debug)..."
./build.sh -l -i -f -p ios debug || {
  echo "Error: Filament debug build failed"
  exit 1
}

# Create target directories and copy libs
echo "Copying libraries..."

mkdir -p "$TARGET_RELEASE_DIR" || {
  echo "Error: Failed to create target directory: $TARGET_RELEASE_DIR"
  exit 1
}
mkdir -p "$TARGET_DEBUG_DIR" || {
  echo "Error: Failed to create target directory: $TARGET_DEBUG_DIR"
  exit 1
}

# Copy release libraries
echo "Copying release libraries..."
cp out/ios-release/filament/lib/universal/*.a "$TARGET_RELEASE_DIR/" || {
  echo "Error: Failed to copy release libraries"
  exit 1
}

# Copy debug libraries
echo "Copying debug libraries..."
cp out/ios-debug/filament/lib/universal/*.a "$TARGET_DEBUG_DIR/" || {
  echo "Error: Failed to copy debug libraries"
  exit 1
}

# Build libz for release
echo "Building libz (release)..."
cd "$FILAMENT_BASE_DIR"
cd out/cmake-ios-release-arm64/third_party
mkdir -p libz && cd libz
cmake -G Ninja -DIOS=1 -DIPHONEOS_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_BUILD_TYPE=Release "$FILAMENT_BASE_DIR/third_party/libz"
ninja

# Build imageio for release
echo "Building imageio (release)..."
cd "$FILAMENT_BASE_DIR/out/cmake-ios-release-arm64/third_party"
mkdir -p imageio && cd imageio
cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 \
        -DPLATFORM_NAME="iphonesimulator" \
        -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
        -DZ_HAVE_UNISTD_H=1 \
        -DUSE_ZLIB=1 \
        -DIMPORT_EXECUTABLES_DIR=out \
        -DCMAKE_CXX_FLAGS="-I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
        "$FILAMENT_BASE_DIR/libs/imageio"
ninja

# Build tinyexr for release
echo "Building tinyexr (release)..."
cd "$FILAMENT_BASE_DIR/out/cmake-ios-release-arm64/third_party"
mkdir -p tinyexr && cd tinyexr
cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 \
        -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
        -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
        -DCMAKE_CXX_FLAGS="-I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
        "$FILAMENT_BASE_DIR/libs/tinyexr"

# Copy release third-party libraries
echo "Copying release third-party libraries..."
cd "$FILAMENT_BASE_DIR"
cp out/cmake-ios-release-arm64/third_party/libz/*.a "$TARGET_RELEASE_DIR/" || echo "Warning: No libz libraries found"
cp out/cmake-ios-release-arm64/third_party/imageio/*.a "$TARGET_RELEASE_DIR/" || {
  echo "Error: Failed to copy imageio libraries"
  exit 1
}
cp out/cmake-ios-release-arm64/third_party/tinyexr/*.a "$TARGET_RELEASE_DIR/" || {
  echo "Error: Failed to copy tinyexr libraries"
  exit 1
}

# Build libz for debug
echo "Building libz (debug)..."
cd "$FILAMENT_BASE_DIR"
cd out/cmake-ios-debug-arm64/third_party
mkdir -p libz && cd libz
cmake -G Ninja -DIOS=1 -DIPHONEOS_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_BUILD_TYPE=Debug "$FILAMENT_BASE_DIR/third_party/libz"
ninja

# Build imageio for debug
echo "Building imageio (debug)..."
cd "$FILAMENT_BASE_DIR/out/cmake-ios-debug-arm64/third_party"
mkdir -p imageio && cd imageio
cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_CXX_STANDARD=17 \
        -DPLATFORM_NAME="iphonesimulator" \
        -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
        -DZ_HAVE_UNISTD_H=1 \
        -DUSE_ZLIB=1 \
        -DIMPORT_EXECUTABLES_DIR=out \
        -DCMAKE_CXX_FLAGS="-I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
        "$FILAMENT_BASE_DIR/libs/imageio"
ninja

# Build tinyexr for debug
echo "Building tinyexr (debug)..."
cd "$FILAMENT_BASE_DIR/out/cmake-ios-debug-arm64/third_party"
mkdir -p tinyexr && cd tinyexr
cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_STANDARD=17 \
        -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
        -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
        -DCMAKE_CXX_FLAGS="-I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
        "$FILAMENT_BASE_DIR/libs/tinyexr"

# Copy debug third-party libraries
echo "Copying debug third-party libraries..."
cd "$FILAMENT_BASE_DIR"
cp out/cmake-ios-debug-arm64/third_party/libz/*.a "$TARGET_DEBUG_DIR/" || echo "Warning: No libz libraries found"
cp out/cmake-ios-debug-arm64/third_party/imageio/*.a "$TARGET_DEBUG_DIR/" || {
  echo "Error: Failed to copy imageio libraries"
  exit 1
}
cp out/cmake-ios-debug-arm64/third_party/tinyexr/*.a "$TARGET_DEBUG_DIR/" || {
  echo "Error: Failed to copy tinyexr libraries"
  exit 1
}

# Create zip files
echo "Creating release zip..."
cd "$TARGET_RELEASE_DIR"
zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-release.zip" . || {
  echo "Error: Failed to create release zip"
  exit 1
}

echo "Creating debug zip..."
cd "$TARGET_DEBUG_DIR"
zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-debug.zip" . || {
  echo "Error: Failed to create debug zip"
  exit 1
}

echo "Build completed successfully!"
echo "Release libraries: $TARGET_RELEASE_DIR"
echo "Debug libraries: $TARGET_DEBUG_DIR"
echo "Release zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-release.zip"
echo "Debug zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-debug.zip"
