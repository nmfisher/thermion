#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# update_vendored_headers.sh — Refresh vendored Filament/third-party headers
# in thermion_dart/native/include/filament/ after a filament.version bump.
#
# Usage:
#   scripts/update_vendored_headers.sh <FILAMENT_BASE_DIR>
#       Copy ALL headers (Filament + imageio + stb + libassimp) from a local
#       Filament checkout.  The checkout needs its build output (out/release/
#       or out/debug/) to exist — no full rebuild required; headers are stable
#       once the build has been run once at this version.
#
#   scripts/update_vendored_headers.sh --from-r2
#       Download the prebuilt macOS zips from Cloudflare R2 and extract ALL
#       headers (Filament API + imageio + stb + libassimp).  The R2 artifacts
#       now include the full header tree, so this is equivalent to the local
#       checkout path except it doesn't require a Filament checkout.
#
# Workflow for a version bump:
#   1.  Edit filament.version  (repo root)
#   2.  scripts/update_vendored_headers.sh /path/to/filament-v1.xx.x
#       (or scripts/update_vendored_headers.sh --from-r2)
#   3.  git add -A thermion_dart/native/include/
#   4.  git commit -m "build: refresh vendored headers for Filament vX.Y.Z"
# ---------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_INCLUDE_DIR="$REPO_DIR/thermion_dart/native/include/filament"

# Prevent macOS ._* resource fork files in copies
export COPYFILE_DISABLE=1

# ---------------------------------------------------------------------------
# Read current Filament version from filament.version
# ---------------------------------------------------------------------------
FILAMENT_VERSION_FILE="$REPO_DIR/filament.version"
FILAMENT_VERSION=""
if [ -f "$FILAMENT_VERSION_FILE" ]; then
  FILAMENT_VERSION="$(tail -c +1 "$FILAMENT_VERSION_FILE" | awk '{print $2}')"
fi
if [ -z "$FILAMENT_VERSION" ]; then
  echo "Warning: could not parse Filament version from $FILAMENT_VERSION_FILE"
  echo "  (proceeding without version info)"
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
FROM_R2=false
FILAMENT_BASE_DIR=""

if [ $# -eq 1 ]; then
  if [ "$1" = "--from-r2" ]; then
    FROM_R2=true
  else
    FILAMENT_BASE_DIR="$1"
  fi
elif [ $# -eq 0 ]; then
  echo "Usage: $(basename "$0") <FILAMENT_BASE_DIR>"
  echo "       $(basename "$0") --from-r2"
  echo ""
  echo "  <FILAMENT_BASE_DIR>  Path to a Filament checkout whose build output"
  echo "                       and source tree are both present (fast copy,"
  echo "                       no rebuild needed)."
  echo "  --from-r2            Download prebuilt macOS zips from R2.  Includes"
  echo "                       all headers (Filament API + imageio + stb +"
  echo "                       libassimp) since the build scripts now include"
  echo "                       third-party headers in the R2 artifacts."
  echo ""
  echo "Filament version: ${FILAMENT_VERSION:-<unknown>}"
  exit 1
else
  echo "Error: unexpected arguments: $*"
  exit 1
fi

echo "=== Updating vendored headers ==="
echo "  Version:  ${FILAMENT_VERSION:-<unknown>}"
if $FROM_R2; then
  echo "  Source:   R2 (filament-${FILAMENT_VERSION}-macos-{release,debug}.zip)"
else
  echo "  Source:   $FILAMENT_BASE_DIR"
fi
echo "  Target:   $OUTPUT_INCLUDE_DIR"
echo ""

# ---------------------------------------------------------------------------
# Clean target
# ---------------------------------------------------------------------------
rm -rf "$OUTPUT_INCLUDE_DIR"
mkdir -p "$OUTPUT_INCLUDE_DIR"

# ---------------------------------------------------------------------------
# FROM R2  — download and extract
# ---------------------------------------------------------------------------
copy_from_r2() {
  local R2_BASE="https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev"
  local TMPDIR
  TMPDIR="$(mktemp -d)"
  local EXTRACT_DIR="$TMPDIR/extract"
  mkdir -p "$EXTRACT_DIR"

  echo "--- Downloading release zip ---"
  local REL_ZIP="$TMPDIR/filament-${FILAMENT_VERSION}-macos-release.zip"
  curl -fsSL -o "$REL_ZIP" \
    "$R2_BASE/filament-${FILAMENT_VERSION}-macos-release.zip" || {
    echo "Error: Failed to download release zip (filament-${FILAMENT_VERSION}-macos-release.zip)"
    echo "  The 'Build Filament' CI workflow may not have finished for this version yet."
    rm -rf "$TMPDIR"
    exit 1
  }

  echo "--- Extracting release headers ---"
  unzip -q -o "$REL_ZIP" -d "$EXTRACT_DIR" "include/*"
  cp -R "$EXTRACT_DIR/include/"* "$OUTPUT_INCLUDE_DIR/"

  echo "--- Downloading debug zip ---"
  local DBG_ZIP="$TMPDIR/filament-${FILAMENT_VERSION}-macos-debug.zip"
  curl -fsSL -o "$DBG_ZIP" \
    "$R2_BASE/filament-${FILAMENT_VERSION}-macos-debug.zip" || {
    echo "  (debug zip not found — skipping debug uberarchive.h)"
  }
  if [ -f "$DBG_ZIP" ]; then
    local DBG_EXTRACT="$TMPDIR/debug_extract"
    mkdir -p "$DBG_EXTRACT"
    unzip -q -o "$DBG_ZIP" -d "$DBG_EXTRACT" "include/*"
    # Copy debug uberarchive to the debug/ subdirectory
    if [ -f "$DBG_EXTRACT/include/gltfio/materials/uberarchive.h" ]; then
      mkdir -p "$OUTPUT_INCLUDE_DIR/debug/gltfio/materials"
      cp "$DBG_EXTRACT/include/gltfio/materials/uberarchive.h" \
         "$OUTPUT_INCLUDE_DIR/debug/gltfio/materials/"
    fi
    # Release uberarchive should already be in the main tree (it's in the release zip)
    # Move it to the release/ subdirectory
    if [ -f "$OUTPUT_INCLUDE_DIR/gltfio/materials/uberarchive.h" ]; then
      mkdir -p "$OUTPUT_INCLUDE_DIR/release/gltfio/materials"
      mv "$OUTPUT_INCLUDE_DIR/gltfio/materials/uberarchive.h" \
         "$OUTPUT_INCLUDE_DIR/release/gltfio/materials/"
    fi
    rm -rf "$DBG_EXTRACT"
  fi

  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# FROM LOCAL CHECKOUT  — copy from Filament source tree + build output
# ---------------------------------------------------------------------------
copy_from_local() {
  if [ ! -d "$FILAMENT_BASE_DIR" ]; then
    echo "Error: Filament base directory does not exist: $FILAMENT_BASE_DIR"
    exit 1
  fi
  cd "$FILAMENT_BASE_DIR"

  # Determine header source directory (prefer release, fall back to debug)
  local HEADER_SOURCE=""
  if [ -d "out/release/filament/include" ]; then
    HEADER_SOURCE="out/release/filament/include"
  elif [ -d "out/debug/filament/include" ]; then
    HEADER_SOURCE="out/debug/filament/include"
  fi

  if [ -z "$HEADER_SOURCE" ]; then
    echo "Error: No build output found at $FILAMENT_BASE_DIR/out/{release,debug}/filament/include"
    echo "  The Filament checkout needs at least one build output to copy headers from."
    echo "  (Full rebuild not required — a previous build at this version is enough.)"
    exit 1
  fi

  echo "--- Copying Filament API headers (from $HEADER_SOURCE) ---"
  cp -R "$HEADER_SOURCE/"* "$OUTPUT_INCLUDE_DIR/"

  echo "--- Copying imageio headers ---"
  if [ -d "libs/imageio/include" ]; then
    cp -R libs/imageio/include/* "$OUTPUT_INCLUDE_DIR/"
  else
    echo "  Warning: libs/imageio/include not found — skipping"
  fi

  echo "--- Copying bluevk headers (includes bluevk, vulkan, vk_video) ---"
  if [ -d "libs/bluevk/include" ]; then
    cp -R libs/bluevk/include/* "$OUTPUT_INCLUDE_DIR/"
  else
    echo "  Warning: libs/bluevk/include not found — skipping"
  fi

  echo "--- Copying source-tree utils compiler.h (install tree strips UTILS_SHARED_LINKING) ---"
  if [ -f "libs/utils/include/utils/compiler.h" ]; then
    cp libs/utils/include/utils/compiler.h "$OUTPUT_INCLUDE_DIR/utils/compiler.h"
  else
    echo "  Warning: libs/utils/include/utils/compiler.h not found — skipping"
  fi

  echo "--- Copying uberarchive.h (release and debug) ---"
  if [ -d "out/release/filament/include/gltfio/materials" ]; then
    mkdir -p "$OUTPUT_INCLUDE_DIR/release/gltfio/materials"
    cp out/release/filament/include/gltfio/materials/uberarchive.h \
       "$OUTPUT_INCLUDE_DIR/release/gltfio/materials/"
  fi
  if [ -d "out/debug/filament/include/gltfio/materials" ]; then
    mkdir -p "$OUTPUT_INCLUDE_DIR/debug/gltfio/materials"
    cp out/debug/filament/include/gltfio/materials/uberarchive.h \
       "$OUTPUT_INCLUDE_DIR/debug/gltfio/materials/"
  fi

  echo "--- Copying stb_image.h ---"
  if [ -f "third_party/stb/stb_image.h" ]; then
    mkdir -p "$OUTPUT_INCLUDE_DIR/third_party/stb"
    cp third_party/stb/stb_image.h "$OUTPUT_INCLUDE_DIR/third_party/stb/"
  else
    echo "  Warning: third_party/stb/stb_image.h not found — skipping"
  fi

  echo "--- Copying libassimp headers ---"
  if [ -d "third_party/libassimp/include/assimp" ]; then
    mkdir -p "$OUTPUT_INCLUDE_DIR/third_party/libassimp/include"
    cp -R third_party/libassimp/include/assimp \
          "$OUTPUT_INCLUDE_DIR/third_party/libassimp/include/"
  else
    echo "  Warning: third_party/libassimp/include/assimp not found — skipping"
  fi
}

# ---------------------------------------------------------------------------
# Run the chosen mode
# ---------------------------------------------------------------------------
if $FROM_R2; then
  copy_from_r2
else
  copy_from_local
fi

echo ""
echo "=== Vendored headers updated ==="
echo "  Target: $OUTPUT_INCLUDE_DIR"
echo ""
echo "  Check what changed:"
echo "    cd $REPO_DIR && git diff --stat -- thermion_dart/native/include/"
echo ""
echo "  If satisfied, commit:"
echo "    git add -A thermion_dart/native/include/"
if [ -n "$FILAMENT_VERSION" ]; then
  echo "    git commit -m \"build: refresh vendored headers for Filament $FILAMENT_VERSION\""
fi
