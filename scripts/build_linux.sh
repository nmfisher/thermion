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

# Detect host architecture. The desktop build is host-native, so an x86_64
# host produces libs under out/*/filament/lib/x86_64/ and an aarch64 host
# produces them under out/*/filament/lib/aarch64/.
HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  x86_64)
    LIB_ARCH_DIR="x86_64"
    ARCH_TAG=""                     # legacy zip names/cache dirs
    ;;
  aarch64)
    LIB_ARCH_DIR="aarch64"
    ARCH_TAG="-arm64"
    ;;
  *)
    echo "Error: Unsupported host architecture: $HOST_ARCH"
    exit 1
    ;;
esac
echo "Host architecture: $HOST_ARCH (library dir: $LIB_ARCH_DIR, zip tag: ${ARCH_TAG:-none})"

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
TARGET_RELEASE_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/linux${ARCH_TAG}/release"
TARGET_DEBUG_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/linux${ARCH_TAG}/debug"

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
echo "Checking out tag: $FILAMENT_VERSION"
git checkout "${FILAMENT_VERSION}" || {
  echo "Error: Failed to checkout tag: $FILAMENT_VERSION"
  exit 1
}

# Patch Filament's build.sh to skip samples (add -DFILAMENT_SKIP_SAMPLES=ON to cmake commands)
echo "Patching Filament build.sh to skip samples..."
sed -i.bak 's|\${architectures} \\$|\${architectures} -DFILAMENT_SKIP_SAMPLES=ON -DFILAMENT_ENABLE_RTTI=ON \\|g' build.sh

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

# Patch FFilamentAsset.h to allow overriding GLTFIO_USE_FILESYSTEM at compile time
echo "Patching FFilamentAsset.h to disable GLTFIO_USE_FILESYSTEM..."
FFILAMENT_ASSET_H="$FILAMENT_BASE_DIR/libs/gltfio/src/FFilamentAsset.h"
sed -i.bak $'s/^#if defined(__EMSCRIPTEN__)/#ifndef GLTFIO_USE_FILESYSTEM\\\n#if defined(__EMSCRIPTEN__)/' "$FFILAMENT_ASSET_H"
sed -i.bak '/^#define GLTFIO_USE_FILESYSTEM 1/{
n
s|^#endif|#endif\
#endif|
}' "$FFILAMENT_ASSET_H"

# Inject -DGLTFIO_USE_FILESYSTEM=0 into gltfio's compile definitions
GLTFIO_CMAKE="$FILAMENT_BASE_DIR/libs/gltfio/CMakeLists.txt"
echo 'target_compile_definitions(gltfio_core PRIVATE GLTFIO_USE_FILESYSTEM=0)' >> "$GLTFIO_CMAKE"

# Patch basisu CMakeLists.txt for position independent code
echo "Patching basisu CMakeLists.txt..."
BASISU_CMAKE="$FILAMENT_BASE_DIR/third_party/basisu/tnt/CMakeLists.txt"
if grep -q "set(CMAKE_POSITION_INDEPENDENT_CODE ON)" "$BASISU_CMAKE"; then
  echo "Already patched"
else
  sed -i '/project(basisu)/a set(CMAKE_POSITION_INDEPENDENT_CODE ON)' "$BASISU_CMAKE" || {
    echo "Warning: Failed to patch basisu CMakeLists.txt"
  }
fi

# Patch build.sh to add CMAKE_POSITION_INDEPENDENT_CODE to build_desktop_target
echo "Patching build.sh to add CMAKE_POSITION_INDEPENDENT_CODE..."
sed -i '/-DCMAKE_BUILD_TYPE="\$1"/a\            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \\' "$FILAMENT_BASE_DIR/build.sh" || {
  echo "Warning: Failed to patch build.sh for POSITION_INDEPENDENT_CODE"
}

# Patch libs/filamat/CMakeLists.txt for position independent code
echo "Patching libs/filamat/CMakeLists.txt..."
FILAMAT_CMAKE="$FILAMENT_BASE_DIR/libs/filamat/CMakeLists.txt"
if grep -q "set(CMAKE_POSITION_INDEPENDENT_CODE ON)" "$FILAMAT_CMAKE"; then
  echo "Already patched"
else
  sed -i '/^project(filamat)/a set(CMAKE_POSITION_INDEPENDENT_CODE ON)' "$FILAMAT_CMAKE" || {
    echo "Warning: Failed to patch filamat CMakeLists.txt"
  }
fi

# Set compiler to clang
export CC=clang
export CXX=clang++

# Build imageio and tinyexr using cmake directly
# build.sh doesn't properly support building these third-party libs on Linux
build_third_party_libs() {
  local BUILD_TYPE=$1  # Release or Debug
  local BUILD_SUFFIX=$2  # release or debug
  local CMAKE_DIR="$FILAMENT_BASE_DIR/out/cmake-${BUILD_SUFFIX}"

  echo "Building imageio ($BUILD_SUFFIX)..."
  mkdir -p "$CMAKE_DIR/libs/imageio" && cd "$CMAKE_DIR/libs/imageio"
  # -stdlib=libc++: these archives are linked into libthermion_dart.so, which is
  # built with libc++ (-stdlib=libc++ in thermion_dart/hook/build.dart). Without
  # this flag clang defaults to libstdc++, so the archives end up libstdc++-ABI
  # and reference libstdc++ symbols (e.g. std::endl, _ZSt4endl...) that the .so
  # does not link against. See docs/release-failure-analysis.md.
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
    -DZ_HAVE_UNISTD_H=1 \
    -DUSE_ZLIB=1 \
    -DCMAKE_CXX_FLAGS="-stdlib=libc++ -Wno-switch-default -Wno-reserved-identifier -Wno-unsafe-buffer-usage -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
    "$FILAMENT_BASE_DIR/libs/imageio" || {
    echo "Error: imageio cmake failed for $BUILD_SUFFIX"
    return 1
  }
  ninja || {
    echo "Error: imageio build failed for $BUILD_SUFFIX"
    return 1
  }

  echo "Building tinyexr ($BUILD_SUFFIX)..."
  mkdir -p "$CMAKE_DIR/third_party/tinyexr" && cd "$CMAKE_DIR/third_party/tinyexr"
  # -stdlib=libc++: see comment in the imageio build above. Same ABI fix.
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_FLAGS="-stdlib=libc++ -Wno-switch-default -Wno-reserved-identifier -Wno-sign-conversion -Wno-tautological-type-limit-compare -Wno-unsafe-buffer-usage -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
    "$FILAMENT_BASE_DIR/third_party/tinyexr" || {
    echo "Error: tinyexr cmake failed for $BUILD_SUFFIX"
    return 1
  }
  ninja || {
    echo "Error: tinyexr build failed for $BUILD_SUFFIX"
    return 1
  }

  cd "$FILAMENT_BASE_DIR"
}


# Run release build
if [ "$BUILD_RELEASE" = true ]; then
  echo "Building Filament for Linux (release)..."
  ./build.sh -i -f -p desktop release || {
    echo "Error: Filament release build failed"
    exit 1
  }

  # Build third-party libraries for release using cmake directly
  echo "Building third-party libraries for release..."
  build_third_party_libs Release release || {
    echo "Error: third-party release build failed"
    exit 1
  }
fi

# Run debug build
if [ "$BUILD_DEBUG" = true ]; then
  echo "Building Filament for Linux (debug)..."
  ./build.sh -i -f -t -d -p desktop debug || {
    echo "Error: Filament debug build failed"
    exit 1
  }

  # Build third-party libraries for debug using cmake directly
  echo "Building third-party libraries for debug..."
  build_third_party_libs Debug debug || {
    echo "Error: third-party debug build failed"
    exit 1
  }
fi

# Create target directories and copy libraries
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
  echo "Searching for release libraries..."
  echo "=== out/release/filament/lib/$LIB_ARCH_DIR/ ==="
  ls -la out/release/filament/lib/$LIB_ARCH_DIR/ 2>&1 || true
  echo "=== out/cmake-release/libs/imageio/ ==="
  ls -la out/cmake-release/libs/imageio/ 2>&1 || true
  echo "=== out/cmake-release/third_party/tinyexr/ ==="
  ls -la out/cmake-release/third_party/tinyexr/ 2>&1 || true
  echo "=== find imageio ==="
  find out/ -name "libimageio*" 2>&1 || true
  echo "=== find tinyexr ==="
  find out/ -name "libtinyexr*" 2>&1 || true

  for lib in out/release/filament/lib/$LIB_ARCH_DIR/*.a; do
    case "$(basename "$lib")" in
      *zstd*) echo "Skipping $lib (bundled in Filament already)" ;;
      *) cp "$lib" "$TARGET_RELEASE_DIR/" ;;
    esac
  done

  # Try multiple known locations for imageio/tinyexr
  for searchdir in "out/cmake-release/libs/imageio" "out/release/filament/lib/$LIB_ARCH_DIR" "out/cmake-release/third_party/imageio"; do
    if [ -f "$searchdir/libimageio.a" ]; then
      echo "Found imageio at $searchdir"
      cp "$searchdir/libimageio.a" "$TARGET_RELEASE_DIR/"
      break
    fi
  done
  if [ ! -f "$TARGET_RELEASE_DIR/libimageio.a" ]; then
    echo "WARNING: libimageio.a not found in any known location"
  fi

  for searchdir in "out/cmake-release/third_party/tinyexr" "out/release/filament/lib/$LIB_ARCH_DIR" "out/cmake-release/third_party/tinyexr/tnt"; do
    if [ -f "$searchdir/libtinyexr.a" ]; then
      echo "Found tinyexr at $searchdir"
      cp "$searchdir/libtinyexr.a" "$TARGET_RELEASE_DIR/"
      break
    fi
  done
  if [ ! -f "$TARGET_RELEASE_DIR/libtinyexr.a" ]; then
    echo "WARNING: libtinyexr.a not found in any known location"
  fi
fi

# Copy debug libraries
if [ "$BUILD_DEBUG" = true ]; then
  echo "Copying debug libraries..."
  echo "Searching for debug libraries..."
  echo "=== out/debug/filament/lib/$LIB_ARCH_DIR/ ==="
  ls -la out/debug/filament/lib/$LIB_ARCH_DIR/ 2>&1 || true
  echo "=== find imageio (debug) ==="
  find out/ -path "*/debug*" -name "libimageio*" 2>&1 || true
  echo "=== find tinyexr (debug) ==="
  find out/ -path "*/debug*" -name "libtinyexr*" 2>&1 || true

  for lib in out/debug/filament/lib/$LIB_ARCH_DIR/*.a; do
    case "$(basename "$lib")" in
      *zstd*) echo "Skipping $lib (bundled in Filament already)" ;;
      *) cp "$lib" "$TARGET_DEBUG_DIR/" ;;
    esac
  done

  for searchdir in "out/cmake-debug/libs/imageio" "out/debug/filament/lib/$LIB_ARCH_DIR" "out/cmake-debug/third_party/imageio"; do
    if [ -f "$searchdir/libimageio.a" ]; then
      echo "Found imageio at $searchdir"
      cp "$searchdir/libimageio.a" "$TARGET_DEBUG_DIR/"
      break
    fi
  done
  if [ ! -f "$TARGET_DEBUG_DIR/libimageio.a" ]; then
    echo "WARNING: libimageio.a not found in any known location"
  fi

  for searchdir in "out/cmake-debug/third_party/tinyexr" "out/debug/filament/lib/$LIB_ARCH_DIR" "out/cmake-debug/third_party/tinyexr/tnt"; do
    if [ -f "$searchdir/libtinyexr.a" ]; then
      echo "Found tinyexr at $searchdir"
      cp "$searchdir/libtinyexr.a" "$TARGET_DEBUG_DIR/"
      break
    fi
  done
  if [ ! -f "$TARGET_DEBUG_DIR/libtinyexr.a" ]; then
    echo "WARNING: libtinyexr.a not found in any known location"
  fi
fi

# Copy header files to target directories (for inclusion in R2 upload zips)
echo "Copying header files to target directories..."

if [ "$BUILD_RELEASE" = true ]; then
  HEADER_SOURCE="out/release/filament/include"
  echo "Copying headers to $TARGET_RELEASE_DIR/include..."
  mkdir -p "$TARGET_RELEASE_DIR/include"
  cp -R "$FILAMENT_BASE_DIR/$HEADER_SOURCE"/* "$TARGET_RELEASE_DIR/include/" || {
    echo "Error: Failed to copy release headers to target"
    exit 1
  }

  # Copy imageio headers
  mkdir -p "$TARGET_RELEASE_DIR/include/imageio"
  cp -R "$FILAMENT_BASE_DIR/libs/imageio/include"/* "$TARGET_RELEASE_DIR/include/" || {
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

  # Copy release-specific uberarchive.h
  mkdir -p "$TARGET_RELEASE_DIR/include/release/gltfio/materials"
  cp "$FILAMENT_BASE_DIR/out/release/filament/include/gltfio/materials/uberarchive.h" \
    "$TARGET_RELEASE_DIR/include/release/gltfio/materials/" || {
    echo "Error: Failed to copy release uberarchive.h to target"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  HEADER_SOURCE="out/debug/filament/include"
  echo "Copying headers to $TARGET_DEBUG_DIR/include..."
  mkdir -p "$TARGET_DEBUG_DIR/include"
  cp -R "$FILAMENT_BASE_DIR/$HEADER_SOURCE"/* "$TARGET_DEBUG_DIR/include/" || {
    echo "Error: Failed to copy debug headers to target"
    exit 1
  }

  # Copy imageio headers
  mkdir -p "$TARGET_DEBUG_DIR/include/imageio"
  cp -R "$FILAMENT_BASE_DIR/libs/imageio/include"/* "$TARGET_DEBUG_DIR/include/" || {
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
  # (the-c8d3: this previously targeted $TARGET_RELEASE_DIR, so debug zips
  # shipped without bluevk headers and debug hook builds failed on
  # <bluevk/BlueVK.h>)
  cp -R "$FILAMENT_BASE_DIR/libs/bluevk/include/"* "$TARGET_DEBUG_DIR/include/" || {
    echo "Error: Failed to copy bluevk headers to target"
    exit 1
  }

  # Copy debug-specific uberarchive.h
  mkdir -p "$TARGET_DEBUG_DIR/include/debug/gltfio/materials"
  cp "$FILAMENT_BASE_DIR/out/debug/filament/include/gltfio/materials/uberarchive.h" \
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
  echo "Contents of release directory:"
  ls -la "$TARGET_RELEASE_DIR"
  cd "$TARGET_RELEASE_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-linux${ARCH_TAG}-release.zip" . || {
    echo "Error: Failed to create release zip"
    exit 1
  }
  echo "Release zip contents:"
  unzip -l "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-linux${ARCH_TAG}-release.zip"
fi

if [ "$BUILD_DEBUG" = true ]; then
  echo "Creating debug zip..."
  echo "Contents of debug directory:"
  ls -la "$TARGET_DEBUG_DIR"
  cd "$TARGET_DEBUG_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-linux${ARCH_TAG}-debug.zip" . || {
    echo "Error: Failed to create debug zip"
    exit 1
  }
  echo "Debug zip contents:"
  unzip -l "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-linux${ARCH_TAG}-debug.zip"
fi

echo "Build completed successfully!"
if [ "$BUILD_RELEASE" = true ]; then
  echo "Release libraries: $TARGET_RELEASE_DIR"
  echo "Release zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-linux${ARCH_TAG}-release.zip"
fi
if [ "$BUILD_DEBUG" = true ]; then
  echo "Debug libraries: $TARGET_DEBUG_DIR"
  echo "Debug zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-linux${ARCH_TAG}-debug.zip"
fi
