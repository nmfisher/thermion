FILAMENT_VERSION := $(word 2,$(shell cat filament.version))
# Pin-aware artifact resolution (thermion_dart/filament.libs.json): uses the
# immutable hash-suffixed key when pinned, else the legacy key.
FILAMENT_WEB_ZIP := $(shell python3 scripts/filament-artifact-url.py web release --name-only)
FILAMENT_WEB_URL := $(shell python3 scripts/filament-artifact-url.py web release)

wasm:
	@if [ ! -f thermion_dart/native/web/lib/release/$(FILAMENT_WEB_ZIP) ]; then \
		echo "Downloading $(FILAMENT_WEB_ZIP)..."; \
		mkdir -p thermion_dart/native/web/lib/release; \
		curl -fL -o thermion_dart/native/web/lib/release/$(FILAMENT_WEB_ZIP) \
			$(FILAMENT_WEB_URL); \
	fi
	@echo "Extracting $(FILAMENT_WEB_ZIP)..."; \
	cd thermion_dart/native/web/lib/release && \
	rm -rf include lib && \
	unzip -o $(FILAMENT_WEB_ZIP)
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
	swiftc -c thermion_flutter/thermion_flutter/darwin/classes/MetalTextureWrapper.swift -module-name thermion_flutter -emit-library -o thermion_flutter/thermion_flutter/test/generated/libMetalTextureWrapper.dylib
	swiftc -c thermion_flutter/thermion_flutter/darwin/SwiftThermionFlutterPluginObjCAPI_Stub.swift -module-name thermion_flutter -emit-objc-header-path thermion_flutter/thermion_flutter/darwin/include/generated/SwiftThermionFlutterPluginObjCAPI.h
dart-bindings:
	cd thermion_dart/ && dart pub get
	cd thermion_dart/ && dart run ffigen --config ffigen/native.yaml
	cd thermion_dart/ && dart run ffigen_js --config ffigen/web.yaml --compiler-opts "$(FFIGEN_JS_COMPILER_OPTS)"
flutter-bindings:
	cd thermion_flutter/thermion_flutter && flutter pub get && flutter pub run ffigen --config ffigen/swift.yaml
bindings: dart-bindings flutter-bindings
shared:
	cd thermion_dart/native && make

# Verifies that the TBackend enum committed in
# thermion_dart/native/include/c_api/TEngine.h matches the filament::backend
# mirror in the pinned Filament version (see scripts/generate_tbackend.py).
# Downloads the pinned Filament artifact's header tree on first use.
tbackend-check:
	python3 scripts/generate_tbackend.py --check

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
