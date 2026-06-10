# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-06-10

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.4.0+1`](#thermion_dart---v0401)
 - [`thermion_flutter` - `v0.4.0+1`](#thermion_flutter---v0401)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter` - `v0.4.0+1`

---

#### `thermion_dart` - `v0.4.0+1`

 - **FIX**: default baseColorFactor to white when hasBaseColorTexture is true.
 - **FIX**: prevent concurrent modification in FFIFilamentApp.destroy to prevent exception when 2+ swap chains existed.


## 2026-06-05

### Changes

---

Packages with breaking changes:

 - [`thermion_dart` - `v0.4.0`](#thermion_dart---v040)
 - [`thermion_flutter` - `v0.4.0`](#thermion_flutter---v040)

Packages with other changes:

 - There are no other changes in this release.

---

#### `thermion_dart` - `v0.4.0`

 - **REFACTOR**: replace Struct.create with StructAllocator.create (for JS interop compatibility).
 - **REFACTOR**: add RenderThread methods for TransformManager createComponent/removeComponent.
 - **REFACTOR**: use render (engine) thread methods for Vertex/IndexBufferBuilder.
 - **REFACTOR**: rename SceneAsset_createGeometry to SceneAsset_createGeometryWithBuilder.
 - **REFACTOR**: (Windows) use render target/imported Vulkan texture (#109).
 - **REFACTOR**: (flutter) migrate overlay implementation to use stacked widgets, each with a render target. Only macOS, iOS and Windows supported in this commit. (#110).
 - **REFACTOR**: pass frame start in nanos, not delta in float.
 - **REFACTOR**: move equality/hashcode overrides to NativeHandle. This allows us to treat all instances of classes that wrap native handles (FFIView, FFIRenderTarget) etc as the same (since they carry no state and only exist to pass-through to native methods.
 - **REFACTOR**: merge macOS/iOS thermion_flutter plugin files into a single darwin/ folder.
 - **REFACTOR**: (web) remove emscripten typed data accessors (these have been implemented directly in Dart in ffigen_js.
 - **REFACTOR**: expose isMacos arg to createHeadlessSwapchain to use TSWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER.
 - **REFACTOR**: bump ffigen_js dependency.
 - **REFACTOR**: use explicitSwapControl on web. In theory this should require emscripten_webgl_commit_frame() but in practice this works without it - I'm not sure it actually makes a difference but (without profiling) it feels slightly smoother.
 - **REFACTOR**: rename and consolidate Metal Texture creation classes on macOS/iOS.
 - **REFACTOR**: use FilamentApp.instance instead of passing app parameter.
 - **REFACTOR**: various changes needed to support HighlightOverlayManager on web.
 - **REFACTOR**: add Dart RenderManager class.
 - **REFACTOR**: move gltf parsing to FilamentApp (#95).
 - **REFACTOR**: create View_getNameRenderThread to help debug crash. also add FFIView.create() for the same reason.
 - **REFACTOR**: stop passing FilamentApp instance around and stop casting to FFI* classes.
 - **REFACTOR**: rename Swift texture wrapper filename and update tests.
 - **REFACTOR**: change shadow transform to Quaternion (not List<double>).
 - **REFACTOR**: remove useDefaultRenderOrder.
 - **REFACTOR**: rename (T)ToneMapping to (T)ToneMapper.
 - **REFACTOR**: return double3 from LightManager_getColor.
 - **REFACTOR**: create RenderableManager Dart interface/implementation.
 - **REFACTOR**: set translation axis priority to 0 (renders first).
 - **REFACTOR**: set grid priority to 6 (renders second-last).
 - **REFACTOR**: remove width/height from RenderTarget_create functions. The… (#128).
 - **REFACTOR**: replace C++ GridOverlay implementation with Dart.
 - **REFACTOR**: ubershader expects UV0 and UV1. Create these for geometry if not otherwise specified.
 - **REFACTOR**: use platform-specific vsync to schedule frames, rather than Flutter's SchedulerBinding. The latter renders a Flutter frame on every request, which isn't necessarily needed - often we just need the Thermion/Filament surface to update independently. (#112).
 - **REFACTOR**: FreeFlightInputHandlerDelegateV2 manages its own frame hook.
 - **REFACTOR**: remove old NativeLibrary.instance._emscripten_stack_get_free.
 - **REFACTOR**: add StructAllocator typedef and replace Struct.create with StructAllocator.create (for JS interop compatibility).
 - **REFACTOR**: replace InputHandlerManagerException with Exception and remove ffi. prefix from InputPipeline.
 - **REFACTOR**: move Swift/ObjC interop lib/headers from thermion_dart to thermion_flutter. In theory we can use these on macOS to create/import external textures as render targets in Dart applications. In practice, this requires the Flutter SDK (for objective_c) so it's not actually very practical. We previously used these to test external texture render targets; now that we run tests mostly on Linux, this is no longer used (render targets are created, but bound to textures created by Filament). However this may be useful to revisit in future so we will preserve the files in thermion_flutter.
 - **REFACTOR**: remove Scene* from AnimationManager, this is no longer needed as components are used for animation, not the Scene object list.
 - **REFACTOR**: rename TInputHandlerPipeline to TTransformPipeline and add ffigen_fix.h to fix problem with ffigen not generating EMSCRIPTEN_KEEPALIVE for definition in APIExport.h header outside the directory for TTransformPipeline.h etc.
 - **REFACTOR**: remove uberarchive.h (this should be routed to debug/release folders.
 - **REFACTOR**: add debug headers for uberarchive.
 - **REFACTOR**: implementing highlight overlays with Flutter widgets showed bad performance. (#111).
 - **REFACTOR**: call clearBackgroundImage in ThermionViewer.dispose().
 - **FIX**: fix setting highlight color consecutively not updating color.
 - **FIX**: add/use RenderThread methods for EntityManager_createEntity/destroyEntity.
 - **FIX**: destroy renderable in GeometrySceneAsset destructor.
 - **FIX**: add iOS ObjC implementation for CADisplayLink frame scheduler.
 - **FIX**: add check/log/return for bluevk::initialize() failure.
 - **FIX**: force RGBA decode on Windows for PNG background uploads.
 - **FIX**: destroy an entity's renderable component before destroying the entity. We also convert TransformManager methods to use RenderThread to help debugging.
 - **FIX**: copy gltf resource data to heap allocated std::vector<uint8_t>.
 - **FIX**: add 30 second timeout to Engine_createRenderThread call in FFIFilamentApp to ensure an exception is thrown if some fatal failure is encountered (e.g. Vulkan drivers can't be found).
 - **FIX**: throw Exception when failing to pull static lib zip file.
 - **FIX**(windows): eliminate texture jank on resize.
 - **FIX**: make sure String pointers are freed after use.
 - **FIX**(windows): eliminate black frame flash on resize.
 - **FIX**: bump ffigen_js dependency for missing Pointer.fromAddress on web.
 - **FIX**: In createEntity() in ffi_filament_app.dart, transformManager.createComponent() was being called without an await. This led to cases where calls to the transform would silently fail after calling createEntity() because the transform hadn't added yet. (#138).
 - **FIX**: consistent screen-space axis line width on the translation gizmo (#143).
 - **FIX**: use RenderThread methods for various Scene_/View_ calls.
 - **FIX**: dont destroy the camera entity after destroying the camera component (presumably the latter does the former internally; if we try and destory again, this will crash when assertions are enabled.
 - **FIX**: (windows) fix multi-viewer runtime hang (UI-thread Blit + FFI callback orphan) (#172).
 - **FIX**: enable postProcessing on highlight view but disable tone mapping.
 - **FIX**: delete duplicated tone mapper.
 - **FIX**: remove public dispose() method from ColorGrading, this should be managed by the relevant View.
 - **FIX**: properly export GltfMeshData.
 - **FIX**: temporarily disable AO options for ffigen/js compat.
 - **FIX**: if irradiance/reflections texture are the same in FFIIndirectLight, don't destroy both.
 - **FIX**: correctly remove views from internal swapchain mapping when destroyView is called.
 - **FIX**: return actual MaterialInstance from FFITexturedQuad.getMaterialInstanceAt (#147).
 - **FIX**: restore 60fps web rendering (#150).
 - **FIX**: migrate FFITexturedQuad.
 - **FIX**: move setName call to first after view creation.
 - **FIX**: set default name for view.
 - **FIX**: dont throw Exception if removeStencilHighlight is called when no overlay manager is available.
 - **FIX**: change View.getName() interface to return String?
 - **FIX**: in debug mode, the vsync frame scheduler will crash when hot restarting (because the Dart callback no longer exists). To fix this, in debug mode we use a Dart Send/ReceivePort to communicate the frame callback. In release mode, the raw function pointer is used. Only applicable to macos, ios, Android and Windows.
 - **FIX**: bugs in wireframe/rebuildVertices and add flatShading toggle (#149).
 - **FIX**: add missing Log include on Linux.
 - **FIX**: check for no swapchain before enabling highlight overlay, and make sure calls to RenderManager.attach/detach are properly awaited.
 - **FIX**: always loadResourcesAsync when FILAMENT_SINGLE_THREADED is true.
 - **FIX**: make sure view handles are freed and cleanup some logging.
 - **FIX**: bounding box calculation.
 - **FIX**: only check path relative to package root when checking which source files to exclude. Prevents false exclusions when the parent directory names contain excluded strings (e.g., "/fix-rebuild-vertices/thermion").
 - **FIX**: fix incorrect pixel buffer format key for macOS texture wrapper.
 - **FIX**: add entity→primitive offset mapping for multi-mesh highlighting.
 - **FIX**: gltf animation cross-fading.
 - **FIX**: temporarily disable gltfmesh parsing, ambient occlusion options and bone names (require support in ffigen_js) first.
 - **FIX**: throw exception in setProjectionFromFieldOfView where inputs are invalid (NaN/non-positive FOV etc).
 - **FIX**: late initialization of HighlightOverlayManager.
 - **FIX**: call destroyAsset when TexturedQuad is disposed and correctly set texture usage flags.
 - **FIX**: temporary fix to ensure JS bindings for TGltfMeshData are properly generated.
 - **FIX**: correct the order in which highlight overlay resources are disposed, and disable postprocessing/use correct texture format for colour correctness.
 - **FIX**: (linux) remove incorrect linked libraries.
 - **FIX**: use ifdef __cplusplus guards for edge_outline.h for Emscripten compatibility.
 - **FIX**: don't import dart:ffi into FFIView (access nullptr via the Thermion ffi.dart instead).
 - **FIX**: reinstate ambient occlusion options (these had been disabled due to compatibility issues on Windows & web.
 - **FIX**: percent-decode resource URIs before filesystem lookup.
 - **FIX**: reinstate rendering with multiple swapchains. I'm not sure if we can create a hardware texture rendertarget on the GLES backend for Android (though this should be possible on Vulkan), so to implement overlays we need to allow multiple swapchains.
 - **FIX**: add #ifdef __cplusplus guards for new overlay materials.
 - **FIX**: add #ifdef __cplusplus guards for new overlay materials.
 - **FIX**: use render thread methods for TransformManager.setParent, Scene.… (#159).
 - **FIX**: use uint32_t for gltf instances, not uint8_t.
 - **FIX**: Ubuntu LLVM libc++ fails to compile since.
 - **FIX**: temporarily disable TGltfParser.cpp.
 - **FIX**: add LOG_ERROR def for Windows compatibility.
 - **FIX**: orthographic projection not being set correctly.
 - **FIX**: use LOG_ERROR in TAnimationManager.cpp for Windows compatibility.
 - **FIX**: windows used different vulkan devices.
 - **FIX**: add message to exception when captureRenderTarget is true but view has no render target.
 - **FIX**: define __builtin_popcountll __popcnt64for Windows compatibility.
 - **FIX**: in loadGltf, normalise paths in Windows so we can correctly determine resourceUri.
 - **FIX**: reinstate raw gltf parsing (this was broken on Windows due to MSVC incompatibilities (#90).
 - **FIX**: use RGBA32F instead of RGB32F for 3-channel background images on Windows.
 - **FIX**: return camera frustum in cameraspace (not worldspace, returned by Filament by default).
 - **FIX**: implement missing js_interop withIntCallback.
 - **FIX**(windows): prevent VkImage double-free on texture resize.
 - **FEAT**: add Dart LightManager.
 - **FEAT**: add quad() to GeometryHelper (different from fullscreenQuad).
 - **FEAT**: expose Engine.setAutomaticInstancingEnabled (#92).
 - **FEAT**: expose SurfaceOrientationBuilder (#91).
 - **FEAT**: custom attribute support in createGeometry.
 - **FEAT**: expose geometry VertexBuffer from ThermionAsset.
 - **FEAT**: (web) define PLUGIN_SOURCES compiled for web.
 - **FEAT**: set camera projection from horizontal/vertical field of view.
 - **FEAT**: support all alphanumeric keys in InputHandler.
 - **FEAT**: add FilamentApp.createColoredSkybox.
 - **FEAT**: add FilamentApp.createColoredSkybox.
 - **FEAT**: expose View.getName().
 - **FEAT**: add createScene option to FilamentApp.createView.
 - **FEAT**: add getFogOptions() to View.
 - **FEAT**: implement dummy plugin system with on_frame_update.
 - **FEAT**: export includeDirs and outputDir in build.dart to facilitate plugin builds.
 - **FEAT**: allow creating a Camera for an arbitrary entity (equivalent to attaching a camera component).
 - **FEAT**: allow setting grid overlay axis colors directly (and allow showing/hiding spcific axes).
 - **FEAT**: expose Engine.getMaxAutomaticInstances().
 - **FEAT**: add speed argument for playGltfAnimation.
 - **FEAT**: remove unnecessary Texture format check in Texture_setImage.
 - **FEAT**: add mouse button bindings for InputPipeline.
 - **FEAT**: add custom key bindings/intents and use int mask for intents.
 - **FEAT**: expose instances() on RenderableManagerBuilder (#93).
 - **FEAT**: allow setting grid spacing/fade distances in ThermionViewer setGridOverlayVisibility.
 - **FEAT**: add setAmbientOcclusionOptions for View.
 - **FEAT**: add wireframe material.
 - **FEAT**: add setTransformAsync method. This may sometimes be needed when something during the internal render() call sets a transform and you need strict ordering guarantees.
 - **FEAT**: add translation axis material.
 - **FEAT**: add setParameterMat3.
 - **FEAT**: add translation axis material.
 - **FEAT**: add raw gltf parser (via cgltf).
 - **FEAT**: add Material.getBlendingMode()/MaterialInstance.getTransparencyMode().
 - **FEAT**: Transform Pipeline.
 - **FEAT**: auto-download web artifacts from thermion_dart build hook.
 - **FEAT**: add Camera getAperture/getShutterSpeed/getSensitivity.
 - **FEAT**: expose LUT format and dimensions on ColorGradingBuilder (#155).
 - **FEAT**: add registerTransformExecutor to pipeline.
 - **FEAT**: add shadow/winding order methods to Dart View.
 - **FEAT**: add Dart LightManager interface.
 - **FEAT**: add const consturctor to DirectLight.
 - **FEAT**: add set/getVsmShadowOptions to View.
 - **FEAT**: add static LightManager methods to compute shadow cascade splits.
 - **FEAT**: add static LightManager methods to compute shadow cascade splits.
 - **FEAT**: add/expand TransformManager, RenderableBuilder and RenderableManager interfaces.
 - **FEAT**: destroyEntity().
 - **FEAT**: add DebugRegistry and getLocalTransform to FilamentApp.
 - **FEAT**: add groundPlane() to GeometryHelper.
 - **FEAT**: add moveOnHover argument to input handler delegates.
 - **FEAT**: add 2 more grid LOD levels.
 - **FEAT**: PixelDataFormat.R support in pixel buffer conversion and capture (#140).
 - **DOCS**: update BUILDING.md.
 - **DOCS**: update BUILDING.md.
 - **BREAKING** **REFACTOR**: (flutter) use ObjC FFI for Swift interop to create textures.
 - **BREAKING** **REFACTOR**: \.
 - **BREAKING** **REFACTOR**: delete old flight/orbit camera delegate.
 - **BREAKING** **REFACTOR**: use const LinearColor for default DirectLight.
 - **BREAKING** **REFACTOR**: remove batch option from DelegateInputHandler.
 - **BREAKING** **REFACTOR**: remove createImageMaterialInstance from FilamentApp API.
 - **BREAKING** **REFACTOR**: move AnimationManager to FilamentApp.
 - **BREAKING** **REFACTOR**: remove hasHighlights() from View. This means the overlay will be rendered if enableHighlightOverlay() has been called, even if no assets are highlighted.
 - **BREAKING** **REFACTOR**: replace register/unregiser/updateRenderOrder on FilamentApp with a single method setRenderOrder.
 - **BREAKING** **FIX**: remove unused entity parameter from DelegateInputHandler parameters.
 - **BREAKING** **FEAT**: rename setGltfAnimationFrame to setGltfAnimationTime (correct time units) (#141).
 - **BREAKING** **FEAT**: add ColorGradingBuilder. you can no longer set ColorGrading on a View with a ToneMapping/ToneMapper enum; now, create an instance of ToneMapper and use the ColorGradingBuilder.toneMapper() method.
 - **BREAKING** **FEAT**: change existing setColor to setColorTemperature, and add method to setColor with linear RGB.
 - **BREAKING** **FEAT**: create AnimationManager interface (allowing users to manually progress the animation time for testing.
 - **BREAKING** **FEAT**: bump hooks/code_assets/test dependencies.
 - **BREAKING** **CI**: upload JS/WASM to Cloudflare R2 rather than storing in repository (#148).

#### `thermion_flutter` - `v0.4.0`

 - **REFACTOR**: (Windows) use render target/imported Vulkan texture (#109).
 - **REFACTOR**: add Dart RenderManager class.
 - **REFACTOR**: merge macOS/iOS thermion_flutter plugin files into a single darwin/ folder.
 - **REFACTOR**: merge macOS/iOS thermion_flutter plugin files into a single darwin/ folder.
 - **REFACTOR**: change construction logic for ThermionListenerWidget inside ViewerWidget to avoid recreating the rendering surface simply when the manipulator type changes.
 - **REFACTOR**: remove destroyed as public property from PlatformTextureDescriptor (implementations should store/check this internally when markTextuerFrameAvailable is called.
 - **REFACTOR**: move Swift/ObjC interop lib/headers from thermion_dart to thermion_flutter. In theory we can use these on macOS to create/import external textures as render targets in Dart applications. In practice, this requires the Flutter SDK (for objective_c) so it's not actually very practical. We previously used these to test external texture render targets; now that we run tests mostly on Linux, this is no longer used (render targets are created, but bound to textures created by Filament). However this may be useful to revisit in future so we will preserve the files in thermion_flutter.
 - **REFACTOR**: various changes needed to support HighlightOverlayManager on web.
 - **REFACTOR**: rename and consolidate Metal Texture creation classes on macOS/iOS.
 - **REFACTOR**: (flutter) allow returning null SwapChain (for Android) when plugin is first initialized.
 - **REFACTOR**: remove enableHighlights from ThermionWidget.
 - **REFACTOR**: use platform-specific vsync to schedule frames, rather than Flutter's SchedulerBinding. The latter renders a Flutter frame on every request, which isn't necessarily needed - often we just need the Thermion/Filament surface to update independently. (#112).
 - **REFACTOR**: implementing highlight overlays with Flutter widgets showed bad performance. (#111).
 - **REFACTOR**: remove redundant method channel calls to getDriverPlatform and getSharedContext on macOS/iOS.
 - **REFACTOR**: (flutter) migrate overlay implementation to use stacked widgets, each with a render target. Only macOS, iOS and Windows supported in this commit. (#110).
 - **FIX**: throw separate errors for frozen properties in ViewerWidget.
 - **FIX**: (windows) fix multi-viewer runtime hang (UI-thread Blit + FFI callback orphan) (#172).
 - **FIX**: set local _texture reference to null in ThermionWidget before destroying.
 - **FIX**: resolve thermion_dart include paths from package_config.json in Flutter plugin CMake.
 - **FIX**: fix broken RenderManager merge for ThermionFlutterPluginImpl.
 - **FIX**: in debug mode, the vsync frame scheduler will crash when hot restarting (because the Dart callback no longer exists). To fix this, in debug mode we use a Dart Send/ReceivePort to communicate the frame callback. In release mode, the raw function pointer is used. Only applicable to macos, ios, Android and Windows.
 - **FIX**: add missing #include "Log.hpp" in Linux Flutter plugin files.
 - **FIX**: restore 60fps web rendering (#150).
 - **FIX**: remove enableHighlights arg from ThermionWidget.
 - **FIX**: gate thermion_flutter hook on buildAssetTypes, not buildCodeAssets.
 - **FIX**: search from build dir, not source dir, for package_config.json.
 - **FIX**: fix FrameCallback imports.
 - **FIX**: add missing Darwin frame scheduler.
 - **FIX**: resolve thermion_dart include paths via package_config.json.
 - **FIX**(windows): eliminate black frame flash on resize.
 - **FIX**(windows): eliminate texture jank on resize.
 - **FIX**(windows): prevent VkImage double-free on texture resize.
 - **FIX**: use walk-up search for package_config.json instead of hardcoded depth.
 - **FIX**: hide VoidCallback to stop export/import conflicts with Flutter.
 - **FIX**: windows used different vulkan devices.
 - **FIX**: revert FilterQuality for TextureWidget to none.
 - **FIX**: pass destroySwapChain flag through and tweak logging.
 - **FIX**: reinstate rendering with multiple swapchains. I'm not sure if we can create a hardware texture rendertarget on the GLES backend for Android (though this should be possible on Vulkan), so to implement overlays we need to allow multiple swapchains.
 - **FEAT**: add VirtualGameController widget.
 - **FEAT**: add pauseFrameScheduler/resumeFrameScheduler (#142).
 - **FEAT**: auto-download web artifacts from thermion_dart build hook.
 - **FEAT**: update ThermionListenerWidget to support shiftLeft/shiftRight keys and track pressed buttons internally (to correctly identify the button for a mouseUp event).
 - **BREAKING** **REFACTOR**: replace register/unregiser/updateRenderOrder on FilamentApp with a single method setRenderOrder.
 - **BREAKING** **REFACTOR**: \.
 - **BREAKING** **REFACTOR**: (flutter) use ObjC FFI for Swift interop to create textures.
 - **BREAKING** **REFACTOR**: replace register/unregiser/updateRenderOrder on FilamentApp with a single method setRenderOrder.
 - **BREAKING** **FEAT**: remove directLightType, add directLight argument to ViewerWidget.


## 2025-09-30

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_flutter` - `v0.3.4`](#thermion_flutter---v034)

---

#### `thermion_flutter` - `v0.3.4`

 - Bump "thermion_flutter" to `0.3.4`.


## 2025-09-30

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.3.4+1`](#thermion_dart---v0341)
 - [`thermion_flutter_platform_interface` - `v0.3.3+2`](#thermion_flutter_platform_interface---v0332)
 - [`thermion_flutter_web` - `v0.3.3+2`](#thermion_flutter_web---v0332)
 - [`thermion_flutter_method_channel` - `v0.3.3+2`](#thermion_flutter_method_channel---v0332)
 - [`thermion_flutter` - `v0.3.3+2`](#thermion_flutter---v0332)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_platform_interface` - `v0.3.3+2`
 - `thermion_flutter_web` - `v0.3.3+2`
 - `thermion_flutter_method_channel` - `v0.3.3+2`
 - `thermion_flutter` - `v0.3.3+2`

---

#### `thermion_dart` - `v0.3.4+1`

 - **FIX**: loosen dependency versions for code_assets, hooks and native_toolchain_c.


## 2025-09-30

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.3.4`](#thermion_dart---v034)
 - [`thermion_flutter` - `v0.3.3+1`](#thermion_flutter---v0331)
 - [`thermion_flutter_method_channel` - `v0.3.3+1`](#thermion_flutter_method_channel---v0331)
 - [`thermion_flutter_web` - `v0.3.3+1`](#thermion_flutter_web---v0331)
 - [`thermion_flutter_platform_interface` - `v0.3.3+1`](#thermion_flutter_platform_interface---v0331)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_method_channel` - `v0.3.3+1`
 - `thermion_flutter_web` - `v0.3.3+1`
 - `thermion_flutter_platform_interface` - `v0.3.3+1`

---

#### `thermion_dart` - `v0.3.4`

 - **REFACTOR**: rename requestId to textureUploadCompleteRequestId in KTX texture methods.
 - **FIX**: only add matdb to macos builds in debug mode.
 - **FIX**: add 16kb page size flags for Android builds and pin the ndkVersion for thermion_flutter to 28.2.13676358.
 - **FIX**: (build) use targetOS rather than platform string.
 - **FIX**: update code_assets, hooks and native_toolchain_c dependecies, and add check for buildCodeAssets (which throws an exception building for web).
 - **FIX**: update code_assets, hooks and native_toolchain_c dependecies, and add check for buildCodeAssets (which throws an exception building for web).
 - **FIX**: reinstate missing Struct.create.
 - **FIX**: throw separate exceptions for invalid near/far/aspect/focalLength in FFICamera.setLensProjection.
 - **FIX**: initialize isCubeMap in background image material to 0.
 - **FIX**: throw Exception if render() is called when no swapchain.
 - **FIX**: remove errant 'dart:io' import from FFIView.
 - **FIX**: use aspect ratio of 1.0 if initial viewport width/height is 0.
 - **FEAT**: update image material with depth parameter.
 - **FEAT**: add TexturedQuad class (and refactor internally so the viewer uses this to implement the background image.
 - **FEAT**: add blending for grid lines.

#### `thermion_flutter` - `v0.3.3+1`

 - **FIX**: add 16kb page size flags for Android builds and pin the ndkVersion for thermion_flutter to 28.2.13676358.


## 2025-07-24

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.3.3`](#thermion_dart---v033)
 - [`thermion_flutter_method_channel` - `v0.3.3`](#thermion_flutter_method_channel---v033)
 - [`thermion_flutter_platform_interface` - `v0.3.3`](#thermion_flutter_platform_interface---v033)
 - [`thermion_flutter_web` - `v0.3.3`](#thermion_flutter_web---v033)
 - [`thermion_flutter` - `v0.3.3`](#thermion_flutter---v033)

---

#### `thermion_dart` - `v0.3.3`

 - Bump "thermion_dart" to `0.3.3`.

#### `thermion_flutter_method_channel` - `v0.3.3`

 - Bump "thermion_flutter_method_channel" to `0.3.3`.

#### `thermion_flutter_platform_interface` - `v0.3.3`

 - Bump "thermion_flutter_platform_interface" to `0.3.3`.

#### `thermion_flutter_web` - `v0.3.3`

 - Bump "thermion_flutter_web" to `0.3.3`.

#### `thermion_flutter` - `v0.3.3`

 - Bump "thermion_flutter" to `0.3.3`.


## 2025-07-17

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.3.3-pre`](#thermion_dart---v033-pre)
 - [`thermion_flutter` - `v0.3.3-pre`](#thermion_flutter---v033-pre)
 - [`thermion_flutter_method_channel` - `v0.3.3-pre`](#thermion_flutter_method_channel---v033-pre)
 - [`thermion_flutter_platform_interface` - `v0.3.3-pre`](#thermion_flutter_platform_interface---v033-pre)
 - [`thermion_flutter_web` - `v0.3.3-pre`](#thermion_flutter_web---v033-pre)

---

#### `thermion_dart` - `v0.3.3-pre`

 - **FIX**: fix Windows build.dart.
 - **FIX**: add nan/negative checks inside setLensProjection.

#### `thermion_flutter` - `v0.3.3-pre`

 - **DOCS**: replace thermion_flutter README with symlink to thermion_dart README.

#### `thermion_flutter_method_channel` - `v0.3.3-pre`

 - **FEAT**: allow passing renderTargetColorTextureFormat via ThermionFlutterOptions.

#### `thermion_flutter_platform_interface` - `v0.3.3-pre`

 - **FEAT**: allow passing renderTargetColorTextureFormat via ThermionFlutterOptions.

#### `thermion_flutter_web` - `v0.3.3-pre`

 - Bump "thermion_flutter_web" to `0.3.3-pre`.


## 2025-07-08

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.3.2`](#thermion_dart---v032)
 - [`thermion_flutter` - `v0.3.2`](#thermion_flutter---v032)
 - [`thermion_flutter_method_channel` - `v0.3.2`](#thermion_flutter_method_channel---v032)
 - [`thermion_flutter_web` - `v0.3.2`](#thermion_flutter_web---v032)
 - [`thermion_flutter_platform_interface` - `v0.3.2`](#thermion_flutter_platform_interface---v032)

---

#### `thermion_dart` - `v0.3.2`

 - Bump "thermion_dart" to `0.3.2`.

#### `thermion_flutter` - `v0.3.2`

 - Bump "thermion_flutter" to `0.3.2`.

#### `thermion_flutter_method_channel` - `v0.3.2`

 - Bump "thermion_flutter_method_channel" to `0.3.2`.

#### `thermion_flutter_web` - `v0.3.2`

 - **FIX**: add missing destroySwapchain argument for web.

#### `thermion_flutter_platform_interface` - `v0.3.2`

 - Bump "thermion_flutter_platform_interface" to `0.3.2`.


## 2025-07-08

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.3.1`](#thermion_dart---v031)
 - [`thermion_flutter` - `v0.3.1`](#thermion_flutter---v031)
 - [`thermion_flutter_method_channel` - `v0.3.1`](#thermion_flutter_method_channel---v031)
 - [`thermion_flutter_web` - `v0.3.1`](#thermion_flutter_web---v031)
 - [`thermion_flutter_platform_interface` - `v0.3.1`](#thermion_flutter_platform_interface---v031)

---

#### `thermion_dart` - `v0.3.1`

 - **REFACTOR**: remove covariant keyword from createInstance args.
 - **FIX**: add flush() to skybox/IBL destroy methods to ensure that textre upload callbacks are completed to avoid stalling.
 - **FIX**: duplicate setting for _grid.

#### `thermion_flutter` - `v0.3.1`

 - **FIX**: addDestroySwapchain argument to createViewer() (true by default). This is only used on iOS/macOS where a single swapchain is shared between all render targets.
 - **DOCS**: fix typo in link.
 - **DOCS**: remove code from thermion_flutter README.md and point to docs/repository example instead.

#### `thermion_flutter_method_channel` - `v0.3.1`

 - **FIX**: addDestroySwapchain argument to createViewer() (true by default). This is only used on iOS/macOS where a single swapchain is shared between all render targets.

#### `thermion_flutter_web` - `v0.3.1`

#### `thermion_flutter_platform_interface` - `v0.3.1`

 - **FIX**: addDestroySwapchain argument to createViewer() (true by default). This is only used on iOS/macOS where a single swapchain is shared between all render targets.

# Change Log

#### v0.3.0

This release involved considerable internal refactoring, allowing us to expose more Filament functionality on the Dart side. Previously, most of this functionality was 
rigidly implemented in C++ and didn't allow for end-users to take advantage of Filament directly.

This also means there are a number of breaking changes from `0.2.1`. To summarize:

- `ViewerWidget` has been introduced. This is a Flutter widget for users who only need basic rendering and don't need/want to deal with camera/materials/etc directly.
- Users who want more fine-grained control than a `ViewerWidget` can still work with `ThermionViewer` and `ThermionWidget`.
- The singleton `FilamentApp.instance` exposes methods for working almost directly with the underlying Filament engine (e.g. loading custom materials from `Uint8List`, creating textures, etc).
- New interfaces have been added for `Material`, `MaterialInstance`, `Texture`, `View`, `Scene` and `Camera`.
- `ThermionAsset` replaces `ThermionEntity` as the main interface for scene objects.
- Transforms/material instances should be set directly by `asset.setTransform`, `asset.setMaterialInstanceAt`
- Material properties can be set directly on the `MaterialInstance`, e.g. `materialInstance.setParameterFloat4("baseColorFactor", 1.0, 0.0, 0.0, 1.0);
- Linux binaries have been added to `thermion_dart`. This package can be run on Linux (which we are using for CI and automated testing) but there are not yet any Flutter bindings, so `thermion_flutter` cannot run on Linux yet.
- On Windows, `thermion_flutter` now uses the Vulkan backend. This is still experimental and will have limited supported on older hardware (pre-2018).
-  Web support for `thermion_dart` has now reached parity with other platforms, though should still be considered experimental. Some manual steps are required to run in a Flutter app or a Dart web app.  

## 2025-01-08

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.20.0`](#thermion_dart---v021-dev200)
 - [`thermion_flutter` - `v0.2.1-dev.20.0`](#thermion_flutter---v021-dev200)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.20.0`](#thermion_flutter_platform_interface---v021-dev200)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.20.0`](#thermion_flutter_ffi---v021-dev200)
 - [`thermion_flutter_web` - `v0.2.0+11`](#thermion_flutter_web---v02011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.2.0+11`

---

#### `thermion_dart` - `v0.2.1-dev.20.0`

 - **FIX**: only use Windows-style ndkRoot when building on Windows.

#### `thermion_flutter` - `v0.2.1-dev.20.0`

 - Bump "thermion_flutter" to `0.2.1-dev.20.0`.

#### `thermion_flutter_platform_interface` - `v0.2.1-dev.20.0`

 - Bump "thermion_flutter_platform_interface" to `0.2.1-dev.20.0`.

#### `thermion_flutter_ffi` - `v0.2.1-dev.20.0`

 - Bump "thermion_flutter_ffi" to `0.2.1-dev.20.0`.


## 2024-11-21

### Changes

---

Packages with breaking changes:

 - [`thermion_dart` - `v0.2.1-dev.19.0`](#thermion_dart---v021-dev190)

Packages with other changes:

 - [`thermion_flutter` - `v0.2.1-dev.19.0`](#thermion_flutter---v021-dev190)
 - [`thermion_flutter_web` - `v0.2.0+10`](#thermion_flutter_web---v02010)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.19.0`](#thermion_flutter_platform_interface---v021-dev190)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.19.0`](#thermion_flutter_ffi---v021-dev190)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter` - `v0.2.1-dev.19.0`
 - `thermion_flutter_web` - `v0.2.0+10`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.19.0`
 - `thermion_flutter_ffi` - `v0.2.1-dev.19.0`

---

#### `thermion_dart` - `v0.2.1-dev.19.0`

 - **FEAT**: use InputAction.ZOOM for scroll wheel in free flight handler.
 - **FEAT**: free flight camera improvements.
 - **BREAKING** **FIX**: update Makefile & rebuild materials for Vulkan.


## 2024-11-18

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.18.0`](#thermion_dart---v021-dev180)
 - [`thermion_flutter` - `v0.2.1-dev.18.0`](#thermion_flutter---v021-dev180)
 - [`thermion_flutter_web` - `v0.2.0+9`](#thermion_flutter_web---v0209)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.18.0`](#thermion_flutter_platform_interface---v021-dev180)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.18.0`](#thermion_flutter_ffi---v021-dev180)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.2.0+9`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.18.0`
 - `thermion_flutter_ffi` - `v0.2.1-dev.18.0`

---

#### `thermion_dart` - `v0.2.1-dev.18.0`

 - **FEAT**: add MaterialInstance.setDepthFunc.

#### `thermion_flutter` - `v0.2.1-dev.18.0`

 - **FIX**: fix windows import header.


## 2024-11-15

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.17`](#thermion_dart---v021-dev0017)
 - [`thermion_flutter` - `v0.2.1-dev.17`](#thermion_flutter---v021-dev17)
 - [`thermion_flutter_web` - `v0.2.0+8`](#thermion_flutter_web---v0208)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.17`](#thermion_flutter_platform_interface---v021-dev17)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.17`](#thermion_flutter_ffi---v021-dev17)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.2.0+8`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.17`
 - `thermion_flutter_ffi` - `v0.2.1-dev.17`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.17`

 - **FIX**: remove superfluous ceil() calls for picking coordinates.
 - **FIX**: remove superfluous ceil() calls for picking coordinates.
 - **FIX**: reduce size of pick functor for compatibility with armeabi-v7a.
 - **FIX**: reduce size of pick functor for compatibility with armeabi-v7a.
 - **FEAT**: add Dart methods for getRenderableBoundingBox, setParameterInt and setParameterFloat4.
 - **FEAT**: Rename Gizmo material to UnlitFixedSize, and expose methods for using this material on other entities. Also exposes new methods for setting single float parameters.
 - **FEAT**: expose zoomSensitivity argument for flight input handler.
 - **FEAT**: Rename Gizmo material to UnlitFixedSize, and expose methods for using this material on other entities. Also exposes new methods for setting single float parameters.
 - **FEAT**: expose zoomSensitivity argument for flight input handler.
 - **FEAT**: sanitize file paths in build.dart for Windows compatibility.
 - **FEAT**: pass through fragment coordinates for picking.
 - **FEAT**: sanitize file paths in build.dart for Windows compatibility.
 - **FEAT**: pass through fragment coordinates for picking.

#### `thermion_flutter` - `v0.2.1-dev.17`

 - **FIX**: multiply coordinates by pixelRatio for scale events.
 - **FIX**: multiply coordinates by pixelRatio for scale events.


## 2024-10-31

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.16`](#thermion_dart---v021-dev0016)
 - [`thermion_flutter` - `v0.2.1-dev.16`](#thermion_flutter---v021-dev16)
 - [`thermion_flutter_web` - `v0.2.0+7`](#thermion_flutter_web---v0207)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.16`](#thermion_flutter_platform_interface---v021-dev16)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.16`](#thermion_flutter_ffi---v021-dev16)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter` - `v0.2.1-dev.16`
 - `thermion_flutter_web` - `v0.2.0+7`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.16`
 - `thermion_flutter_ffi` - `v0.2.1-dev.16`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.16`

 - **FEAT**: Rename Gizmo material to UnlitFixedSize, and expose methods for using this material on other entities. Also exposes new methods for setting single float parameters.


## 2024-10-31

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.15`](#thermion_dart---v021-dev0015)
 - [`thermion_flutter` - `v0.2.1-dev.15`](#thermion_flutter---v021-dev15)
 - [`thermion_flutter_web` - `v0.2.0+6`](#thermion_flutter_web---v0206)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.15`](#thermion_flutter_platform_interface---v021-dev15)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.15`](#thermion_flutter_ffi---v021-dev15)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.2.0+6`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.15`
 - `thermion_flutter_ffi` - `v0.2.1-dev.15`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.15`

 - **FIX**: remove superfluous ceil() calls for picking coordinates.
 - **FEAT**: expose zoomSensitivity argument for flight input handler.

#### `thermion_flutter` - `v0.2.1-dev.15`

 - **FIX**: multiply coordinates by pixelRatio for scale events.


## 2024-10-30

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.14`](#thermion_dart---v021-dev0014)
 - [`thermion_flutter` - `v0.2.1-dev.14`](#thermion_flutter---v021-dev14)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.14`](#thermion_flutter_platform_interface---v021-dev14)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.14`](#thermion_flutter_ffi---v021-dev14)
 - [`thermion_flutter_web` - `v0.2.0+5`](#thermion_flutter_web---v0205)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter` - `v0.2.1-dev.14`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.14`
 - `thermion_flutter_ffi` - `v0.2.1-dev.14`
 - `thermion_flutter_web` - `v0.2.0+5`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.14`

 - **FIX**: reduce size of pick functor for compatibility with armeabi-v7a.
 - **FEAT**: sanitize file paths in build.dart for Windows compatibility.
 - **FEAT**: pass through fragment coordinates for picking.
 - **FEAT**: pass through fragment coordinates for picking.


## 2024-10-29

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.13`](#thermion_dart---v021-dev0013)
 - [`thermion_flutter_web` - `v0.2.0+4`](#thermion_flutter_web---v0204)
 - [`thermion_flutter` - `v0.2.1-dev.13`](#thermion_flutter---v021-dev13)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.13`](#thermion_flutter_ffi---v021-dev13)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.13`](#thermion_flutter_platform_interface---v021-dev13)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.2.0+4`
 - `thermion_flutter` - `v0.2.1-dev.13`
 - `thermion_flutter_ffi` - `v0.2.1-dev.13`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.13`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.13`

 - **FIX**: properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
 - **FIX**: properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
 - **FEAT**: pass through fragment coordinates for picking.
 - **FEAT**: add SCALE2_MOVE InputType.
 - **FEAT**: add SCALE2_MOVE InputType.


## 2024-10-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.12`](#thermion_dart---v021-dev0012)
 - [`thermion_flutter` - `v0.2.1-dev.12`](#thermion_flutter---v021-dev12)
 - [`thermion_flutter_web` - `v0.2.0+3`](#thermion_flutter_web---v0203)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.12`](#thermion_flutter_platform_interface---v021-dev12)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.12`](#thermion_flutter_ffi---v021-dev12)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.2.0+3`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.12`
 - `thermion_flutter_ffi` - `v0.2.1-dev.12`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.12`

 - **FIX**: properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
 - **FIX**: properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
 - **FEAT**: add SCALE2_MOVE InputType.
 - **FEAT**: add SCALE2_MOVE InputType.

#### `thermion_flutter` - `v0.2.1-dev.12`

 - **FIX**: (flutter) (windows) remove deleted source file from Windows CMakeLists.


## 2024-10-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.12`](#thermion_dart---v021-dev0012)
 - [`thermion_flutter_web` - `v0.2.0+2`](#thermion_flutter_web---v0202)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.11`](#thermion_flutter_platform_interface---v021-dev11)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.11`](#thermion_flutter_ffi---v021-dev11)
 - [`thermion_flutter` - `v0.2.1-dev.11`](#thermion_flutter---v021-dev11)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.2.0+2`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.11`
 - `thermion_flutter_ffi` - `v0.2.1-dev.11`
 - `thermion_flutter` - `v0.2.1-dev.11`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.12`

 - **FIX**: properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
 - **FEAT**: add SCALE2_MOVE InputType.


## 2024-10-24

### Changes

---

Packages with breaking changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.11`](#thermion_dart---v021-dev0011)
 - [`thermion_flutter` - `v0.2.1-dev.10`](#thermion_flutter---v021-dev10)

Packages with other changes:

 - [`thermion_flutter_web` - `v0.2.0+1`](#thermion_flutter_web---v0201)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.10`](#thermion_flutter_platform_interface---v021-dev10)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.10`](#thermion_flutter_ffi---v021-dev10)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.2.0+1`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.10`
 - `thermion_flutter_ffi` - `v0.2.1-dev.10`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.11`

 - **FEAT**: add SCALE2_ROTATE to InputHandler.
 - **BREAKING** **FEAT**: expose velocity, rotation and timestamp for scale events in listener. accept rotationSensitivity/zoomSensitivity for FixedOrbitRotateInputHandlerDelegate.

#### `thermion_flutter` - `v0.2.1-dev.10`

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FIX**: fix all Windows warnings so apps will compile with /WX.
 - **FIX**: use internal Set for determining first ThermionTextureWidget to call requestFrame and cleanup destruction logic.
 - **FIX**: (flutter) pass ThermionFlutterOptions to ThermionWidget, use dpr for resizeTexture, delete unnecessary TransparencyPainter class.
 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FIX**: (flutter) desktop gesture detector changes for new Gizmo methods.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add Destroy() to BackingWindow.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: add rendering check to ThermionWidget ticker.
 - **FEAT**: allow passing null options to ThermionWidget.
 - **FEAT**: (flutter) (web) if importCanvasAsWidget is false, render transparency.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: highlight gizmo on hover.
 - **BREAKING** **FIX**: remove EntityControllerMouseWidget (replace with GestureHandler).
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FEAT**: expose velocity, rotation and timestamp for scale events in listener. accept rotationSensitivity/zoomSensitivity for FixedOrbitRotateInputHandlerDelegate.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.
 - **BREAKING** **CHORE**: remove superseded HardwareKeyboard* classes.
 - **BREAKING** **CHORE**: (flutter) cleanup for pub.dev publishing.
 - **BREAKING** **CHORE**: remove EntityListWidget - will replace with new Scene.
 - **BREAKING** **CHORE**: rename controller to viewer in gesture detector widgets.


## 2024-10-23

### Changes

---

Packages with breaking changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.10`](#thermion_dart---v021-dev0010)
 - [`thermion_flutter` - `v0.2.1-dev.9`](#thermion_flutter---v021-dev9)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.9`](#thermion_flutter_ffi---v021-dev9)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.9`](#thermion_flutter_platform_interface---v021-dev9)
 - [`thermion_flutter_web` - `v0.2.0`](#thermion_flutter_web---v020)

Packages with other changes:

 - There are no other changes in this release.

---

#### `thermion_dart` - `v0.2.1-dev.0.0.10`

 - Change defaults for DelegateInputHandler

 - **REFACTOR**: move native types to own header, add methods for create/destroy material instance, add priority/layer to load_glb_from_buffer.
 - **REFACTOR**: native types.
 - **REFACTOR**: continual refactor to support multiple render targets.
 - **REFACTOR**: native types.
 - **REFACTOR**: move native types to own header, add methods for create/destroy material instance, add priority/layer to load_glb_from_buffer.
 - **REFACTOR**: Dart types.
 - **REFACTOR**: Dart types.
 - **REFACTOR**: continual refactor to support multiple render targets.
 - **REFACTOR**: native types.
 - **REFACTOR**: native types.
 - **FIX**: set render target to null for each view and then destroy render targets when viewer disposed.
 - **FIX**: add check for nan NDC coordinates for viewport translation.
 - **FIX**: move createUnlitMaterialInstance and createGeometry to render thread.
 - **FIX**: properly destroy entities/material/etc in Gizmo on destruction, remove custom scene creation logic.
 - **FIX**: dont calculate surface orientation for non-triangle geometry.
 - **FIX**: set View render target to nullptr if Dart renderTarget is null.
 - **FIX**: properly destroy entities/material/etc in Gizmo on destruction, remove custom scene creation logic.
 - **FIX**: add Fence to capture() and set stencil buffer by default.
 - **FIX**: emscripten export visibility for add_light.
 - **FIX**: (wasm) use correct coords for pick, free memory correctly, keep pixelratio copy.
 - **FIX**: add more nan checks for gizmo manipulation.
 - **FIX**: add check for nan NDC coordinates for viewport translation.
 - **FIX**: (web) add emscripten guards for flushAndWait call when swapchain destroyed.
 - **FIX**: move createUnlitMaterialInstance and createGeometry to render thread.
 - **FIX**: move createUnlitMaterialInstance and createGeometry to render thread.
 - **FIX**: move createUnlitMaterialInstance and createGeometry to render thread.
 - **FIX**: dont calculate surface orientation for non-triangle geometry.
 - **FIX**: add more nan checks for gizmo manipulation.
 - **FIX**: set View render target to nullptr if Dart renderTarget is null.
 - **FIX**: set render target to null for each view and then destroy render targets when viewer disposed.
 - **FIX**: move ThermionWin32.h to include.
 - **FIX**: move ThermionWin32.h to include.
 - **FIX**: (wasm) use correct coords for pick, free memory correctly, keep pixelratio copy.
 - **FIX**: emscripten export visibility for add_light.
 - **FIX**: ignore pick results directly on axis.
 - **FIX**: add Fence to capture() and set stencil buffer by default.
 - **FIX**: move createUnlitMaterialInstance and createGeometry to render thread.
 - **FIX**: (web) add emscripten guards for flushAndWait call when swapchain destroyed.
 - **FIX**: ignore pick results directly on axis.
 - **FIX**: move createUnlitMaterialInstance and createGeometry to render thread.
 - **FEAT**: download WASM module directly on web (no need to embed in index.html any more) and expose updateViewportAndCameraProjection.
 - **FEAT**: layers, grid.
 - **FEAT**: simplify FixedOrbitCameraRotationDelegate.
 - **FEAT**: produce debug symbols on Windows.
 - **FEAT**: move HighlightOverlay to nested class, move createGeometry to SceneManager, add queueRelativePositionUpdateFromViewportVector.
 - **FEAT**: set InputType.SCALE1 to ROTATE by default for DelegateInputHandler.fixedOrbit.
 - **FEAT**: parent the cloned entity instance when setting stencil highlight.
 - **FEAT**: add getAncestor method.
 - **FEAT**: add getAncestor method.
 - **FEAT**: set stencil highlight on gizmo attach.
 - **FEAT**: move createGeometry to SceneManager, add queueRelativePositionUpdateFromViewportVector and removeStencilHighlight.
 - **FEAT**: download WASM module directly on web (no need to embed in index.html any more) and expose updateViewportAndCameraProjection.
 - **FEAT**: move HighlightOverlay to nested class, move createGeometry to SceneManager, add queueRelativePositionUpdateFromViewportVector.
 - **FEAT**: add removeStencilHighlight, accept color param for setStencilHighlight, queuePositionUpdateFromViewportCoords to ThermionDartApi.
 - **FEAT**: add removeStencilHighlight, queuePositionUpdateFromViewportCoords to ThermionViewer.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: add flag for keepData for gltf instancing, add highlightScene, add stencilHighlight method.
 - **FEAT**: grid uses own material.
 - **FEAT**: set SCALE2:InputAction.ZOOM by default.
 - **FEAT**: add grid material.
 - **FEAT**: expose setLightDirection and setLightPosition.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: add setGizmoVisibility/pickGizmo methods to ThermionViewer.
 - **FEAT**: remove gizmo view references, exclude gizmo entities from picking, add createIbl.
 - **FEAT**: createIbl.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: expose API methods for create_ibl, pick/set gizmo visibility.
 - **FEAT**: create transparent overlay for gizmo for easier picking.
 - **FEAT**: rescale gizmo based on distance from camera.
 - **FEAT**: rescale gizmo based on distance from camera.
 - **FEAT**: track zoom delta for DelegateInputHandler.
 - **FEAT**: expose setLayerEnabled, viewportDimensions and getCameraFov on ThermionView.
 - **FEAT**: layers, grid.
 - **FEAT**: add capture() function and expose viewportDimensions on ThermionViewer (allows easier saving of captured images to PNG).
 - **FEAT**: ignore grid overlay and gizmo center when picking, implement highlighting.
 - **FEAT**: SceneManager updates (setLayer, add grid, queueRelativePositionUpdateWorld.
 - **FEAT**: expose set_layer_enabled, get_camera_fov and queue_relative_position_updateg_world_axis to ThermionDartApi.h.
 - **FEAT**: add getCameraFov to FilamentViewer.
 - **FEAT**: add new grid overlay files to web CmakeLists.
 - **FEAT**: re-implement (native) Gizmo class, expose preserveScaling parameter for setParent, add methods for getting viewport bounding box from renderable entity.
 - **FEAT**: more work on multiple views/swapchains.
 - **FEAT**: rescale gizmo based on distance from camera.
 - **FEAT**: add capture() function and expose viewportDimensions on ThermionViewer (allows easier saving of captured images to PNG).
 - **FEAT**: (web) allow table growth in emscripten module for passing C-style callback function pointers.
 - **FEAT**: (web) add capture() method and missing camera navigation controls.
 - **FEAT**: rescale gizmo based on distance from camera.
 - **FEAT**: add grid material.
 - **FEAT**: add startOffset parameter to gltf playAnimation.
 - **FEAT**: create transparent overlay for gizmo for easier picking.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: produce debug symbols on Windows.
 - **FEAT**: (web) add capture() method and missing camera navigation controls.
 - **FEAT**: re-implement (native) Gizmo class, expose preserveScaling parameter for setParent, add methods for getting viewport bounding box from renderable entity.
 - **FEAT**: add new grid overlay files to web CmakeLists.
 - **FEAT**: expose API methods for create_ibl, pick/set gizmo visibility.
 - **FEAT**: add setParameterFloat2 method.
 - **FEAT**: createIbl.
 - **FEAT**: simplify FixedOrbitCameraRotationDelegate.
 - **FEAT**: add setParameterFloat2 method.
 - **FEAT**: expose setLayerEnabled, viewportDimensions and getCameraFov on ThermionView.
 - **FEAT**: (web) allow table growth in emscripten module for passing C-style callback function pointers.
 - **FEAT**: add getCameraFov to FilamentViewer.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: add removeStencilHighlight, accept color param for setStencilHighlight, queuePositionUpdateFromViewportCoords to ThermionDartApi.
 - **FEAT**: expose set_layer_enabled, get_camera_fov and queue_relative_position_updateg_world_axis to ThermionDartApi.h.
 - **FEAT**: more work on multiple views/swapchains.
 - **FEAT**: move createGeometry to SceneManager, add queueRelativePositionUpdateFromViewportVector and removeStencilHighlight.
 - **FEAT**: remove gizmo view references, exclude gizmo entities from picking, add createIbl.
 - **FEAT**: add setGizmoVisibility/pickGizmo methods to ThermionViewer.
 - **FEAT**: add uvScale to unlit material.
 - **FEAT**: add setParameterFloat2 method.
 - **FEAT**: add setParameterFloat2 method.
 - **FEAT**: set stencil highlight on gizmo attach.
 - **FEAT**: add startOffset parameter to gltf playAnimation.
 - **FEAT**: add ThirdPersonCameraDelegate.
 - **FEAT**: add uvScale to unlit material.
 - **FEAT**: add ThirdPersonCameraDelegate.
 - **FEAT**: expose setLightDirection and setLightPosition.
 - **FEAT**: set camera model matrix directly.
 - **FEAT**: expose more camera methods.
 - **FEAT**: add getAncestor method.
 - **FEAT**: grid uses own material.
 - **FEAT**: add flag for keepData for gltf instancing, add highlightScene, add stencilHighlight method.
 - **FEAT**: set camera model matrix directly.
 - **FEAT**: add removeStencilHighlight, queuePositionUpdateFromViewportCoords to ThermionViewer.
 - **FEAT**: expose more camera methods.
 - **FEAT**: ignore grid overlay and gizmo center when picking, implement highlighting.
 - **FEAT**: layers, grid.
 - **FEAT**: layers, grid.
 - **FEAT**: parent the cloned entity instance when setting stencil highlight.
 - **FEAT**: add getAncestor method.
 - **FEAT**: SceneManager updates (setLayer, add grid, queueRelativePositionUpdateWorld.
 - **DOCS**: add quickstart to README.
 - **DOCS**: add quickstart to README.
 - **BREAKING** **REFACTOR**: remove RenderThread methods no longer needed.
 - **BREAKING** **REFACTOR**: refactor to support multiple Views/Render Targets.
 - **BREAKING** **REFACTOR**: refactor to support multiple Views/Render Targets.
 - **BREAKING** **REFACTOR**: remove RenderThread methods no longer needed.
 - **BREAKING** **FIX**: Dart-only release mode builds on Window.
 - **BREAKING** **FIX**: (windows) add flushAndWait call to capture() to prevent stalling on Windows; use provided buffer as pixelBuffer rather than duplicate allocation.
 - **BREAKING** **FIX**: fix min SDK for thermion_dart.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FIX**: add meshoptimizer lib on Windows.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FIX**: Dart-only release mode builds on Window.
 - **BREAKING** **FIX**: (web/wasm) free pick callbacks on dispose.
 - **BREAKING** **FIX**: (windows) add flushAndWait call to capture() to prevent stalling on Windows; use provided buffer as pixelBuffer rather than duplicate allocation.
 - **BREAKING** **FIX**: add meshoptimizer lib on Windows.
 - **BREAKING** **FIX**: (web/wasm) free pick callbacks on dispose.
 - **BREAKING** **FIX**: fix min SDK for thermion_dart.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FEAT**: update web/http dependencies.
 - **BREAKING** **FEAT**: big refactor to support multiple swapchains.
 - **BREAKING** **FEAT**: update web/http dependencies.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: set baseColorIndex to -1 by default in unlit materialss.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: big refactor to support multiple swapchains.
 - **BREAKING** **FEAT**: set baseColorIndex to -1 by default in unlit materialss.
 - **BREAKING** **CHORE**: cleanup deleted export.
 - **BREAKING** **CHORE**: remove EntityTransformController (requires replacement).
 - **BREAKING** **CHORE**: restructure viewer folders as libraries to only export the public interface.
 - **BREAKING** **CHORE**: View.getCamera returns Future<Camera>.
 - **BREAKING** **CHORE**: cleanup deleted export.
 - **BREAKING** **CHORE**: remove EntityTransformController (requires replacement).
 - **BREAKING** **CHORE**: View.getCamera returns Future<Camera>.
 - **BREAKING** **CHORE**: restructure viewer folders as libraries to only export the public interface.

#### `thermion_flutter` - `v0.2.1-dev.9`

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FIX**: (flutter) pass ThermionFlutterOptions to ThermionWidget, use dpr for resizeTexture, delete unnecessary TransparencyPainter class.
 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FIX**: use internal Set for determining first ThermionTextureWidget to call requestFrame and cleanup destruction logic.
 - **FIX**: (flutter) pass ThermionFlutterOptions to ThermionWidget, use dpr for resizeTexture, delete unnecessary TransparencyPainter class.
 - **FIX**: fix all Windows warnings so apps will compile with /WX.
 - **FIX**: (flutter) desktop gesture detector changes for new Gizmo methods.
 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FIX**: use internal Set for determining first ThermionTextureWidget to call requestFrame and cleanup destruction logic.
 - **FIX**: fix all Windows warnings so apps will compile with /WX.
 - **FIX**: (flutter) desktop gesture detector changes for new Gizmo methods.
 - **FEAT**: highlight gizmo on hover.
 - **FEAT**: add rendering check to ThermionWidget ticker.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: allow passing null options to ThermionWidget.
 - **FEAT**: (flutter) (web) if importCanvasAsWidget is false, render transparency.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: highlight gizmo on hover.
 - **FEAT**: (flutter) (web) if importCanvasAsWidget is false, render transparency.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: add rendering check to ThermionWidget ticker.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add Destroy() to BackingWindow.
 - **FEAT**: (flutter) (windows) add Destroy() to BackingWindow.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: allow passing null options to ThermionWidget.
 - **FEAT**: use imported texture on iOS.
 - **BREAKING** **FIX**: remove EntityControllerMouseWidget (replace with GestureHandler).
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: remove EntityControllerMouseWidget (replace with GestureHandler).
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.
 - **BREAKING** **CHORE**: remove superseded HardwareKeyboard* classes.
 - **BREAKING** **CHORE**: (flutter) cleanup for pub.dev publishing.
 - **BREAKING** **CHORE**: remove EntityListWidget - will replace with new Scene.
 - **BREAKING** **CHORE**: rename controller to viewer in gesture detector widgets.
 - **BREAKING** **CHORE**: rename controller to viewer in gesture detector widgets.
 - **BREAKING** **CHORE**: remove EntityListWidget - will replace with new Scene.
 - **BREAKING** **CHORE**: (flutter) cleanup for pub.dev publishing.
 - **BREAKING** **CHORE**: remove superseded HardwareKeyboard* classes.

#### `thermion_flutter_ffi` - `v0.2.1-dev.9`

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FIX**: on resize, destroy swapchain if destroySwapChainOnResize is true.
 - **FIX**: add listener in ThermionFlutterTextureBackedPlatform to unset viewer on dispose.
 - **FIX**: add listener in ThermionFlutterMethodChannelInterface to unset viewer on dispose.
 - **FIX**: clean up destruction logic for FlutterPlatformTexture.
 - **FIX**: on resize, destroy swapchain if destroySwapChainOnResize is true.
 - **FIX**: add listener in ThermionFlutterTextureBackedPlatform to unset viewer on dispose.
 - **FIX**: add listener in ThermionFlutterMethodChannelInterface to unset viewer on dispose.
 - **FIX**: clean up destruction logic for FlutterPlatformTexture.
 - **FIX**: web/JS bool checks need to compare to int.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: (flutter) move DPR calculation to resizeTexture and add createViewerWithOptions method to ThermionFlutterFFI.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: (flutter) move DPR calculation to resizeTexture and add createViewerWithOptions method to ThermionFlutterFFI.
 - **BREAKING** **REFACTOR**: refactor to support multiple Views/Render Targets.
 - **BREAKING** **REFACTOR**: refactor to support multiple Views/Render Targets.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FEAT**: big refactor to support multiple swapchains.
 - **BREAKING** **FEAT**: big refactor to support multiple swapchains.

#### `thermion_flutter_platform_interface` - `v0.2.1-dev.9`

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add ThermionFlutterOptions classes, rename interface parameter for offsetTop and ensure pixelRatio is passed to resizeTexture.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add ThermionFlutterOptions classes, rename interface parameter for offsetTop and ensure pixelRatio is passed to resizeTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.

#### `thermion_flutter_web` - `v0.2.0`

 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FEAT**: (flutter) (web) use options to determine whether to create canvas, and set fixed position + offset.
 - **FEAT**: add ThermionFlutterOptions classes, rename interface parameter for offsetTop and ensure pixelRatio is passed to resizeTexture.
 - **FEAT**: (flutter) (web) use options to determine whether to create canvas, and set fixed position + offset.
 - **FEAT**: add ThermionFlutterOptions classes, rename interface parameter for offsetTop and ensure pixelRatio is passed to resizeTexture.
 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.
 - **BREAKING** **FEAT**: (flutter) (web) upgrade package:web dep to 1.0.0.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.
 - **BREAKING** **FEAT**: (flutter) (web) upgrade package:web dep to 1.0.0.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.
 - **BREAKING** **CHORE**: restructure viewer folders as libraries to only export the public interface.
 - **BREAKING** **CHORE**: restructure viewer folders as libraries to only export the public interface.


## 2024-10-23

### Changes

---

Packages with breaking changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.9`](#thermion_dart---v021-dev009)

Packages with other changes:

 - [`thermion_flutter` - `v0.2.1-dev.8`](#thermion_flutter---v021-dev8)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.8`](#thermion_flutter_ffi---v021-dev8)
 - [`thermion_flutter_web` - `v0.1.1`](#thermion_flutter_web---v011)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.8`](#thermion_flutter_platform_interface---v021-dev8)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_platform_interface` - `v0.2.1-dev.8`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.9`

 - Fix release builds on Windows

 - **FIX**: move createUnlitMaterialInstance and createGeometry to render thread.
 - **FIX**: move createUnlitMaterialInstance and createGeometry to render thread.
 - **FIX**: move createUnlitMaterialInstance and createGeometry to render thread.
 - **FIX**: dont calculate surface orientation for non-triangle geometry.
 - **FIX**: set View render target to nullptr if Dart renderTarget is null.
 - **FIX**: set render target to null for each view and then destroy render targets when viewer disposed.
 - **FEAT**: produce debug symbols on Windows.
 - **FEAT**: simplify FixedOrbitCameraRotationDelegate.
 - **DOCS**: add quickstart to README.
 - **BREAKING** **FIX**: (windows) add flushAndWait call to capture() to prevent stalling on Windows; use provided buffer as pixelBuffer rather than duplicate allocation.
 - **BREAKING** **FIX**: add meshoptimizer lib on Windows.
 - **BREAKING** **FIX**: Dart-only release mode builds on Window.
 - **BREAKING** **CHORE**: View.getCamera returns Future<Camera>.

#### `thermion_flutter` - `v0.2.1-dev.8`

 - **FIX**: fix all Windows warnings so apps will compile with /WX.
 - **FIX**: use internal Set for determining first ThermionTextureWidget to call requestFrame and cleanup destruction logic.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add DestroyRenderingSurface method.
 - **FEAT**: (flutter) (windows) add Destroy() to BackingWindow.

#### `thermion_flutter_ffi` - `v0.2.1-dev.8`

 - **FIX**: on resize, destroy swapchain if destroySwapChainOnResize is true.
 - **FIX**: add listener in ThermionFlutterTextureBackedPlatform to unset viewer on dispose.
 - **FIX**: add listener in ThermionFlutterMethodChannelInterface to unset viewer on dispose.
 - **FIX**: clean up destruction logic for FlutterPlatformTexture.
 - **FIX**: web/JS bool checks need to compare to int.

#### `thermion_flutter_web` - `v0.1.1`

 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.


## 2024-10-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.8`](#thermion_dart---v021-dev008)
 - [`thermion_flutter_web` - `v0.1.0+9`](#thermion_flutter_web---v0109)
 - [`thermion_flutter` - `v0.2.1-dev.7`](#thermion_flutter---v021-dev7)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.7`](#thermion_flutter_platform_interface---v021-dev7)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.7`](#thermion_flutter_ffi---v021-dev7)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.1.0+9`
 - `thermion_flutter` - `v0.2.1-dev.7`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.7`
 - `thermion_flutter_ffi` - `v0.2.1-dev.7`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.8`

 - **FIX**: move ThermionWin32.h to include.


## 2024-10-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.7`](#thermion_dart---v021-dev007)
 - [`thermion_flutter_web` - `v0.1.0+8`](#thermion_flutter_web---v0108)
 - [`thermion_flutter` - `v0.2.1-dev.6`](#thermion_flutter---v021-dev6)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.6`](#thermion_flutter_platform_interface---v021-dev6)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.6`](#thermion_flutter_ffi---v021-dev6)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.1.0+8`
 - `thermion_flutter` - `v0.2.1-dev.6`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.6`
 - `thermion_flutter_ffi` - `v0.2.1-dev.6`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.7`

 - Bump "thermion_dart" to `0.2.1-dev.0.0.7`.


## 2024-10-10

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.6`](#thermion_dart---v021-dev006)
 - [`thermion_flutter_web` - `v0.1.0+7`](#thermion_flutter_web---v0107)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.5`](#thermion_flutter_platform_interface---v021-dev5)
 - [`thermion_flutter` - `v0.2.1-dev.5`](#thermion_flutter---v021-dev5)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.5`](#thermion_flutter_ffi---v021-dev5)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.1.0+7`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.5`
 - `thermion_flutter` - `v0.2.1-dev.5`
 - `thermion_flutter_ffi` - `v0.2.1-dev.5`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.6`

 - Bump "thermion_dart" to `0.2.1-dev.0.0.6`.


## 2024-10-10

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.5`](#thermion_dart---v021-dev005)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.4`](#thermion_flutter_platform_interface---v021-dev4)
 - [`thermion_flutter_web` - `v0.1.0+6`](#thermion_flutter_web---v0106)
 - [`thermion_flutter` - `v0.2.1-dev.4`](#thermion_flutter---v021-dev4)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.4`](#thermion_flutter_ffi---v021-dev4)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_platform_interface` - `v0.2.1-dev.4`
 - `thermion_flutter_web` - `v0.1.0+6`
 - `thermion_flutter` - `v0.2.1-dev.4`
 - `thermion_flutter_ffi` - `v0.2.1-dev.4`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.5`

 - Bump "thermion_dart" to `0.2.1-dev.0.0.5`.


## 2024-10-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.4`](#thermion_dart---v021-dev004)
 - [`thermion_flutter_web` - `v0.1.0+5`](#thermion_flutter_web---v0105)
 - [`thermion_flutter` - `v0.2.1-dev.3`](#thermion_flutter---v021-dev3)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.3`](#thermion_flutter_platform_interface---v021-dev3)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.3`](#thermion_flutter_ffi---v021-dev3)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.1.0+5`
 - `thermion_flutter` - `v0.2.1-dev.3`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.3`
 - `thermion_flutter_ffi` - `v0.2.1-dev.3`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.4`


## 2024-10-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.3`](#thermion_dart---v021-dev003)
 - [`thermion_flutter_web` - `v0.1.0+4`](#thermion_flutter_web---v0104)
 - [`thermion_flutter` - `v0.2.1-dev.2`](#thermion_flutter---v021-dev2)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.2`](#thermion_flutter_platform_interface---v021-dev2)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.2`](#thermion_flutter_ffi---v021-dev2)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.1.0+4`
 - `thermion_flutter` - `v0.2.1-dev.2`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.2`
 - `thermion_flutter_ffi` - `v0.2.1-dev.2`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.3`

 - Bump "thermion_dart" to `0.2.1-dev.0.0.3`.


## 2024-10-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.2`](#thermion_dart---v021-dev002)
 - [`thermion_flutter_web` - `v0.1.0+3`](#thermion_flutter_web---v0103)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.1`](#thermion_flutter_ffi---v021-dev1)
 - [`thermion_flutter` - `v0.2.1-dev.1`](#thermion_flutter---v021-dev1)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.1`](#thermion_flutter_platform_interface---v021-dev1)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.1.0+3`
 - `thermion_flutter_ffi` - `v0.2.1-dev.1`
 - `thermion_flutter` - `v0.2.1-dev.1`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.1`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.2`


## 2024-10-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.1`](#thermion_dart---v021-dev001)
 - [`thermion_flutter_web` - `v0.1.0+2`](#thermion_flutter_web---v0102)
 - [`thermion_flutter` - `v0.2.1-dev.0`](#thermion_flutter---v021-dev0)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.0`](#thermion_flutter_platform_interface---v021-dev0)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.0`](#thermion_flutter_ffi---v021-dev0)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.1.0+2`
 - `thermion_flutter` - `v0.2.1-dev.0`
 - `thermion_flutter_platform_interface` - `v0.2.1-dev.0`
 - `thermion_flutter_ffi` - `v0.2.1-dev.0`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.1`


## 2024-10-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.1-dev.0.0.0`](#thermion_dart---v021-dev000)
 - [`thermion_flutter` - `v0.2.1-dev.0.0.0`](#thermion_flutter---v021-dev000)
 - [`thermion_flutter_ffi` - `v0.2.1-dev.0.0.0`](#thermion_flutter_ffi---v021-dev000)
 - [`thermion_flutter_platform_interface` - `v0.2.1-dev.0.0.0`](#thermion_flutter_platform_interface---v021-dev000)
 - [`thermion_flutter_web` - `v0.1.0+1`](#thermion_flutter_web---v0101)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.1.0+1`

---

#### `thermion_dart` - `v0.2.1-dev.0.0.0`

 - y

#### `thermion_flutter` - `v0.2.1-dev.0.0.0`

 - y

#### `thermion_flutter_ffi` - `v0.2.1-dev.0.0.0`

 - y

#### `thermion_flutter_platform_interface` - `v0.2.1-dev.0.0.0`

 - y


## 2024-10-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.2.0`](#thermion_dart---v020)
 - [`thermion_flutter` - `v0.2.0`](#thermion_flutter---v020)
 - [`thermion_flutter_ffi` - `v0.2.0`](#thermion_flutter_ffi---v020)
 - [`thermion_flutter_platform_interface` - `v0.2.0`](#thermion_flutter_platform_interface---v020)
 - [`thermion_flutter_web` - `v0.1.0`](#thermion_flutter_web---v010)

Packages graduated to a stable release (see pre-releases prior to the stable version for changelog entries):

 - `thermion_dart` - `v0.2.0`
 - `thermion_flutter` - `v0.2.0`
 - `thermion_flutter_ffi` - `v0.2.0`
 - `thermion_flutter_platform_interface` - `v0.2.0`
 - `thermion_flutter_web` - `v0.1.0`

---

#### `thermion_dart` - `v0.2.0`

#### `thermion_flutter` - `v0.2.0`

#### `thermion_flutter_ffi` - `v0.2.0`

#### `thermion_flutter_platform_interface` - `v0.2.0`

#### `thermion_flutter_web` - `v0.1.0`


## 2024-10-02

### Changes

---

Packages with breaking changes:

 - [`thermion_dart` - `v0.2.0-dev.8.0.0`](#thermion_dart---v020-dev800)
 - [`thermion_flutter_ffi` - `v0.2.0-dev.8.0.0`](#thermion_flutter_ffi---v020-dev800)

Packages with other changes:

 - [`thermion_flutter` - `v0.2.0-dev.8.0.0`](#thermion_flutter---v020-dev800)
 - [`thermion_flutter_platform_interface` - `v0.2.0-dev.8.0.0`](#thermion_flutter_platform_interface---v020-dev800)
 - [`thermion_flutter_web` - `v0.1.0-dev.8.0.0`](#thermion_flutter_web---v010-dev800)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.1.0-dev.8.0.0`

---

#### `thermion_dart` - `v0.2.0-dev.8.0.0`

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: more work on multiple views/swapchains.
 - **FEAT**: add setParameterFloat2 method.
 - **FEAT**: add setParameterFloat2 method.
 - **FEAT**: add uvScale to unlit material.
 - **FEAT**: add ThirdPersonCameraDelegate.
 - **FEAT**: set camera model matrix directly.
 - **FEAT**: expose more camera methods.
 - **BREAKING** **REFACTOR**: refactor to support multiple Views/Render Targets.
 - **BREAKING** **REFACTOR**: remove RenderThread methods no longer needed.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FIX**: replace queuePosition/Rotation with queueTransforms.
 - **BREAKING** **FEAT**: big refactor to support multiple swapchains.
 - **BREAKING** **FEAT**: set baseColorIndex to -1 by default in unlit materialss.

#### `thermion_flutter_ffi` - `v0.2.0-dev.8.0.0`

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **BREAKING** **REFACTOR**: refactor to support multiple Views/Render Targets.
 - **BREAKING** **FEAT**: big refactor to support multiple swapchains.

#### `thermion_flutter` - `v0.2.0-dev.8.0.0`

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FEAT**: camera and resizing improvements.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: use imported texture on iOS.
 - **FEAT**: working implementation of multiple widgets on macos.
 - **FEAT**: add rendering check to ThermionWidget ticker.

#### `thermion_flutter_platform_interface` - `v0.2.0-dev.8.0.0`

 - **REFACTOR**: continual refactor to support multiple render targets.
 - **FEAT**: support multiple ThermionWidget on Android.
 - **FEAT**: working implementation of multiple widgets on macos.

# Change Log

v0.2.0

- **BREAKING** Dart SDK 3.6.0 required 
- **BREAKING** Libraries have been restructured so you should only need to import `package:thermion_dart/thermion_dart.dart`, `package:thermion_flutter/thermion_flutter.dart`
- **BREAKING** The former GestureDetector widgets and EntityControllerMouseWidget/EntityTransformController have been removed and replaced with ThermionListenerWidget. that accepts an InputHandler.
- **BREAKING** The former debugging widgets and Scene class have been removed.
- **REFACTOR** The creation of the main camera has been refactored; the default projection & near/far planes should not have changed, but pay close attention.
- **REFACTOR**: add methods for create/destroy material instance, add priority/layer to load_glb_from_buffer.
- **FEAT**: Translation gizmo, stencil highlight & overlays.
- **FEAT**: new setLightDirection and setLightPosition.
- **FEAT**: move HighlightOverlay to nested class, move createGeometry to SceneManager, add queueRelativePositionUpdateFromViewportVector.
 - **FEAT**: move createGeometry to SceneManager, add queueRelativePositionUpdateFromViewportVector and removeStencilHighlight.
 - **FEAT**: add setGizmoVisibility/pickGizmo methods to ThermionViewer.
 - **FEAT**: remove gizmo view references, exclude gizmo entities from picking, add createIbl.
 - **FEAT**: set stencil highlight on gizmo attach.
 - **FEAT**: add getAncestor method.
 - **FEAT**: expose API methods for create_ibl, pick/set gizmo visibility.
 - **FEAT**: create transparent overlay for gizmo for easier picking.
 - **FEAT**: rescale gizmo based on distance from camera.
 - **FEAT**: rescale gizmo based on distance from camera.
 - **FEAT**: add getAncestor method.
 - **FEAT**: add startOffset parameter to gltf playAnimation.
 - **FEAT**: layers, grid.
 - **FEAT**: layers, grid.
 - **FEAT**: ignore grid overlay and gizmo center when picking, implement highlighting.
 - **FEAT**: SceneManager updates (setLayer, add grid, queueRelativePositionUpdateWorld.
 - **FEAT**: expose set_layer_enabled, get_camera_fov and queue_relative_position_updateg_world_axis to ThermionDartApi.h.
 - **FEAT**: add getCameraFov to FilamentViewer.
 - **FEAT**: add new grid overlay files to web CmakeLists.
 - **FEAT**: re-implement (native) Gizmo class, expose preserveScaling parameter for setParent, add methods for getting viewport bounding box from renderable entity.
 - **FEAT**: expose setLayerEnabled, viewportDimensions and getCameraFov on ThermionView.
 - **FEAT**: download WASM module directly on web (no need to embed in index.html any more) and expose updateViewportAndCameraProjection.
 - **FEAT**: add capture() function and expose viewportDimensions on ThermionViewer (allows easier saving of captured images to PNG).
 - **FEAT**: (web) allow table growth in emscripten module for passing C-style callback function pointers.
 - **FEAT**: (web) add capture() method and missing camera navigation controls.
 - **FEAT**: createIbl.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: update web/http dependencies.
 - **FIX**: (flutter) pass ThermionFlutterOptions to ThermionWidget, use dpr for resizeTexture, delete unnecessary TransparencyPainter class.
 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FIX**: (flutter) desktop gesture detector changes for new Gizmo methods.
 - **FEAT**: allow passing null options to ThermionWidget.
 - **FEAT**: (flutter) (web) if importCanvasAsWidget is false, render transparency.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: highlight gizmo on hover.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.
 - **BREAKING** **CHORE**: rename controller to viewer in gesture detector widgets.
 - **FEAT**: (flutter) move DPR calculation to resizeTexture and add createViewerWithOptions method to ThermionFlutterFFI.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add ThermionFlutterOptions classes, rename interface parameter for offsetTop and ensure pixelRatio is passed to resizeTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.
 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FEAT**: (flutter) (web) use options to determine whether to create canvas, and set fixed position + offset.
 - **FEAT**: add ThermionFlutterOptions classes, rename interface parameter for offsetTop and ensure pixelRatio is passed to resizeTexture.
 - **BREAKING** **FEAT**: (flutter) (web) upgrade package:web dep to 1.0.0.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.


## v0.1.3
 - **FIX**: manually remove leading slash for compiler path on Windows when building for Android.
 - **FIX**: web/JS bool checks need to compare to int.
 - **FIX**: shadow JS<->WASM bridge methods.
 - **FIX**: manually remove leading slash for compiler path on Windows when building for Android.
 - **FIX**: web/JS bool checks need to compare to int.
 - **FIX**: shadow JS<->WASM bridge methods.
 - **FEAT**: add clearMorphAnimationData function.
 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.
 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.

#### `thermion_flutter_ffi` - `v0.1.0+12`

 - **FIX**: add logging dependency.
 - **FIX**: web/JS bool checks need to compare to int.
 - **FIX**: add logging dependency.
 - **FIX**: web/JS bool checks need to compare to int.

#### `thermion_flutter_web` - `v0.0.3`

 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.
 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.


## 2024-07-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_flutter_ffi` - `v0.1.0+11`](#thermion_flutter_ffi---v01011)
 - [`thermion_flutter` - `v0.1.1+12`](#thermion_flutter---v01112)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter` - `v0.1.1+12`

---

#### `thermion_flutter_ffi` - `v0.1.0+11`

 - **FIX**: add logging dependency.


## 2024-07-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.2`](#thermion_dart---v012)
 - [`thermion_flutter_ffi` - `v0.1.0+10`](#thermion_flutter_ffi---v01010)
 - [`thermion_flutter_web` - `v0.0.2`](#thermion_flutter_web---v002)
 - [`thermion_flutter` - `v0.1.1+11`](#thermion_flutter---v01111)
 - [`thermion_flutter_platform_interface` - `v0.1.0+10`](#thermion_flutter_platform_interface---v01010)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter` - `v0.1.1+11`
 - `thermion_flutter_platform_interface` - `v0.1.0+10`

---

#### `thermion_dart` - `v0.1.2`

 - **FIX**: manually remove leading slash for compiler path on Windows when building for Android.
 - **FIX**: web/JS bool checks need to compare to int.
 - **FIX**: shadow JS<->WASM bridge methods.
 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.

#### `thermion_flutter_ffi` - `v0.1.0+10`

 - **FIX**: web/JS bool checks need to compare to int.

#### `thermion_flutter_web` - `v0.0.2`

 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.


## 2024-07-04

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.1+5`](#thermion_dart---v0115)
 - [`thermion_flutter_web` - `v0.0.1+9`](#thermion_flutter_web---v0019)
 - [`thermion_flutter` - `v0.1.1+10`](#thermion_flutter---v01110)
 - [`thermion_flutter_platform_interface` - `v0.1.0+9`](#thermion_flutter_platform_interface---v0109)
 - [`thermion_flutter_ffi` - `v0.1.0+9`](#thermion_flutter_ffi---v0109)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.0.1+9`
 - `thermion_flutter` - `v0.1.1+10`
 - `thermion_flutter_platform_interface` - `v0.1.0+9`
 - `thermion_flutter_ffi` - `v0.1.0+9`

---

#### `thermion_dart` - `v0.1.1+5`

 - Bump "thermion_dart" to `0.1.1+5`.


## 2024-07-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.1+4`](#thermion_dart---v0114)
 - [`thermion_flutter_web` - `v0.0.1+8`](#thermion_flutter_web---v0018)
 - [`thermion_flutter` - `v0.1.1+9`](#thermion_flutter---v0119)
 - [`thermion_flutter_platform_interface` - `v0.1.0+8`](#thermion_flutter_platform_interface---v0108)
 - [`thermion_flutter_ffi` - `v0.1.0+8`](#thermion_flutter_ffi---v0108)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.0.1+8`
 - `thermion_flutter` - `v0.1.1+9`
 - `thermion_flutter_platform_interface` - `v0.1.0+8`
 - `thermion_flutter_ffi` - `v0.1.0+8`

---

#### `thermion_dart` - `v0.1.1+4`

 - **FIX**: defer creating image entity/material/etc until actually requested.


## 2024-06-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.1+3`](#thermion_dart---v0113)
 - [`thermion_flutter` - `v0.1.1+8`](#thermion_flutter---v0118)
 - [`thermion_flutter_web` - `v0.0.1+7`](#thermion_flutter_web---v0017)
 - [`thermion_flutter_platform_interface` - `v0.1.0+7`](#thermion_flutter_platform_interface---v0107)
 - [`thermion_flutter_ffi` - `v0.1.0+7`](#thermion_flutter_ffi---v0107)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.0.1+7`
 - `thermion_flutter_platform_interface` - `v0.1.0+7`
 - `thermion_flutter_ffi` - `v0.1.0+7`

---

#### `thermion_dart` - `v0.1.1+3`

 - **FIX**: bump ffigen dependency version & regenerate bindings (and revert to ffi.Int rather than ffi.Int32).
 - **DOCS**: update homepage links and minor documentation updates.

#### `thermion_flutter` - `v0.1.1+8`

 - **DOCS**: update homepage links and minor documentation updates.


## 2024-06-26

### Changes

---

Packages with breaking changes:

 - [`thermion_dart` - `v0.1.1+2`](#thermion_dart---v0112)
 - [`thermion_flutter` - `v0.1.1+7`](#thermion_flutter---v0117)

Packages with other changes:

 - [`thermion_flutter_ffi` - `v0.1.0+6`](#thermion_flutter_ffi---v0106)
 - [`thermion_flutter_platform_interface` - `v0.1.0+6`](#thermion_flutter_platform_interface---v0106)
 - [`thermion_flutter_web` - `v0.0.1+6`](#thermion_flutter_web---v0016)

Packages graduated to a stable release (see pre-releases prior to the stable version for changelog entries):

 - `thermion_dart` - `v0.1.1+2`
 - `thermion_flutter` - `v0.1.1+7`
 - `thermion_flutter_ffi` - `v0.1.0+6`
 - `thermion_flutter_platform_interface` - `v0.1.0+6`
 - `thermion_flutter_web` - `v0.0.1+6`

---

#### `thermion_dart` - `v0.1.1+2`

#### `thermion_flutter` - `v0.1.1+7`

#### `thermion_flutter_ffi` - `v0.1.0+6`

#### `thermion_flutter_platform_interface` - `v0.1.0+6`

#### `thermion_flutter_web` - `v0.0.1+6`


## 2024-06-26

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.1-dev.0+2`](#thermion_dart---v011-dev02)
 - [`thermion_flutter` - `v0.1.1-dev.0+7`](#thermion_flutter---v011-dev07)
 - [`thermion_flutter_platform_interface` - `v0.1.0-dev.0+6`](#thermion_flutter_platform_interface---v010-dev06)
 - [`thermion_flutter_web` - `v0.0.1-dev.0+6`](#thermion_flutter_web---v001-dev06)
 - [`thermion_flutter_ffi` - `v0.1.0-dev.0+6`](#thermion_flutter_ffi---v010-dev06)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_platform_interface` - `v0.1.0-dev.0+6`
 - `thermion_flutter_web` - `v0.0.1-dev.0+6`
 - `thermion_flutter_ffi` - `v0.1.0-dev.0+6`

---

#### `thermion_dart` - `v0.1.1-dev.0+2`

 - **FIX**: revert to std::thread (pthreads not easily available on Windows).
 - **FIX**: on Windows, pass static libs via -l rather than custom linkWith property so build.dart stays compatible between published & custom versions.

#### `thermion_flutter` - `v0.1.1-dev.0+7`

 - **FIX**: add ResourceBuffer header directly to Windows build so I don't have to fiddle around getting the CMake path right.


## 2024-06-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.1+1`](#thermion_dart---v0111)
 - [`thermion_flutter` - `v0.1.1+6`](#thermion_flutter---v0116)
 - [`thermion_flutter_web` - `v0.0.1+5`](#thermion_flutter_web---v0015)
 - [`thermion_flutter_platform_interface` - `v0.1.0+5`](#thermion_flutter_platform_interface---v0105)
 - [`thermion_flutter_ffi` - `v0.1.0+5`](#thermion_flutter_ffi---v0105)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.0.1+5`
 - `thermion_flutter_platform_interface` - `v0.1.0+5`
 - `thermion_flutter_ffi` - `v0.1.0+5`

---

#### `thermion_dart` - `v0.1.1+1`

 - **DOCS**: update with links to playground.

#### `thermion_flutter` - `v0.1.1+6`

 - **DOCS**: update with links to playground.


## 2024-06-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.1`](#thermion_dart---v011)

---

#### `thermion_dart` - `v0.1.1`

 - Bump "thermion_dart" to `0.1.1`.


## 2024-06-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.0+4`](#thermion_dart---v0104)
 - [`thermion_flutter_web` - `v0.0.1+4`](#thermion_flutter_web---v0014)
 - [`thermion_flutter_platform_interface` - `v0.1.0+4`](#thermion_flutter_platform_interface---v0104)
 - [`thermion_flutter` - `v0.1.1+5`](#thermion_flutter---v0115)
 - [`thermion_flutter_ffi` - `v0.1.0+4`](#thermion_flutter_ffi---v0104)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.0.1+4`
 - `thermion_flutter_platform_interface` - `v0.1.0+4`
 - `thermion_flutter` - `v0.1.1+5`
 - `thermion_flutter_ffi` - `v0.1.0+4`

---

#### `thermion_dart` - `v0.1.0+4`

 - **FIX**: add dummy asset to build.dart on Linux builds so we can use the package on a Linux host.


## 2024-06-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.0+3`](#thermion_dart---v0103)
 - [`thermion_flutter_web` - `v0.0.1+3`](#thermion_flutter_web---v0013)
 - [`thermion_flutter` - `v0.1.1+4`](#thermion_flutter---v0114)
 - [`thermion_flutter_platform_interface` - `v0.1.0+3`](#thermion_flutter_platform_interface---v0103)
 - [`thermion_flutter_ffi` - `v0.1.0+3`](#thermion_flutter_ffi---v0103)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.0.1+3`
 - `thermion_flutter` - `v0.1.1+4`
 - `thermion_flutter_platform_interface` - `v0.1.0+3`
 - `thermion_flutter_ffi` - `v0.1.0+3`

---

#### `thermion_dart` - `v0.1.0+3`

 - **FIX**: exit build.dart early on Linux builds so we can use the package on a Linux host.


## 2024-06-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.0+2`](#thermion_dart---v0102)
 - [`thermion_flutter_ffi` - `v0.1.0+2`](#thermion_flutter_ffi---v0102)
 - [`thermion_flutter_web` - `v0.0.1+2`](#thermion_flutter_web---v0012)
 - [`thermion_flutter` - `v0.1.1+3`](#thermion_flutter---v0113)
 - [`thermion_flutter_platform_interface` - `v0.1.0+2`](#thermion_flutter_platform_interface---v0102)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_web` - `v0.0.1+2`
 - `thermion_flutter` - `v0.1.1+3`
 - `thermion_flutter_platform_interface` - `v0.1.0+2`

---

#### `thermion_dart` - `v0.1.0+2`

 - **REFACTOR**: rearrange some stubs/imports for easier web WASM deployment.

#### `thermion_flutter_ffi` - `v0.1.0+2`

 - **REFACTOR**: rearrange some stubs/imports for easier web WASM deployment.


## 2024-06-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_flutter` - `v0.1.1+2`](#thermion_flutter---v0112)

---

#### `thermion_flutter` - `v0.1.1+2`

 - **FIX**: update Flutter example project to use new API.
 - **FIX**: add logging dependency to thermion_flutter.


## 2024-06-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.0+1`](#thermion_dart---v0101)
 - [`thermion_flutter` - `v0.1.1+1`](#thermion_flutter---v0111)
 - [`thermion_flutter_web` - `v0.0.1+1`](#thermion_flutter_web---v0011)
 - [`thermion_flutter_platform_interface` - `v0.1.0+1`](#thermion_flutter_platform_interface---v0101)
 - [`thermion_flutter_ffi` - `v0.1.0+1`](#thermion_flutter_ffi---v0101)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_platform_interface` - `v0.1.0+1`
 - `thermion_flutter_ffi` - `v0.1.0+1`

---

#### `thermion_dart` - `v0.1.0+1`

 - **REFACTOR**: export ThermionViewerWasm for web and hide FFI/WASM version.
 - **FIX**: use preserveDrawingBuffer=true on web.

#### `thermion_flutter` - `v0.1.1+1`

 - **REFACTOR**: export ThermionViewerWasm for web and hide FFI/WASM version.
 - **FIX**: catch exception if gizmo unavailable in ThermionGestureDestectorDesktop.

#### `thermion_flutter_web` - `v0.0.1+1`

 - **REFACTOR**: export ThermionViewerWasm for web and hide FFI/WASM version.

