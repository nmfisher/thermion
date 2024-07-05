# building on MacOS, we currently just delete the macos/include 
# and macos/src directories and copy from iOS
sync-macos: FORCE
	rm -rf ${current_dir}macos/include ${current_dir}macos/src 
	cp -R ${current_dir}ios/include ${current_dir}macos
	cp -R ${current_dir}ios/src ${current_dir}macos

# We compile a small set of custom materials for various helpers (background image, gizmo, etc)
# You must specify the `FILAMENT_PATH` environment variable, either the path /out/release
# eg: FILAMENT_PATH=/path/to/filament/out/release/bin make materials
# 
materials: FORCE
	@echo "Using Filament build from ${FILAMENT_PATH}"
	${FILAMENT_PATH}/matc -a opengl -a metal -o materials/image.filamat materials/image.mat
	$(FILAMENT_PATH)/resgen -c -p image -x ios/include/material/ materials/image.filamat   
	$(FILAMENT_PATH)/matc -a opengl -a metal -o materials/gizmo.filamat materials/gizmo.mat
	$(FILAMENT_PATH)/resgen -c -p gizmo -x ios/include/material/ materials/gizmo.filamat
	#rm materials/*.filamat

FORCE: ;

