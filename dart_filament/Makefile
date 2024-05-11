web:
	cd native/web; mkdir -p build && cd build && emcmake cmake .. && emmake make
web-example-clean:
	cd native/web && rm -rf build
web-example: web
	cp native/web/build/build/out/dart_filament* examples/web_wasm/bin
	cd examples/web_wasm/bin && dart compile wasm example_web.dart
web-bindings:
	dart --enable-experiment=native-assets run ffigen --config ffigen/swift.yaml
swift-bindings:
	dart --enable-experiment=native-assets run ffigen --config ffigen/swift.yaml
shared-bindings:
	dart --enable-experiment=native-assets run ffigen --config ffigen/shared.yaml
bindings: shared-bindings swift-bindings web-bindings

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
	