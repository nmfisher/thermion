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

# Patch the libassimp tnt overlay to enable STL/PLY import + glTF2/FBX export.
# Must run AFTER the checkout so it patches the checked-out tag. Idempotent.
python3 "$SCRIPT_DIR/patch_libassimp_tnt.py" "$FILAMENT_BASE_DIR"

# Patch Filament's build.sh to skip samples (add -DFILAMENT_SKIP_SAMPLES=ON to cmake commands)
echo "Patching Filament build.sh to skip samples..."
sed -i.bak 's|\${architectures} \\$|\${architectures} -DFILAMENT_SKIP_SAMPLES=ON -DFILAMENT_ENABLE_RTTI=ON \\|g' build.sh

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

# Android ABI names (used in output lib dirs) and cmake arch names (used in build dirs)
ARCHS="arm64-v8a armeabi-v7a x86_64 x86"

abi_to_cmake_arch() {
  case "$1" in
    arm64-v8a)   echo "aarch64" ;;
    armeabi-v7a) echo "arm7" ;;
    x86_64)      echo "x86_64" ;;
    x86)         echo "x86" ;;
  esac
}

# Find Android NDK toolchain
if [ -n "$ANDROID_NDK_HOME" ]; then
  NDK_TOOLCHAIN="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
elif [ -n "$ANDROID_NDK_ROOT" ]; then
  NDK_TOOLCHAIN="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake"
elif [ -n "$ANDROID_NDK" ]; then
  NDK_TOOLCHAIN="$ANDROID_NDK/build/cmake/android.toolchain.cmake"
else
  echo "Error: Cannot find Android NDK. Set ANDROID_NDK_HOME, ANDROID_NDK_ROOT, or ANDROID_NDK."
  exit 1
fi

if [ ! -f "$NDK_TOOLCHAIN" ]; then
  echo "Error: NDK toolchain not found at: $NDK_TOOLCHAIN"
  exit 1
fi
echo "Using NDK toolchain: $NDK_TOOLCHAIN"

# Build imageio and tinyexr for each Android architecture using cmake + NDK toolchain.
# Filament's build.sh -p android only cross-compiles core libs, not imageio/tinyexr.
build_third_party_for_arch() {
  local BUILD_TYPE=$1  # Release or Debug
  local BUILD_SUFFIX=$2  # release or debug
  local ABI=$3
  local CMAKE_ARCH=$(abi_to_cmake_arch "$ABI")
  local CMAKE_DIR="$FILAMENT_BASE_DIR/out/cmake-android-${BUILD_SUFFIX}-${CMAKE_ARCH}"

  echo "Building imageio + tinyexr for $ABI ($BUILD_SUFFIX)..."

  mkdir -p "$CMAKE_DIR/third_party/imageio" && cd "$CMAKE_DIR/third_party/imageio"
  cmake -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$NDK_TOOLCHAIN" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-21 \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_CXX_STANDARD=17 \
    -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
    -DZ_HAVE_UNISTD_H=1 \
    -DUSE_ZLIB=1 \
    -DIMPORT_EXECUTABLES_DIR=out \
    -DCMAKE_CXX_FLAGS="-Wno-switch-default -Wno-reserved-identifier -Wno-unsafe-buffer-usage -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
    "$FILAMENT_BASE_DIR/libs/imageio" || {
    echo "Error: imageio cmake failed for $ABI ($BUILD_SUFFIX)"
    return 1
  }
  ninja || {
    echo "Error: imageio build failed for $ABI ($BUILD_SUFFIX)"
    return 1
  }

  mkdir -p "$CMAKE_DIR/third_party/tinyexr" && cd "$CMAKE_DIR/third_party/tinyexr"
  cmake -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$NDK_TOOLCHAIN" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-21 \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_CXX_STANDARD=17 \
    -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
    -DZ_HAVE_UNISTD_H=1 \
    -DUSE_ZLIB=1 \
    -DIMPORT_EXECUTABLES_DIR=out \
    -DCMAKE_CXX_FLAGS="-Wno-switch-default -Wno-reserved-identifier -Wno-sign-conversion -Wno-tautological-type-limit-compare -Wno-unsafe-buffer-usage -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
    "$FILAMENT_BASE_DIR/third_party/tinyexr" || {
    echo "Error: tinyexr cmake failed for $ABI ($BUILD_SUFFIX)"
    return 1
  }
  ninja || {
    echo "Error: tinyexr build failed for $ABI ($BUILD_SUFFIX)"
    return 1
  }

  echo "Building libassimp for $ABI ($BUILD_SUFFIX)..."
  mkdir -p "$CMAKE_DIR/third_party/libassimp" && cd "$CMAKE_DIR/third_party/libassimp"
  cmake -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$NDK_TOOLCHAIN" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-21 \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_C_FLAGS="-I$FILAMENT_BASE_DIR/third_party/libz" \
    -DCMAKE_CXX_FLAGS="-I$FILAMENT_BASE_DIR/third_party/libz" \
    -DASSIMP_BUILD_ASSIMP_TOOLS=OFF \
    -DASSIMP_BUILD_TESTS=OFF \
    -DASSIMP_BUILD_SAMPLES=OFF \
    -DASSIMP_WARNINGS_AS_ERRORS=OFF \
    "$FILAMENT_BASE_DIR/third_party/libassimp/tnt" || {
    echo "Error: libassimp cmake failed for $ABI ($BUILD_SUFFIX)"
    return 1
  }
  ninja || {
    echo "Error: libassimp build failed for $ABI ($BUILD_SUFFIX)"
    return 1
  }

  cd "$FILAMENT_BASE_DIR"
}

if [ "$BUILD_RELEASE" = true ]; then
  for ARCH in $ARCHS; do
    build_third_party_for_arch Release release "$ARCH" || {
      echo "Error: third-party build failed for $ARCH (release)"
      exit 1
    }
  done
fi

if [ "$BUILD_DEBUG" = true ]; then
  for ARCH in $ARCHS; do
    build_third_party_for_arch Debug debug "$ARCH" || {
      echo "Error: third-party build failed for $ARCH (debug)"
      exit 1
    }
  done
fi

# Create target directories and copy libraries
echo "Copying libraries..."

if [ "$BUILD_RELEASE" = true ]; then
  mkdir -p "$TARGET_RELEASE_DIR" || {
    echo "Error: Failed to create target directory: $TARGET_RELEASE_DIR"
    exit 1
  }

  echo "Copying release libraries..."
  for ARCH in $ARCHS; do
    CMAKE_ARCH=$(abi_to_cmake_arch "$ARCH")
    mkdir -p "$TARGET_RELEASE_DIR/$ARCH"

    # Copy main Filament libraries
    for lib in out/android-release/filament/lib/$ARCH/*.a; do
      case "$(basename "$lib")" in
        *zstd*) echo "Skipping $lib (bundled in Filament already)" ;;
        *) cp "$lib" "$TARGET_RELEASE_DIR/$ARCH/" ;;
      esac
    done

    # Copy imageio (built per-arch by build_third_party_for_arch)
    IMAGEIO_SRC="out/cmake-android-release-${CMAKE_ARCH}/third_party/imageio/libimageio.a"
    if [ -f "$IMAGEIO_SRC" ]; then
      echo "Found imageio at $IMAGEIO_SRC"
      cp "$IMAGEIO_SRC" "$TARGET_RELEASE_DIR/$ARCH/"
    else
      echo "WARNING: libimageio.a not found for $ARCH at $IMAGEIO_SRC"
    fi

    # Copy tinyexr (built per-arch by build_third_party_for_arch)
    TINYEXR_SRC="out/cmake-android-release-${CMAKE_ARCH}/third_party/tinyexr/libtinyexr.a"
    if [ -f "$TINYEXR_SRC" ]; then
      echo "Found tinyexr at $TINYEXR_SRC"
      cp "$TINYEXR_SRC" "$TARGET_RELEASE_DIR/$ARCH/"
    else
      echo "WARNING: libtinyexr.a not found for $ARCH at $TINYEXR_SRC"
    fi

    # Copy libassimp (built per-arch by build_third_party_for_arch)
    ASSIMP_SRC="out/cmake-android-release-${CMAKE_ARCH}/third_party/libassimp/libassimp.a"
    if [ -f "$ASSIMP_SRC" ]; then
      echo "Found libassimp at $ASSIMP_SRC"
      cp "$ASSIMP_SRC" "$TARGET_RELEASE_DIR/$ARCH/"
    else
      echo "WARNING: libassimp.a not found for $ARCH at $ASSIMP_SRC"
    fi
  done
fi

if [ "$BUILD_DEBUG" = true ]; then
  mkdir -p "$TARGET_DEBUG_DIR" || {
    echo "Error: Failed to create target directory: $TARGET_DEBUG_DIR"
    exit 1
  }

  echo "Copying debug libraries..."
  for ARCH in $ARCHS; do
    CMAKE_ARCH=$(abi_to_cmake_arch "$ARCH")
    mkdir -p "$TARGET_DEBUG_DIR/$ARCH"

    # Copy main Filament libraries
    for lib in out/android-debug/filament/lib/$ARCH/*.a; do
      case "$(basename "$lib")" in
        *zstd*) echo "Skipping $lib (bundled in Filament already)" ;;
        *) cp "$lib" "$TARGET_DEBUG_DIR/$ARCH/" ;;
      esac
    done

    # Copy imageio (built per-arch by build_third_party_for_arch)
    IMAGEIO_SRC="out/cmake-android-debug-${CMAKE_ARCH}/third_party/imageio/libimageio.a"
    if [ -f "$IMAGEIO_SRC" ]; then
      echo "Found imageio at $IMAGEIO_SRC"
      cp "$IMAGEIO_SRC" "$TARGET_DEBUG_DIR/$ARCH/"
    else
      echo "WARNING: libimageio.a not found for $ARCH at $IMAGEIO_SRC"
    fi

    # Copy tinyexr (built per-arch by build_third_party_for_arch)
    TINYEXR_SRC="out/cmake-android-debug-${CMAKE_ARCH}/third_party/tinyexr/libtinyexr.a"
    if [ -f "$TINYEXR_SRC" ]; then
      echo "Found tinyexr at $TINYEXR_SRC"
      cp "$TINYEXR_SRC" "$TARGET_DEBUG_DIR/$ARCH/"
    else
      echo "WARNING: libtinyexr.a not found for $ARCH at $TINYEXR_SRC"
    fi

    # Copy libassimp (built per-arch by build_third_party_for_arch)
    ASSIMP_SRC="out/cmake-android-debug-${CMAKE_ARCH}/third_party/libassimp/libassimp.a"
    if [ -f "$ASSIMP_SRC" ]; then
      echo "Found libassimp at $ASSIMP_SRC"
      cp "$ASSIMP_SRC" "$TARGET_DEBUG_DIR/$ARCH/"
    else
      echo "WARNING: libassimp.a not found for $ARCH at $ASSIMP_SRC"
    fi
  done
fi

# Copy header files to target directories (for inclusion in R2 upload zips)
echo "Copying header files to target directories..."

if [ "$BUILD_RELEASE" = true ]; then
  HEADER_SOURCE="out/android-release/filament/include"
  echo "Copying headers to $TARGET_RELEASE_DIR/include..."
  mkdir -p "$TARGET_RELEASE_DIR/include"
  cp -R "$FILAMENT_BASE_DIR/$HEADER_SOURCE"/* "$TARGET_RELEASE_DIR/include/" || {
    echo "Error: Failed to copy release headers to target"
    exit 1
  }

  # Copy imageio headers
  mkdir -p "$TARGET_RELEASE_DIR/include/imageio"
  cp -R "$FILAMENT_BASE_DIR/libs/imageio/include"/* "$TARGET_RELEASE_DIR/include/imageio/" || {
    echo "Error: Failed to copy imageio headers to target"
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

  # Copy libassimp headers
  mkdir -p "$TARGET_RELEASE_DIR/include/third_party/libassimp/include"
  cp -R "$FILAMENT_BASE_DIR/third_party/libassimp/include/assimp" \
    "$TARGET_RELEASE_DIR/include/third_party/libassimp/include/" || {
    echo "Error: Failed to copy assimp headers to target"
    exit 1
  }

  # Copy release-specific uberarchive.h
  mkdir -p "$TARGET_RELEASE_DIR/include/release/gltfio/materials"
  cp "$FILAMENT_BASE_DIR/out/android-release/filament/include/gltfio/materials/uberarchive.h" \
    "$TARGET_RELEASE_DIR/include/release/gltfio/materials/" || {
    echo "Error: Failed to copy release uberarchive.h to target"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  HEADER_SOURCE="out/android-debug/filament/include"
  echo "Copying headers to $TARGET_DEBUG_DIR/include..."
  mkdir -p "$TARGET_DEBUG_DIR/include"
  cp -R "$FILAMENT_BASE_DIR/$HEADER_SOURCE"/* "$TARGET_DEBUG_DIR/include/" || {
    echo "Error: Failed to copy debug headers to target"
    exit 1
  }

  # Copy imageio headers
  mkdir -p "$TARGET_DEBUG_DIR/include/imageio"
  cp -R "$FILAMENT_BASE_DIR/libs/imageio/include"/* "$TARGET_DEBUG_DIR/include/imageio/" || {
    echo "Error: Failed to copy imageio headers to target"
    exit 1
  }

  # Copy stb_image.h
  mkdir -p "$TARGET_DEBUG_DIR/include/third_party/stb"
  cp "$FILAMENT_BASE_DIR/third_party/stb/stb_image.h" "$TARGET_DEBUG_DIR/include/third_party/stb/" || {
    echo "Error: Failed to copy stb_image.h to target"
    exit 1
  }

  # Copy bluevk headers (includes bluevk/BlueVK.h, vulkan/vulkan.h, vk_video/)
  cp -R "$FILAMENT_BASE_DIR/libs/bluevk/include/"* "$TARGET_RELEASE_DIR/include/" || {
    echo "Error: Failed to copy bluevk headers to target"
    exit 1
  }

  # Copy libassimp headers
  mkdir -p "$TARGET_DEBUG_DIR/include/third_party/libassimp/include"
  cp -R "$FILAMENT_BASE_DIR/third_party/libassimp/include/assimp" \
    "$TARGET_DEBUG_DIR/include/third_party/libassimp/include/" || {
    echo "Error: Failed to copy assimp headers to target"
    exit 1
  }

  # Copy debug-specific uberarchive.h
  mkdir -p "$TARGET_DEBUG_DIR/include/debug/gltfio/materials"
  cp "$FILAMENT_BASE_DIR/out/android-debug/filament/include/gltfio/materials/uberarchive.h" \
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
