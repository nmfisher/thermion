#!/bin/bash

# Prevent macOS ._* resource fork files in copies and zips
export COPYFILE_DISABLE=1

# Save script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR> [options]"
  echo "Example: $0 /path/to/filament v1.75.0 /path/to/output"
  echo "         $0 /path/to/filament latest /path/to/output --webgpu --upload"
  echo "         $0 /path/to/filament v1.75.0 /path/to/output --clean"
  echo "         $0 /path/to/filament v1.75.0 /path/to/output --release"
  echo ""
  echo "Options:"
  echo "  --clean         Remove existing target directories before building"
  echo "  --release       Build release only"
  echo "  --debug         Build debug only"
  echo "  --webgpu        Build with FILAMENT_SUPPORTS_WEBGPU=ON (includes Dawn)"
  echo "  --upload        Upload resulting zip(s) to Cloudflare R2 after build"
  echo "  (default)       Build both release and debug, no WebGPU, no upload"
  echo ""
  echo "If FILAMENT_VERSION is 'latest', the newest v*.* tag on"
  echo "https://github.com/google/filament is resolved and checked out."
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
WEBGPU_FLAG=false
UPLOAD_FLAG=false

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
    --webgpu)
      WEBGPU_FLAG=true
      ;;
    --upload)
      UPLOAD_FLAG=true
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

# Resolve FILAMENT_VERSION=latest by querying github for the newest v*.* tag.
if [ "$FILAMENT_VERSION" = "latest" ]; then
  echo "Resolving latest Filament tag..."
  FILAMENT_VERSION=$(git ls-remote --tags --refs --sort=-version:refname \
    https://github.com/google/filament 'v*' \
    | awk -F/ '{print $NF}' \
    | head -1)
  if [ -z "$FILAMENT_VERSION" ]; then
    echo "Error: could not resolve latest Filament tag from github"
    exit 1
  fi
  echo "Latest Filament: $FILAMENT_VERSION"
fi

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
echo "Checking out tag: $FILAMENT_VERSION"
git checkout "${FILAMENT_VERSION}" || {
  echo "Error: Failed to checkout tag: $FILAMENT_VERSION"
  exit 1
}

# Patch the libassimp tnt overlay to enable STL/PLY import + glTF2/FBX export.
# Must run AFTER the checkout so it patches the checked-out tag. Idempotent.
python3 "$SCRIPT_DIR/patch_libassimp_tnt.py" "$FILAMENT_BASE_DIR"

# Patch Filament's build.sh to skip samples (add -DFILAMENT_SKIP_SAMPLES=ON to cmake commands).
# When --webgpu is set, also inject -DFILAMENT_SUPPORTS_WEBGPU=ON so the
# Dawn-based WebGPU backend gets built into libbackend.a.
CMAKE_INJECT="-DFILAMENT_SKIP_SAMPLES=ON -DFILAMENT_ENABLE_RTTI=ON"
if [ "$WEBGPU_FLAG" = true ]; then
  CMAKE_INJECT="$CMAKE_INJECT -DFILAMENT_SUPPORTS_WEBGPU=ON"
fi
echo "Patching Filament build.sh to inject: $CMAKE_INJECT"
sed -i.bak "s|\${architectures} \\\\\$|\${architectures} $CMAKE_INJECT \\\\|g" build.sh

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
  cmake -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    "$FILAMENT_BASE_DIR/third_party/libz"
  ninja

  # Build imageio for release
  echo "Building imageio (release)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-release/third_party"
  mkdir -p imageio && cd imageio
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
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
          -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
          -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
          -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
          -DCMAKE_CXX_FLAGS="-Wno-poison-system-directories -Wno-switch-default -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
          "$FILAMENT_BASE_DIR/third_party/tinyexr"
  ninja

  # Build libassimp for release
  echo "Building libassimp (release)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-release/third_party"
  rm -rf libassimp
  mkdir -p libassimp && cd libassimp
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
          -DCMAKE_CXX_STANDARD=17 \
          -DASSIMP_BUILD_ASSIMP_TOOLS=OFF \
          -DASSIMP_BUILD_TESTS=OFF \
          -DASSIMP_BUILD_SAMPLES=OFF \
          -DASSIMP_WARNINGS_AS_ERRORS=OFF \
          "$FILAMENT_BASE_DIR/third_party/libassimp/tnt"
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
  cmake -G Ninja -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    "$FILAMENT_BASE_DIR/third_party/libz"
  ninja

  # Build imageio for debug
  echo "Building imageio (debug)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-debug/third_party"
  mkdir -p imageio && cd imageio
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Debug \
          -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
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
          -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
          -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
          -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
          -DCMAKE_CXX_FLAGS="-Wno-poison-system-directories -Wno-switch-default -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
          "$FILAMENT_BASE_DIR/third_party/tinyexr"
  ninja

  # Build libassimp for debug
  echo "Building libassimp (debug)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-debug/third_party"
  rm -rf libassimp
  mkdir -p libassimp && cd libassimp
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Debug \
          -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
          -DCMAKE_CXX_STANDARD=17 \
          -DASSIMP_BUILD_ASSIMP_TOOLS=OFF \
          -DASSIMP_BUILD_TESTS=OFF \
          -DASSIMP_BUILD_SAMPLES=OFF \
          -DASSIMP_WARNINGS_AS_ERRORS=OFF \
          "$FILAMENT_BASE_DIR/third_party/libassimp/tnt"
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
  cp out/cmake-release/third_party/libassimp/libassimp.a "$TARGET_RELEASE_DIR/" || {
    echo "Error: Failed to copy libassimp libraries"
    exit 1
  }
fi

# Copy Dawn / WebGPU libs and headers when --webgpu was set.
# Dawn is built as a third-party subproject and produces many granular
# static libs (dawn_native, dawn_proc, webgpu_dawn, the Tint compiler
# stack, absl, etc.) scattered through its build tree — so we recurse.
copy_dawn_artifacts() {
  local cmake_dir="$1"
  local target_dir="$2"
  local dawn_root="$FILAMENT_BASE_DIR/$cmake_dir/third_party/dawn"
  if [ ! -d "$dawn_root" ]; then
    echo "Warning: dawn build dir not found at $dawn_root — skipping"
    return 0
  fi
  echo "Copying Dawn static libs from $dawn_root..."
  find "$dawn_root" -name '*.a' -type f -exec cp {} "$target_dir/" \;
  # Generated webgpu_cpp.h lives under dawn's build tree alongside the
  # other generated bindings.
  local generated_inc="$dawn_root/gen/include"
  if [ -d "$generated_inc/webgpu" ]; then
    echo "Copying generated webgpu headers from $generated_inc/webgpu..."
    mkdir -p "$target_dir/include/webgpu"
    cp -R "$generated_inc/webgpu"/* "$target_dir/include/webgpu/" || true
  fi
}

if [ "$WEBGPU_FLAG" = true ] && [ "$BUILD_RELEASE" = true ]; then
  copy_dawn_artifacts "out/cmake-release" "$TARGET_RELEASE_DIR"
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
  cp out/cmake-debug/third_party/libassimp/libassimp.a "$TARGET_DEBUG_DIR/" || {
    echo "Error: Failed to copy libassimp libraries"
    exit 1
  }
fi

if [ "$WEBGPU_FLAG" = true ] && [ "$BUILD_DEBUG" = true ]; then
  copy_dawn_artifacts "out/cmake-debug" "$TARGET_DEBUG_DIR"
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

  # Copy libassimp headers
  mkdir -p "$TARGET_RELEASE_DIR/include/third_party/libassimp/include"
  cp -R "$FILAMENT_BASE_DIR/third_party/libassimp/include/assimp" \
    "$TARGET_RELEASE_DIR/include/third_party/libassimp/include/" || {
    echo "Error: Failed to copy assimp headers to target"
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
  cp -R "$FILAMENT_BASE_DIR/libs/bluevk/include/"* "$TARGET_DEBUG_DIR/include/" || {
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

# Optional upload to Cloudflare R2. Uses scripts/upload_r2.sh, which picks
# wrangler vs aws CLI based on file size. Credentials must already be
# configured (wrangler login or R2_ACCESS_KEY_ID/R2_SECRET_ACCESS_KEY env vars).
if [ "$UPLOAD_FLAG" = true ]; then
  echo ""
  echo "Uploading artifacts to Cloudflare R2..."
  if [ "$BUILD_RELEASE" = true ]; then
    "$SCRIPT_DIR/upload_r2.sh" "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-macos-release.zip" || {
      echo "Error: Failed to upload release zip"
      exit 1
    }
  fi
  if [ "$BUILD_DEBUG" = true ]; then
    "$SCRIPT_DIR/upload_r2.sh" "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-macos-debug.zip" || {
      echo "Error: Failed to upload debug zip"
      exit 1
    }
  fi
fi
