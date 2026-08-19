# ReactPhysics3D is compiled into the single thermion_dart WASM through the
# EXTERNAL_PROJECTS hook in thermion_dart/native/web/CMakeLists.txt: thermion
# itself never references the rp3d C API, so its objects are only kept alive by
# the -Wl,--whole-archive group and its _rp3d_* functions are exported from the
# same Module object as the _Thermion_* ones. That is what lets one
# NativeLibrary.initBindings("thermion_dart") serve both packages on the web.
# scripts/build_reactphysics3d_web.sh stages the sources and the Emscripten
# build of libreactphysics3d.a that the hook links in.
# Set EXTERNAL_PROJECTS_CMAKE= (empty) to build a WASM without physics.
RP3D_EXTERNAL_DIR := thermion_dart/native/web/lib/external
EXTERNAL_PROJECTS_CMAKE ?= $(RP3D_EXTERNAL_DIR)/reactphysics3d_dart/native/web/reactphysics3d_dart.cmake
WASM_OUT_DIR := thermion_dart/native/web/build/build/out
# Sample of the _rp3d_* API the physics example calls; the whole C API is
# linked, these just gate the build against silent dead-code elimination.
RP3D_REQUIRED_EXPORTS := _rp3d_physics_common_create _rp3d_physics_common_create_physics_world \
	_rp3d_world_update _rp3d_world_create_rigid_body _rp3d_body_get_transform \
	_rp3d_physics_common_create_box_shape _rp3d_physics_common_create_sphere_shape

wasm:
	@if [ ! -f thermion_dart/native/web/lib/release/filament-v1.75.0-web-release.zip ]; then \
		echo "Downloading filament-v1.75.0-web-release.zip..."; \
		mkdir -p thermion_dart/native/web/lib/release; \
		curl -L -o thermion_dart/native/web/lib/release/filament-v1.75.0-web-release.zip \
			https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/filament-v1.75.0-web-release.zip; \
	fi
	@echo "Extracting filament-v1.75.0-web-release.zip..."; \
	cd thermion_dart/native/web/lib/release && \
	rm -rf include lib && \
	unzip -o filament-v1.75.0-web-release.zip
ifneq ($(strip $(EXTERNAL_PROJECTS_CMAKE)),)
	scripts/build_reactphysics3d_web.sh
endif
	cd thermion_dart/native/web && \
	mkdir -p build && \
	cd build && \
	emcmake cmake $(if $(strip $(EXTERNAL_PROJECTS_CMAKE)),-DEXTERNAL_PROJECTS=$(abspath $(EXTERNAL_PROJECTS_CMAKE)),) .. && \
	emmake make
	scripts/verify_web_wasm_exports.sh $(WASM_OUT_DIR) $(RP3D_REQUIRED_EXPORTS)
wasm-clean:
	cd thermion_dart/native/web && rm -rf build
	@echo "Note: $(RP3D_EXTERNAL_DIR) is kept (cached ReactPhysics3D sources/build)."
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
	cd thermion_dart/ && dart run ffigen_js --config ffigen/web.yaml
flutter-bindings:
	cd thermion_flutter/thermion_flutter && flutter pub get && flutter pub run ffigen --config ffigen/swift.yaml
bindings: dart-bindings flutter-bindings
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
