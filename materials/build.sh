#!/bin/bash
set -euo pipefail

# Builds materials for all platforms, producing eight variants per material:
#
#   Variant         | matc flags                  | Use case
#   ----------------|-----------------------------|----------------------------------
#   _apple          | -a metal                    | iOS/macOS (Metal only)
#   _android        | -a vulkan -a opengl         | Android (Vulkan/GL, runtime selection)
#   _desktop        | -a vulkan -a opengl         | Linux/Windows (Vulkan/GL, runtime selection)
#   _opengl         | -a opengl                   | Android/Linux/Windows, GL-only (opt-in via materials.backends)
#   _vulkan         | -a vulkan                   | Android/Linux/Windows, Vulkan-only (opt-in via materials.backends)
#   _webgpu         | -a webgpu                   | Native Dawn or web WebGPU-only
#   _web_webgl      | -a opengl                   | Web WebGL2-only (smallest web variant)
#   _web_combined   | -a opengl -a webgpu         | Web dual-backend (runtime selection)
#
# The former _native variant (-a opengl -a metal -a vulkan) bundled every
# backend into one blob, so each platform carried shaders it never uses
# (~5.5MB total across materials). The per-platform split removes that;
# _opengl/_vulkan let apps shed even more by committing to a single backend
# (no runtime fallback if the device doesn't support it).
#
# All variants use the same resgen prefix so the C symbols are identical
# (IMAGE_PACKAGE, IMAGE_IMAGE_DATA, etc.). Only one .c is compiled by the
# build hook (native) or CMakeLists (web), selected by the backend user define
# and the target OS. A forwarding header (e.g., image.h) dispatches to the
# correct variant via #ifdef on THERMION_MATERIAL_* defines.
#
# Requires: FILAMENT_PATH pointing to a Filament out/release (or similar)
#           directory with matc and resgen binaries. matc must be built with
#           FILAMENT_SUPPORTS_WEBGPU=ON for the _webgpu and _web_combined variants.

if [ -z "${FILAMENT_PATH:-}" ]; then
    echo "ERROR: FILAMENT_PATH is not set"
    exit 1
fi

# FILAMENT_PATH must contain matc and resgen. Release/bin-style layouts
# have them as files; Ninja out/<config>/tools layouts have them as
# directories containing the binary (tools/matc/matc). Resolve both, and
# keep everything quoted - paths with spaces otherwise word-split.
MATC="${FILAMENT_PATH}/matc"
if [ -d "${MATC}" ]; then
    MATC="${MATC}/matc"
fi
RESGEN="${FILAMENT_PATH}/resgen"
if [ -d "${RESGEN}" ]; then
    RESGEN="${RESGEN}/resgen"
fi
MATERIAL_DIR="thermion_dart/native/include/material"
MATERIALS=(image unlit_fixed_size grid linear_depth silhouette edge_outline wireframe translation_axis bone_overlay capture_uv)
# capture_uv is now in the main list; gizmo handled separately below
GIZMO_NAME="gizmo"
EXAMPLE_MATERIALS=(customattributes solidcolor viewspace proceduralquad hit_flash hologram force_field dissolve_burn water smoke fire lava shockwave_ground shockwave_dome shore_waves sand)

# Probe WebGPU support once: a matc built without FILAMENT_SUPPORTS_WEBGPU=ON
# cannot emit WGSL, so the _webgpu/_web_combined variants (and the webgpu
# backend in example .filamats) must be skipped rather than fail the build.
# Existing committed webgpu blobs are left untouched in that case.
WEBGPU_SUPPORTED=1
if ! printf 'material { name : Probe, shadingModel : unlit, blending : opaque }\nfragment { void material(inout MaterialInputs m) { prepareMaterial(m); m.baseColor = vec4(1.0); } }\n' \
        > "${TMPDIR:-/tmp}/thermion_webgpu_probe.mat" \
   || ! "${MATC}" -a webgpu -o "${TMPDIR:-/tmp}/thermion_webgpu_probe.filamat" \
        "${TMPDIR:-/tmp}/thermion_webgpu_probe.mat" > /dev/null 2>&1; then
    WEBGPU_SUPPORTED=0
    echo "WARNING: matc lacks WebGPU support (build Filament with"
    echo "FILAMENT_SUPPORTS_WEBGPU=ON to enable it). Skipping _webgpu and"
    echo "_web_combined variants; committed webgpu blobs are left as-is."
fi
rm -f "${TMPDIR:-/tmp}/thermion_webgpu_probe.mat" \
      "${TMPDIR:-/tmp}/thermion_webgpu_probe.filamat"

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
    local upper_suffix
    upper_suffix=$(echo "${suffix}" | tr '[:lower:]' '[:upper:]')
    local guard_name="${upper}_${upper_suffix}_H_"

    echo "  ${suffix}: matc ${arch_flags[*]}"

    "${MATC}" "${arch_flags[@]}" \
        -o "materials/${material}.filamat" "materials/${material}.mat" || return 1
    "${RESGEN}" -c -p "${material}" -x "${MATERIAL_DIR}/" "materials/${material}.filamat" || return 1

    # Rename to suffixed files
    mv "${MATERIAL_DIR}/${material}.c" "${MATERIAL_DIR}/${material}_${suffix}.c"
    mv "${MATERIAL_DIR}/${material}.h" "${MATERIAL_DIR}/${material}_${suffix}.h"

    # Fix #include in .c to point to suffixed .h
    # (perl rather than sed: BSD sed has no GNU-style in-place editing)
    perl -i -pe "s/#include \"${material}\\.h\"/#include \"${material}_${suffix}.h\"/" \
        "${MATERIAL_DIR}/${material}_${suffix}.c"

    # Fix header guard
    perl -i -pe "s/${upper}_H_/${guard_name}/" "${MATERIAL_DIR}/${material}_${suffix}.h"

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
# create_forwarding_header <material> <upper_name> [<include_stem>]
#
# Creates a forwarding header that dispatches to the correct variant
# based on THERMION_MATERIAL_* defines. <include_stem> defaults to
# <material> and only differs for gizmo (gizmo_material).
#
# THERMION_MATERIAL_NATIVE is kept as a legacy fallback so trees with
# stale pre-split blobs keep compiling until make materials is re-run.
# -------------------------------------------------------------------
create_forwarding_header() {
    local material="$1"
    local upper="$2"
    local stem="${3:-${material}}"

    cat > "${MATERIAL_DIR}/${material}.h" << EOF
#ifndef ${upper}_H_
#define ${upper}_H_

#if defined(THERMION_MATERIAL_APPLE)
#include "${stem}_apple.h"
#elif defined(THERMION_MATERIAL_ANDROID)
#include "${stem}_android.h"
#elif defined(THERMION_MATERIAL_DESKTOP)
#include "${stem}_desktop.h"
#elif defined(THERMION_MATERIAL_OPENGL)
#include "${stem}_opengl.h"
#elif defined(THERMION_MATERIAL_VULKAN)
#include "${stem}_vulkan.h"
#elif defined(THERMION_MATERIAL_WEBGPU)
#include "${stem}_webgpu.h"
#elif defined(THERMION_MATERIAL_WEB_WEBGL)
#include "${stem}_web_webgl.h"
#elif defined(THERMION_MATERIAL_WEB_COMBINED)
#include "${stem}_web_combined.h"
#else
#error "No material backend variant selected. Define one of: THERMION_MATERIAL_APPLE, THERMION_MATERIAL_ANDROID, THERMION_MATERIAL_DESKTOP, THERMION_MATERIAL_OPENGL, THERMION_MATERIAL_VULKAN, THERMION_MATERIAL_WEBGPU, THERMION_MATERIAL_WEB_WEBGL, THERMION_MATERIAL_WEB_COMBINED"
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

    build_variant "$material" apple     -a metal
    build_variant "$material" android   -a vulkan -a opengl
    build_variant "$material" desktop   -a vulkan -a opengl
    build_variant "$material" opengl    -a opengl
    build_variant "$material" vulkan    -a vulkan
    if [ "${WEBGPU_SUPPORTED}" -eq 1 ]; then
        build_variant "$material" webgpu   -a webgpu
        build_variant "$material" web_combined -a opengl -a webgpu
    fi
    build_variant "$material" web_webgl -a opengl

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
GIZMO_SUFFIXES="apple android desktop opengl vulkan webgpu web_webgl web_combined"
if [ "${WEBGPU_SUPPORTED}" -eq 0 ]; then
    GIZMO_SUFFIXES="apple android desktop opengl vulkan web_webgl"
fi
for suffix in ${GIZMO_SUFFIXES}; do
    case "$suffix" in
        apple)        matc_flags="-a metal" ;;
        android)      matc_flags="-a vulkan -a opengl" ;;
        desktop)      matc_flags="-a vulkan -a opengl" ;;
        opengl)       matc_flags="-a opengl" ;;
        vulkan)       matc_flags="-a vulkan" ;;
        webgpu)       matc_flags="-a webgpu" ;;
        web_webgl)    matc_flags="-a opengl" ;;
        web_combined) matc_flags="-a opengl -a webgpu" ;;
    esac

    echo "  ${suffix}: matc ${matc_flags}"

    "${MATC}" ${matc_flags} \
        -o "materials/gizmo.filamat" "materials/gizmo.mat" || exit 1
    "${RESGEN}" -c -p "gizmo" -x "${MATERIAL_DIR}/" "materials/gizmo.filamat" || exit 1

    # Rename .c/.h to gizmo_material_<suffix>
    mv "${MATERIAL_DIR}/gizmo.c" "${MATERIAL_DIR}/gizmo_material_${suffix}.c"
    mv "${MATERIAL_DIR}/gizmo.h" "${MATERIAL_DIR}/gizmo_material_${suffix}.h"

    # Fix #include (perl rather than sed: BSD sed has no GNU-style in-place
    # editing)
    perl -i -pe "s/#include \"gizmo\\.h\"/#include \"gizmo_material_${suffix}.h\"/" \
        "${MATERIAL_DIR}/gizmo_material_${suffix}.c"

    # Fix header guard
    upper_suffix=$(echo "${suffix}" | tr '[:lower:]' '[:upper:]')
    perl -i -pe "s/GIZMO_H_/GIZMO_MATERIAL_${upper_suffix}_H_/" \
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

# Gizmo forwarding header (include stem is gizmo_material, not gizmo)
create_forwarding_header "gizmo" "GIZMO" "gizmo_material"

echo ""

# -------------------------------------------------------------------
# Wireframe is listed in MATERIALS above, so it's already built.
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# Compile example asset materials (standalone .filamat, not embedded)
# -------------------------------------------------------------------
EXAMPLE_BACKENDS="-a opengl -a metal -a vulkan -a webgpu"
if [ "${WEBGPU_SUPPORTED}" -eq 0 ]; then
    EXAMPLE_BACKENDS="-a opengl -a metal -a vulkan"
fi
for material in "${EXAMPLE_MATERIALS[@]}"; do
    echo "=== examples/assets/$material (${EXAMPLE_BACKENDS}) ==="
    "${MATC}" ${EXAMPLE_BACKENDS} \
        -o "examples/assets/${material}.filamat" "examples/assets/${material}.mat" || exit 1
done

echo "=== Done ==="
