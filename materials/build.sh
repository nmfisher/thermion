#!/bin/bash
set -euo pipefail

# Compiles standalone example asset materials (examples/assets/*.mat -> .filamat).
#
# Built-in helper materials live under thermion_dart/hook/materials/*.mat and are
# compiled on demand by thermion_dart/hook/build.dart (cached under
# thermion_dart/.dart_tool/thermion_dart/materials/) using version-matched
# matc/resgen binaries from R2.
#
# Requires: FILAMENT_PATH pointing to a Filament out/release (or similar)
#           directory with matc built with FILAMENT_SUPPORTS_WEBGPU=ON.

if [ -z "${FILAMENT_PATH:-}" ]; then
    echo "ERROR: FILAMENT_PATH is not set"
    exit 1
fi

MATC="${FILAMENT_PATH}/matc"

for mat_file in examples/assets/*.mat; do
    material="$(basename "${mat_file}" .mat)"
    echo "=== examples/assets/$material (all platforms) ==="
    "${MATC}" -a opengl -a metal -a vulkan -a webgpu \
        -o "examples/assets/${material}.filamat" "${mat_file}" || exit 1
done

echo "=== Done ==="
