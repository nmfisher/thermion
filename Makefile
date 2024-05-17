dart-web:
	cd dart_filament/native/web; mkdir -p build && cd build && emcmake cmake .. && emmake make
dart-web-clean:
	cd dart_filament/native/web && rm -rf build
dart-wasm-cli-example: dart-web
	cd dart_filament/examples/cli_wasm/bin && dart compile wasm example_cli.dart && node main.js > build.log 2>&1
dart-web-example: dart-web
	cp dart_filament/native/web/build/build/out/dart_filament* examples/web_wasm/bin
	cd dart_filament/examples/web_wasm/bin && dart compile wasm example_web.dart
swift-bindings:
	cd dart_filament/ && dart --enable-experiment=native-assets run ffigen --config ffigen/swift.yaml
bindings:
	cd dart_filament/ && dart --enable-experiment=native-assets run ffigen --config ffigen/native.yaml

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
	
