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
