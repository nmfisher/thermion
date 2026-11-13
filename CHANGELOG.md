> Shared changelog for `thermion_dart` and `thermion_flutter` (released in lockstep).

Earlier entries are consolidated. [Original detailed history](https://github.com/nmfisher/thermion/blob/29a53ae682891be0aed05c59fe7ad5f490d2e44e/CHANGELOG.md).

## 0.7.0 - 2026-11-13

- Add opt-in runtime material compilation on native and web, with includes,
  package metadata, and compiler diagnostics.
- Compile app materials at build time with caching, resgen output, and optional
  native embedding through `material_compilation.link_generated`.
- Ship pinned macOS material tools and fix Android and Windows material builds.
- Fix Wasm material/compiler memory leaks and pending gizmo callback lifetimes.
- Serialize native engine access and defer callbacks until the engine lock is released.
- Generate backend enums from Filament (`WEBGPU = 4`, `NOOP = 5`).
- **Breaking:** `setStencilHighlight` without an entity now highlights all
  renderables, including instances.

## 0.6.1 - 2026-11-02

- Fix Vulkan initialization on Vulkan 1.1 drivers, including Mesa Dozen.
- Fix Windows process-exit crashes during blit-worker teardown.
- Queue native picking on the owning job thread to avoid rendering races.
- Resolve glTF instances to their owning asset correctly.

## 0.6.0 - 2026-11-02

Upgrade to Filament 1.77.2. Recompile custom materials and rebuild native/Wasm
libraries together with their Dart bindings. Stable release of 0.6.0-pre.3.

### Breaking changes

- Linux requires Clang/libc++ 18; Flutter requires 3.44 / Dart 3.12.
- Replace `rebuildVertices` with `requiredGeometryCapabilities` when loading glTF.
- Replace morph-name/weight APIs with `getMorphTargets` / `getMorphTargetSets`;
  use `setMorphWeightAt` for individual weights.
- Rename `RenderThread` to `JobThread`, and `withIntCallback` to `withInt32Callback`.
- Await `RenderManager.destroy()` and light/renderable shadow setters.
- Implement `ThermionAsset.owner`; `instanceOwner` is deprecated.
- Bounding boxes are asset-owned and shared; destroy them with `asset.destroyBoundingBox()`.
- Create color grading through `View.createColorGradingBuilder()` and detach it
  from every view before disposal. `createColorGrading` / `setToneMapper` are removed.
- Remove the unused native `RenderManager_requestRender` API.
- Android uses Flutter's built-in Kotlin; apply the Kotlin plugin in your app if needed.

### Changes

- Add main-thread web rendering, independent frame rates, nonblocking pause,
  and worker command/callback queues.
- Add editable glTF geometry, buffer-storage metadata, `BufferObject` APIs,
  non-indexed geometry, and morph-target discovery and animation controls.
- Add GTAO/PCSS controls, renderable diagnostics, public engine access,
  and caller-owned skybox and color-grading APIs.
- Fix web struct bindings, frame admission, morph updates, asset ownership,
  geometry updates, and callback/resource cleanup.
- Reject incompatible material packages with `FormatException`.
- Disable C++ runtime exceptions; Filament panics abort. Host tools retain exceptions.
- Support Darwin SPM-only apps with `objective_c` 9.x; ship Linux material tools.

## 0.6.0-pre.3 - 2026-11-02

- Candidate for 0.6.0; refresh Swift bindings and release verification.

## 0.6.0-pre.2 - 2026-11-02

- Candidate for 0.6.0; fix ownership tests and release run lookups.

## 0.6.0-pre.1 - 2026-11-02

- Candidate for 0.6.0; fix web bindings, frame admission, and asset ownership errors.

## 0.6.0-pre.0 - 2026-11-01

- Initial 0.6.0 candidate. See 0.6.0 for the consolidated features and breaking changes.

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

- Add independent web viewers, per-viewer canvases, `maxViewers`, and lifecycle hooks.
- Add `ThermionAsset.releaseSourceData()` and improve animation, texture, and resource cleanup.
- **Breaking:** viewer and tone-mapper constructors require their owning app.
- **Breaking:** replace `createGeometry(releaseSourceData: ...)` with the asset method.
- **Breaking:** plugin initialization returns `InitializeResult`; surface builders receive a `View`.
- **Breaking:** `WebOptions.importCanvasAsWidget` defaults to `true`.

## 0.4.1

- re-publish without Melos

## 0.4.0

- Upgrade to Filament 1.69.1; improve Windows Vulkan, web parity, and multi-viewer support.
- Add experimental Linux Wayland/Vulkan support and platform vsync scheduling.
- Add glTF parsing, custom geometry attributes, vertex buffers, lighting,
  renderable, camera, material, and animation controls.
- Improve picking, gizmos, overlays, highlights, textures, and resource cleanup.
- **Breaking:** use `RenderManager.attach` / `detach` instead of app registration methods.
- **Breaking:** rename `GeometryHelper` to `GeometryUtils`, `setGltfAnimationFrame`
  to `setGltfAnimationTime`, and the old light `setColor` to `setColorTemperature`.
- **Breaking:** create tone mapping through `ColorGradingBuilder`; shadow rotation uses `Quaternion`.
- **Breaking:** input delegates lose entity/batch arguments; animation is managed by `FilamentApp`.
- **Breaking:** remove `createImageMaterialInstance` and `View.hasHighlights`.

## 0.3.4+1

- loosen dependency versions for code_assets, hooks and native_toolchain_c.

## 0.3.4

- rename requestId to textureUploadCompleteRequestId in KTX texture methods.
- only add matdb to macos builds in debug mode.
- add 16kb page size flags for Android builds and pin the ndkVersion for thermion_flutter to 28.2.13676358.
- (build) use targetOS rather than platform string.
- update code_assets, hooks and native_toolchain_c dependecies, and add check for buildCodeAssets (which throws an exception building for web).
- reinstate missing Struct.create.
- throw separate exceptions for invalid near/far/aspect/focalLength in FFICamera.setLensProjection.
- initialize isCubeMap in background image material to 0.
- throw Exception if render() is called when no swapchain.
- remove errant 'dart:io' import from FFIView.
- use aspect ratio of 1.0 if initial viewport width/height is 0.
- update image material with depth parameter.
- add TexturedQuad class (and refactor internally so the viewer uses this to implement the background image.
- add blending for grid lines.

## 0.3.3

- Bump "thermion_dart" to `0.3.3`.

## 0.3.3-pre

- fix Windows build.dart.
- add nan/negative checks inside setLensProjection.

## 0.3.2

- Bump "thermion_dart" to `0.3.2`.

## 0.3.1

- remove covariant keyword from createInstance args.
- add flush() to skybox/IBL destroy methods to ensure that textre upload callbacks are completed to avoid stalling.
- duplicate setting for _grid.

## 0.3.0

- Upgrade to Filament 1.56.4; add rotation gizmos, wireframe bounds, and custom grid materials.
- Expose material instances, transparency, shadow controls, and gizmo attachment streams.
- Fix glTF instances, geometry UVs, overlays, and material/resource cleanup.
- **Breaking:** move lighting to scene/light managers; rename removal APIs to destruction APIs.
- **Breaking:** camera near/far defaults become 0.1/100; pointer scale uses a continuous ratio.
- **Breaking:** set render targets through `View` instead of the viewer.

## 0.2.1-dev.20.0

- only use Windows-style ndkRoot when building on Windows.

## 0.2.1-dev.19.0

> Note: This release has breaking changes.
- use InputAction.ZOOM for scroll wheel in free flight handler.
- free flight camera improvements.
- **Breaking:** update Makefile & rebuild materials for Vulkan.

## 0.2.1-dev.18.0

- add MaterialInstance.setDepthFunc.

## 0.2.1-dev.0.0.17

- remove superfluous ceil() calls for picking coordinates.
- reduce size of pick functor for compatibility with armeabi-v7a.
- add Dart methods for getRenderableBoundingBox, setParameterInt and setParameterFloat4.
- Rename Gizmo material to UnlitFixedSize, and expose methods for using this material on other entities. Also exposes new methods for setting single float parameters.
- expose zoomSensitivity argument for flight input handler.
- sanitize file paths in build.dart for Windows compatibility.
- pass through fragment coordinates for picking.

## 0.2.1-dev.0.0.16

- Rename Gizmo material to UnlitFixedSize, and expose methods for using this material on other entities. Also exposes new methods for setting single float parameters.

## 0.2.1-dev.0.0.15

- remove superfluous ceil() calls for picking coordinates.
- expose zoomSensitivity argument for flight input handler.

## 0.2.1-dev.0.0.14

- reduce size of pick functor for compatibility with armeabi-v7a.
- sanitize file paths in build.dart for Windows compatibility.
- pass through fragment coordinates for picking.

## 0.2.1-dev.0.0.13

- properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
- pass through fragment coordinates for picking.
- add SCALE2_MOVE InputType.

## 0.2.1-dev.0.0.12

- properly pass through loadResourcesAsync flag for loadGlbFromBuffer.
- add SCALE2_MOVE InputType.

## 0.2.1-dev.0.0.11

> Note: This release has breaking changes.
- add SCALE2_ROTATE to InputHandler.
- **Breaking:** expose velocity, rotation and timestamp for scale events in listener. accept rotationSensitivity/zoomSensitivity for FixedOrbitRotateInputHandlerDelegate.

## 0.2.1-dev.0.0.10

- Add multiple views/render targets, Android/macOS widgets, iOS imported textures,
  web module downloads, capture, and camera controls.
- Add gizmos, highlights, grids, layers, material controls, and animation offsets.
- Fix picking, disposal, geometry, and Windows/web builds.
- **Breaking:** replace `queuePosition` / `queueRotation` with `queueTransforms`.
- **Breaking:** create web canvases per viewer; `View.getCamera()` is asynchronous.
- **Breaking:** remove `EntityTransformController` and obsolete render-thread APIs;
  restructure public exports and change input defaults and SDK/dependency requirements.

## 0.2.1-dev.0.0.9

> Note: This release has breaking changes.
- Fix release builds on Windows
- move createUnlitMaterialInstance and createGeometry to render thread.
- dont calculate surface orientation for non-triangle geometry.
- set View render target to nullptr if Dart renderTarget is null.
- set render target to null for each view and then destroy render targets when viewer disposed.
- produce debug symbols on Windows.
- simplify FixedOrbitCameraRotationDelegate.
- add quickstart to README.
- **Breaking:** (windows) add flushAndWait call to capture() to prevent stalling on Windows; use provided buffer as pixelBuffer rather than duplicate allocation.
- **Breaking:** add meshoptimizer lib on Windows.
- **Breaking:** Dart-only release mode builds on Window.
- **Breaking:** View.getCamera returns Future<Camera>.

## 0.2.1-dev.0.0.8

- move ThermionWin32.h to include.

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
- continual refactor to support multiple render targets.
- camera and resizing improvements.
- support multiple ThermionWidget on Android.
- use imported texture on iOS.
- working implementation of multiple widgets on macos.
- more work on multiple views/swapchains.
- add setParameterFloat2 method.
- add uvScale to unlit material.
- add ThirdPersonCameraDelegate.
- set camera model matrix directly.
- expose more camera methods.
- **Breaking:** refactor to support multiple Views/Render Targets.
- **Breaking:** remove RenderThread methods no longer needed.
- **Breaking:** replace queuePosition/Rotation with queueTransforms.
- **Breaking:** big refactor to support multiple swapchains.
- **Breaking:** set baseColorIndex to -1 by default in unlit materialss.

## 0.2.0-dev.7.0

> Note: This release has breaking changes.
- **Breaking:** fix min SDK for thermion_dart.

## 0.2.0-dev.6.0

> Note: This release has breaking changes.
- **Breaking:** cleanup deleted export.

## 0.2.0-dev.5.0

> Note: This release has breaking changes.
- **Breaking:** remove EntityTransformController (requires replacement).

## 0.2.0-dev.4.0

> Note: This release has breaking changes.
- **Breaking:** (web/wasm) free pick callbacks on dispose.
- **Breaking:** restructure viewer folders as libraries to only export the public interface.

## 0.2.0-dev.1.0

- Add highlights, gizmos, grids, layers, lighting, animation offsets, and capture.
- Add native geometry/instance controls and automatic web module loading.
- Fix picking, transforms, disposal, and web callback exports.
- **Breaking:** create web canvases per viewer and update web/http dependencies.

## 0.1.3

- manually remove leading slash for compiler path on Windows when building for Android.
- web/JS bool checks need to compare to int.
- shadow JS<->WASM bridge methods.
- add clearMorphAnimationData function.
- allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.

## 0.1.2

- manually remove leading slash for compiler path on Windows when building for Android.
- web/JS bool checks need to compare to int.
- shadow JS<->WASM bridge methods.
- allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.

## 0.1.1+5

- Bump "thermion_dart" to `0.1.1+5`.

## 0.1.1+4

- defer creating image entity/material/etc until actually requested.

## 0.1.1+3

- bump ffigen dependency version & regenerate bindings (and revert to ffi.Int rather than ffi.Int32).
- update homepage links and minor documentation updates.

## 0.1.1+2

- Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.1.1-dev.0+2

- revert to std::thread (pthreads not easily available on Windows).
- on Windows, pass static libs via -l rather than custom linkWith property so build.dart stays compatible between published & custom versions.

## 0.1.1+1

- update with links to playground.

## 0.1.1

- Bump "thermion_dart" to `0.1.1`.

## 0.1.0+4

- add dummy asset to build.dart on Linux builds so we can use the package on a Linux host.

## 0.1.0+3

- exit build.dart early on Linux builds so we can use the package on a Linux host.

## 0.1.0+2

- rearrange some stubs/imports for easier web WASM deployment.

## 0.1.0+1

- export ThermionViewerWasm for web and hide FFI/WASM version.
- use preserveDrawingBuffer=true on web.

## 0.0.1

- First release of Dart-only package
