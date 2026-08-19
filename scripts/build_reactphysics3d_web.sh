#!/bin/bash

# Stages ReactPhysics3D for the thermion web (Emscripten) build.
#
# thermion's web CMakeLists links third-party code into the single
# thermion_dart WASM through the EXTERNAL_PROJECTS hook: nothing in thermion
# references the rp3d C API, so its objects are only pulled in by the
# -Wl,--whole-archive group and its _rp3d_* functions end up on the same Module
# object as the _Thermion_* ones. This script prepares everything that hook
# needs:
#
#   1. a reactphysics3d_dart checkout at a pinned ref (the same ref the
#      examples' pubspecs depend on), providing native/web/
#      reactphysics3d_dart.cmake and the C API wrapper (rp3d_c_api.cpp), and
#   2. libreactphysics3d.a built for Emscripten, dropped next to that cmake
#      file where it expects to find it.
#
# The engine sources are NOT vendored by reactphysics3d_dart -- only its
# headers are (native/include/reactphysics3d/). The engine ref below must
# therefore stay in sync with those headers, or the wrapper and the library
# will disagree about the rp3d ABI.
#
# Everything is cached under thermion_dart/native/web/lib/external/ so repeated
# `make wasm` runs only rebuild when a ref changes. That directory survives
# `make wasm-clean` (which only removes native/web/build) on purpose.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The reactphysics3d_dart commit to build against. Keep this in sync with the
# git dependency in examples/dart/examples_lib/pubspec.yaml -- building a
# different rp3d C API than the one the Dart bindings were generated from
# silently breaks the example at runtime.
RP3D_DART_URL="https://github.com/nmfisher/reactphysics3d_dart.git"
RP3D_DART_REF="52eec72e06b322080d395415bc1dfaffd8c45d2f"

# The ReactPhysics3D engine release to compile. Must match the headers vendored
# at native/include/reactphysics3d/ inside the reactphysics3d_dart checkout
# above (verified: that tree is byte-identical to this tag's include/ tree).
RP3D_ENGINE_URL="https://github.com/DanielChappuis/reactphysics3d.git"
RP3D_ENGINE_REF="v0.10.2"

CACHE_DIR="${RP3D_WEB_CACHE_DIR:-$REPO_ROOT/thermion_dart/native/web/lib/external}"
DART_DIR="$CACHE_DIR/reactphysics3d_dart"
ENGINE_DIR="$CACHE_DIR/reactphysics3d"
ENGINE_LIB="$ENGINE_DIR/build-web/libreactphysics3d.a"
STAMP_FILE="$CACHE_DIR/.stamp"

# Mirror the flags the Filament web libraries are built with
# (scripts/build_web.sh) so the whole archive set is compiled consistently.
ENGINE_CXX_FLAGS="-pthread -matomics -mbulk-memory"

if [ -z "${EMSDK}" ] && [ -z "${EMSCRIPTEN}" ]; then
  echo "Error: EMSDK or EMSCRIPTEN environment variable must be set"
  echo "Example: export EMSDK=/path/to/emsdk"
  exit 1
fi

if [ -n "${EMSDK}" ]; then
  EMSCRIPTEN_CMAKE="$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake"
else
  EMSCRIPTEN_CMAKE="$EMSCRIPTEN/cmake/Modules/Platform/Emscripten.cmake"
fi

if [ ! -f "$EMSCRIPTEN_CMAKE" ]; then
  echo "Error: Emscripten cmake toolchain file not found: $EMSCRIPTEN_CMAKE"
  exit 1
fi

mkdir -p "$CACHE_DIR"

# Checkout at a pinned commit, shallow. Re-uses an existing clone by fetching
# the ref into it, so a ref bump does not require wiping the cache.
checkout_pinned() {
  local url="$1"
  local ref="$2"
  local dir="$3"

  if [ ! -d "$dir/.git" ]; then
    echo "Cloning $url into $dir ..."
    git init -q "$dir"
    git -C "$dir" remote add origin "$url"
  fi

  # Tags can be fetched directly; a commit SHA needs it spelled out explicitly.
  git -C "$dir" fetch -q --depth 1 origin "$ref" ||
    git -C "$dir" fetch -q --depth 1 origin "refs/tags/$ref"
  git -C "$dir" checkout -q --detach FETCH_HEAD
}

CURRENT_STAMP="dart=$RP3D_DART_REF engine=$RP3D_ENGINE_REF"
if [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE")" = "$CURRENT_STAMP" ] && [ -f "$ENGINE_LIB" ]; then
  echo "ReactPhysics3D web build up to date at $CACHE_DIR"
else
  echo "Building ReactPhysics3D for Emscripten ($CURRENT_STAMP)..."
  checkout_pinned "$RP3D_ENGINE_URL" "$RP3D_ENGINE_REF" "$ENGINE_DIR"

  # Disable the testbed/tests: they pull in OpenGL/GLFW and would fail to
  # configure for Emscripten. Only the static library is wanted.
  emcmake cmake -S "$ENGINE_DIR" -B "$ENGINE_DIR/build-web" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="$ENGINE_CXX_FLAGS" \
    -DRP3D_COMPILE_TESTS=OFF \
    -DRP3D_COMPILE_TESTBED=OFF

  emmake make -C "$ENGINE_DIR/build-web" -j"$(nproc)"

  if [ ! -f "$ENGINE_LIB" ]; then
    echo "Error: expected library was not produced: $ENGINE_LIB"
    exit 1
  fi

  checkout_pinned "$RP3D_DART_URL" "$RP3D_DART_REF" "$DART_DIR"

  # reactphysics3d_dart.cmake imports this as a prebuilt IMPORTED library
  # located next to itself.
  cp "$ENGINE_LIB" "$DART_DIR/native/web/libreactphysics3d.a"

  echo "$CURRENT_STAMP" > "$STAMP_FILE"
fi

RP3D_CMAKE="$DART_DIR/native/web/reactphysics3d_dart.cmake"
if [ ! -f "$RP3D_CMAKE" ]; then
  echo "Error: $RP3D_CMAKE not found"
  exit 1
fi

echo "ReactPhysics3D staged: $RP3D_CMAKE"
