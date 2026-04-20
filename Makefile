wasm:
	@if [ ! -f thermion_dart/native/web/lib/release/filament-v1.69.1-web-release.zip ]; then \
		echo "Downloading filament-v1.69.1-web-release.zip..."; \
		mkdir -p thermion_dart/native/web/lib/release; \
		curl -L -o thermion_dart/native/web/lib/release/filament-v1.69.1-web-release.zip \
			https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/filament-v1.69.1-web-release.zip; \
		echo "Extracting filament-v1.69.1-web-release.zip..."; \
		cd thermion_dart/native/web/lib/release && \
		unzip filament-v1.69.1-web-release.zip; \
	fi
	cd thermion_dart/native/web && \
	mkdir -p build && \
	cd build && \
	emcmake cmake .. && \
	emmake make
wasm-clean:
	cd thermion_dart/native/web && rm -rf build
wasm-example-web: 
	cd examples/dart/js_wasm
	mkdir -p build
	dart compile js web/example.dart -o build/example.dart.js

flutter-example-web: dart-web-clean dart-web
	cd thermion_flutter_federated/thermion_flutter/example/web && dart compile wasm main.dart && cd .. && flutter build web --wasm --profile
flutter-example-macos:
	cd thermion_flutter_federated/thermion_flutter/example/web && flutter run -d macos
swift-bindings:
	swiftc -c thermion_flutter/thermion_flutter/darwin/classes/MetalTextureWrapper.swift -module-name thermion_flutter -emit-objc-header-path thermion_flutter/thermion_flutter/darwin/include/generated/MetalTextureWrapperObjCAPI.h -emit-library -o thermion_flutter/thermion_flutter/test/generated/libMetalTextureWrapper.dylib
	swiftc -c thermion_flutter/thermion_flutter/darwin/SwiftThermionFlutterPluginObjCAPI_Stub.swift -module-name thermion_flutter -emit-objc-header-path thermion_flutter/thermion_flutter/darwin/include/generated/SwiftThermionFlutterPluginObjCAPI.h
bindings:
	cd thermion_dart/ && dart pub get
	cd thermion_dart/ && dart run ffigen --config ffigen/native.yaml
	cd thermion_dart/ && dart run ffigen_js --config ffigen/web.yaml
	cd thermion_flutter/thermion_flutter && flutter pub get && flutter pub run ffigen --config ffigen/swift.yaml
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
