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

# Patch the libassimp tnt overlay to enable STL/PLY import + FBX export.
# Must run AFTER the checkout so it patches the checked-out tag. Idempotent.
python3 "$SCRIPT_DIR/patch_libassimp_tnt.py" "$FILAMENT_BASE_DIR"

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

# Run release build (-s adds iOS simulator support, -l builds universal libraries)
if [ "$BUILD_RELEASE" = true ]; then
  echo "Building Filament for iOS (release)..."
  ./build.sh -s -l -i -f -p ios release || {
    echo "Error: Filament release build failed"
    exit 1
  }
fi

# Run debug build (-s adds iOS simulator support, -l builds universal libraries)
if [ "$BUILD_DEBUG" = true ]; then
  echo "Building Filament for iOS (debug)..."
  ./build.sh -s -l -i -f -p ios debug || {
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

  # Filament v1.74.0 builds iOS XCFramework bundles (lib<name>.xcframework/)
  # and removes the intermediate flat per-arch .a directories. Thermion links
  # flat -l<name> .a archives, so extract the per-slice .a from each xcframework
  # and lipo the slices into a single universal (device + simulator) .a in the
  # target directory.
  _LIB_DIR="out/ios-release/filament/lib"
  for _xcf in "$_LIB_DIR"/*.xcframework; do
    [ -d "$_xcf" ] || continue
    _name=$(basename "$_xcf" .xcframework)
    _slices=()
    while IFS= read -r -d '' _a; do _slices+=("$_a"); done < <(find "$_xcf" -name '*.a' -print0)
    [ "${#_slices[@]}" -gt 0 ] || continue
    if [ "${#_slices[@]}" -eq 1 ]; then
      cp "${_slices[0]}" "$TARGET_RELEASE_DIR/$_name.a"
    else
      # Slices can overlap in architecture — v1.75.0's simulator slices are
      # fat (arm64 + x86_64) while the device slices are arm64-only, so
      # lipo -create of all slices fails ("same architectures and can't be
      # in the same fat output file"). Deduplicate by extracting a thin
      # slice per unique architecture, then combine those.
      _have=()
      _inputs=()
      _tmpdir=$(mktemp -d)
      for _a in "${_slices[@]}"; do
        for _arch in $(lipo -archs "$_a"); do
          case " ${_have[*]} " in
            *" $_arch "*) continue ;;
          esac
          _have+=("$_arch")
          if [ "$(lipo -archs "$_a" | wc -w)" -eq 1 ]; then
            _inputs+=("$_a")
          else
            lipo -extract "$_arch" "$_a" -output "$_tmpdir/$_name-$_arch.a" || {
              echo "Error: failed to extract $_arch from $_a"
              rm -rf "$_tmpdir"
              exit 1
            }
            _inputs+=("$_tmpdir/$_name-$_arch.a")
          fi
        done
      done
      lipo -create "${_inputs[@]}" -output "$TARGET_RELEASE_DIR/$_name.a" || {
        echo "Error: failed to lipo universal library $_name"
        rm -rf "$_tmpdir"
        exit 1
      }
      rm -rf "$_tmpdir"
    fi
  done
  echo "Extracted universal libraries from XCFrameworks into $TARGET_RELEASE_DIR"

  # Build libz for release
  echo "Building libz (release)..."
  cd "$FILAMENT_BASE_DIR"
  cd out/cmake-ios-release-arm64-iphoneos/third_party
  mkdir -p libz && cd libz
  cmake -G Ninja -DIOS=1 -DIPHONEOS_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_BUILD_TYPE=Release "$FILAMENT_BASE_DIR/third_party/libz"
  ninja

  # Build imageio for release
  echo "Building imageio (release)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-ios-release-arm64-iphoneos/third_party"
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
  cd "$FILAMENT_BASE_DIR/out/cmake-ios-release-arm64-iphoneos/third_party"
  mkdir -p tinyexr && cd tinyexr
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 \
          -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
          -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
          -DCMAKE_CXX_FLAGS="-Wno-poison-system-directories -Wno-switch-default -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
          "$FILAMENT_BASE_DIR/third_party/tinyexr"
  ninja

  # Build libassimp for release
  echo "Building libassimp (release)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-ios-release-arm64-iphoneos/third_party"
  rm -rf libassimp
  mkdir -p libassimp && cd libassimp
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_STANDARD=17 \
          -DIOS=1 \
          -DASSIMP_BUILD_ASSIMP_TOOLS=OFF \
          -DASSIMP_BUILD_TESTS=OFF \
          -DASSIMP_BUILD_SAMPLES=OFF \
          -DASSIMP_WARNINGS_AS_ERRORS=OFF \
          "$FILAMENT_BASE_DIR/third_party/libassimp/tnt"
  ninja

  # Copy release third-party libraries
  echo "Copying release third-party libraries..."
  cd "$FILAMENT_BASE_DIR"
  cp out/cmake-ios-release-arm64-iphoneos/third_party/libz/*.a "$TARGET_RELEASE_DIR/" || echo "Warning: No libz libraries found"
  cp out/cmake-ios-release-arm64-iphoneos/third_party/imageio/*.a "$TARGET_RELEASE_DIR/" || {
    echo "Error: Failed to copy imageio libraries"
    exit 1
  }
  cp out/cmake-ios-release-arm64-iphoneos/third_party/tinyexr/*.a "$TARGET_RELEASE_DIR/" || {
    echo "Error: Failed to copy tinyexr libraries"
    exit 1
  }
  cp out/cmake-ios-release-arm64-iphoneos/third_party/libassimp/libassimp.a "$TARGET_RELEASE_DIR/" || {
    echo "Error: Failed to copy libassimp libraries"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  mkdir -p "$TARGET_DEBUG_DIR" || {
    echo "Error: Failed to create target directory: $TARGET_DEBUG_DIR"
    exit 1
  }

  # Extract universal libs from XCFrameworks (see release block above).
  _LIB_DIR="out/ios-debug/filament/lib"
  for _xcf in "$_LIB_DIR"/*.xcframework; do
    [ -d "$_xcf" ] || continue
    _name=$(basename "$_xcf" .xcframework)
    _slices=()
    while IFS= read -r -d '' _a; do _slices+=("$_a"); done < <(find "$_xcf" -name '*.a' -print0)
    [ "${#_slices[@]}" -gt 0 ] || continue
    if [ "${#_slices[@]}" -eq 1 ]; then
      cp "${_slices[0]}" "$TARGET_DEBUG_DIR/$_name.a"
    else
      # See the release block above: slices can overlap in architecture
      # (v1.75.0's simulator slices are fat arm64+x86_64), so deduplicate by
      # extracting a thin slice per unique architecture before combining.
      _have=()
      _inputs=()
      _tmpdir=$(mktemp -d)
      for _a in "${_slices[@]}"; do
        for _arch in $(lipo -archs "$_a"); do
          case " ${_have[*]} " in
            *" $_arch "*) continue ;;
          esac
          _have+=("$_arch")
          if [ "$(lipo -archs "$_a" | wc -w)" -eq 1 ]; then
            _inputs+=("$_a")
          else
            lipo -extract "$_arch" "$_a" -output "$_tmpdir/$_name-$_arch.a" || {
              echo "Error: failed to extract $_arch from $_a"
              rm -rf "$_tmpdir"
              exit 1
            }
            _inputs+=("$_tmpdir/$_name-$_arch.a")
          fi
        done
      done
      lipo -create "${_inputs[@]}" -output "$TARGET_DEBUG_DIR/$_name.a" || {
        echo "Error: failed to lipo universal library $_name"
        rm -rf "$_tmpdir"
        exit 1
      }
      rm -rf "$_tmpdir"
    fi
  done
  echo "Extracted universal libraries from XCFrameworks into $TARGET_DEBUG_DIR"

  # Build libz for debug
  echo "Building libz (debug)..."
  cd "$FILAMENT_BASE_DIR"
  cd out/cmake-ios-debug-arm64-iphoneos/third_party
  mkdir -p libz && cd libz
  cmake -G Ninja -DIOS=1 -DIPHONEOS_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_BUILD_TYPE=Debug "$FILAMENT_BASE_DIR/third_party/libz"
  ninja

  # Build imageio for debug
  echo "Building imageio (debug)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-ios-debug-arm64-iphoneos/third_party"
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
  cd "$FILAMENT_BASE_DIR/out/cmake-ios-debug-arm64-iphoneos/third_party"
  mkdir -p tinyexr && cd tinyexr
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_STANDARD=17 \
          -DZLIB_INCLUDE_DIR="$FILAMENT_BASE_DIR/third_party/libz" \
          -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
          -DCMAKE_CXX_FLAGS="-Wno-poison-system-directories -Wno-switch-default -I$FILAMENT_BASE_DIR/libs/image/include -I$FILAMENT_BASE_DIR/libs/utils/include -I$FILAMENT_BASE_DIR/libs/math/include -I$FILAMENT_BASE_DIR/third_party/tinyexr -I$FILAMENT_BASE_DIR/third_party/libpng -I$FILAMENT_BASE_DIR/third_party/basisu/encoder" \
          "$FILAMENT_BASE_DIR/third_party/tinyexr"
  ninja

  # Build libassimp for debug
  echo "Building libassimp (debug)..."
  cd "$FILAMENT_BASE_DIR/out/cmake-ios-debug-arm64-iphoneos/third_party"
  rm -rf libassimp
  mkdir -p libassimp && cd libassimp
  cmake -G Ninja \
          -DCMAKE_BUILD_TYPE=Debug \
          -DCMAKE_CXX_STANDARD=17 \
          -DIOS=1 \
          -DASSIMP_BUILD_ASSIMP_TOOLS=OFF \
          -DASSIMP_BUILD_TESTS=OFF \
          -DASSIMP_BUILD_SAMPLES=OFF \
          -DASSIMP_WARNINGS_AS_ERRORS=OFF \
          "$FILAMENT_BASE_DIR/third_party/libassimp/tnt"
  ninja

  # Copy debug third-party libraries
  echo "Copying debug third-party libraries..."
  cd "$FILAMENT_BASE_DIR"
  cp out/cmake-ios-debug-arm64-iphoneos/third_party/libz/*.a "$TARGET_DEBUG_DIR/" || echo "Warning: No libz libraries found"
  cp out/cmake-ios-debug-arm64-iphoneos/third_party/imageio/*.a "$TARGET_DEBUG_DIR/" || {
    echo "Error: Failed to copy imageio libraries"
    exit 1
  }
  cp out/cmake-ios-debug-arm64-iphoneos/third_party/tinyexr/*.a "$TARGET_DEBUG_DIR/" || {
    echo "Error: Failed to copy tinyexr libraries"
    exit 1
  }
  cp out/cmake-ios-debug-arm64-iphoneos/third_party/libassimp/libassimp.a "$TARGET_DEBUG_DIR/" || {
    echo "Error: Failed to copy libassimp libraries"
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
  echo "Creating release zip..."
  cd "$TARGET_RELEASE_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-ios-release.zip" . || {
    echo "Error: Failed to create release zip"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
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
