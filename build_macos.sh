#!/bin/bash

# Save script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate arguments
if [ $# -ne 3 ]; then
  echo "Usage: $0 <FILAMENT_BASE_DIR> <FILAMENT_VERSION> <OUTPUT_BASE_DIR>"
  echo "Example: $0 /path/to/filament v1.69.0 /path/to/output"
  exit 1
fi

FILAMENT_BASE_DIR=$1
FILAMENT_VERSION=$2
OUTPUT_BASE_DIR=$3

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

# Check if target directories already exist (fail if exists)
TARGET_RELEASE_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/macos/release"
TARGET_DEBUG_DIR="$OUTPUT_BASE_DIR/$FILAMENT_VERSION/macos/debug"

if [ -d "$TARGET_RELEASE_DIR" ] || [ -d "$TARGET_DEBUG_DIR" ]; then
  echo "Error: Target directory already exists."
  echo "Please remove it first if you want to rebuild."
  exit 1
fi

# Change to Filament directory and checkout tag
cd "$FILAMENT_BASE_DIR" || exit 1
echo "Checking out tag: $FILAMENT_VERSION"
git checkout "${FILAMENT_VERSION}" || {
  echo "Error: Failed to checkout tag: $FILAMENT_VERSION"
  exit 1
}

# Run release build
echo "Building Filament for macOS (release)..."
./build.sh -l -i -f -p desktop release || {
  echo "Error: Filament release build failed"
  exit 1
}

# Run debug build (with framegraph viewer/material debug server)
echo "Building Filament for macOS (debug)..."
./build.sh -l -i -f -t -d -p desktop debug || {
  echo "Error: Filament debug build failed"
  exit 1
}

# Create target directories and copy libs
echo "Copying libraries..."

mkdir -p "$TARGET_RELEASE_DIR" || {
  echo "Error: Failed to create target directory: $TARGET_RELEASE_DIR"
  exit 1
}
mkdir -p "$TARGET_DEBUG_DIR" || {
  echo "Error: Failed to create target directory: $TARGET_DEBUG_DIR"
  exit 1
}

# Copy release libraries
echo "Copying release libraries..."
cp out/release/filament/lib/universal/*.a "$TARGET_RELEASE_DIR/" || {
  echo "Error: Failed to copy release libraries"
  exit 1
}

# Copy debug libraries
echo "Copying debug libraries..."
cp out/debug/filament/lib/universal/*.a "$TARGET_DEBUG_DIR/" || {
  echo "Error: Failed to copy debug libraries"
  exit 1
}

# Create zip files
echo "Creating release zip..."
cd "$TARGET_RELEASE_DIR"
zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-macos-release.zip" . || {
  echo "Error: Failed to create release zip"
  exit 1
}

echo "Creating debug zip..."
cd "$TARGET_DEBUG_DIR"
zip -r "${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-macos-debug.zip" . || {
  echo "Error: Failed to create debug zip"
  exit 1
}

echo "Build completed successfully!"
echo "Release libraries: $TARGET_RELEASE_DIR"
echo "Debug libraries: $TARGET_DEBUG_DIR"
echo "Release zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-macos-release.zip"
echo "Debug zip: ${OUTPUT_BASE_DIR}/filament-${FILAMENT_VERSION}-macos-debug.zip"
