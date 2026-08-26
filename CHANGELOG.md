> Shared changelog for `thermion_dart` and `thermion_flutter` (released in lockstep).

## Unreleased

### Changes

- `FilamentApp` exposes the native engine handle as a public
- `TranslationAxisMaterial.createMaterialInstance` and `ToneMapper` factory methods
  now take the abstract `FilamentApp` instead of
  `FFIFilamentApp`
- `ColorGrading` follows Filament's ownership model (caller
  manages lifecycle). A `ColorGrading` must be dissociated from every view
  (`setColorGrading` with a replacement or null) BEFORE calling
  `ColorGrading.dispose()`. Attaching one grading to multiple views
  remains supported, but its lifetime is entirely yours. 
- `ColorGrading` and `ColorGradingBuilder` expose `dispose()` through the
  public interface (previously FFI-only / missing). 
- `Skybox` is now exported from the public API with methods for layer mask, intensity, etc.  
- `ThermionViewer.setBackgroundColor` and `ThermionViewer.loadSkybox` now
  return the created `Skybox`, and
  `ThermionViewer.getSkybox` returns whatever skybox is currently attached
  to the viewer's scene. The viewer no longer caches the skybox internally:
  `removeSkybox` derives it from the scene, detaches it, and returns it without
  destroying caller-owned resources.
  Native library rebuild required (C API signatures for
  the skybox builders changed).
- `RenderableBuilder.geometryNonIndexed` and
  `ThermionRenderableManager.setGeometryAtNonIndexed` expose Filament's
  non-indexed geometry, so procedural geometry (e.g. particles) can render
  without an `IndexBuffer`, including attribute-less vertex buffers built
  with `bufferCount(0)`. Native library rebuild required.
- Fix intermittent `RenderableManager.setMorphWeights` crashes by validating
  source ranges, copying FFI payloads before asynchronous dispatch, and
  applying updates on the owning render thread. This also prevents temporary
  morph-weight buffers from leaking Emscripten stack space on web.
- Add `MorphTarget` and asset-bound `MorphTargetSet` APIs for discovering the
  entity, index, and optional name of every morph target. Named and indexed
  updates no longer require callers to construct an opaque full weight array;
  strict full-pose updates remain available through `setAllWeights`.
- Apply overlapping custom morph animations oldest-first so the most recently
  added animation has final priority for shared targets. Active animations
  continue to overwrite manual weights on their next update.
- Fix `VertexBufferMode.editable` glTF assets so their vertex streams can be
  updated through `VertexBuffer.setBufferAt`; editable buffers no longer use
  the `BufferObject` backing reserved for unwelded smooth/flat shading swaps.
  Buffer updates, flat shading, and stencil highlighting now throw actionable
  errors when used with incompatible buffer storage or asset capabilities.
- Expose native `VertexBuffer.storageMode` metadata and first-class
  `BufferObject` creation, upload, and attachment APIs. `supportsSetBufferAt`
  is now derived from immutable metadata supplied by the native builder or
  owning asset, without a global pointer registry or duplicated glTF load
  state in Dart. Asset-owned vertex buffers are explicitly borrowed.

### Breaking changes
- Replace the `rebuildVertices` in `ThermionViewer.loadGltf`,
  `ThermionViewer.loadGltfFromBuffer`, and `FilamentApp.loadGltfFromBuffer` with
  `vertexBufferMode: VertexBufferMode.unwelded`. Use
  `VertexBufferMode.editable` when mutable indexed topology is required.
  `original` leaves gltfio geometry untouched, `unwelded` creates per-triangle
  vertices with barycentric coordinates, and `editable` exposes mutable vertex
  buffers while preserving source vertex order, indices, and morph-target
  compatibility. 
- remove the unused `FilamentApp.createColorGrading` — it returned a raw
  pointer nobody could destroy; use `View.createColorGradingBuilder().build()`
  instead.
- remove `View.setToneMapper` and `ThermionViewer.setToneMapper` - use
  `view.createColorGradingBuilder().toneMapper(...).build()` followed by
  `view.setColorGrading()` instead.
- Replace `ThermionAsset.getMorphTargetNames` and `setMorphTargetWeights` with
  `getMorphTargets` / `getMorphTargetSets`. `RenderableManager.setMorphWeights`
  now infers and enforces the complete target count; use `setMorphWeightAt` for
  a single indexed update.

## 0.6.0

Update to Filament v1.75.0!

### Changes
- `allocate` FFI shim now takes `byteCount` instead of `count`
- Add SAO/GTAO algorithm selection and GTAO sampling, thickness, and
  visibility-bitmask controls to `AmbientOcclusionOptions`.
- Expose global and per-light PCSS penumbra and blocker-search controls.
- Expose visible-renderable diagnostics on views.

### Breaking changes
- `LightManager.setShadowCaster`/`setShadowOptions` and
  `RenderableManager.setCastShadows`/`setReceiveShadows` now return `Future`
  instead of `void` (internally, these now correctly run on the
  main Filament thread).


## 0.5.0-pre.5

- Rework the CI release pipeline: releases are cut from `develop` via a manual
  dispatch of `Create Release`, which tags the develop tip and publishes both
  packages plus the docs site.
- Add publish gates (dry-run validation, regenerated-binding verify checks, full
  test matrix) that run before anything reaches pub.dev.

## 0.5.0-pre.2

### New features
- add a WASM gallery of Dart examples, embedded in the documentation site. The
  gallery is deployed alongside the docs to thermion.dev (Cloudflare Pages) and
  only updates on release tags.
- add resolution/aspect presets to the headless `render_demo` CLI example.

### Fixes
- correct procedural geometry and WebGL material lighting.
- dispatch `setGltfAnimationTime` on the render thread; it previously applied
  morph-target weights on the caller's thread and panicked (debug assertion)
  for any glTF animation driving morph weights.
- apply the glTF animation on the first `update()` call; the first rendered
  frame after playback started was previously the asset's rest/export pose
  instead of animation-frame-0.
- update the `thermion_flutter` dependency on `thermion_dart` to 0.5.0-pre.2.

## 0.5.0-pre

### Breaking changes
- `ToneMapper.linear/aces/acesLegacy/filmic/pbrNeutral/agx/generic` now take
  the owning `FFIFilamentApp` as their first argument (engine-scoped objects no
  longer read `FilamentApp.instance`).
- `ThermionViewerFFI` now requires an explicit `app` argument.
- remove the releaseSourceData parameter from createGeometry — source-data
   release only applies to glTF assets, so call releaseSourceData() on the
   returned asset instead.
- engine-scoped FFI objects now retain their owning `FFIFilamentApp`;
   `ThermionViewerFFI` and tone-mapper factories require it explicitly.
- `ThermionFlutterPlugin.initialize()` now returns `InitializeResult`, and
   `ThermionWidgetInternal.surfaceWidgetBuilder` receives the owning `View`.
- `WebOptions.importCanvasAsWidget` now defaults to `true`.
- fix web multi-viewer hang: scope RenderManager attachment state per engine
   so a viewer only syncs its own swapchains/views.

### New features
 - add web multi-viewer support with one engine, render thread, WebGL context,
   and canvas per viewer.
 - add `WebOptions.maxViewers`, per-viewer canvas IDs and lifecycle hooks, and
   host web canvases inside each viewer widget by default.

### Fixes
 - route loadKtx2 through the render thread on web.
 - pick readPixels type per-view from render-target format.
 - add BLIT_SRC|BLIT_DST when decodeToTexture asks mipmaps.
 - free stb buffer after LinearImage decode.
 - add Engine_destroyRenderer + RenderThread variant.
 - add releaseSourceData() to ThermionAsset so the CPU-side glTF source copy
   can be freed after all instances have been created.
 - update the thermion_flutter dependency on thermion_dart to 0.5.0-pre.
 - scope render attachment state per engine so one web viewer never submits
   another engine's views or swapchains.
 - apply the glTF animation on the first `update()` call; the first rendered
   frame after playback started was previously the asset's rest/export pose
   instead of animation-frame-0.
 - dispatch `setGltfAnimationTime` on the render thread; it previously applied
   morph-target weights on the caller's thread and panicked (debug assertion)
   for any glTF animation driving morph weights.

## 0.4.1
- re-publish without Melos

## 0.4.0

### New features:
- improved Windows Vulkan support (including improvements for resizing to eliminate texture jank on/black frame flash)
- experimental Linux desktop support (Wayland + Vulkan) 
- improved web support, almost at feature parity with native platforms (#150). 
- use platform-specific vsync to schedule frames, rather than Flutter's SchedulerBinding. (#112). In debug mode, uses a Dart Send/ReceivePort to communicate the frame callback. In release mode, the raw function pointer is used. Only applicable to macos, ios, Android and Windows.
- added `parseGltf` method to FilamentApp (#95). Allows parsing/manipulating vertex/index buffers from a raw glTF file.
- updated Filament to `v1.69.1`
- added custom attribute support in createGeometry.
- fixed various issues with multiple viewers (simultaneous and sequential).
- expose geometry VertexBuffer from ThermionAsset.
- create Dart `LightManager` interface. 

### Breaking changes:
- replace register/unregiser/updateRenderOrder on FilamentApp with a `RenderManager` interface. Call `attach` and `detach` to mark a view as renderable.
- GeometryHelper renamed to GeometryUtils
- rename setGltfAnimationFrame to setGltfAnimationTime (correct time units) (#141).
- remove unused entity parameter from DelegateInputHandler parameters.
- remove `batch` arg from DelegateInputHandler.
- add ColorGradingBuilder. you can no longer set ColorGrading on a View with a ToneMapping/ToneMapper enum; now, create an instance of ToneMapper and use the ColorGradingBuilder.toneMapper() method.
- change existing setColor to setColorTemperature, and add method to setColor with linear RGB.
- create AnimationManager interface (allowing users to manually progress the animation time for testing).
- bump hooks/code_assets/test dependencies. This release now requires Flutter >=
- add quad() to GeometryHelper (different from fullscreenQuad).
- expose Engine.setAutomaticInstancingEnabled (#92).
- (flutter) migrate overlay implementation to use stacked widgets, each with a render target. Only macOS, iOS and Windows supported in this commit. (#110).
- change shadow transform to Quaternion (not List<double>).
- return double3 from LightManager_getColor.
- create RenderableManager Dart interface/implementation.
- set translation axis priority to 0 (renders first).
- set grid priority to 6 (renders second-last).
- FreeFlightInputHandlerDelegateV2 manages its own frame hook.
- replace InputHandlerManagerException with Exception and remove ffi. prefix from InputPipeline.
- move Swift/ObjC interop lib/headers from thermion_dart to thermion_flutter. In theory we can use these on macOS to create/import external textures as render targets in Dart applications. In practice, this requires the Flutter SDK (for objective_c) so it's not actually very practical. We previously used these to test external texture render targets; now that we run tests mostly on Linux, this is no longer used (render targets are created, but bound to textures created by Filament). However this may be useful to revisit in future so we will preserve the files in thermion_flutter.
- use const LinearColor for default DirectLight.
- remove createImageMaterialInstance from FilamentApp API.
- move AnimationManager to FilamentApp.
- remove hasHighlights() from View. This means the overlay will be rendered if enableHighlightOverlay() has been called, even if no assets are highlighted.
   
### Miscellaneous:
- prevent concurrent modification in FFIFilamentApp.destroy to prevent exception when 2+ swap chains existed.
- default baseColorFactor to white when hasBaseColorTexture is true.
-  In createEntity() in ffi_filament_app.dart, transformManager.createComponent() was being called without an await. This led to cases where calls to the transform would silently fail after calling createEntity() because the transform hadn't added yet. (#138).
- add RenderThread methods for TransformManager createComponent/removeComponent.
- rename (T)ToneMapping to (T)ToneMapper.
- expose isMacos arg to createHeadlessSwapchain to use TSWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER.
- remove width/height from RenderTarget_create functions. The… (#128).
- replace C++ GridOverlay implementation with Dart.
- ubershader expects UV0 and UV1. Create these for geometry if not otherwise specified.
- rename TInputHandlerPipeline to TTransformPipeline and add ffigen_fix.h to fix problem with ffigen not generating EMSCRIPTEN_KEEPALIVE for definition in APIExport.h header outside the directory for TTransformPipeline.h etc.
- remove Scene* from AnimationManager, this is no longer needed as components are used for animation, not the Scene object list.
- move equality/hashcode overrides to NativeHandle. This allows us to treat all instances of classes that wrap native handles (FFIView, FFIRenderTarget) etc as the same (since they carry no state and only exist to pass-through to native methods).
- merge macOS/iOS thermion_flutter plugin files into a single darwin/ folder.
- upload JS/WASM to Cloudflare R2 rather than storing in repository (#148).
- fix setting highlight color consecutively not updating color.
- add/use RenderThread methods for EntityManager_createEntity/destroyEntity.
- destroy renderable in GeometrySceneAsset destructor.
- add check/log/return for bluevk::initialize() failure.
- force RGBA decode on Windows for PNG background uploads.
- destroy an entity's renderable component before destroying the entity. We also convert TransformManager methods to use RenderThread to help debugging.
- copy gltf resource data to heap allocated std::vector<uint8_t>.
- add 30 second timeout to Engine_createRenderThread call in FFIFilamentApp to ensure an exception is thrown if some fatal failure is encountered (e.g. Vulkan drivers can't be found).
- throw Exception when failing to pull static lib zip file.
- pass frame start in nanos, not delta in float. 
-  make sure String pointers are freed after use.
-  bump ffigen_js dependency for missing Pointer.fromAddress on web.
-  consistent screen-space axis line width on the translation gizmo (#143).
-  use RenderThread methods for various Scene_/View_ calls.
-  dont destroy the camera entity after destroying the camera component (presumably the latter does the former internally; if we try and destory again, this will crash when assertions are enabled.
-  enable postProcessing on highlight view but disable tone mapping.
 -  delete duplicated tone mapper.
 -  remove public dispose() method from ColorGrading, this should be managed by the relevant View.
 -  properly export GltfMeshData.
 -  temporarily disable AO options for ffigen/js compat.
 -  if irradiance/reflections texture are the same in FFIIndirectLight, don't destroy both.
 -  correctly remove views from internal swapchain mapping when destroyView is called.
 -  return actual MaterialInstance from FFITexturedQuad.getMaterialInstanceAt (#147).
 -  migrate FFITexturedQuad.
 -  move setName call to first after view creation.
 -  set default name for view.
 -  dont throw Exception if removeStencilHighlight is called when no overlay manager is available.
 -  change View.getName() interface to return String?
 -  bugs in wireframe/rebuildVertices and add flatShading toggle (#149).
 -  add missing Log include on Linux.
 -  check for no swapchain before enabling highlight overlay, and make sure calls to RenderManager.attach/detach are properly awaited.
 -  always loadResourcesAsync when FILAMENT_SINGLE_THREADED is true.
 -  make sure view handles are freed and cleanup some logging.
 -  bounding box calculation.
 -  only check path relative to package root when checking which source files to exclude. Prevents false exclusions when the parent directory names contain excluded strings (e.g., "/fix-rebuild-vertices/thermion").
 -  fix incorrect pixel buffer format key for macOS texture wrapper.
 -  add entity→primitive offset mapping for multi-mesh highlighting.
 -  gltf animation cross-fading.
 -  temporarily disable gltfmesh parsing, ambient occlusion options and bone names (require support in ffigen_js) first.
 -  throw exception in setProjectionFromFieldOfView where inputs are invalid (NaN/non-positive FOV etc).
 -  late initialization of HighlightOverlayManager.
 -  call destroyAsset when TexturedQuad is disposed and correctly set texture usage flags.
  -  correct the order in which highlight overlay resources are disposed, and disable postprocessing/use correct texture format for colour correctness.
 -  (linux) remove incorrect linked libraries.
  -  don't import dart:ffi into FFIView (access nullptr via the Thermion ffi.dart instead).
  -  percent-decode resource URIs before filesystem lookup.
 -  reinstate rendering with multiple swapchains. I'm not sure if we can create a hardware texture rendertarget on the GLES backend for Android (though this should be possible on Vulkan), so to implement overlays we need to allow multiple swapchains.
 -  add #ifdef __cplusplus guards for new overlay materials.
  -  use render thread methods for TransformManager.setParent, Scene.… (#159).
 -  use uint32_t for gltf instances, not uint8_t.
 -  Ubuntu LLVM libc++ fails to compile since.
  -  add LOG_ERROR def for Windows compatibility.
 -  orthographic projection not being set correctly.
 -  use LOG_ERROR in TAnimationManager.cpp for Windows compatibility.
 -  windows used different vulkan devices.
 -  add message to exception when captureRenderTarget is true but view has no render target.
 -  define __builtin_popcountll __popcnt64for Windows compatibility.
 -  in loadGltf, normalise paths in Windows so we can correctly determine resourceUri.
 -  reinstate raw gltf parsing (this was broken on Windows due to MSVC incompatibilities (#90).
 -  use RGBA32F instead of RGB32F for 3-channel background images on Windows.
 -  return camera frustum in cameraspace (not worldspace, returned by Filament by default).
 -  implement missing js_interop withIntCallback.
 - (windows): prevent VkImage double-free on texture resize.
  - use explicitSwapControl on web. In theory this should require emscripten_webgl_commit_frame() but in practice this works without it - I'm not sure it actually makes a difference but (without profiling) it feels slightly smoother.
 - rename and consolidate Metal Texture creation classes on macOS/iOS.
  - various changes needed to support HighlightOverlayManager on web.
- add Dart RenderManager class.
- create View_getNameRenderThread to help debug crash. also add FFIView.create() for the same reason.
- stop passing FilamentApp instance around and stop casting to FFI* classes.
- rename Swift texture wrapper filename and update tests. 
- expose SurfaceOrientationBuilder (#91).
- (web) define PLUGIN_SOURCES compiled for web.
 - set camera projection from horizontal/vertical field of view.
 - support all alphanumeric keys in InputHandler.
 - add FilamentApp.createColoredSkybox.
 - add FilamentApp.createColoredSkybox.
 - expose View.getName().
 - add createScene option to FilamentApp.createView.
 - add getFogOptions() to View.
 - implement dummy plugin system with on_frame_update.
 - export includeDirs and outputDir in build.dart to facilitate plugin builds.
 - allow creating a Camera for an arbitrary entity (equivalent to attaching a camera component).
 - allow setting grid overlay axis colors directly (and allow showing/hiding spcific axes).
 - expose Engine.getMaxAutomaticInstances().
 - add speed argument for playGltfAnimation.
 - remove unnecessary Texture format check in Texture_setImage.
 - add mouse button bindings for InputPipeline.
 - add custom key bindings/intents and use int mask for intents.
 - expose instances() on RenderableManagerBuilder (#93).
 - allow setting grid spacing/fade distances in ThermionViewer setGridOverlayVisibility.
 - add setAmbientOcclusionOptions for View.
 - add wireframe material.
 - add setTransformAsync method. This may sometimes be needed when something during the internal render() call sets a transform and you need strict ordering guarantees.
 - add translation axis material.
 - add setParameterMat3.
 - add translation axis material.
 - add raw gltf parser (via cgltf).
 - add Material.getBlendingMode()/MaterialInstance.getTransparencyMode().
 - Transform Pipeline.
 - auto-download web artifacts from thermion_dart build hook.
 - add Camera getAperture/getShutterSpeed/getSensitivity.
 - expose LUT format and dimensions on ColorGradingBuilder (#155).
 - add registerTransformExecutor to pipeline.
 - add shadow/winding order methods to Dart View.
 - add Dart LightManager interface.
 - add const consturctor to DirectLight.
 - add set/getVsmShadowOptions to View.
 - add static LightManager methods to compute shadow cascade splits.
 - add static LightManager methods to compute shadow cascade splits.
 - add/expand TransformManager, RenderableBuilder and RenderableManager interfaces.
 - destroyEntity().
 - add DebugRegistry and getLocalTransform to FilamentApp.
 - add groundPlane() to GeometryHelper.
 - add moveOnHover argument to input handler delegates.
 - add 2 more grid LOD levels.
 - PixelDataFormat.R now supported in pixel buffer conversion and capture (#140).
 - added BUILDING.md with instructions for compiling Filament from source.
 - delete old flight/orbit camera delegate.

 
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
