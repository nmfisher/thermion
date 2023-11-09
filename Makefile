mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(dir $(mkfile_path))
parent_dir := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

filament_build_out := $(parent_dir)/filament/out/cmake-release

# building on MacOS, we currently just delete the macos/include 
# and macos/src directories and copy from iOS

sync-macos: FORCE
	rm -rf ${current_dir}macos/include ${current_dir}macos/src 
	cp -R ${current_dir}ios/include ${current_dir}macos
	cp -R ${current_dir}ios/src ${current_dir}macos

FORCE: ;

# We use a single material (no lighting and no transparency) for background images
# 
# by default this assumes you have built filament in a sibling folder
# you may customize the out folder by speicifying `filament_build_out`
# 
# eg: make generate-background-material filament_build_out=/filament/out/release
# 
generate-background-material:
	${filament_build_out}/tools/matc/matc -a opengl -a metal -o materials/image.filamat materials/image.mat
	${filament_build_out}/tools/resgen/resgen -c -p image -x ios/include/material/ materials/image.filamat   
	rm materials/image.filamat
