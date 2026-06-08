#!/bin/bash
set -euo pipefail

# Builds materials for all platforms, producing two variants per material:
#   - _native: OpenGL + Metal + Vulkan (GLSL, SPIR-V, MSL shaders)
#   - _webgpu: WebGPU only (WGSL shaders)
#
# Both variants use the same resgen prefix so the C symbols are identical
# (IMAGE_PACKAGE, IMAGE_IMAGE_DATA, etc.). Only one .c is compiled by the
# build hook, selected by the webgpu user-define. A forwarding header
# (e.g., image.h) dispatches to the correct variant via #ifdef.
#
# Requires: FILAMENT_PATH pointing to a Filament out/release (or similar)
#           directory with matc and resgen binaries. matc must be built with
#           FILAMENT_SUPPORTS_WEBGPU=ON for the _webgpu variants.

if [ -z "${FILAMENT_PATH:-}" ]; then
    echo "ERROR: FILAMENT_PATH is not set"
    exit 1
fi

MATC="${FILAMENT_PATH}/matc"
RESGEN="${FILAMENT_PATH}/resgen"
MATERIAL_DIR="thermion_dart/native/include/material"
MATERIALS=(image unlit_fixed_size grid linear_depth silhouette edge_outline wireframe translation_axis gizmo bone_overlay)
EXAMPLE_MATERIALS=(customattributes solidcolor viewspace)

for material in "${MATERIALS[@]}"; do
    echo "=== $material (native: opengl+metal+vulkan) ==="
    ${MATC} -a opengl -a metal -a vulkan \
        -o "materials/${material}.filamat" "materials/${material}.mat" || exit 1
    ${RESGEN} -c -p "${material}" -x "${MATERIAL_DIR}/" "materials/${material}.filamat" || exit 1

    # Rename to _native suffix
    mv "${MATERIAL_DIR}/${material}.c" "${MATERIAL_DIR}/${material}_native.c"
    mv "${MATERIAL_DIR}/${material}.h" "${MATERIAL_DIR}/${material}_native.h"

    # Fix #include in .c to point to _native.h
    sed -i "s/#include \"${material}\\.h\"/#include \"${material}_native.h\"/" \
        "${MATERIAL_DIR}/${material}_native.c"

    # Fix header guard
    UPPER=$(echo "${material}" | tr '[:lower:]' '[:upper:]')
    sed -i "s/${UPPER}_H_/${UPPER}_NATIVE_H_/" "${MATERIAL_DIR}/${material}_native.h"

    # Add #include at top of .c and cplusplus guards in .h
    echo "#include \"${material}_native.h\"" | cat - "${MATERIAL_DIR}/${material}_native.c" > \
        "${MATERIAL_DIR}/${material}_native.c.tmp" && mv "${MATERIAL_DIR}/${material}_native.c.tmp" \
        "${MATERIAL_DIR}/${material}_native.c"
    perl -i -pe 's/extern "C" \{/#ifdef __cplusplus\nextern "C" {\n#endif/' "${MATERIAL_DIR}/${material}_native.h"
    # Close the last } with a cplusplus guard — be careful not to match earlier }
    perl -i -0pe 's/\n\}\n/\n#ifdef __cplusplus\n}\n#endif\n/' "${MATERIAL_DIR}/${material}_native.h"

    echo "=== $material (webgpu: wgsl) ==="
    ${MATC} -a webgpu \
        -o "materials/${material}.filamat" "materials/${material}.mat" || exit 1
    ${RESGEN} -c -p "${material}" -x "${MATERIAL_DIR}/" "materials/${material}.filamat" || exit 1

    # Rename to _webgpu suffix
    mv "${MATERIAL_DIR}/${material}.c" "${MATERIAL_DIR}/${material}_webgpu.c"
    mv "${MATERIAL_DIR}/${material}.h" "${MATERIAL_DIR}/${material}_webgpu.h"

    # Fix #include in .c to point to _webgpu.h
    sed -i "s/#include \"${material}\\.h\"/#include \"${material}_webgpu.h\"/" \
        "${MATERIAL_DIR}/${material}_webgpu.c"

    # Fix header guard
    sed -i "s/${UPPER}_H_/${UPPER}_WEBGPU_H_/" "${MATERIAL_DIR}/${material}_webgpu.h"

    # Add #include at top of .c and cplusplus guards in .h
    echo "#include \"${material}_webgpu.h\"" | cat - "${MATERIAL_DIR}/${material}_webgpu.c" > \
        "${MATERIAL_DIR}/${material}_webgpu.c.tmp" && mv "${MATERIAL_DIR}/${material}_webgpu.c.tmp" \
        "${MATERIAL_DIR}/${material}_webgpu.c"
    perl -i -pe 's/extern "C" \{/#ifdef __cplusplus\nextern "C" {\n#endif/' "${MATERIAL_DIR}/${material}_webgpu.h"
    perl -i -0pe 's/\n\}\n/\n#ifdef __cplusplus\n}\n#endif\n/' "${MATERIAL_DIR}/${material}_webgpu.h"

    # Create forwarding header
    cat > "${MATERIAL_DIR}/${material}.h" << EOF
#ifndef ${UPPER}_H_
#define ${UPPER}_H_

#ifdef THERMION_SUPPORTS_WEBGPU
#include "${material}_webgpu.h"
#else
#include "${material}_native.h"
#endif

#endif
EOF

    # Clean up intermediate .filamat
    rm -f "materials/${material}.filamat"

    echo ""
done

# The gizmo material .c/.h must be renamed to gizmo_material_*.c/.h to avoid a
# case-insensitive .obj collision with scene/Gizmo.cpp on Windows.
# Symbol names (GIZMO_PACKAGE, GIZMO_GIZMO_DATA, etc.) are unchanged since
# the resgen prefix stays "gizmo".
echo "=== gizmo rename special case ==="
mv "${MATERIAL_DIR}/gizmo_native.c" "${MATERIAL_DIR}/gizmo_material_native.c"
mv "${MATERIAL_DIR}/gizmo_native.h" "${MATERIAL_DIR}/gizmo_material_native.h"
sed -i 's/#include "gizmo_native\.h"/#include "gizmo_material_native.h"/' \
    "${MATERIAL_DIR}/gizmo_material_native.c"
sed -i 's/GIZMO_NATIVE_H_/GIZMO_MATERIAL_NATIVE_H_/' "${MATERIAL_DIR}/gizmo_material_native.h"

mv "${MATERIAL_DIR}/gizmo_webgpu.c" "${MATERIAL_DIR}/gizmo_material_webgpu.c"
mv "${MATERIAL_DIR}/gizmo_webgpu.h" "${MATERIAL_DIR}/gizmo_material_webgpu.h"
sed -i 's/#include "gizmo_webgpu\.h"/#include "gizmo_material_webgpu.h"/' \
    "${MATERIAL_DIR}/gizmo_material_webgpu.c"
sed -i 's/GIZMO_WEBGPU_H_/GIZMO_MATERIAL_WEBGPU_H_/' "${MATERIAL_DIR}/gizmo_material_webgpu.h"

# Update the gizmo forwarding header to point to renamed files
cat > "${MATERIAL_DIR}/gizmo.h" << 'EOF'
#ifndef GIZMO_H_
#define GIZMO_H_

#ifdef THERMION_SUPPORTS_WEBGPU
#include "gizmo_material_webgpu.h"
#else
#include "gizmo_material_native.h"
#endif

#endif
EOF

echo ""

# Compile example asset materials (standalone .filamat, not embedded)
for material in "${EXAMPLE_MATERIALS[@]}"; do
    echo "=== examples/assets/$material (all platforms) ==="
    ${MATC} -a opengl -a metal -a vulkan -a webgpu \
        -o "examples/assets/${material}.filamat" "examples/assets/${material}.mat" || exit 1
done

echo "=== Done ==="
