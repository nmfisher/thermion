#!/usr/bin/env bash
# Regenerate every committed material artifact with the matc/resgen pair
# matching the Filament version pinned in filament.version.
#
# Downloads the WebGPU-capable matc + resgen from the version-matched
# webgpu-suffixed R2 artifact (filament-<tag>-linux-release-webgpu.zip,
# staged by scripts/build_linux.sh --webgpu) into a per-version cache, so
# repeated runs only pay the download once per bump. The official Filament
# release matc is built without FILAMENT_SUPPORTS_WEBGPU and cannot compile
# the _webgpu/_web_combined variants (WGSL); the matc in this artifact
# compiles every variant materials/build.sh emits. Produces exactly what
# `make materials` produces locally:
#   - materials/*.filamat (untracked build outputs)
#   - thermion_dart/native/include/material/* (resgen .c/.h/.S/.apple.S/.bin)
#   - examples/assets/*.filamat
#
# Intended for CI: run it whenever filament.version changes, then commit the
# diff (see .github/workflows/regenerate-materials.yml). matc output for a
# fixed version is deterministic, so an already-up-to-date tree produces no
# diff and no commit.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TAG=$(awk '{print $2}' filament.version)
if [ -z "$TAG" ]; then
    echo "Could not read Filament version from filament.version" >&2
    exit 2
fi

CACHE_ROOT="${FILAMENT_TOOLS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/thermion/filament-tools}"
# Distinct from the old official-tarball cache dir (filament-$TAG) so a
# stale non-WebGPU matc from an existing actions/cache entry is never used.
TOOLS="$CACHE_ROOT/filament-$TAG-webgpu"

R2_PUBLIC_URL="${R2_PUBLIC_URL:-https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev}"
ZIP_NAME="filament-$TAG-linux-release-webgpu.zip"

# Smoke test: compile a minimal material with -a webgpu. matc built without
# FILAMENT_SUPPORTS_WEBGPU fails this, so a bad or wrong-version cache is
# re-downloaded instead of failing on every material later.
SMOKE_DIR=$(mktemp -d)
trap 'rm -rf "$SMOKE_DIR"' EXIT
printf 'material {\n    name : smoke_webgpu,\n    shadingModel : unlit\n}\n' \
    > "$SMOKE_DIR/smoke.mat"

webgpu_matc_ok() {
    [ -x "$TOOLS/bin/matc" ] && [ -x "$TOOLS/bin/resgen" ] &&
        "$TOOLS/bin/matc" -a webgpu -o "$SMOKE_DIR/smoke.filamat" \
            "$SMOKE_DIR/smoke.mat" >/dev/null 2>&1
}

if ! webgpu_matc_ok; then
    echo "Downloading Filament $TAG WebGPU tools (matc, resgen) from R2..."
    echo "  $R2_PUBLIC_URL/$ZIP_NAME"
    rm -rf "$TOOLS"
    mkdir -p "$TOOLS"
    if ! curl -fsSL -o "$CACHE_ROOT/$ZIP_NAME" "$R2_PUBLIC_URL/$ZIP_NAME"; then
        echo "Error: could not download $R2_PUBLIC_URL/$ZIP_NAME" >&2
        echo "Run the Build Filament workflow with platform=linux webgpu=true" >&2
        echo "upload_to_r2=true for $TAG first, so the artifact carries the tools." >&2
        exit 2
    fi
    # The zip is dominated by static libs and headers; we only need bin/.
    unzip -q "$CACHE_ROOT/$ZIP_NAME" 'bin/*' -d "$TOOLS"
    rm -f "$CACHE_ROOT/$ZIP_NAME"
    if ! webgpu_matc_ok; then
        echo "Error: matc from $ZIP_NAME does not support -a webgpu." >&2
        echo "Re-run the Build Filament workflow with webgpu=true for $TAG." >&2
        exit 2
    fi
fi

echo "Using WebGPU-capable matc/resgen from $TOOLS"
chmod +x materials/build.sh
FILAMENT_PATH="$TOOLS/bin" make materials
