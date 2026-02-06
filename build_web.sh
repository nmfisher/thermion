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
  echo ""
  echo "Environment variables:"
  echo "  EMSDK          Path to Emscripten SDK (default: \$EMSDK or \$EMSCRIPTEN)"
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

# Check for EMSDK environment variable
if [ -z "$EMSDK" ] && [ -z "$EMSCRIPTEN" ]; then
  echo "Error: EMSDK or EMSCRIPTEN environment variable must be set"
  echo "Example: export EMSDK=/path/to/emsdk"
  exit 1
fi

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
echo "Checking out branch: thermion-custom-build"
git checkout thermion-custom-build || {
  echo "Error: Failed to checkout branch: thermion-custom-build"
  exit 1
}

# Patch Filament's build.sh to skip samples (add -DFILAMENT_SKIP_SAMPLES=ON to cmake commands)
echo "Patching Filament build.sh to skip samples..."
sed -i.bak 's|\${architectures} \\$|\${architectures} -DFILAMENT_SKIP_SAMPLES=ON \\|g' build.sh

# Patch libz CMakeLists.txt to fix duplicate libz.a output issue (Emscripten-specific)
echo "Patching libz CMakeLists.txt for Emscripten..."
sed -i.bak 's/set_target_properties(zlib zlibstatic PROPERTIES OUTPUT_NAME z)/set_target_properties(zlib PROPERTIES OUTPUT_NAME z)\n set_target_properties(zlibstatic PROPERTIES OUTPUT_NAME zstatic)/g' third_party/libz/CMakeLists.txt

# Ensure desktop tools are available (needed for web cross-compilation)
if [ ! -d "out/cmake-release/tools" ]; then
  echo "Desktop tools not found. Building desktop release (required for web cross-compilation)..."
  ./build.sh -p desktop release || {
    echo "Error: Desktop tools build failed"
    exit 1
  }
fi

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
    -DWEBGL=1 \
    -DWEBGL_PTHREADS=0 \
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
    -DCMAKE_C_FLAGS="-pthread -I../libz" \
    -DCMAKE_CXX_FLAGS="-pthread -I../libz -matomics -mbulk-memory" \
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
    -DCMAKE_C_FLAGS="-pthread -I../libz" \
    -DCMAKE_CXX_FLAGS="-pthread -I../libz -matomics -mbulk-memory -Wno-reserved-identifier -Wno-tautological-type-limit-compare -Wno-switch-default -Wno-sign-conversion -Wno-unsafe-buffer-usage" \
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
    -DWEBGL=1 \
    -DWEBGL_PTHREADS=0 \
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
    -DCMAKE_C_FLAGS="-pthread -I../libz" \
    -DCMAKE_CXX_FLAGS="-pthread -I../libz -matomics -mbulk-memory" \
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
    -DCMAKE_C_FLAGS="-pthread -I../libz" \
    -DCMAKE_CXX_FLAGS="-pthread -I../libz -matomics -mbulk-memory -Wno-reserved-identifier -Wno-tautological-type-limit-compare -Wno-switch-default -Wno-sign-conversion -Wno-unsafe-buffer-usage" \
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

# Copy header files to thermion_dart (separate directories for release and debug)
if [ "$BUILD_RELEASE" = true ]; then
  echo "Copying Filament release header files to thermion_dart..."
  THERMION_INCLUDE_RELEASE="$SCRIPT_DIR/thermion_dart/native/include/filament/release/filament"

  # Clean and recreate release include directory
  rm -rf "$THERMION_INCLUDE_RELEASE"
  mkdir -p "$THERMION_INCLUDE_RELEASE"

  # Copy all headers from Filament's release install directory
  cd "$FILAMENT_BASE_DIR"
  cp -R out/webgl-release/filament/include/* "$THERMION_INCLUDE_RELEASE/" || {
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

  # Copy all headers from Filament's debug install directory
  cd "$FILAMENT_BASE_DIR"
  cp -R out/webgl-debug/filament/include/* "$THERMION_INCLUDE_DEBUG/" || {
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
