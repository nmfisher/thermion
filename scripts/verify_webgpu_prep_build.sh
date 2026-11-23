#!/bin/bash
# Local verification for the raytracer-webgpu prep branch:
#  1. default (WebGL) web engine build in native/web/build
#  2. WebGPU web engine build in native/web/build-webgpu
#     (needs the legacy -webgpu Filament archive; downloaded on first use)
# Mirrors the CI build-webgpu-engine job (.github/workflows/build-filament.yml).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
WEB=thermion_dart/native/web

source /tmp/emsdk-src/emsdk/emsdk_env.sh >/dev/null 2>&1

STEP=${1:-all}

build_webgl() {
  emcmake cmake -S "$WEB" -B "$WEB/build" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$WEB/build" --parallel "$(nproc)"
}

build_webgpu() {
  local zip="$WEB/lib/release/filament-v1.77.2-web-release-webgpu.zip"
  if [ ! -f "$zip" ]; then
    # The web WebGPU libs are not on R2 yet (no web-webgpu pin entry, legacy
    # key 404). Use the CI artifact from the build-filament.yml run that
    # produced the pinned engine (verified sha256
    # fa091b352f0183837003fde7463ef7ea985f43e9a9c6e263291b31cf3631e993):
    #   gh run download 45107983622 -R nmfisher/thermion \
    #     -n filament-web-release-webgpu -D "$(dirname "$zip")"
    echo "ERROR: $zip missing; download the CI artifact (see comment in $0)" >&2
    exit 1
  fi
  # Same layout as CI: unzip the WebGPU archive over lib/release.
  unzip -qo "$zip" -d "$WEB/lib/release"
  emcmake cmake -S "$WEB" -B "$WEB/build-webgpu" -DCMAKE_BUILD_TYPE=Release \
    -DTHERMION_ENABLE_WEBGPU=ON
  cmake --build "$WEB/build-webgpu" --parallel "$(nproc)"
}

case "$STEP" in
  webgl) build_webgl ;;
  webgpu) build_webgpu ;;
  all) build_webgl; build_webgpu ;;
  *) echo "usage: $0 [webgl|webgpu|all]"; exit 1 ;;
esac
echo "BUILD OK: $STEP"
