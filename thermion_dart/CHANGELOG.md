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
