#!/bin/bash

# Save script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate arguments
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR> [--clean]"
  echo "Example: $0 /path/to/filament v1.69.0 /path/to/output"
  echo "         $0 /path/to/filament v1.69.0 /path/to/output --clean"
  echo ""
  echo "Options:"
  echo "  --clean    Remove existing target directories before building"
  exit 1
fi

FILAMENT_BASE_DIR=$1
FILAMENT_VERSION=$2
OUTPUT_BASE_DIR=$3
CLEAN_FLAG=$4

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

if [ -d "$TARGET_RELEASE_DIR" ] || [ -d "$TARGET_DEBUG_DIR" ]; then
  if [ "$CLEAN_FLAG" = "--clean" ]; then
    echo "Removing existing target directories..."
    rm -rf "$TARGET_RELEASE_DIR" "$TARGET_DEBUG_DIR"
  else
    echo "Error: Target directory already exists."
    echo "Please remove it first or use --clean to rebuild."
    exit 1
  fi
fi

# Change to Filament directory and checkout tag
cd "$FILAMENT_BASE_DIR" || exit 1
echo "Checking out tag: $FILAMENT_VERSION"
git checkout "${FILAMENT_VERSION}" || {
  echo "Error: Failed to checkout tag: $FILAMENT_VERSION"
  exit 1
}

# Run release build
echo "Building Filament for Android (release)..."
./build.sh -i -f -p android release || {
  echo "Error: Filament release build failed"
  exit 1
}

# Run debug build
echo "Building Filament for Android (debug)..."
./build.sh -i -f -t -d -p android debug || {
  echo "Error: Filament debug build failed"
  exit 1
}

# Create target directories
echo "Creating target directories..."

mkdir -p "$TARGET_RELEASE_DIR" || {
  echo "Error: Failed to create target directory: $TARGET_RELEASE_DIR"
  exit 1
}
mkdir -p "$TARGET_DEBUG_DIR" || {
  echo "Error: Failed to create target directory: $TARGET_DEBUG_DIR"
  exit 1
}

# Android architectures
ARCHS="arm64-v8a armeabi-v7a x86_64 x86"

# Copy release libraries for each architecture
echo "Copying release libraries..."
for ARCH in $ARCHS; do
  mkdir -p "$TARGET_RELEASE_DIR/$ARCH" || {
    echo "Error: Failed to create directory: $TARGET_RELEASE_DIR/$ARCH"
    exit 1
  }
  cp out/android-release/filament/lib/$ARCH/*.a "$TARGET_RELEASE_DIR/$ARCH/" 2>/dev/null || {
    echo "Warning: No release libraries found for $ARCH"
  }
done

# Copy debug libraries for each architecture
echo "Copying debug libraries..."
for ARCH in $ARCHS; do
  mkdir -p "$TARGET_DEBUG_DIR/$ARCH" || {
    echo "Error: Failed to create directory: $TARGET_DEBUG_DIR/$ARCH"
    exit 1
  }
  cp out/android-debug/filament/lib/$ARCH/*.a "$TARGET_DEBUG_DIR/$ARCH/" 2>/dev/null || {
    echo "Warning: No debug libraries found for $ARCH"
  }
done

# Build and copy third-party libraries for release
echo "Building third-party libraries for release..."
./build.sh -i -f -p android release zstd || {
  echo "Warning: zstd release build failed"
}
./build.sh -i -f -p android release tinyexr || {
  echo "Warning: tinyexr release build failed"
}
./build.sh -i -f -p android release imageio || {
  echo "Warning: imageio release build failed"
}

for ARCH in $ARCHS; do
  for LIB in libimageio.a libtinyexr.a; do
    cp out/android-release/filament/lib/$ARCH/$LIB "$TARGET_RELEASE_DIR/$ARCH/" 2>/dev/null || {
      echo "Warning: Failed to copy $LIB for $ARCH (release)"
    }
  done
done

# Build and copy third-party libraries for debug
echo "Building third-party libraries for debug..."
./build.sh -i -f -p android debug zstd || {
  echo "Warning: zstd debug build failed"
}
./build.sh -i -f -p android debug tinyexr || {
  echo "Warning: tinyexr debug build failed"
}
./build.sh -i -f -p android debug imageio || {
  echo "Warning: imageio debug build failed"
}

for ARCH in $ARCHS; do
  for LIB in libimageio.a libtinyexr.a; do
    cp out/android-debug/filament/lib/$ARCH/$LIB "$TARGET_DEBUG_DIR/$ARCH/" 2>/dev/null || {
      echo "Warning: Failed to copy $LIB for $ARCH (debug)"
    }
  done
done

# Create zip files
echo "Creating release zip..."
cd "$TARGET_RELEASE_DIR"
zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-android-release.zip" . || {
  echo "Error: Failed to create release zip"
  exit 1
}

echo "Creating debug zip..."
cd "$TARGET_DEBUG_DIR"
zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-android-debug.zip" . || {
  echo "Error: Failed to create debug zip"
  exit 1
}

echo "Build completed successfully!"
echo "Release libraries: $TARGET_RELEASE_DIR"
echo "Debug libraries: $TARGET_DEBUG_DIR"
echo "Release zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-android-release.zip"
echo "Debug zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-android-debug.zip"
