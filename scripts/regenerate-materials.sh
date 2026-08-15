#!/usr/bin/env bash
# Regenerate every committed material artifact with the matc/resgen pair
# matching the Filament version pinned in filament.version.
#
# Downloads the versioned Filament release tarball (bin/matc + bin/resgen)
# into a per-version cache, so repeated runs only pay the download once per
# bump. Produces exactly what `make materials` produces locally:
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
TOOLS="$CACHE_ROOT/filament-$TAG"

if [ ! -x "$TOOLS/bin/matc" ] || [ ! -x "$TOOLS/bin/resgen" ]; then
    echo "Downloading Filament $TAG tools (matc, resgen)..."
    mkdir -p "$TOOLS"
    curl -fsSL -o "$CACHE_ROOT/filament-$TAG-linux.tgz" \
        "https://github.com/google/filament/releases/download/$TAG/filament-$TAG-linux.tgz"
    tar xzf "$CACHE_ROOT/filament-$TAG-linux.tgz" -C "$TOOLS" --strip-components=1
    rm -f "$CACHE_ROOT/filament-$TAG-linux.tgz"
fi

echo "Using matc/resgen from $TOOLS"
chmod +x materials/build.sh
FILAMENT_PATH="$TOOLS/bin" make materials
