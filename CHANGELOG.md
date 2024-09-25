# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2024-09-25

### Changes

---

Packages with breaking changes:

 - [`thermion_dart` - `v0.2.0-dev.4.0`](#thermion_dart---v020-dev40)
 - [`thermion_flutter_web` - `v0.1.0-dev.4.0`](#thermion_flutter_web---v010-dev40)

Packages with other changes:

 - [`thermion_flutter` - `v0.2.0-dev.4.0`](#thermion_flutter---v020-dev40)
 - [`thermion_flutter_platform_interface` - `v0.2.0-dev.4.0`](#thermion_flutter_platform_interface---v020-dev40)
 - [`thermion_flutter_ffi` - `v0.2.0-dev.4.0`](#thermion_flutter_ffi---v020-dev40)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter` - `v0.2.0-dev.4.0`
 - `thermion_flutter_platform_interface` - `v0.2.0-dev.4.0`
 - `thermion_flutter_ffi` - `v0.2.0-dev.4.0`

---

#### `thermion_dart` - `v0.2.0-dev.4.0`

 - **BREAKING** **FIX**: (web/wasm) free pick callbacks on dispose.
 - **BREAKING** **CHORE**: restructure viewer folders as libraries to only export the public interface.

#### `thermion_flutter_web` - `v0.1.0-dev.4.0`

 - **BREAKING** **CHORE**: restructure viewer folders as libraries to only export the public interface.


## 2024-09-25

### Changes

---

Packages with breaking changes:

 - [`thermion_flutter` - `v0.2.0-dev.3.0`](#thermion_flutter---v020-dev30)

Packages with other changes:

 - There are no other changes in this release.

---

#### `thermion_flutter` - `v0.2.0-dev.3.0`

 - **BREAKING** **FIX**: remove EntityControllerMouseWidget (replace with GestureHandler).
 - **BREAKING** **CHORE**: (flutter) cleanup for pub.dev publishing.


## 2024-09-25

### Changes

---

Packages with breaking changes:

 - [`thermion_flutter` - `v0.2.0-dev.2.0`](#thermion_flutter---v020-dev20)

Packages with other changes:

 - There are no other changes in this release.

---

#### `thermion_flutter` - `v0.2.0-dev.2.0`

 - **BREAKING** **CHORE**: remove EntityListWidget - will replace with new Scene.


## 2024-09-25

### Changes

---

Packages with breaking changes:

 - [`thermion_dart` - `v0.2.0-dev.1.0`](#thermion_dart---v020-dev10)
 - [`thermion_flutter` - `v0.2.0-dev.1.0`](#thermion_flutter---v020-dev10)
 - [`thermion_flutter_ffi` - `v0.2.0-dev.1.0`](#thermion_flutter_ffi---v020-dev10)
 - [`thermion_flutter_platform_interface` - `v0.2.0-dev.1.0`](#thermion_flutter_platform_interface---v020-dev10)
 - [`thermion_flutter_web` - `v0.1.0-dev.1.0`](#thermion_flutter_web---v010-dev10)

Packages with other changes:

 - There are no other changes in this release.

---

#### `thermion_dart` - `v0.2.0-dev.1.0`

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

#### `thermion_flutter` - `v0.2.0-dev.1.0`

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

#### `thermion_flutter_ffi` - `v0.2.0-dev.1.0`

 - **FEAT**: (flutter) move DPR calculation to resizeTexture and add createViewerWithOptions method to ThermionFlutterFFI.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.

#### `thermion_flutter_platform_interface` - `v0.2.0-dev.1.0`

 - **FEAT**: add createViewerWithOptions to ThermionFlutterPlugin and mark createViewer as deprecated.
 - **FEAT**: add ThermionFlutterOptions classes, rename interface parameter for offsetTop and ensure pixelRatio is passed to resizeTexture.
 - **BREAKING** **FIX**: (flutter) pass pixelRatio to createTexture.

#### `thermion_flutter_web` - `v0.1.0-dev.1.0`

 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FEAT**: (flutter) (web) use options to determine whether to create canvas, and set fixed position + offset.
 - **FEAT**: add ThermionFlutterOptions classes, rename interface parameter for offsetTop and ensure pixelRatio is passed to resizeTexture.
 - **BREAKING** **FEAT**: (flutter) (web) upgrade package:web dep to 1.0.0.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.


## 2024-07-23

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`thermion_dart` - `v0.1.3`](#thermion_dart---v013)
 - [`thermion_flutter_ffi` - `v0.1.0+12`](#thermion_flutter_ffi---v01012)
 - [`thermion_flutter_web` - `v0.0.3`](#thermion_flutter_web---v003)
 - [`thermion_flutter_platform_interface` - `v0.1.0+11`](#thermion_flutter_platform_interface---v01011)
 - [`thermion_flutter` - `v0.1.1+13`](#thermion_flutter---v01113)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `thermion_flutter_platform_interface` - `v0.1.0+11`
 - `thermion_flutter` - `v0.1.1+13`

---

#### `thermion_dart` - `v0.1.3`

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

