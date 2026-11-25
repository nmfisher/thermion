> Shared changelog for `thermion_dart` and `thermion_flutter` (released in lockstep).

Earlier entries are consolidated. [Original detailed history](https://github.com/nmfisher/thermion/blob/29a53ae682891be0aed05c59fe7ad5f490d2e44e/CHANGELOG.md).

## 0.8.0 - 2026-11-25

### Breaking changes

#### Built-in helper materials require explicit keys

Migrate when your app uses any feature in the table below, including through a
widget or plugin. Thermion previously bundled most of these helpers by default.
Apps that only render glTF models with their authored materials, load skyboxes,
or display solid backgrounds need no configuration change.

| If your app uses… | Enable these material keys |
| --- | --- |
| Transform gizmos (`TransformationGizmo`) | `gizmo` |
| Background images (`setBackgroundImage`, `setBackgroundImageFromTexture`) or textured quads (`createTexturedQuad`) | `image` |
| Grid overlay (`setGridOverlayVisibility`) | `grid` |
| Translation-axis overlay (`setTranslationAxisVisibility`) | `translation_axis` |
| Bone or skeleton overlay (`createBoneOverlayMaterial`) | `bone_overlay` |
| Selection outlines (`setStencilHighlight` or `ViewerWidget(enableHighlights: true)`) | Both `silhouette` and `edge_outline` |
| Wireframe rendering (`createWireframeMaterialInstance`) | `wireframe` |
| World-space normal visualization | `normal_color` |
| Masked triangle-edge visualization | `sharp_edge` |
| The built-in UV capture material (`BuiltInMaterial.captureUv`) | `capture_uv` |
| The built-in linear depth material (`BuiltInMaterial.linearDepth`) | `linear_depth` |
| The built-in fixed-size unlit material (`BuiltInMaterial.unlitFixedSize`) | `unlit_fixed_size` |

**Flutter and native Dart apps.** Set each required key to `true` in the app's
root `pubspec.yaml` (the workspace root for a pub workspace), then rebuild.
Keep any keys already set to `true`. If you used `include_defaults`, replace it
with the keys for the features you use. For example, an app that displays a
transform gizmo over a background image needs these two entries.

```yaml
hooks:
  user_defines:
    thermion_dart:
      materials:
        gizmo: true
        image: true
```

**Plain Dart web apps.** Pass the individual keys to `download_web` and deploy
the resulting `thermion_dart.wasm` and `thermion_dart.js` together. The same gizmo and background
image example uses this command.

```sh
dart run thermion_dart:download_web -o web --materials gizmo,image
```

On any platform, requesting an omitted helper raises a `StateError` naming
the key to enable.

#### Removed native FFIGizmo / TGizmo and embedded gizmo assets

The unused legacy native gizmo implementation is removed: the `TGizmo`,
`TGizmoType`, `TGizmoAxis` and `TGizmoPickResultType` types, the `Gizmo_*`
C API / JobThread symbols, and the embedded translation/rotation gizmo GLB
assets. Dart and Flutter apps are unaffected — `TransformationGizmo` is
Dart-only and never used this code. Native C callers must move to the
Dart-side `TransformationGizmo` (or supply their own gizmo implementation).

#### SilhouetteView and EdgeDetectionView no longer extend FFIView

`SilhouetteView` and `EdgeDetectionView` now compose a private view instead
of inheriting from `FFIView`, so they can no longer be passed where a `View`
is expected. `getHighlightOverlay()` is removed from the public `View`
interface. View picking state (the pick-request list and native callback
holder) is now allocated lazily on first use, so views that never pick —
such as silhouette views — no longer pay for it at construction.

### Features

#### Opt-in WebGPU backend

WebGPU is now available as an opt-in rendering backend alongside the default
WebGL2. Nothing changes for existing apps: default builds keep the
per-platform Metal/Vulkan/OpenGL set natively and WebGL2 on the web.

**Selecting the variant at build time.** Set the `backend` user define under
`hooks.user_defines.thermion_dart` in the app's root `pubspec.yaml`, then
rebuild.

```yaml
hooks:
  user_defines:
    thermion_dart:
      backend: hybrid
```

`native` (the default) is unchanged. `webgpu` builds WebGPU-only WGSL
materials; on native platforms it also swaps in the Dawn-linked Filament
artifact (intended for local testing — ship Metal/Vulkan/OpenGL builds).
`webgl2` builds the smallest WebGL2-only variant. `hybrid` ships both the
GLSL and WGSL material sets so the backend can be chosen at runtime. Web
`webgpu`/`hybrid` engines must be compiled with
`-DTHERMION_ENABLE_WEBGPU=ON`; in `webgl2`-only builds the WebGPU platform
is compiled out and engine creation with `Backend.WEBGPU` fails.

**Per-OS backends.** `backend` also accepts a map keyed by target OS —
including `web` — so one pubspec can request WebGPU on the web while native
platforms keep their default Metal/Vulkan/OpenGL set:

```yaml
hooks:
  user_defines:
    thermion_dart:
      backend:
        web: webgpu
        macos: native
```

A per-OS entry wins; targets without an entry keep the default. The flat
string form still works and acts as a global fallback for every target OS
(including web), and the deprecated `webgpu: true` spelling keeps mapping
to `backend: webgpu`. Everything follows the resolved backend: natively the
`-webgpu` Filament artifact, Dawn linking, and the default material
variant; on the web the WebGPU-enabled engine (`-sUSE_WEBGPU`, fetched
under a `-webgpu` artifact suffix; `web_local` copies from `build-webgpu`)
and the material variant embedded into it (WGSL for `webgpu`, GLSL for
`webgl2`, both for `hybrid`/`native`). `materials.backends` still takes
precedence for material variants on the OSes it covers.

**Selecting the backend at runtime.** Pass `Backend.WEBGPU` where the engine
is created — `FFIFilamentConfig(backend: Backend.WEBGPU)` in plain Dart
apps, or `WebOptions(backend: Backend.WEBGPU)` in Flutter web apps. The
default remains `Backend.OPENGL` (WebGL2). Runtime selection requires a
`hybrid` build; `FilamentApp.backend` reports the backend in use.

**Browser requirements.** WebGPU needs a browser that exposes
`navigator.gpu`. Check availability first — `WebGpu.isSupported()` from
`thermion_flutter`, or `navigator.gpu` directly in plain Dart apps — and
fall back to WebGL2 when it is absent. Flutter web throws a `StateError`
when `Backend.WEBGPU` is requested without `navigator.gpu`.

**Deprecation.** The legacy `webgpu: true` user define still works — it is
equivalent to `backend: webgpu` — but is deprecated; replace it with
`backend: webgpu`.

#### Compile-time opt-outs for optional native libraries (slim builds)

Apps can compile optional native libraries out of `libthermion_dart` for
slimmer builds. Set the `features` user defines in the app's root
`pubspec.yaml`, then rebuild. Every feature is on by default; an absent key
keeps it, so existing apps build exactly as before.

```yaml
hooks:
  user_defines:
    thermion_dart:
      features:
        gltf: false            # no gltfio: glTF loading, glTF clip/bone animation, ubershader materials
        ktx: false             # no KTX1/KTX2 textures (incl. Basis Universal)
        image_decoding: false  # no PNG/JPEG decoding
```

Each disabled feature drops its Filament archives from the link line.
`FilamentApp.supports(ThermionFeature)` reports what the loaded build
contains; APIs that need a disabled feature (e.g. `loadGltf` with
`gltf: false`) throw an `UnsupportedError` naming the key to re-enable.
Procedural geometry keeps working without gltfio: `createUnlitMaterialInstance`
uses a small precompiled fallback unlit material in `gltf: false` builds, and
entity-keyed morph animation stays available. Runtime material compilation
(filamat) remains separately opt-in through `runtime_materials: true` and is
reported by `ThermionFeature.runtimeMaterials`; leave it off for the slimmest
binaries. `gltf: true` cannot be combined with a disabled decoder — the build
hook rejects it. Web engines are prebuilt with every feature, so `features.*`
only affects native builds.

#### Depth textures in the image material

The image material accepts an `isDepthTexture` parameter
(`setParameterInt('isDepthTexture', 1)` on a background-image or textured-quad
material instance) to visualize depth textures: the inverted red channel is
displayed in grayscale, with the existing background color, visibility, UV
transform and fragment-depth behavior. Requires the `image` built-in material
key (see the breaking change above).

#### Renderer frame-time history

`FilamentApp.getFrameInfoHistory(count: ...)` exposes Filament's
`Renderer::getFrameInfoHistory` as `FrameTimingInfo` records, so frame-time
budgets can include the renderer's own GPU work even when the view renders on
Thermion's job thread. Unsupported and pending Filament sentinels map to
`null`. Available on native and web.

#### Up to 255 views per swapchain

The 8-view limit is raised to 255. Swapchains now sync only when dirty
instead of re-syncing every view on each attach/detach mutation, and the new
batch `RenderManager.setAttachments` / `updateAttachments` API updates
multi-view setups atomically.

### Performance

- Bone-matrix uploads run once per asset per frame instead of once per bone,
  and frames with no active bone animation do zero bone-matrix uploads (#518).
- Runtime morph/bone animation and glTF clip playback are decoupled from
  gltfio (#515), as is the core `SceneAsset` path (#514) — the groundwork for
  the `gltf: false` slim builds above.
- Silhouettes render target entities directly through a per-view material
  override instead of duplicating entities, so posed and morphed entities
  silhouette correctly and `accessibleGeometryBuffers` is no longer required
  for `setStencilHighlight` (#469).
- Highlight overlays render directly onto the shared presentation target;
  the extra intermediate render target and full-screen composite copy are
  gone (#468).

### Fixes

- Frame capture runs atomically in the native `RenderManager`, removing
  concurrent-render interleaving, mid-frame wedging and the fixed web sleeps
  (#471).
- Flutter preserves `View` `renderOrder` across texture resizes (#473).
- Linux EGL texture ownership hardening: correct DRM render node selection,
  leak-free teardown ordering and resize-leak fixes (#262).
- Vulkan initializes `mipLevels` in `ExternalImageMetadata` on Linux and
  Windows, fixing validation errors on external-image import (#465).
- Linux Vulkan blits exports before texture notification and restricts
  exportable textures to single-plane DRM modifiers (#464, #461).
- Windows runs the D3D-interop blit on Filament's queue and publishes only
  completed copies (#460).
- Gizmo resource leaks fixed; the camera context is shared per pointer event
  (#247).
- Android uses 64-bit vsync timestamps, fixing the ~2-second animation
  freeze/jump on 32-bit devices; iOS targets `targetTimestamp` with a
  flexible ProMotion frame-rate range (#480).

### Build

- Windows linked libraries moved from `#pragma`s in `ThermionWin32.h` to
  `hook/build.dart` (#511).
- Windows Filament archives ship version-matched `matc`/`resgen` tools, built
  with MSVC v143, and the build hook extracts them from the pinned ZIP
  correctly (#484, #486, #489).
- Web JS bindings regenerate cleanly from the repository without an
  Emscripten SDK; CI fails if committed bindings drift (#508).

## 0.7.0 - 2026-11-13

- Add opt-in runtime material compilation on native and web, with includes,
  package metadata, and compiler diagnostics.
- Compile app materials at build time with caching, resgen output, and optional
  native embedding through `material_compilation.link_generated`.
- Ship pinned macOS material tools; fix Android shader targeting and Windows
  runtime-material linking.
- Fix Wasm material/compiler memory leaks and pending gizmo callback lifetimes.
- Serialize native engine access; fix worker starvation, shutdown hangs, and callback delivery.
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
