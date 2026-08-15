#!/bin/bash
set -e

# Build arm64 iOS simulator Filament libraries.
# Run AFTER build_ios.sh — reuses the same Filament checkout and host tools.
#
# Usage: build_ios_simulator.sh <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR> [options]
#
# Output goes to <OUTPUT_BASE_DIR>/<FILAMENT_VERSION>/ios-simulator/{debug,release}/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 3 ]; then
  echo "Usage: $0 <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR> [options]"
  echo "Options:"
  echo "  --clean         Remove existing target directories before building"
  echo "  --release       Build release only"
  echo "  --debug         Build debug only"
  exit 1
fi

FILAMENT_BASE_DIR=$(cd "$1" && pwd)
FILAMENT_VERSION=$2
OUTPUT_BASE_DIR=$(cd "$3" && pwd)
shift 3

CLEAN_FLAG=""
BUILD_RELEASE=true
BUILD_DEBUG=true

for arg in "$@"; do
  case $arg in
    --clean) CLEAN_FLAG="--clean" ;;
    --release) BUILD_DEBUG=false ;;
    --debug) BUILD_RELEASE=false ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

TARGET_RELEASE_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/ios-simulator/release"
TARGET_DEBUG_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/ios-simulator/debug"

# Clean if requested
if [ "$BUILD_RELEASE" = true ] && [ -d "$TARGET_RELEASE_DIR" ]; then
  if [ "$CLEAN_FLAG" = "--clean" ]; then
    rm -rf "$TARGET_RELEASE_DIR"
  else
    echo "Error: Release target directory already exists: $TARGET_RELEASE_DIR"
    echo "Use --clean to rebuild."
    exit 1
  fi
fi

if [ "$BUILD_DEBUG" = true ] && [ -d "$TARGET_DEBUG_DIR" ]; then
  if [ "$CLEAN_FLAG" = "--clean" ]; then
    rm -rf "$TARGET_DEBUG_DIR"
  else
    echo "Error: Debug target directory already exists: $TARGET_DEBUG_DIR"
    echo "Use --clean to rebuild."
    exit 1
  fi
fi

cd "$FILAMENT_BASE_DIR" || exit 1

# build_ios.sh (Filament's build.sh) builds the host code-generator tools once,
# as prebuilt artifacts under out/prebuilt-tools-release/, and every iOS
# cross-build imports them via ImportExecutables-Prebuilt.cmake. The top-level
# out/ImportExecutables-<Debug|Release>.cmake is NOT produced on 1.75.0, so the
# Filament cross-build below must point at the prebuilt dir too — otherwise
# CMake falls back to ${CMAKE_BUILD_TYPE} and fails with
# "include could not find requested file: out/ImportExecutables-Debug.cmake".
PREBUILT_TOOLS_IMPORT="out/prebuilt-tools-release/ImportExecutables-Prebuilt.cmake"
if [ ! -f "$PREBUILT_TOOLS_IMPORT" ]; then
  echo "Error: $PREBUILT_TOOLS_IMPORT not found."
  echo "Run build_ios.sh first — it builds the host tools this script imports."
  exit 1
fi

# Ensure we're on the right tag (build_ios.sh should have already checked this out)
CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null || true)
if [ "$CURRENT_TAG" != "$FILAMENT_VERSION" ]; then
  echo "Warning: Expected tag $FILAMENT_VERSION but found '$CURRENT_TAG'"
  echo "Make sure you've run build_ios.sh first."
fi

# Patch build.sh if not already patched
if ! grep -q "DFILAMENT_SKIP_SAMPLES" build.sh; then
  echo "Patching Filament build.sh to skip samples..."
  sed -i.bak 's|\${architectures} \\$|\${architectures} -DFILAMENT_SKIP_SAMPLES=ON \\|g' build.sh
fi

# Also patch the build_ios function to add arm64 simulator support.
# We insert an additional build_ios_target call for arm64 iphonesimulator
# right after the existing x86_64 iphonesimulator call.
# Only patch if not already patched.
if ! grep -q 'arm64.*iphonesimulator' build.sh; then
  echo "Patching Filament build.sh to add arm64 simulator target..."
  sed -i.bak2 '/build_ios_target.*x86_64.*iphonesimulator/a\
            build_ios_target "$1" "arm64" "iphonesimulator"
' build.sh
fi

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

# We also need to patch create-universal-libs.sh to handle three architectures.
# Instead of patching lipo (which can't merge two arm64 slices), we'll build
# separately and skip the universal step. Run Filament's build without -l.
#
# Strategy: use Filament's build.sh with -s (simulator) but NOT -l (universal).
# This produces per-arch installed libs, then we just copy the arm64 simulator ones.

build_sim_target() {
  local BUILD_TYPE=$1
  local lc_type=$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')
  local BUILD_DIR="out/cmake-ios-${lc_type}-arm64-sim"
  local INSTALL_DIR="out/ios-${lc_type}-sim/filament"

  echo "Building Filament arm64 simulator ($lc_type)..."
  mkdir -p "$BUILD_DIR"

  pushd "$BUILD_DIR" > /dev/null

  cmake \
    -G Ninja \
    -DFILAMENT_IMPORT_PREBUILT_EXECUTABLES_DIR=out/prebuilt-tools-release \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_INSTALL_PREFIX="../ios-${lc_type}-sim/filament" \
    -DIOS_ARCH="arm64" \
    -DPLATFORM_NAME="iphonesimulator" \
    -DIOS=1 \
    -DCMAKE_TOOLCHAIN_FILE=../../third_party/clang/iOS.cmake \
    -DFILAMENT_SKIP_SAMPLES=ON \
    ../..

  ninja
  ninja install

  # Echo the install tree so the layout Filament produced is visible in the
  # CI log (1.75.0 emits XCFramework bundles, not the flat lib/<arch>/*.a that
  # older versions produced). copy_sim_libs handles both, but this avoids
  # blind guessing if that ever changes again.
  echo "Installed ${lc_type} simulator lib layout:"
  find "../ios-${lc_type}-sim/filament/lib" \
    \( -name '*.a' -o -name '*.xcframework' \) -maxdepth 2 2>/dev/null || true

  popd > /dev/null
}

build_sim_third_party() {
  local BUILD_TYPE=$1
  local lc_type=$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')
  local BUILD_DIR="out/cmake-ios-${lc_type}-arm64-sim/third_party"

  # Build libz
  echo "Building libz (${lc_type}, arm64 simulator)..."
  mkdir -p "$BUILD_DIR/libz" && pushd "$BUILD_DIR/libz" > /dev/null
  cmake -G Ninja \
    -DIOS=1 \
    -DIPHONEOS_DEPLOYMENT_TARGET=13.0 \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    "$FILAMENT_BASE_DIR/third_party/libz"
  ninja
  popd > /dev/null

  # Build imageio
  echo "Building imageio (${lc_type}, arm64 simulator)..."
  mkdir -p "$BUILD_DIR/imageio" && pushd "$BUILD_DIR/imageio" > /dev/null
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_CXX_STANDARD=17 \
    -DPLATFORM_NAME="iphonesimulator" \
    -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
    -DZ_HAVE_UNISTD_H=1 \
    -DUSE_ZLIB=1 \
    -DIMPORT_EXECUTABLES_DIR=out \
    -DCMAKE_CXX_FLAGS="-I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
    "$FILAMENT_BASE_DIR/libs/imageio"
  ninja
  popd > /dev/null

  # Build tinyexr
  echo "Building tinyexr (${lc_type}, arm64 simulator)..."
  mkdir -p "$BUILD_DIR/tinyexr" && pushd "$BUILD_DIR/tinyexr" > /dev/null
  cmake -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_CXX_STANDARD=17 \
    -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
    -DZ_HAVE_UNISTD_H=1 \
    -DUSE_ZLIB=1 \
    -DIMPORT_EXECUTABLES_DIR=out \
    -DCMAKE_CXX_FLAGS="-Wno-poison-system-directories -Wno-switch-default -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
    "$FILAMENT_BASE_DIR/third_party/tinyexr"
  ninja
  popd > /dev/null
}

copy_sim_libs() {
  local BUILD_TYPE=$1
  local lc_type=$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')
  local TARGET_DIR=$2

  mkdir -p "$TARGET_DIR"

  # Copy main Filament libs (installed by ninja install) into flat lib<name>.a
  # archives (what build.dart links). Filament's iOS install layout varies by
  # version/platform:
  #   - arm64 iphonesimulator (this build): lib/arm64-iphonesimulator/*.a
  #     (the subdir is "${IOS_ARCH}-${PLATFORM_NAME}")
  #   - other arm builds:                    lib/<arch>/*.a  (e.g. lib/arm64)
  #   - some packaging flows:                lib/*.xcframework/<slice>/*.a
  # Collect every .a under lib/ at one subdir of depth (covers the first two)
  # and also extract a slice from any xcframework bundle.
  local found=0
  local INSTALL_LIB="out/ios-${lc_type}-sim/filament/lib"
  echo "Copying ${lc_type} simulator libraries from $INSTALL_LIB..."
  shopt -s nullglob

  # Flat or one-level-arch subdir: lib/*.a and lib/*/*.a
  for _a in "$INSTALL_LIB"/*.a "$INSTALL_LIB"/*/*.a; do
    cp "$_a" "$TARGET_DIR/$(basename "$_a")"
    found=1
  done

  # XCFramework bundles: extract one .a slice each (simulator slice preferred).
  for _xcf in "$INSTALL_LIB"/*.xcframework; do
    [ -d "$_xcf" ] || continue
    _name=$(basename "$_xcf" .xcframework)
    _slice=$(find "$_xcf" -type f -name '*.a' -path '*simulator*' | head -n1)
    [ -z "$_slice" ] && _slice=$(find "$_xcf" -type f -name '*.a' | head -n1)
    if [ -n "$_slice" ]; then
      cp "$_slice" "$TARGET_DIR/$_name.a"
      found=1
    else
      echo "Warning: no .a found in $_xcf"
    fi
  done
  shopt -u nullglob

  if [ "$found" = 0 ]; then
    echo "Error: No Filament simulator libraries found under $INSTALL_LIB"
    echo "--- full install lib tree ---"
    find "$INSTALL_LIB" -maxdepth 3 -print 2>/dev/null || true
    exit 1
  fi
  echo "Copied $(ls "$TARGET_DIR"/*.a 2>/dev/null | wc -l | tr -d ' ') main simulator libraries"

  # Copy third-party libs
  local TP_DIR="out/cmake-ios-${lc_type}-arm64-sim/third_party"
  cp "$TP_DIR/libz/"*.a "$TARGET_DIR/" || echo "Warning: No libz libraries found"
  cp "$TP_DIR/imageio/"*.a "$TARGET_DIR/" || {
    echo "Error: Failed to copy imageio libraries"
    exit 1
  }
  cp "$TP_DIR/tinyexr/"*.a "$TARGET_DIR/" || {
    echo "Error: Failed to copy tinyexr libraries"
    exit 1
  }
}

# Build
if [ "$BUILD_DEBUG" = true ]; then
  build_sim_target "Debug"
  build_sim_third_party "Debug"
  copy_sim_libs "Debug" "$TARGET_DEBUG_DIR"
fi

if [ "$BUILD_RELEASE" = true ]; then
  build_sim_target "Release"
  build_sim_third_party "Release"
  copy_sim_libs "Release" "$TARGET_RELEASE_DIR"
fi

# Write success tokens so build.dart skips downloading
if [ "$BUILD_DEBUG" = true ]; then
  echo "SUCCESS" > "$TARGET_DEBUG_DIR/success"
fi
if [ "$BUILD_RELEASE" = true ]; then
  echo "SUCCESS" > "$TARGET_RELEASE_DIR/success"
fi

# Create zip files
if [ "$BUILD_RELEASE" = true ]; then
  echo "Creating release simulator zip..."
  cd "$TARGET_RELEASE_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-simulator-release.zip" .
fi

if [ "$BUILD_DEBUG" = true ]; then
  echo "Creating debug simulator zip..."
  cd "$TARGET_DEBUG_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-simulator-debug.zip" .
fi

echo "Simulator build completed successfully!"
if [ "$BUILD_RELEASE" = true ]; then
  echo "Release simulator libraries: $TARGET_RELEASE_DIR"
fi
if [ "$BUILD_DEBUG" = true ]; then
  echo "Debug simulator libraries: $TARGET_DEBUG_DIR"
fi
