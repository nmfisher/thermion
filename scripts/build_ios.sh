#!/bin/bash

# Save script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR> [options]"
  echo "Example: $0 /path/to/filament v1.74.0 /path/to/output"
  echo "         $0 /path/to/filament v1.74.0 /path/to/output --clean"
  echo "         $0 /path/to/filament v1.74.0 /path/to/output --release"
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
TARGET_RELEASE_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/ios/release"
TARGET_DEBUG_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/ios/debug"

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

# Keep host tools separate from the runtime archives built below.
git apply "$SCRIPT_DIR/filament-no-exceptions.patch" || exit 1

# Patch Filament's build.sh to skip samples (add -DFILAMENT_SKIP_SAMPLES=ON -DFILAMENT_BUILD_TESTING=OFF to cmake commands)
echo "Patching Filament build.sh to skip samples..."
sed -i.bak 's|\${architectures} \\$|\${architectures} -DFILAMENT_SKIP_SAMPLES=ON -DFILAMENT_BUILD_TESTING=OFF -DFILAMENT_ENABLE_RTTI=ON \\|g' build.sh

# Suppress warnings in the vendored tinyexr that trip its own -Weverything -Werror
# (new in Filament v1.75.0; CLANG_COMPILE_FLAGS are per-source COMPILE_FLAGS,
# appended after the strict flags, so the -Wno-* wins). Idempotent, no-op on
# versions whose CMakeLists lacks the anchor string.
echo "Patching tinyexr CMakeLists.txt..."
TINYEXR_CMAKE="$FILAMENT_BASE_DIR/third_party/tinyexr/CMakeLists.txt"
if grep -q "Wno-implicit-int-conversion" "$TINYEXR_CMAKE"; then
  echo "Already patched"
else
  sed -i.bak 's|-Wno-unused-member-function|-Wno-unused-member-function -Wno-implicit-int-conversion -Wno-implicit-int-float-conversion -Wno-old-style-cast -Wno-sign-conversion -Wno-unused-parameter -Wno-unused-function -Wno-poison-system-directories|' "$TINYEXR_CMAKE"
fi

# Filament creates device-only XCFrameworks without -s or -l. Simulator
# libraries are built and packaged separately by build_ios_simulator.sh.
if [ "$BUILD_RELEASE" = true ]; then
  echo "Building Filament for iOS (release)..."
  ./build.sh -E -i -f -p ios release || {
    echo "Error: Filament release build failed"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  echo "Building Filament for iOS (debug)..."
  ./build.sh -E -i -f -p ios debug || {
    echo "Error: Filament debug build failed"
    exit 1
  }
fi

# Create target directories and copy libs
echo "Copying libraries..."

if [ "$BUILD_RELEASE" = true ]; then
  mkdir -p "$TARGET_RELEASE_DIR" || {
    echo "Error: Failed to create target directory: $TARGET_RELEASE_DIR"
    exit 1
  }

  # Select the device library by XCFramework metadata. Simulator libraries
  # are packaged separately by build_ios_simulator.sh.
  python3 "$SCRIPT_DIR/ios_device_libraries.py" extract \
    "out/ios-release/filament/lib" "$TARGET_RELEASE_DIR" || exit 1

  # Build libz for release
  echo "Building libz (release)..."
  cd "$FILAMENT_BASE_DIR"
  cd out/cmake-ios-release-arm64-iphoneos/third_party
  mkdir -p libz && cd libz
  cmake -G Ninja -DIOS=1 -DIPHONEOS_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_BUILD_TYPE=Release "$FILAMENT_BASE_DIR/third_party/libz"
  ninja

  # Build tinyexr for release
  echo "Building tinyexr (release)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-ios-release-arm64-iphoneos/third_party"
  mkdir -p tinyexr && cd tinyexr
  cmake -G Ninja \
          -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
          -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
          -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 \
          -DTINYEXR_BUILD_SAMPLE=OFF \
          -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
          -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
          -DCMAKE_CXX_FLAGS="-fno-exceptions -Wno-poison-system-directories -Wno-switch-default -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
          "$FILAMENT_BASE_DIR/third_party/tinyexr"
  ninja

  # Copy release third-party libraries
  echo "Copying release third-party libraries..."
  cd "$FILAMENT_BASE_DIR"
  cp out/cmake-ios-release-arm64-iphoneos/third_party/libz/*.a "$TARGET_RELEASE_DIR/" || echo "Warning: No libz libraries found"
  cp out/cmake-ios-release-arm64-iphoneos/third_party/tinyexr/*.a "$TARGET_RELEASE_DIR/" || {
    echo "Error: Failed to copy tinyexr libraries"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  mkdir -p "$TARGET_DEBUG_DIR" || {
    echo "Error: Failed to create target directory: $TARGET_DEBUG_DIR"
    exit 1
  }

  # Select the device library by XCFramework metadata. Simulator libraries
  # are packaged separately by build_ios_simulator.sh.
  python3 "$SCRIPT_DIR/ios_device_libraries.py" extract \
    "out/ios-debug/filament/lib" "$TARGET_DEBUG_DIR" || exit 1

  # Build libz for debug
  echo "Building libz (debug)..."
  cd "$FILAMENT_BASE_DIR"
  cd out/cmake-ios-debug-arm64-iphoneos/third_party
  mkdir -p libz && cd libz
  cmake -G Ninja -DIOS=1 -DIPHONEOS_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_BUILD_TYPE=Debug "$FILAMENT_BASE_DIR/third_party/libz"
  ninja

  # Build tinyexr for debug
  echo "Building tinyexr (debug)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-ios-debug-arm64-iphoneos/third_party"
  mkdir -p tinyexr && cd tinyexr
  cmake -G Ninja \
          -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
          -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
          -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_STANDARD=17 \
          -DTINYEXR_BUILD_SAMPLE=OFF \
          -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
          -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
          -DCMAKE_CXX_FLAGS="-fno-exceptions -Wno-poison-system-directories -Wno-switch-default -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
          "$FILAMENT_BASE_DIR/third_party/tinyexr"
  ninja

  # Copy debug third-party libraries
  echo "Copying debug third-party libraries..."
  cd "$FILAMENT_BASE_DIR"
  cp out/cmake-ios-debug-arm64-iphoneos/third_party/libz/*.a "$TARGET_DEBUG_DIR/" || echo "Warning: No libz libraries found"
  cp out/cmake-ios-debug-arm64-iphoneos/third_party/tinyexr/*.a "$TARGET_DEBUG_DIR/" || {
    echo "Error: Failed to copy tinyexr libraries"
    exit 1
  }
fi

# Copy header files to target directories (for inclusion in R2 upload zips)
echo "Copying header files to target directories..."

if [ "$BUILD_RELEASE" = true ]; then
  HEADER_SOURCE="out/ios-release/filament/include"
  echo "Copying headers to $TARGET_RELEASE_DIR/include..."
  mkdir -p "$TARGET_RELEASE_DIR/include"
  cp -R "$FILAMENT_BASE_DIR/$HEADER_SOURCE"/* "$TARGET_RELEASE_DIR/include/" || {
    echo "Error: Failed to copy release headers to target"
    exit 1
  }


  # Copy stb_image.h
  mkdir -p "$TARGET_RELEASE_DIR/include/third_party/stb"
  cp "$FILAMENT_BASE_DIR/third_party/stb/stb_image.h" "$TARGET_RELEASE_DIR/include/third_party/stb/" || {
    echo "Error: Failed to copy stb_image.h to target"
    exit 1
  }

  # Copy bluevk headers (includes bluevk/BlueVK.h, vulkan/vulkan.h, vk_video/)
  cp -R "$FILAMENT_BASE_DIR/libs/bluevk/include/"* "$TARGET_RELEASE_DIR/include/" || {
    echo "Error: Failed to copy bluevk headers to target"
    exit 1
  }

  # Copy release-specific uberarchive.h
  mkdir -p "$TARGET_RELEASE_DIR/include/release/gltfio/materials"
  cp "$FILAMENT_BASE_DIR/out/ios-release/filament/include/gltfio/materials/uberarchive.h" \
    "$TARGET_RELEASE_DIR/include/release/gltfio/materials/" || {
    echo "Error: Failed to copy release uberarchive.h to target"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  HEADER_SOURCE="out/ios-debug/filament/include"
  echo "Copying headers to $TARGET_DEBUG_DIR/include..."
  mkdir -p "$TARGET_DEBUG_DIR/include"
  cp -R "$FILAMENT_BASE_DIR/$HEADER_SOURCE"/* "$TARGET_DEBUG_DIR/include/" || {
    echo "Error: Failed to copy debug headers to target"
    exit 1
  }


  # Copy stb_image.h
  mkdir -p "$TARGET_DEBUG_DIR/include/third_party/stb"
  cp "$FILAMENT_BASE_DIR/third_party/stb/stb_image.h" "$TARGET_DEBUG_DIR/include/third_party/stb/" || {
    echo "Error: Failed to copy stb_image.h to target"
    exit 1
  }

  # Copy bluevk headers (includes bluevk/BlueVK.h, vulkan/vulkan.h, vk_video/)
  cp -R "$FILAMENT_BASE_DIR/libs/bluevk/include/"* "$TARGET_DEBUG_DIR/include/" || {
    echo "Error: Failed to copy bluevk headers to target"
    exit 1
  }

  # Copy debug-specific uberarchive.h
  mkdir -p "$TARGET_DEBUG_DIR/include/debug/gltfio/materials"
  cp "$FILAMENT_BASE_DIR/out/ios-debug/filament/include/gltfio/materials/uberarchive.h" \
    "$TARGET_DEBUG_DIR/include/debug/gltfio/materials/" || {
    echo "Error: Failed to copy debug uberarchive.h to target"
    exit 1
  }
fi

# Filament headers are bundled into the artifact zip's include/ above (per
# target dir). They are no longer copied into a committed tree under
# thermion_dart/native/include/filament — consumers source them from the
# version-matched R2 artifact at build time (see thermion_dart/hook/build.dart).

# Create zip files
if [ "$BUILD_RELEASE" = true ]; then
  # Validate the final contents, including separately copied third-party libs.
  python3 "$SCRIPT_DIR/ios_device_libraries.py" validate "$TARGET_RELEASE_DIR" || exit 1
  echo "Creating release zip..."
  cd "$TARGET_RELEASE_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-release.zip" . || {
    echo "Error: Failed to create release zip"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  # Validate the final contents, including separately copied third-party libs.
  python3 "$SCRIPT_DIR/ios_device_libraries.py" validate "$TARGET_DEBUG_DIR" || exit 1
  echo "Creating debug zip..."
  cd "$TARGET_DEBUG_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-debug.zip" . || {
    echo "Error: Failed to create debug zip"
    exit 1
  }
fi

echo "Build completed successfully!"
if [ "$BUILD_RELEASE" = true ]; then
  echo "Release libraries: $TARGET_RELEASE_DIR"
  echo "Release zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-release.zip"
fi
if [ "$BUILD_DEBUG" = true ]; then
  echo "Debug libraries: $TARGET_DEBUG_DIR"
  echo "Debug zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-debug.zip"
fi
