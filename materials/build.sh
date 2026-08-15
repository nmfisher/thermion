#!/bin/bash
set -euo pipefail

# Builds materials for all platforms, producing four variants per material:
#
#   Variant         | matc flags                  | Use case
#   ----------------|-----------------------------|----------------------------------
#   _native         | -a opengl -a metal -a vulkan| iOS/macOS (Metal), Android (Vulkan/GL)
#   _webgpu         | -a webgpu                   | Native Dawn or web WebGPU-only
#   _web_webgl      | -a opengl                   | Web WebGL2-only (smallest web variant)
#   _web_combined   | -a opengl -a webgpu         | Web dual-backend (runtime selection)
#
# All variants use the same resgen prefix so the C symbols are identical
# (IMAGE_PACKAGE, IMAGE_IMAGE_DATA, etc.). Only one .c is compiled by the
# build hook (native) or CMakeLists (web), selected by the backend user define.
# A forwarding header (e.g., image.h) dispatches to the correct variant via
# #ifdef on THERMION_MATERIAL_* defines.
#
# Requires: FILAMENT_PATH pointing to a Filament out/release (or similar)
#           directory with matc and resgen binaries. matc must be built with
#           FILAMENT_SUPPORTS_WEBGPU=ON for the _webgpu and _web_combined variants.

if [ -z "${FILAMENT_PATH:-}" ]; then
    echo "ERROR: FILAMENT_PATH is not set"
    exit 1
fi

MATC="${FILAMENT_PATH}/matc"
RESGEN="${FILAMENT_PATH}/resgen"
MATERIAL_DIR="thermion_dart/native/include/material"
MATERIALS=(image unlit_fixed_size grid linear_depth silhouette edge_outline wireframe translation_axis bone_overlay capture_uv)
# capture_uv is now in the main list; gizmo handled separately below
GIZMO_NAME="gizmo"
EXAMPLE_MATERIALS=(customattributes solidcolor viewspace)

# -------------------------------------------------------------------
# build_variant <material> <variant_suffix> <matc_arch_flags...>
#
# Compiles <material>.mat with the given arch flags, runs resgen,
# renames to <material>_<variant_suffix>.c/.h, and fixes includes,
# guards, and cplusplus extern blocks.
# -------------------------------------------------------------------
build_variant() {
    local material="$1"
    local suffix="$2"
    shift 2
    # remaining args are the matc -a flags
    local arch_flags=("$@")

    local upper
    upper=$(echo "${material}" | tr '[:lower:]' '[:upper:]')
    local guard_name="${upper}_${suffix^^}_H_"

    echo "  ${suffix}: matc ${arch_flags[*]}"

    ${MATC} "${arch_flags[@]}" \
        -o "materials/${material}.filamat" "materials/${material}.mat" || return 1
    ${RESGEN} -c -p "${material}" -x "${MATERIAL_DIR}/" "materials/${material}.filamat" || return 1

    # Rename to suffixed files
    mv "${MATERIAL_DIR}/${material}.c" "${MATERIAL_DIR}/${material}_${suffix}.c"
    mv "${MATERIAL_DIR}/${material}.h" "${MATERIAL_DIR}/${material}_${suffix}.h"

    # Fix #include in .c to point to suffixed .h
    sed -i "s/#include \"${material}\\.h\"/#include \"${material}_${suffix}.h\"/" \
        "${MATERIAL_DIR}/${material}_${suffix}.c"

    # Fix header guard
    sed -i "s/${upper}_H_/${guard_name}/" "${MATERIAL_DIR}/${material}_${suffix}.h"

    # Prepend #include at top of .c
    echo "#include \"${material}_${suffix}.h\"" | cat - "${MATERIAL_DIR}/${material}_${suffix}.c" > \
        "${MATERIAL_DIR}/${material}_${suffix}.c.tmp" && \
        mv "${MATERIAL_DIR}/${material}_${suffix}.c.tmp" \
           "${MATERIAL_DIR}/${material}_${suffix}.c"

    # Add cplusplus extern guards in .h
    perl -i -pe 's/extern "C" \{/#ifdef __cplusplus\nextern "C" {\n#endif/' \
        "${MATERIAL_DIR}/${material}_${suffix}.h"
    perl -i -0pe 's/\n\}\n/\n#ifdef __cplusplus\n}\n#endif\n/' \
        "${MATERIAL_DIR}/${material}_${suffix}.h"

    # Clean up intermediate .filamat
    rm -f "materials/${material}.filamat"
}

# -------------------------------------------------------------------
# create_forwarding_header <material> <upper_name>
#
# Creates a forwarding header that dispatches to the correct variant
# based on THERMION_MATERIAL_* defines.
# -------------------------------------------------------------------
create_forwarding_header() {
    local material="$1"
    local upper="$2"

    cat > "${MATERIAL_DIR}/${material}.h" << EOF
#ifndef ${upper}_H_
#define ${upper}_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "${material}_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "${material}_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "${material}_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "${material}_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
EOF
}

# -------------------------------------------------------------------
# Build all variants for the main materials list
# -------------------------------------------------------------------
for material in "${MATERIALS[@]}"; do
    upper=$(echo "${material}" | tr '[:lower:]' '[:upper:]')
    echo "=== $material ==="

    build_variant "$material" native   -a opengl -a metal -a vulkan
    build_variant "$material" webgpu   -a webgpu
    build_variant "$material" web_webgl -a opengl
    build_variant "$material" web_combined -a opengl -a webgpu

    create_forwarding_header "$material" "$upper"

    echo ""
done

# -------------------------------------------------------------------
# Gizmo special case: rename files to gizmo_material_* to avoid a
# case-insensitive .obj collision with scene/Gizmo.cpp on Windows.
# Symbol names (GIZMO_PACKAGE, GIZMO_GIZMO_DATA, etc.) are unchanged
# since the resgen prefix stays "gizmo".
# -------------------------------------------------------------------
echo "=== gizmo rename special case ==="

# Build gizmo as a regular material first
for suffix in native webgpu web_webgl web_combined; do
    case "$suffix" in
        native)       matc_flags="-a opengl -a metal -a vulkan" ;;
        webgpu)       matc_flags="-a webgpu" ;;
        web_webgl)    matc_flags="-a opengl" ;;
        web_combined) matc_flags="-a opengl -a webgpu" ;;
    esac

    echo "  ${suffix}: matc ${matc_flags}"

    ${MATC} ${matc_flags} \
        -o "materials/gizmo.filamat" "materials/gizmo.mat" || exit 1
    ${RESGEN} -c -p "gizmo" -x "${MATERIAL_DIR}/" "materials/gizmo.filamat" || exit 1

    # Rename .c/.h to gizmo_material_<suffix>
    mv "${MATERIAL_DIR}/gizmo.c" "${MATERIAL_DIR}/gizmo_material_${suffix}.c"
    mv "${MATERIAL_DIR}/gizmo.h" "${MATERIAL_DIR}/gizmo_material_${suffix}.h"

    # Fix #include
    sed -i "s/#include \"gizmo\\.h\"/#include \"gizmo_material_${suffix}.h\"/" \
        "${MATERIAL_DIR}/gizmo_material_${suffix}.c"

    # Fix header guard
    upper_suffix=$(echo "${suffix}" | tr '[:lower:]' '[:upper:]')
    sed -i "s/GIZMO_H_/GIZMO_MATERIAL_${upper_suffix}_H_/" \
        "${MATERIAL_DIR}/gizmo_material_${suffix}.h"

    # Prepend #include
    echo "#include \"gizmo_material_${suffix}.h\"" | \
        cat - "${MATERIAL_DIR}/gizmo_material_${suffix}.c" > \
        "${MATERIAL_DIR}/gizmo_material_${suffix}.c.tmp" && \
        mv "${MATERIAL_DIR}/gizmo_material_${suffix}.c.tmp" \
           "${MATERIAL_DIR}/gizmo_material_${suffix}.c"

    # Cplusplus guards
    perl -i -pe 's/extern "C" \{/#ifdef __cplusplus\nextern "C" {\n#endif/' \
        "${MATERIAL_DIR}/gizmo_material_${suffix}.h"
    perl -i -0pe 's/\n\}\n/\n#ifdef __cplusplus\n}\n#endif\n/' \
        "${MATERIAL_DIR}/gizmo_material_${suffix}.h"

    rm -f "materials/gizmo.filamat"
done

# Gizmo forwarding header
cat > "${MATERIAL_DIR}/gizmo.h" << 'EOF'
#ifndef GIZMO_H_
#define GIZMO_H_

#if defined(THERMION_MATERIAL_NATIVE)
#include "gizmo_material_native.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "gizmo_material_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "gizmo_material_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "gizmo_material_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_NATIVE, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
#endif

#endif
EOF

echo ""

# -------------------------------------------------------------------
# Wireframe is listed in MATERIALS above, so it's already built.
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# Compile example asset materials (standalone .filamat, not embedded)
# -------------------------------------------------------------------
for material in "${EXAMPLE_MATERIALS[@]}"; do
    echo "=== examples/assets/$material (all platforms) ==="
    ${MATC} -a opengl -a metal -a vulkan -a webgpu \
        -o "examples/assets/${material}.filamat" "examples/assets/${material}.mat" || exit 1
done

echo "=== Done ==="
