#!/bin/bash

# Stages ReactPhysics3D for the thermion web (Emscripten) build.
#
# thermion's web CMakeLists links third-party code into the single
# thermion_dart WASM through the EXTERNAL_PROJECTS hook: nothing in thermion
# references the rp3d C API, so its objects are only pulled in by the
# -Wl,--whole-archive group and its _rp3d_* functions end up on the same Module
# object as the _Thermion_* ones.
#
# ReactPhysics3D itself is NOT built here. reactphysics3d_dart publishes
# prebuilt libraries from its own "Build artifacts" workflow (see BUILDING.md,
# "Release artifacts", in that repository); this script downloads the
# web-emscripten zip and stages what the hook needs:
#
#   1. a reactphysics3d_dart checkout at the pinned tag, providing
#      native/web/reactphysics3d_dart.cmake (the file EXTERNAL_PROJECTS points
#      at), the C API wrapper it compiles (native/src/rp3d_c_api.cpp) and the
#      headers under native/include/, and
#   2. libreactphysics3d.a (engine, wasm32) from the release zip, dropped next
#      to that cmake file, which imports it as a prebuilt library.
#
# The zip also ships libreactphysics3d_dart.a -- the same wrapper prebuilt --
# which is not extracted: the cmake hook compiles the wrapper from source so
# the C API always matches the vendored headers of the checked-out tag.
#
# Everything is cached under thermion_dart/native/web/lib/external/, which
# survives `make wasm-clean` (it only removes native/web/build) and is
# gitignored/pubignored like the Filament web libraries.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The reactphysics3d_dart release to build against. Both the downloaded zip
# and the staged checkout come from this tag, so the C API the Dart bindings
# call and the engine library that implements it cannot drift apart.
#
# reactphysics3d_dart publishes on `v*` tag pushes only (its build-artifacts
# workflow stops short of publishing on pull requests); cutting a release is
# `git tag v<x.y.z> && git push origin v<x.y.z>` in that repository.
RP3D_DART_REPO="${RP3D_DART_REPO:-https://github.com/nmfisher/reactphysics3d_dart.git}"
RP3D_DART_TAG="${RP3D_DART_TAG:-v0.1.0}"
RP3D_DART_VERSION="${RP3D_DART_VERSION:-${RP3D_DART_TAG#v}}"
RP3D_DART_ZIP_URL="${RP3D_DART_ZIP_URL:-${RP3D_DART_REPO%.git}/releases/download/${RP3D_DART_TAG}/reactphysics3d_dart-${RP3D_DART_VERSION}-web-emscripten.zip}"

CACHE_DIR="${RP3D_WEB_CACHE_DIR:-$REPO_ROOT/thermion_dart/native/web/lib/external}"
DART_DIR="$CACHE_DIR/reactphysics3d_dart"
STAMP_FILE="$CACHE_DIR/.stamp"
ENGINE_LIB="$DART_DIR/native/web/libreactphysics3d.a"

CURRENT_STAMP="tag=$RP3D_DART_TAG url=$RP3D_DART_ZIP_URL"

if [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE")" = "$CURRENT_STAMP" ] && [ -s "$ENGINE_LIB" ]; then
  echo "ReactPhysics3D $RP3D_DART_TAG already staged at $CACHE_DIR"
else
  mkdir -p "$CACHE_DIR"

  if [ ! -d "$DART_DIR/.git" ]; then
    echo "Cloning $RP3D_DART_REPO into $DART_DIR ..."
    git init -q "$DART_DIR"
    git -C "$DART_DIR" remote add origin "$RP3D_DART_REPO"
  fi

  echo "Checking out reactphysics3d_dart $RP3D_DART_TAG ..."
  if ! git -C "$DART_DIR" fetch -q --depth 1 origin "refs/tags/$RP3D_DART_TAG"; then
    echo ""
    echo "Error: tag $RP3D_DART_TAG not found in $RP3D_DART_REPO."
    echo "reactphysics3d_dart publishes its libraries from 'v*' tag pushes"
    echo "only (its build-artifacts workflow stops short of publishing on"
    echo "pull requests). Cut the release there first:"
    echo "  git tag $RP3D_DART_TAG && git push origin $RP3D_DART_TAG"
    exit 1
  fi
  git -C "$DART_DIR" checkout -q --detach FETCH_HEAD

  ZIP_FILE="$CACHE_DIR/reactphysics3d_dart-$RP3D_DART_VERSION-web-emscripten.zip"
  echo "Downloading $RP3D_DART_ZIP_URL ..."
  if ! curl -fSL --retry 3 -o "$ZIP_FILE" "$RP3D_DART_ZIP_URL"; then
    echo ""
    echo "Error: could not download $RP3D_DART_ZIP_URL."
    echo "The release asset is created by the same 'v*' tag push that"
    echo "provides the checkout above -- see BUILDING.md, \"Release"
    echo "artifacts\", in the reactphysics3d_dart repository."
    exit 1
  fi

  # The zip is flat: libreactphysics3d.a, libreactphysics3d_dart.a, README.txt.
  # Extract only the engine library -- see the note at the top of this script.
  unzip -oq "$ZIP_FILE" libreactphysics3d.a -d "$DART_DIR/native/web/"

  if [ ! -s "$ENGINE_LIB" ]; then
    echo "Error: $ENGINE_LIB was not extracted from $ZIP_FILE"
    exit 1
  fi

  echo "$CURRENT_STAMP" > "$STAMP_FILE"
fi

RP3D_CMAKE="$DART_DIR/native/web/reactphysics3d_dart.cmake"
if [ ! -f "$RP3D_CMAKE" ]; then
  echo "Error: $RP3D_CMAKE not found"
  exit 1
fi

echo "ReactPhysics3D staged: $RP3D_CMAKE"
