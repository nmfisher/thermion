#!/bin/bash

# Prevent macOS ._* resource fork files in copies and zips
export COPYFILE_DISABLE=1

# Save script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR> [options]"
  echo "Example: $0 /path/to/filament v1.74.0 /path/to/output"
  echo "         $0 /path/to/filament v1.74.0 /path/to/output --clean"
  echo "         $0 /path/to/filament v1.74.0 /path/to/output --release"
  echo "         $0 /path/to/filament v1.74.0 /path/to/output --tools-dir /path/to/tools"
  echo ""
  echo "Options:"
  echo "  --clean         Remove existing target directories before building"
  echo "  --release       Build release only"
  echo "  --debug         Build debug only"
  echo "  --tools-dir DIR Use prebuilt desktop tools from DIR (skips desktop build)"
  echo "                  DIR must contain ImportExecutables-Release.cmake and tools/"
  echo "  (default)       Build both release and debug"
  echo ""
  echo "Environment variables:"
  echo "  EMSDK          Path to Emscripten SDK (default: \$EMSDK or \$EMSCRIPTEN)"
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
TOOLS_DIR=""

while [ $# -gt 0 ]; do
  case $1 in
    --clean)
      CLEAN_FLAG="--clean"
      ;;
    --release)
      BUILD_DEBUG=false
      ;;
    --debug)
      BUILD_RELEASE=false
      ;;
    --tools-dir)
      shift
      TOOLS_DIR="$1"
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
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

# Check for EMSDK environment variable
if [ -z "$EMSDK" ] && [ -z "$EMSCRIPTEN" ]; then
  echo "Error: EMSDK or EMSCRIPTEN environment variable must be set"
  echo "Example: export EMSDK=/path/to/emsdk"
  exit 1
fi

# Set compiler to clang
export CC=clang
export CXX=clang++

# Use EMSDK if available, otherwise fall back to EMSCRIPTEN
if [ -n "$EMSDK" ]; then
  EMSCRIPTEN_CMAKE="$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake"
else
  EMSCRIPTEN_CMAKE="$EMSCRIPTEN/cmake/Modules/Platform/Emscripten.cmake"
fi

if [ ! -f "$EMSCRIPTEN_CMAKE" ]; then
  echo "Error: Emscripten cmake toolchain file not found: $EMSCRIPTEN_CMAKE"
  exit 1
fi

# Check if target directories already exist
TARGET_RELEASE_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/web/release"
TARGET_DEBUG_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/web/debug"

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

# Patch Filament's build.sh to skip samples (add -DFILAMENT_SKIP_SAMPLES=ON to cmake commands)
echo "Patching Filament build.sh to skip samples..."
sed -i.bak 's|\${architectures} \\$|\${architectures} -DFILAMENT_SKIP_SAMPLES=ON \\|g' build.sh

# Patch libz CMakeLists.txt to fix duplicate libz.a output issue (Emscripten-specific)
echo "Patching libz CMakeLists.txt for Emscripten..."
sed -i.bak 's/set_target_properties(zlib zlibstatic PROPERTIES OUTPUT_NAME z)/set_target_properties(zlib PROPERTIES OUTPUT_NAME z)\n set_target_properties(zlibstatic PROPERTIES OUTPUT_NAME zstatic)/g' third_party/libz/CMakeLists.txt

# emsdk 6.0.4 ships clang 19+, which adds new warning categories that Filament
# promotes to hard errors via -Werror (e.g. -Wunused-template in robin-map, and
# -Wlifetime-safety-* in tinyexr). Rather than chase each one, disable -Werror
# for the web build so warnings stay non-fatal. Convert every standalone
# -Werror to -Wno-error in Filament's CMake config (leaving -Werror=<specific>
# untouched, though Filament doesn't use that form).
echo "Disabling -Werror in Filament CMake for the web build..."
grep -rl -- '-Werror' "$FILAMENT_BASE_DIR" --include='CMakeLists.txt' --include='*.cmake' \
  | while read -r _cm; do
      sed -i 's/-Werror\([^=]\)/-Wno-error\1/g; s/-Werror$/-Wno-error/g' "$_cm"
    done

# Ensure desktop tools are available (needed for web cross-compilation)
if [ -n "$TOOLS_DIR" ]; then
  # Use prebuilt tools from a local directory
  TOOLS_DIR=$(cd "$TOOLS_DIR" && pwd)
  echo "Using prebuilt desktop tools from: $TOOLS_DIR"
elif [ ! -d "$FILAMENT_BASE_DIR/out/cmake-release/tools" ]; then
  # Download official Filament release to get prebuilt tools
  echo "Downloading official Filament release for desktop tools..."
  RELEASE_URL="https://github.com/google/filament/releases/download/${FILAMENT_VERSION}/filament-${FILAMENT_VERSION}-linux.tgz"
  TOOLS_DIR="$FILAMENT_BASE_DIR/out/filament-release"
  mkdir -p "$TOOLS_DIR"
  curl -sL "$RELEASE_URL" | tar xz -C "$TOOLS_DIR" --strip-components=1 || {
    echo "Error: Failed to download Filament release from: $RELEASE_URL"
    echo "Falling back to building desktop tools from source..."
    TOOLS_DIR=""
    ./build.sh -p desktop release || {
      echo "Error: Desktop tools build failed"
      exit 1
    }
  }
fi

# If using prebuilt tools (downloaded or provided), set them up
if [ -n "$TOOLS_DIR" ]; then
  # Verify tools exist
  for tool in matc cmgen filamesh mipgen resgen uberz glslminifier; do
    if [ ! -f "$TOOLS_DIR/bin/$tool" ]; then
      echo "Error: Tool not found: $TOOLS_DIR/bin/$tool"
      exit 1
    fi
  done

  # Generate ImportExecutables-Release.cmake pointing to the tools
  mkdir -p "$FILAMENT_BASE_DIR/out"
  TOOLS_BIN_DIR="$TOOLS_DIR/bin"
  cat > "$FILAMENT_BASE_DIR/out/ImportExecutables-Release.cmake" << CMAKE_EOF
cmake_policy(PUSH)
cmake_policy(VERSION 2.8.3...3.31)
set(CMAKE_IMPORT_FILE_VERSION 1)

foreach(_tool matc cmgen filamesh mipgen resgen uberz glslminifier)
  if(NOT TARGET \${_tool})
    add_executable(\${_tool} IMPORTED)
    set_property(TARGET \${_tool} APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
    set_target_properties(\${_tool} PROPERTIES
      IMPORTED_LOCATION_RELEASE "${TOOLS_BIN_DIR}/\${_tool}"
    )
  endif()
endforeach()

set(CMAKE_IMPORT_FILE_VERSION)
cmake_policy(POP)
CMAKE_EOF

  # Set up tools directory structure for symlinks in build dirs
  mkdir -p "$FILAMENT_BASE_DIR/out/cmake-release/tools"
  for tool in matc cmgen filamesh mipgen resgen uberz glslminifier; do
    mkdir -p "$FILAMENT_BASE_DIR/out/cmake-release/tools/$tool"
    ln -sf "$TOOLS_BIN_DIR/$tool" "$FILAMENT_BASE_DIR/out/cmake-release/tools/$tool/$tool"
  done
fi

# Verify ImportExecutables file exists
IMPORT_FILE="$FILAMENT_BASE_DIR/out/ImportExecutables-Release.cmake"
if [ ! -f "$IMPORT_FILE" ]; then
  echo "Error: ImportExecutables-Release.cmake not found at: $IMPORT_FILE"
  echo "Contents of $FILAMENT_BASE_DIR/out/:"
  ls -la "$FILAMENT_BASE_DIR/out/" 2>/dev/null || echo "(directory does not exist)"
  exit 1
fi
echo "Found ImportExecutables file: $IMPORT_FILE"

# Build release
if [ "$BUILD_RELEASE" = true ]; then
  echo "Building Filament for Web (release)..."

  cd "$FILAMENT_BASE_DIR"

  # Create release build directory
  mkdir -p out/cmake-webgl-release
  cd out/cmake-webgl-release

  # Link tools directory
  if [ ! -L tools ]; then
    ln -s ../cmake-release/tools tools
  fi

  # Configure and build filament
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DFILAMENT_SKIP_SAMPLES=1 \
    -DCMAKE_CXX_STANDARD=20 \
    -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -matomics -mbulk-memory" \
    -DCMAKE_CXX_FLAGS="-pthread -matomics -mbulk-memory" \
    -DIS_HOST_PLATFORM=0 \
    -DZ_HAVE_UNISTD_H=1 \
    -DUSE_ZLIB=1 \
    -DIMPORT_EXECUTABLES_DIR=out \
    -DCMAKE_INSTALL_PREFIX="$FILAMENT_BASE_DIR/out/webgl-release/filament" \
    -DWASM=1 \
    -DWASM_PTHREADS=0 \
    ../../ || {
    echo "Error: Filament release cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: Filament release build failed"
    exit 1
  }

  ninja install || {
    echo "Error: Filament release install failed"
    exit 1
  }

  # Build imageio
  echo "Building imageio (release)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-webgl-release"
  mkdir -p libs/imageio
  cd libs/imageio

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DFILAMENT_SKIP_SAMPLES=1 \
    -DCMAKE_CXX_STANDARD=20 \
    -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -matomics -mbulk-memory" \
    -DCMAKE_CXX_FLAGS="-pthread -matomics -mbulk-memory -I../../../../libs/image/include -I../../../../libs/utils/include -I../../../../libs/math/include -I../../../../third_party/tinyexr -I../../../../third_party/libpng -I../../../../third_party/basisu/encoder" \
    -DZ_HAVE_UNISTD_H=1 \
    -DUSE_ZLIB=1 \
    -DIMPORT_EXECUTABLES_DIR=out \
    ../../../../libs/imageio || {
    echo "Error: imageio release cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: imageio release build failed"
    exit 1
  }

  # Build third_party libraries
  echo "Building third-party libraries (release)..."

  # Build libz
  cd "$FILAMENT_BASE_DIR/out/cmake-webgl-release"
  mkdir -p third_party/libz
  cd third_party/libz

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -matomics -mbulk-memory" \
    -DCMAKE_CXX_FLAGS="-pthread -matomics -mbulk-memory" \
    ../../../../third_party/libz || {
    echo "Error: libz release cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: libz release build failed"
    exit 1
  }

  # Build libpng
  cd "$FILAMENT_BASE_DIR/out/cmake-webgl-release/third_party"
  mkdir -p libpng
  cd libpng

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -I../libz -I../../../../third_party/libz" \
    -DCMAKE_CXX_FLAGS="-pthread -I../libz -I../../../../third_party/libz -matomics -mbulk-memory" \
    -DPNG_SHARED=OFF \
    -DZLIB_ROOT=../../../../third_party/libz \
    -DZLIB_LIBRARY=../../../../third_party/libz/libz.a \
    -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
    ../../../../third_party/libpng || {
    echo "Error: libpng release cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: libpng release build failed"
    exit 1
  }

  # Build tinyexr
  cd "$FILAMENT_BASE_DIR/out/cmake-webgl-release/third_party"
  mkdir -p tinyexr
  cd tinyexr

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -I../libz -I../../../../third_party/libz" \
    -DCMAKE_CXX_FLAGS="-pthread -I../libz -I../../../../third_party/libz -matomics -mbulk-memory -Wno-reserved-identifier -Wno-tautological-type-limit-compare -Wno-switch-default -Wno-sign-conversion -Wno-unsafe-buffer-usage" \
    -DPNG_SHARED=OFF \
    -DZLIB_ROOT=../../../../third_party/libz \
    -DZLIB_LIBRARY=../../../../third_party/libz/libz.a \
    -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
    ../../../../third_party/tinyexr || {
    echo "Error: tinyexr release cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: tinyexr release build failed"
    exit 1
  }

  # Build libassimp for release
  echo "Building libassimp (release)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-webgl-release/third_party"
  mkdir -p libassimp && cd libassimp

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -I../libz -I../../../../third_party/libz -matomics -mbulk-memory" \
    -DCMAKE_CXX_FLAGS="-pthread -I../libz -I../../../../third_party/libz -matomics -mbulk-memory" \
    -DASSIMP_BUILD_ASSIMP_TOOLS=OFF \
    -DASSIMP_BUILD_TESTS=OFF \
    -DASSIMP_BUILD_SAMPLES=OFF \
    -DASSIMP_WARNINGS_AS_ERRORS=OFF \
    ../../../../third_party/libassimp/tnt || {
    echo "Error: libassimp release cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: libassimp release build failed"
    exit 1
  }
fi

# Build debug (if requested)
if [ "$BUILD_DEBUG" = true ]; then
  echo "Building Filament for Web (debug)..."

  cd "$FILAMENT_BASE_DIR"

  # Create debug build directory
  mkdir -p out/cmake-webgl-debug
  cd out/cmake-webgl-debug

  # Link tools directory
  if [ ! -L tools ]; then
    ln -s ../cmake-release/tools tools
  fi

  # Configure and build filament
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DFILAMENT_SKIP_SAMPLES=1 \
    -DCMAKE_CXX_STANDARD=20 \
    -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -matomics -mbulk-memory" \
    -DCMAKE_CXX_FLAGS="-pthread -matomics -mbulk-memory" \
    -DIS_HOST_PLATFORM=0 \
    -DZ_HAVE_UNISTD_H=1 \
    -DUSE_ZLIB=1 \
    -DIMPORT_EXECUTABLES_DIR=out \
    -DCMAKE_INSTALL_PREFIX="$FILAMENT_BASE_DIR/out/webgl-debug/filament" \
    -DWASM=1 \
    -DWASM_PTHREADS=0 \
    ../../ || {
    echo "Error: Filament debug cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: Filament debug build failed"
    exit 1
  }

  ninja install || {
    echo "Error: Filament debug install failed"
    exit 1
  }

  # Build imageio for debug
  echo "Building imageio (debug)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-webgl-debug"
  mkdir -p libs/imageio
  cd libs/imageio

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DFILAMENT_SKIP_SAMPLES=1 \
    -DCMAKE_CXX_STANDARD=20 \
    -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -matomics -mbulk-memory" \
    -DCMAKE_CXX_FLAGS="-pthread -matomics -mbulk-memory -I../../../../libs/image/include -I../../../../libs/utils/include -I../../../../libs/math/include -I../../../../third_party/tinyexr -I../../../../third_party/libpng -I../../../../third_party/basisu/encoder" \
    -DZ_HAVE_UNISTD_H=1 \
    -DUSE_ZLIB=1 \
    -DIMPORT_EXECUTABLES_DIR=out \
    ../../../../libs/imageio || {
    echo "Error: imageio debug cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: imageio debug build failed"
    exit 1
  }

  # Build third_party libraries for debug
  echo "Building third-party libraries (debug)..."

  # Build libz for debug
  cd "$FILAMENT_BASE_DIR/out/cmake-webgl-debug"
  mkdir -p third_party/libz
  cd third_party/libz

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -matomics -mbulk-memory" \
    -DCMAKE_CXX_FLAGS="-pthread -matomics -mbulk-memory" \
    ../../../../third_party/libz || {
    echo "Error: libz debug cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: libz debug build failed"
    exit 1
  }

  # Build libpng for debug
  cd "$FILAMENT_BASE_DIR/out/cmake-webgl-debug/third_party"
  mkdir -p libpng
  cd libpng

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -I../libz -I../../../../third_party/libz" \
    -DCMAKE_CXX_FLAGS="-pthread -I../libz -I../../../../third_party/libz -matomics -mbulk-memory" \
    -DPNG_SHARED=OFF \
    -DZLIB_ROOT=../../../../third_party/libz \
    -DZLIB_LIBRARY=../../../../third_party/libz/libz.a \
    -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
    ../../../../third_party/libpng || {
    echo "Error: libpng debug cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: libpng debug build failed"
    exit 1
  }

  # Build tinyexr for debug
  cd "$FILAMENT_BASE_DIR/out/cmake-webgl-debug/third_party"
  mkdir -p tinyexr
  cd tinyexr

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -I../libz -I../../../../third_party/libz" \
    -DCMAKE_CXX_FLAGS="-pthread -I../libz -I../../../../third_party/libz -matomics -mbulk-memory -Wno-reserved-identifier -Wno-tautological-type-limit-compare -Wno-switch-default -Wno-sign-conversion -Wno-unsafe-buffer-usage" \
    -DPNG_SHARED=OFF \
    -DZLIB_ROOT=../../../../third_party/libz \
    -DZLIB_LIBRARY=../../../../third_party/libz/libz.a \
    -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
    ../../../../third_party/tinyexr || {
    echo "Error: tinyexr debug cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: tinyexr debug build failed"
    exit 1
  }

  # Build libassimp for debug
  echo "Building libassimp (debug)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-webgl-debug/third_party"
  mkdir -p libassimp && cd libassimp

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -I../libz -I../../../../third_party/libz -matomics -mbulk-memory" \
    -DCMAKE_CXX_FLAGS="-pthread -I../libz -I../../../../third_party/libz -matomics -mbulk-memory" \
    -DASSIMP_BUILD_ASSIMP_TOOLS=OFF \
    -DASSIMP_BUILD_TESTS=OFF \
    -DASSIMP_BUILD_SAMPLES=OFF \
    -DASSIMP_WARNINGS_AS_ERRORS=OFF \
    ../../../../third_party/libassimp/tnt || {
    echo "Error: libassimp debug cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: libassimp debug build failed"
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
  cd "$FILAMENT_BASE_DIR"

  # Copy main filament libraries (.a files for web)
  find out/cmake-webgl-release -name "*.a" -type f -exec cp {} "$TARGET_RELEASE_DIR/" \; || {
    echo "Error: Failed to copy release libraries"
    exit 1
  }

  # Copy .bc (bitcode) files if they exist
  find out/cmake-webgl-release -name "*.bc" -type f -exec cp {} "$TARGET_RELEASE_DIR/" \; 2>/dev/null
fi

# Copy debug libraries
if [ "$BUILD_DEBUG" = true ]; then
  echo "Copying debug libraries..."
  cd "$FILAMENT_BASE_DIR"

  # Copy main filament libraries (.a files for web)
  find out/cmake-webgl-debug -name "*.a" -type f -exec cp {} "$TARGET_DEBUG_DIR/" \; || {
    echo "Error: Failed to copy debug libraries"
    exit 1
  }

  # Copy .bc (bitcode) files if they exist
  find out/cmake-webgl-debug -name "*.bc" -type f -exec cp {} "$TARGET_DEBUG_DIR/" \; 2>/dev/null
fi

# Bundle the Filament header tree into each target zip directory so the web
# R2 artifact is self-contained (libraries + matching headers), exactly like
# the other platforms. The flat `include/` layout mirrors Filament's install
# tree; gltfio/materials/uberarchive.h is the web-specific variant. This lets
# `make wasm` source headers from the downloaded web zip instead of a
# hand-committed tree that can drift on version bumps.
copy_web_headers() {
  local target_dir="$1"    # $TARGET_RELEASE_DIR or $TARGET_DEBUG_DIR
  local header_src="$2"    # out/webgl-<mode>/filament/include
  local inc="$target_dir/include"

  echo "Bundling Filament headers into $inc ..."
  mkdir -p "$inc"
  cp -R "$FILAMENT_BASE_DIR/$header_src/"* "$inc/" || {
    echo "Error: Failed to copy Filament headers"
    exit 1
  }

  # imageio headers (not part of the main install include dir).
  # libs/imageio/include/ contains an imageio/ subdir, so copy into $inc/ to
  # land at include/imageio/ImageDecoder.h (consumers include <imageio/...>).
  cp -R "$FILAMENT_BASE_DIR/libs/imageio/include/"* "$inc/" || {
    echo "Error: Failed to copy imageio headers"
    exit 1
  }

  # stb_image.h (third-party header used by TTexture.cpp)
  mkdir -p "$inc/third_party/stb"
  cp "$FILAMENT_BASE_DIR/third_party/stb/stb_image.h" "$inc/third_party/stb/" || {
    echo "Error: Failed to copy stb_image.h"
    exit 1
  }

  # Assimp headers (for model import support)
  mkdir -p "$inc/third_party/libassimp/include"
  cp -R "$FILAMENT_BASE_DIR/third_party/libassimp/include/assimp" "$inc/third_party/libassimp/include/" || {
    echo "Error: Failed to copy Assimp headers"
    exit 1
  }
}

if [ "$BUILD_RELEASE" = true ]; then
  copy_web_headers "$TARGET_RELEASE_DIR" "out/webgl-release/filament/include"
fi
if [ "$BUILD_DEBUG" = true ]; then
  copy_web_headers "$TARGET_DEBUG_DIR" "out/webgl-debug/filament/include"
fi

# Create zip files
if [ "$BUILD_RELEASE" = true ]; then
  echo "Creating release zip..."
  cd "$TARGET_RELEASE_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-web-release.zip" . || {
    echo "Error: Failed to create release zip"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  echo "Creating debug zip..."
  cd "$TARGET_DEBUG_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-web-debug.zip" . || {
    echo "Error: Failed to create debug zip"
    exit 1
  }
fi

echo "Build completed successfully!"
if [ "$BUILD_RELEASE" = true ]; then
  echo "Release libraries: $TARGET_RELEASE_DIR"
  echo "Release zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-web-release.zip"
fi
if [ "$BUILD_DEBUG" = true ]; then
  echo "Debug libraries: $TARGET_DEBUG_DIR"
  echo "Debug zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-web-debug.zip"
fi
