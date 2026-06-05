## 0.4.0

> Note: This release has breaking changes.

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

## 0.3.4+1

 - **FIX**: loosen dependency versions for code_assets, hooks and native_toolchain_c.

## 0.3.4

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

## 0.3.3

 - Bump "thermion_dart" to `0.3.3`.

## 0.3.3-pre

 - **FIX**: fix Windows build.dart.
 - **FIX**: add nan/negative checks inside setLensProjection.

## 0.3.2

 - Bump "thermion_dart" to `0.3.2`.

## 0.3.1

 - **REFACTOR**: remove covariant keyword from createInstance args.
 - **FIX**: add flush() to skybox/IBL destroy methods to ensure that textre upload callbacks are completed to avoid stalling.
 - **FIX**: duplicate setting for _grid.

## 0.3.0

 - n

## 0.3.0

> Note: This release has breaking changes.

 - **REFACTOR**: gizmo/input handler improvements.
 - **REFACTOR**: add createGizmoRenderThread.
 - **REFACTOR**: Gizmo internals.
 - **REFACTOR**: dont require GizmoInputHandler to wrap an existing InputHandler (you can do this by creating your own InputHandler that wraps two children.
 - **FIX**: glTF instancing when loaded via buffer.
 - **FIX**: don't return entity from SceneManager_addLightRenderThread.
 - **FIX**: return light entity from SceneManager.
 - **FIX**: store reference to material instances in ThermionViewer so they can be cleaned up on dispose.
 - **FIX**: remove MaterialInstance from SceneManager storage when destroyed.
 - **FIX**: add destroyCamera to ThermionViewer interface.
 - **FIX**: UV calculation for geometry.
 - **FIX**: use createGizmoRenderThread.
 - **FIX**: remove MaterialInstance from SceneManager storage when destroyed.
 - **FIX**: move removeIbl to render thread.
 - **FIX**: move material/instance creation to render thread.
 - **FIX**: allow destroying instances independently of owner.
 - **FIX**: remove MaterialInstance from SceneManager storage when destroyed.
 - **FIX**: use render thread methods for grid overlay creation and create ubershader instance.
 - **FIX**: only use Windows-style ndkRoot when building on Windows.
 - **FIX**: set overlay layer visibility when adding grid.
 - **FIX**: only use Windows-style ndkRoot when building on Windows.
 - **FIX**: when creating geometry, normals/uvs are set to false by default. remove wirefame camera container (can now be replaced by bounding box methods.
 - **FIX**: fix highlights after first.
 - **FEAT**: remove bounding box from SceneAsset and create renderable wireframe bounding box in ThermionAsset.
 - **FEAT**: add setTransparencyMode to Dart Material class.
 - **FEAT**: expose attached entity as Stream on GizmoInputHandler.
 - **FEAT**: allow custom material for grid overlay, and material creation from Uint8List.
 - **FEAT**: allow setting material instance directly on ThermionAsset.
 - **FEAT**: allow passing custom material for grid overlay.
 - **FEAT**: allow passing custom material for grid overlay.
 - **FEAT**: allow passing custom material for grid overlay.
 - **FEAT**: more rotation gizmo improvements.
 - **FEAT**: rotation gizmo improvements.
 - **FEAT**: add rotation gizmo.
 - **FEAT**: add rotation gizmo asset + resource file.
 - **FEAT**: add rotation gizmo asset + resource file.
 - **FEAT**: use existing material instances when creating an instance of GeometrySceneAsset and no material instance is passed.
 - **FEAT**: re-implement grid overlay.
 - **FEAT**: add gizmo.glb to assets/resources.
 - **FEAT**: add TRACE macro.
 - **FEAT**: update Filament to v1.56.4.
 - **FEAT**: expose setCastShadows/setReceiveShadows.
 - **FEAT**: re-add uvScale, vertexScale to unlit material.
 - **FEAT**: re-add uvScale, vertexScale to unlit material.
 - **BREAKING** **REFACTOR**: move light methods from FilamentViewer to SceneManager/TLightManager and rename clearLights/clearAssets to destroyLights/destroyAssets.
 - **BREAKING** **REFACTOR**: rename removeAsset to destroyAsset.
 - **BREAKING** **FIX**: rename removeEntity to removeAsset.
 - **BREAKING** **FEAT**: change default near/far to 0.1/100.0.
 - **BREAKING** **FEAT**: use raw pointer scale (>1 meaning zoom in, <1 meaning zoom out) rather than binary -1/1 for DelegateInputHandler.
 - **BREAKING** **FEAT**: remove Viewer setRenderTarget method (use the View method instead).

## 0.2.1-dev.20.0

 - **FIX**: only use Windows-style ndkRoot when building on Windows.

## 0.2.1-dev.19.0

> Note: This release has breaking changes.

 - **FEAT**: use InputAction.ZOOM for scroll wheel in free flight handler.
 - **FEAT**: free flight camera improvements.
 - **BREAKING** **FIX**: update Makefile & rebuild materials for Vulkan.

## 0.2.1-dev.18.0

 - **FEAT**: add MaterialInstance.setDepthFunc.

## 0.2.1-dev.0.0.17

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

## 0.2.1-dev.0.0.16

 - **FEAT**: Rename Gizmo material to UnlitFixedSize, and expose methods for using this material on other entities. Also exposes new methods for setting single float parameters.

## 0.2.1-dev.0.0.15

 - **FIX**: remove superfluous ceil() calls for picking coordinates.
 - **FEAT**: expose zoomSensitivity argument for flight input handler.

## 0.2.1-dev.0.0.14

 - **FIX**: reduce size of pick functor for compatibility with armeabi-v7a.
 - **FEAT**: sanitize file paths in build.dart for Windows compatibility.
 - **FEAT**: pass through fragment coordinates for picking.
 - **FEAT**: pass through fragment coordinates for picking.

## 0.2.1-dev.0.0.13

 - **FIX**: properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
 - **FIX**: properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
 - **FEAT**: pass through fragment coordinates for picking.
 - **FEAT**: add SCALE2_MOVE InputType.
 - **FEAT**: add SCALE2_MOVE InputType.

## 0.2.1-dev.0.0.12

 - **FIX**: properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
 - **FIX**: properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
 - **FEAT**: add SCALE2_MOVE InputType.
 - **FEAT**: add SCALE2_MOVE InputType.

## 0.2.1-dev.0.0.12

 - **FIX**: properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
 - **FEAT**: add SCALE2_MOVE InputType.

## 0.2.1-dev.0.0.11

> Note: This release has breaking changes.

 - **FEAT**: add SCALE2_ROTATE to InputHandler.
 - **BREAKING** **FEAT**: expose velocity, rotation and timestamp for scale events in listener. accept rotationSensitivity/zoomSensitivity for FixedOrbitRotateInputHandlerDelegate.

## 0.2.1-dev.0.0.10

> Note: This release has breaking changes.

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

## 0.2.1-dev.0.0.9

> Note: This release has breaking changes.

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

## 0.2.1-dev.0.0.8

 - **FIX**: move ThermionWin32.h to include.

## 0.2.1-dev.0.0.7

 - Bump "thermion_dart" to `0.2.1-dev.0.0.7`.

## 0.2.1-dev.0.0.6

 - Bump "thermion_dart" to `0.2.1-dev.0.0.6`.

## 0.2.1-dev.0.0.5

 - Bump "thermion_dart" to `0.2.1-dev.0.0.5`.

## 0.2.1-dev.0.0.4

## 0.2.1-dev.0.0.3

 - Bump "thermion_dart" to `0.2.1-dev.0.0.3`.

## 0.2.1-dev.0.0.2

## 0.2.1-dev.0.0.1

## 0.2.1-dev.0.0.0

 - y

## 0.2.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.2.0-dev.8.0.0

> Note: This release has breaking changes.

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

## 0.2.0-dev.7.0

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: fix min SDK for thermion_dart.

## 0.2.0-dev.6.0

> Note: This release has breaking changes.

 - **BREAKING** **CHORE**: cleanup deleted export.

## 0.2.0-dev.5.0

> Note: This release has breaking changes.

 - **BREAKING** **CHORE**: remove EntityTransformController (requires replacement).

## 0.2.0-dev.4.0

> Note: This release has breaking changes.

 - **BREAKING** **FIX**: (web/wasm) free pick callbacks on dispose.
 - **BREAKING** **CHORE**: restructure viewer folders as libraries to only export the public interface.

## 0.2.0-dev.1.0

> Note: This release has breaking changes.

 - **REFACTOR**: native types.
 - **REFACTOR**: native types.
 - **REFACTOR**: move native types to own header, add methods for create/destroy material instance, add priority/layer to load_glb_from_buffer.
 - **REFACTOR**: Dart types.
 - **FIX**: (web) add emscripten guards for flushAndWait call when swapchain destroyed.
 - **FIX**: ignore pick results directly on axis.
 - **FIX**: properly destroy entities/material/etc in Gizmo on destruction, remove custom scene creation logic.
 - **FIX**: add check for nan NDC coordinates for viewport translation.
 - **FIX**: (wasm) use correct coords for pick, free memory correctly, keep pixelratio copy.
 - **FIX**: add more nan checks for gizmo manipulation.
 - **FIX**: emscripten export visibility for add_light.
 - **FIX**: add Fence to capture() and set stencil buffer by default.
 - **FEAT**: add removeStencilHighlight, queuePositionUpdateFromViewportCoords to ThermionViewer.
 - **FEAT**: add removeStencilHighlight, accept color param for setStencilHighlight, queuePositionUpdateFromViewportCoords to ThermionDartApi.
 - **FEAT**: add flag for keepData for gltf instancing, add highlightScene, add stencilHighlight method.
 - **FEAT**: grid uses own material.
 - **FEAT**: parent the cloned entity instance when setting stencil highlight.
 - **FEAT**: add grid material.
 - **FEAT**: expose setLightDirection and setLightPosition.
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

## 0.1.3

 - **FIX**: manually remove leading slash for compiler path on Windows when building for Android.
 - **FIX**: web/JS bool checks need to compare to int.
 - **FIX**: shadow JS<->WASM bridge methods.
 - **FIX**: manually remove leading slash for compiler path on Windows when building for Android.
 - **FIX**: web/JS bool checks need to compare to int.
 - **FIX**: shadow JS<->WASM bridge methods.
 - **FEAT**: add clearMorphAnimationData function.
 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.
 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.

## 0.1.2

 - **FIX**: manually remove leading slash for compiler path on Windows when building for Android.
 - **FIX**: web/JS bool checks need to compare to int.
 - **FIX**: shadow JS<->WASM bridge methods.
 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.

## 0.1.1+5

 - Bump "thermion_dart" to `0.1.1+5`.

## 0.1.1+4

 - **FIX**: defer creating image entity/material/etc until actually requested.

## 0.1.1+3

 - **FIX**: bump ffigen dependency version & regenerate bindings (and revert to ffi.Int rather than ffi.Int32).
 - **DOCS**: update homepage links and minor documentation updates.

## 0.1.1+2

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.1.1-dev.0+2

 - **FIX**: revert to std::thread (pthreads not easily available on Windows).
 - **FIX**: on Windows, pass static libs via -l rather than custom linkWith property so build.dart stays compatible between published & custom versions.

## 0.1.1+1

 - **DOCS**: update with links to playground.

## 0.1.1

 - Bump "thermion_dart" to `0.1.1`.

## 0.1.0+4

 - **FIX**: add dummy asset to build.dart on Linux builds so we can use the package on a Linux host.

## 0.1.0+3

 - **FIX**: exit build.dart early on Linux builds so we can use the package on a Linux host.

## 0.1.0+2

 - **REFACTOR**: rearrange some stubs/imports for easier web WASM deployment.

## 0.1.0+1

 - **REFACTOR**: export ThermionViewerWasm for web and hide FFI/WASM version.
 - **FIX**: use preserveDrawingBuffer=true on web.

## 0.0.1
* First release of Dart-only package
