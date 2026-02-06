#!/bin/bash

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

# Check if target directories already exist
TARGET_RELEASE_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/linux/release"
TARGET_DEBUG_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/linux/debug"

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

# Set compiler to clang
export CC=clang
export CXX=clang++

# Run release build
if [ "$BUILD_RELEASE" = true ]; then
  echo "Building Filament for Linux (release)..."
  ./build.sh -l -i -f -p desktop release || {
    echo "Error: Filament release build failed"
    exit 1
  }

  # Build third-party libraries for release
  echo "Building third-party libraries for release..."
  ./build.sh -l -i -f -p desktop release zstd || {
    echo "Warning: zstd release build failed"
  }
  ./build.sh -l -i -f -p desktop release tinyexr || {
    echo "Warning: tinyexr release build failed"
  }
  ./build.sh -l -i -f -p desktop release imageio || {
    echo "Warning: imageio release build failed"
  }
fi

# Run debug build
if [ "$BUILD_DEBUG" = true ]; then
  echo "Building Filament for Linux (debug)..."
  ./build.sh -l -i -f -t -d -p desktop debug || {
    echo "Error: Filament debug build failed"
    exit 1
  }

  # Build third-party libraries for debug
  echo "Building third-party libraries for debug..."
  ./build.sh -l -i -f -p desktop debug zstd || {
    echo "Warning: zstd debug build failed"
  }
  ./build.sh -l -i -f -p desktop debug tinyexr || {
    echo "Warning: tinyexr debug build failed"
  }
  ./build.sh -l -i -f -p desktop debug imageio || {
    echo "Warning: imageio debug build failed"
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
  cp out/release/filament/lib/x86_64/*.a "$TARGET_RELEASE_DIR/" || {
    echo "Error: Failed to copy release libraries"
    exit 1
  }
fi

# Copy debug libraries
if [ "$BUILD_DEBUG" = true ]; then
  echo "Copying debug libraries..."
  cp out/debug/filament/lib/x86_64/*.a "$TARGET_DEBUG_DIR/" || {
    echo "Error: Failed to copy debug libraries"
    exit 1
  }
fi

# Copy header files to thermion_dart (separate directories for release and debug)
if [ "$BUILD_RELEASE" = true ]; then
  echo "Copying Filament release header files to thermion_dart..."
  THERMION_INCLUDE_RELEASE="$SCRIPT_DIR/thermion_dart/native/include/filament/release/filament"

  # Clean and recreate release include directory
  rm -rf "$THERMION_INCLUDE_RELEASE"
  mkdir -p "$THERMION_INCLUDE_RELEASE"

  # Copy all headers from Filament's release include directory
  cd "$FILAMENT_BASE_DIR"
  cp -R out/release/filament/include/* "$THERMION_INCLUDE_RELEASE/" || {
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

  # Copy all headers from Filament's debug include directory
  cd "$FILAMENT_BASE_DIR"
  cp -R out/debug/filament/include/* "$THERMION_INCLUDE_DEBUG/" || {
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
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-linux-release.zip" . || {
    echo "Error: Failed to create release zip"
    exit 1
  }
fi

if [ "$BUILD_DEBUG" = true ]; then
  echo "Creating debug zip..."
  cd "$TARGET_DEBUG_DIR"
  zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-linux-debug.zip" . || {
    echo "Error: Failed to create debug zip"
    exit 1
  }
fi

echo "Build completed successfully!"
if [ "$BUILD_RELEASE" = true ]; then
  echo "Release libraries: $TARGET_RELEASE_DIR"
  echo "Release zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-linux-release.zip"
fi
if [ "$BUILD_DEBUG" = true ]; then
  echo "Debug libraries: $TARGET_DEBUG_DIR"
  echo "Debug zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-linux-debug.zip"
fi
