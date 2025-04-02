for material in image unlit_fixed_size grid; do \
    echo $material
    ${FILAMENT_PATH}/matc -a opengl -a metal -a vulkan -o materials/$material.filamat materials/$material.mat || exit 1; \
	${FILAMENT_PATH}/resgen -c -p $material -x thermion_dart/native/include/material/ materials/$material.filamat || exit 1; \
    echo '#include "'$material'.h"' | cat - thermion_dart/native/include/material/$material.c > thermion_dart/native/include/material/$material.c.new; \
    mv thermion_dart/native/include/material/$material.c.new thermion_dart/native/include/material/$material.c; \
done