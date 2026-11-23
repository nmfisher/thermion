#!/bin/bash

# Prevent macOS ._* resource fork files in copies and zips
export COPYFILE_DISABLE=1

# Save script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR> [options]"
  echo "Example: $0 /path/to/filament v1.77.2 /path/to/output"
  echo "         $0 /path/to/filament v1.77.2 /path/to/output --clean"
  echo "         $0 /path/to/filament v1.77.2 /path/to/output --release"
  echo "         $0 /path/to/filament v1.77.2 /path/to/output --tools-dir /path/to/tools"
  echo ""
  echo "Options:"
  echo "  --clean         Remove existing target directories before building"
  echo "  --release       Build release only"
  echo "  --debug         Build debug only"
  echo "  --tools-dir DIR Use prebuilt desktop tools from DIR (matc must support WGSL)"
  echo "                  DIR must contain ImportExecutables-Release.cmake and tools/"
  echo "  (default)       Build release and debug for both WebGL and WebGPU"
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

BUILD_MODES=()
if [ "$BUILD_RELEASE" = true ]; then
  BUILD_MODES+=(release)
fi
if [ "$BUILD_DEBUG" = true ]; then
  BUILD_MODES+=(debug)
fi

# Check every requested output before building either backend.
for suffix in "" "-webgpu"; do
  for mode in "${BUILD_MODES[@]}"; do
    target_dir="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/web$suffix/$mode"
    if [ -d "$target_dir" ]; then
      if [ "$CLEAN_FLAG" != "--clean" ]; then
        echo "Error: Target directory already exists: $target_dir"
        echo "Please remove it first or use --clean to rebuild."
        exit 1
      fi
      echo "Removing existing target directory: $target_dir"
      rm -rf "$target_dir" || exit 1
    fi
  done
done

# Change to Filament directory and checkout branch
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
git grep -lz -e '-Werror' -- ':(glob)**/CMakeLists.txt' '*.cmake' \
  | while IFS= read -r -d '' cmake_file; do
      sed -i.bak 's/-Werror\([^=]\)/-Wno-error\1/g; s/-Werror$/-Wno-error/g' "$cmake_file" || exit 1
    done || exit 1

# Ensure desktop tools are available (needed for web cross-compilation)
if [ -n "$TOOLS_DIR" ]; then
  # Use prebuilt tools from a local directory
  TOOLS_DIR=$(cd "$TOOLS_DIR" && pwd) || exit 1
  echo "Using prebuilt desktop tools from: $TOOLS_DIR"
else
  # The official desktop tools lack WGSL support. Use Filament's split-build
  # export format and build the host tools from the same source as the port.
  cmake -G Ninja -S . -B out/prebuilt-tools-release \
    -DCMAKE_BUILD_TYPE=Release -DFILAMENT_SUPPORTS_WEBGPU=ON \
    -DFILAMENT_ENABLE_EXCEPTIONS=ON -DFILAMENT_SKIP_SAMPLES=ON \
    -DFILAMENT_BUILD_TESTING=OFF \
    -DFILAMENT_EXPORT_PREBUILT_EXECUTABLES_DIR=out/prebuilt-tools-release && \
    cmake --build out/prebuilt-tools-release --target matc cmgen filamesh mipgen resgen uberz glslminifier || exit 1
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

# Filament's split desktop build exports source-built tools separately.
IMPORT_OPTION="-DIMPORT_EXECUTABLES_DIR=out"
IMPORT_FILE="$FILAMENT_BASE_DIR/out/ImportExecutables-Release.cmake"
SOURCE_TOOLS_DIR="out/prebuilt-tools-release"
if [ -z "$TOOLS_DIR" ]; then
  IMPORT_OPTION="-DFILAMENT_IMPORT_PREBUILT_EXECUTABLES_DIR=$SOURCE_TOOLS_DIR"
  IMPORT_FILE="$FILAMENT_BASE_DIR/$SOURCE_TOOLS_DIR/ImportExecutables-Prebuilt.cmake"
fi
if [ ! -f "$IMPORT_FILE" ]; then
  echo "Error: Filament host-tool export not found at: $IMPORT_FILE"
  echo "Contents of $FILAMENT_BASE_DIR/out/:"
  ls -la "$FILAMENT_BASE_DIR/out/" 2>/dev/null || echo "(directory does not exist)"
  exit 1
fi
echo "Found ImportExecutables file: $IMPORT_FILE"

# Build the port from Filament's Dawn revision, as Filament's own WebGPU
# build does. Bundle it with the archive so clients use the same ABI and glue.
DAWN_BUILD="$FILAMENT_BASE_DIR/out/cmake-wasm-dawn"
cmake -G Ninja -S "$FILAMENT_BASE_DIR/third_party/dawn" -B "$DAWN_BUILD" \
  -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
  -DDAWN_ABSEIL_DIR="$FILAMENT_BASE_DIR/third_party/abseil" \
  -DDAWN_BUILD_TESTS=OFF -DDAWN_BUILD_SAMPLES=OFF \
  -DDAWN_BUILD_PROTOBUF=OFF -DDAWN_SUPPORTS_CXX_MODULES=OFF \
  -DTINT_BUILD_TESTS=OFF -DTINT_BUILD_BENCHMARKS=OFF && \
  cmake --build "$DAWN_BUILD" --target emdawnwebgpu_pkg || exit 1
DAWN_PACKAGE="$DAWN_BUILD/emdawnwebgpu_pkg"

build_web_archive() {
  local backend="$1"
  local mode="$2"
  local build_type=Release
  if [ "$mode" = debug ]; then
    build_type=Debug
  fi

  local suffix="" enable_webgpu=OFF build_filamat=ON dawn_port_flag=""
  if [ "$backend" = webgpu ]; then
    suffix="-webgpu"
    enable_webgpu=ON
    build_filamat=OFF
    dawn_port_flag=" --use-port=\"$DAWN_PACKAGE/emdawnwebgpu.port.py\""
  fi

  local build_dir="$FILAMENT_BASE_DIR/out/cmake-$backend-$mode"
  local install_dir="$FILAMENT_BASE_DIR/out/$backend-$mode/filament"
  local target_dir="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/web$suffix/$mode"
  local zip_path="$OUTPUT_BASE_DIR/filament-$FILAMENT_VERSION-web-$mode$suffix.zip"

  echo "Building Filament for $backend ($mode)..."
  mkdir -p "$build_dir" || exit 1
  cd "$build_dir" || exit 1

  # Link tools directory
  if [ ! -L tools ]; then
    ln -s ../cmake-release/tools tools
  fi

  # Configure and build filament
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE="$build_type" \
    -DFILAMENT_ENABLE_EXCEPTIONS=OFF \
    -DFILAMENT_SKIP_SAMPLES=1 -DFILAMENT_BUILD_TESTING=OFF \
    -DFILAMENT_BUILD_FILAMAT="$build_filamat" \
    -DFILAMENT_SUPPORTS_WEBGPU="$enable_webgpu" \
    -DCMAKE_CXX_STANDARD=20 \
    -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -matomics -mbulk-memory$dawn_port_flag" \
    -DCMAKE_CXX_FLAGS="-fno-exceptions -pthread -matomics -mbulk-memory$dawn_port_flag" \
    -DIS_HOST_PLATFORM=0 \
    -DZ_HAVE_UNISTD_H=1 \
    -DUSE_ZLIB=1 \
    "$IMPORT_OPTION" \
    -DCMAKE_INSTALL_PREFIX="$install_dir" \
    -DWASM=1 \
    -DWASM_PTHREADS=0 \
    ../../ || {
    echo "Error: Filament $mode cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: Filament $mode build failed"
    exit 1
  }

  ninja install || {
    echo "Error: Filament $mode install failed"
    exit 1
  }

  # Build libz
  cd "$build_dir" || exit 1
  mkdir -p third_party/libz
  cd third_party/libz || exit 1

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE="$build_type" \
    -DCMAKE_CXX_STANDARD=20 \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -matomics -mbulk-memory" \
    -DCMAKE_CXX_FLAGS="-fno-exceptions -pthread -matomics -mbulk-memory" \
    ../../../../third_party/libz || {
    echo "Error: libz $mode cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: libz $mode build failed"
    exit 1
  }

  # Build libpng
  cd "$build_dir/third_party" || exit 1
  mkdir -p libpng
  cd libpng || exit 1

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE="$build_type" \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -I../libz -I../../../../third_party/libz" \
    -DCMAKE_CXX_FLAGS="-fno-exceptions -pthread -I../libz -I../../../../third_party/libz -matomics -mbulk-memory" \
    -DPNG_SHARED=OFF \
    -DZLIB_ROOT=../../../../third_party/libz \
    -DZLIB_LIBRARY=../../../../third_party/libz/libz.a \
    -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
    ../../../../third_party/libpng || {
    echo "Error: libpng $mode cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: libpng $mode build failed"
    exit 1
  }

  # Build tinyexr
  cd "$build_dir/third_party" || exit 1
  mkdir -p tinyexr
  cd tinyexr || exit 1

  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE="$build_type" \
    -DCMAKE_TOOLCHAIN_FILE="$EMSCRIPTEN_CMAKE" \
    -DCMAKE_C_FLAGS="-pthread -I../libz -I../../../../third_party/libz" \
    -DCMAKE_CXX_FLAGS="-fno-exceptions -pthread -I../libz -I../../../../third_party/libz -matomics -mbulk-memory -Wno-reserved-identifier -Wno-tautological-type-limit-compare -Wno-switch-default -Wno-sign-conversion -Wno-unsafe-buffer-usage" \
    -DPNG_SHARED=OFF \
    -DZLIB_ROOT=../../../../third_party/libz \
    -DZLIB_LIBRARY=../../../../third_party/libz/libz.a \
    -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
    ../../../../third_party/tinyexr || {
    echo "Error: tinyexr $mode cmake configuration failed"
    exit 1
  }

  ninja || {
    echo "Error: tinyexr $mode build failed"
    exit 1
  }

  echo "Packaging Filament for $backend ($mode)..."
  mkdir -p "$target_dir/include/third_party/stb" || exit 1
  find "$build_dir" -type f \( -name '*.a' -o -name '*.bc' \) -exec cp {} "$target_dir/" \; || exit 1

  # Emscripten only ships libzstatic.a. The web CMakeLists expects libz.a.
  if [ ! -f "$target_dir/libz.a" ] && [ -f "$target_dir/libzstatic.a" ]; then
    cp "$target_dir/libzstatic.a" "$target_dir/libz.a" || exit 1
  fi

  # Package the matching headers and, for WebGPU, the Dawn browser port.
  cp -R "$install_dir/include/." "$target_dir/include/" || exit 1
  cp "$FILAMENT_BASE_DIR/third_party/stb/stb_image.h" "$target_dir/include/third_party/stb/" || exit 1
  if [ "$enable_webgpu" = ON ]; then
    cp -R "$DAWN_PACKAGE" "$target_dir/" || exit 1
  fi

  cd "$target_dir" || exit 1
  rm -f "$zip_path" || exit 1
  zip -r "$zip_path" . || exit 1
  echo "Created $zip_path"
}

# WebGPU uses precompiled materials. Build it before adding the parser and
# compiler patches for the WebGL runtime-materials archive.
for mode in "${BUILD_MODES[@]}"; do
  build_web_archive webgpu "$mode"
done

cd "$FILAMENT_BASE_DIR" || exit 1
git apply "$SCRIPT_DIR/filament-smolv-combined.patch" || exit 1
git apply "$SCRIPT_DIR/filament-matp-runtime.patch" || exit 1
for mode in "${BUILD_MODES[@]}"; do
  build_web_archive webgl "$mode"
done

echo "Build completed successfully!"
