for material in image unlit_fixed_size grid linear_depth silhouette edge_outline wireframe translation_axis; do \
    echo $material
    ${FILAMENT_PATH}/matc -a opengl -a metal -a vulkan -o materials/$material.filamat materials/$material.mat || exit 1; \
	${FILAMENT_PATH}/resgen -c -p $material -x thermion_dart/native/include/material/ materials/$material.filamat || exit 1; \
    echo '#include "'$material'.h"' | cat - thermion_dart/native/include/material/$material.c > thermion_dart/native/include/material/$material.c.new; \
    mv thermion_dart/native/include/material/$material.c.new thermion_dart/native/include/material/$material.c; \
    # Add #ifdef __cplusplus guards around extern "C" in the header file
    sed -i '' 's/extern "C" {/#ifdef __cplusplus\nextern "C" {\n#endif/' thermion_dart/native/include/material/$material.h; \
    sed -i '' 's/^}$/#ifdef __cplusplus\n}\n#endif/' thermion_dart/native/include/material/$material.h; \
done

# Compile example asset materials (no embedded resources)
for material in customattributes solidcolor viewspace; do \
    echo "examples/assets/$material"
    ${FILAMENT_PATH}/matc -a opengl -a metal -a vulkan -o examples/assets/$material.filamat examples/assets/$material.mat || exit 1; \
done