for material in image unlit_fixed_size grid linear_depth silhouette edge_outline wireframe translation_axis gizmo bone_overlay; do \
    echo $material
    ${FILAMENT_PATH}/matc -a opengl -a metal -a vulkan -o materials/$material.filamat materials/$material.mat || exit 1; \
	${FILAMENT_PATH}/resgen -c -p $material -x thermion_dart/native/include/material/ materials/$material.filamat || exit 1; \
    echo '#include "'$material'.h"' | cat - thermion_dart/native/include/material/$material.c > thermion_dart/native/include/material/$material.c.new; \
    mv thermion_dart/native/include/material/$material.c.new thermion_dart/native/include/material/$material.c; \
    # Add #ifdef __cplusplus guards around extern "C" in the header file
    # Use perl for portability between macOS and Linux sed
    perl -i -pe 's/extern "C" {/#ifdef __cplusplus\nextern "C" {\n#endif/' thermion_dart/native/include/material/$material.h; \
    perl -i -pe 's/^}$/#ifdef __cplusplus\n}\n#endif/' thermion_dart/native/include/material/$material.h; \
done

# The gizmo material .c/.h must be renamed to gizmo_material.c/.h to avoid a
# case-insensitive .obj collision with scene/Gizmo.cpp on Windows.
# Symbol names (GIZMO_PACKAGE, GIZMO_GIZMO_DATA, etc.) are unchanged since
# the resgen prefix stays "gizmo".
mv thermion_dart/native/include/material/gizmo.c thermion_dart/native/include/material/gizmo_material.c
mv thermion_dart/native/include/material/gizmo.h thermion_dart/native/include/material/gizmo_material.h
perl -i -pe 's/#include "gizmo\.h"/#include "gizmo_material.h"/' thermion_dart/native/include/material/gizmo_material.c
perl -i -pe 's/GIZMO_H_/GIZMO_MATERIAL_H_/' thermion_dart/native/include/material/gizmo_material.h

# Compile example asset materials (no embedded resources)
for material in customattributes solidcolor viewspace; do \
    echo "examples/assets/$material"
    ${FILAMENT_PATH}/matc -a opengl -a metal -a vulkan -o examples/assets/$material.filamat examples/assets/$material.mat || exit 1; \
done