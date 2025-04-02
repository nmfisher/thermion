dart-web:
	cd thermion_dart/native/web; mkdir -p build && cd build && emcmake cmake .. && emmake make
dart-web-clean:
	cd thermion_dart/native/web && rm -rf build
dart-wasm-cli-example: dart-web-clean dart-web
	cd thermion_dart/examples/cli_wasm/bin && dart compile wasm example_cli.dart && node main.js
dart-web-example: dart-web
	cp thermion_dart/native/web/build/build/out/thermion_dart* examples/web_wasm/bin
	cd thermion_dart/examples/web_wasm/bin && dart compile wasm example_web.dart
flutter-example-web: dart-web-clean dart-web
	cd thermion_flutter_federated/thermion_flutter/example/web && dart compile wasm main.dart && cd .. && flutter build web --wasm --profile
flutter-example-macos:
	cd thermion_flutter_federated/thermion_flutter/example/web && flutter run -d macos
swift-bindings:
	swiftc -c thermion_dart/native/macos/ThermionTexture.swift -module-name swift_module -emit-objc-header-path thermion_dart/native/include/generated/ThermionTextureSwiftObjCAPI.h -emit-library -o thermion_dart/test/libThermionTextureSwift.dylib
	cd thermion_dart/ && dart --enable-experiment=native-assets run ffigen --config ffigen/swift.yaml
bindings:
	cd thermion_dart/ && dart --enable-experiment=native-assets run ffigen --config ffigen/native.yaml
shared:
	cd thermion_dart/native && make

# We compile a small set of custom materials for various helpers (background image, gizmo, etc)
# You must specify the `FILAMENT_PATH` environment variable, either the path /out/release
# eg: FILAMENT_PATH=/path/to/filament/out/release/bin make materials
# 
materials: FORCE
ifndef FILAMENT_PATH
	@echo "FILAMENT_PATH is not set"
else
	@echo "Using Filament build from ${FILAMENT_PATH}"
	./materials/build.sh	
endif

resources: FORCE
ifndef FILAMENT_PATH
	@echo "FILAMENT_PATH is not set"
else
	@echo "Using Filament build from ${FILAMENT_PATH}"
	@for gizmo in translation rotation; do \
		$(FILAMENT_PATH)/resgen -c -p $${gizmo}_gizmo_glb -x thermion_dart/native/include/resources assets/$${gizmo}_gizmo.glb || exit 1; \
		echo '#include "'$${gizmo}_gizmo_glb.h'"' | cat - thermion_dart/native/include/resources/$${gizmo}_gizmo_glb.c > thermion_dart/native/include/resources/$${gizmo}_gizmo_glb.c.new; \
		mv thermion_dart/native/include/resources/$${gizmo}_gizmo_glb.c.new thermion_dart/native/include/resources/$${gizmo}_gizmo_glb.c; \
	done
endif

FORCE: ;
