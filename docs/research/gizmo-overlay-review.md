# Gizmo & Highlight Overlay — Implementation Review

**Date:** 2026-08-16
**Branch:** `asb/gizmo-overlay-review` (research only — no code changed)
**Question:** Is the gizmo and overlay implementation optimal and efficient?

## Executive summary

| System | Verdict |
|---|---|
| Gizmo (current `TransformationGizmo`, pure Dart) | **Reasonable for now.** Near-zero per-frame cost; costs are per-input-event and small. One real bug-class finding: `dispose()` leaks native resources. Two to three generations of dead gizmo code coexist and should be deleted. |
| Highlight overlay (`HighlightOverlayManager`) | **Mostly sound design, with one structural cost issue.** When enabled it adds 2 extra full-screen passes per frame (silhouette + edge detection) and, in composite mode, redirects the main view through an offscreen texture — *even when zero entities are highlighted*. This was a deliberate trade-off (commit `2ca9fc0b` removed `hasHighlights()`), but it is the single biggest GPU cost in either system and is worth revisiting. |

Neither system does meaningful work on the render thread per frame beyond what Filament itself renders; there are no per-frame buffer uploads, no per-frame Dart→native round-trips introduced by either system, and no unbounded per-frame allocation growth. The inefficiencies that exist are (a) constant GPU cost in the overlay, (b) per-input-event FFI chatter in the gizmo, and (c) a resource leak in gizmo disposal.

---

## 1. Gizmo system map

There are **three generations** of gizmo code in the tree:

| Generation | Files | State |
|---|---|---|
| 1. Native glTF gizmo (`TGizmo`) | `thermion_dart/native/src/scene/Gizmo.cpp`, `native/src/c_api/TGizmo.cpp`, `native/include/scene/Gizmo.hpp`, `lib/src/filament/src/implementation/ffi_gizmo.dart` | Live code, exposed via FFI/WASM bindings, **not used by any current example**. Loads an embedded glTF (`translation_gizmo_glb.bin` / `rotation_gizmo_glb.bin`), 3 axis instances + invisible "HitTest" volumes, GPU picking via `View::pick`. |
| 2. Deprecated handlers | `lib/src/utils/src/gizmo.dart` (fully commented out), `lib/src/input/src/implementations/gizmo_input_handler.dart` (fully commented out), `gizmo_pick_delegate.dart` (fully commented out), `native/src/scene/RotationGizmo.cpp` (fully commented out, ~350 lines) | Dead code. |
| 3. Current pure-Dart gizmo | `lib/src/utils/src/gizmos.dart` (`TransformationGizmo`), driven by `lib/src/input/src/implementations/gizmo_attachment_delegate.dart` | **This is what runs today** (used by `examples/dart/examples_lib/lib/src/gizmo_basics.dart:27-29` and `GizmoAttachmentDelegate`). |

### 1.1 Setup (once per gizmo / per type switch)

`TransformationGizmo.create()` (`gizmos.dart:57-82`):
- 1 shared `Material` (cached app-wide at `ffi_filament_app.dart:577-585`) + 5 material instances (red/green/blue/white/yellow), each a `createInstance()` render-thread round trip.
- Geometry (cylinder/cone/torus/sphere) generated **in Dart** into growable `List<double>` then copied via `Float32List.fromList` (`gizmos.dart:214-369`) — triple copy (list → typed list → native marshalling in `createGeometry`), but setup-only and tiny (a 64×12 torus is ~3 k floats).
- 8 renderables total for translation (2 per axis) or 3 rings + 2 markers for rotation; all parented to one root entity. `setPriority(7)` to draw on top.

### 1.2 Per-frame (render loop) cost

**Effectively zero.** The gizmo is ordinary scene geometry; there is no per-frame callback, no per-frame FFI, no animation. The only "per frame" GPU characteristics come from the material (`materials/gizmo.mat`):
- `blending: transparent` → rendered in the transparent pass;
- `depthWrite: true` + `depthCulling: false` + `gl_FragDepth = 0.999f` in the fragment shader (`materials/gizmo.mat:27`) → depth write per fragment disables early-Z for those fragments. With ~8 small renderables this is negligible, but it is the kind of thing that would matter if the gizmo were instantiated many times.

### 1.3 Per-input-event cost (where the gizmo actually spends time)

`GizmoAttachmentDelegate.handle()` (`gizmo_attachment_delegate.dart:170-225`) runs on every pointer event (events are *not* batched — `delegate_input_handler.dart:23-25, 72-75`):

**On every hover/move while not dragging** (`gizmo_attachment_delegate.dart:205-211`):
1. `_gizmo.update()` (`gizmos.dart:413-439`):
   - `transformManager.getWorldTransform(target)` — sync FFI + `Matrix4` alloc + native struct round-trip copy (`ffi_transform_manager.dart`, `utils/src/matrix.dart:22-40`),
   - `viewer.getActiveCamera()` → `View_getCamera` FFI + **new `FFICamera` wrapper object every call** (`ffi_view.dart:106-109`, `thermion_viewer_ffi.dart:822-824`),
   - `camera.getPosition()` → `getModelMatrix()` FFI + `Matrix4` + `Vector3` allocs (`interface/camera.dart:10-13`),
   - `setTransform(rootEntity, …)` — sync FFI + native struct alloc (`matrix4ToDouble4x4`).
2. `_gizmo.hover(x, y)` → `pickAxis()` (`gizmos.dart:441-535`): 4 more FFI reads (viewport, projection, view matrix, gizmo world transform), then pure-Dart screen-space math. For **rotation** gizmos the picking loop is 3 axes × 32 segments × 2 projected points ≈ **192 matrix×vector multiplies per mouse-move event** (`gizmos.dart:499-522`) — plus the same math again inside `_getMarkerPositionOnRing` (64 samples, `gizmos.dart:883-903`) once a drag starts.

**Net:** ~8–10 FFI calls and ~10 short-lived Dart objects per pointer-move event. At 120 Hz mouse polling this is tens of microseconds per second of CPU — not a bottleneck on desktop, but it is pure waste when the camera and target haven't moved (i.e. almost always). During an active drag, `_updateTranslationDrag` (`gizmos.dart:603-673`) re-fetches viewport/projection/view/model matrices **and** `_updateRotationDrag` re-fetches camera position, then `update(position: …)` fetches camera position *again* (`gizmos.dart:426-429`) — the same matrices are read 2–3× per event.

### 1.4 Concrete gizmo findings (ranked)

1. **`dispose()` leaks native resources** — `gizmos.dart:990-1030` only calls `viewer.removeFromScene(asset)` (which is scene-remove only, `thermion_viewer_ffi.dart:871-874`); it never calls `destroyAsset`. The 8 geometry assets (vertex/index buffers + entities), the root entity, and the 5 material instances leak. The code even contains the acknowledgement as comments (`gizmos.dart:997-998`, `1004-1007`). `GizmoAttachmentDelegate.setGizmoType()` (`gizmo_attachment_delegate.dart:151-168`) disposes and recreates on every type switch, so each translation↔rotation toggle leaks a full gizmo's GPU memory. **Impact: high on long sessions / type-switching UIs. Effort: small (S) — route dispose through `viewer.destroyAsset` + destroy root entity/material instances).**
2. **Dead code: three generations coexist** — ~1,000 lines of commented-out gizmo code (`gizmo.dart` 116 lines, `gizmo_input_handler.dart` 372 lines, `gizmo_pick_delegate.dart` 42 lines, `RotationGizmo.cpp` ~350 lines) plus the live-but-unused native `Gizmo`/`TGizmo` path (`Gizmo.cpp` 249 lines, `TGizmo.cpp`, `ffi_gizmo.dart`, WASM/FFI bindings, two embedded glTFs `translation_gizmo_glb.bin`/`rotation_gizmo_glb.bin` shipped in `native/include/resources/`). **Impact: binary size (embedded glb blobs), maintenance confusion, double the surface to review. Effort: small (S) to delete the commented files; medium (M) to remove or re-wire the native path.**
3. **Redundant per-event camera/transform reads** — `update()` + `pickAxis()` + drag handlers re-read the same camera matrices and world transforms 2–3× per pointer event, each with fresh allocations (details in §1.3). **Impact: low (µs/event). Effort: small (S) — cache per-event (or per-frame) camera state in the delegate and pass it down; or only run `update()` when the camera or target transform actually changed.**
4. **`_updateMarkerPosition` calls `setPriority(marker, 7)` on every drag frame** (`gizmos.dart:957-963`) although the priority never changes. **Impact: negligible. Effort: trivial.**
5. **Legacy native gizmo material does hidden double-draw** — the "HitTest" volumes use `TWO_PASSES_ONE_SIDE` transparency with alpha 0 (`Gizmo.cpp:105-112`): invisible but rasterized and blended twice per face, and `gl_FragDepth` in `gizmo.mat:27` disables early-Z. Only matters if generation-1 is ever revived. **Impact: none today (unused path).**
6. **Screen-space picking can't be occlusion-aware** — `pickAxis` deliberately avoids depth ("Use screen-space picking to avoid depth buffer issues", `gizmos.dart:444`). Fine functionally, but it means the gizmo is hoverable through geometry; the native path solved this with `View::pick` (`Gizmo.cpp:214-222`). Worth documenting as a behavioural trade-off rather than fixing.

### 1.5 Gizmo API-shape notes

- `TransformationGizmo.update()` is *pull-based*: callers must invoke it on camera motion (`GizmoAttachmentDelegate` does so on scroll/move events). Nothing updates it when the camera is animated by other code (e.g. an animation or another delegate moving the camera programmatically) — the gizmo will visibly lag/detach. A per-frame hook (the app already has `render()` request-frame hooks, `ffi_filament_app.dart:803-818`) would be the conventional place.
- `pickAxis`/`hover`/`updateDrag` are `async` but contain no awaits that need to be — the entire API drags `Future` chaining through pure math, adding event-loop hops per event. Cosmetic, but it prevents trivial batching.
- `GizmoAttachmentDelegate._findAssetForEntity` is a stub returning null with a TODO (`gizmo_attachment_delegate.dart:307-317`) — bone-vs-entity attachment degrades to entity-only.

---

## 2. Highlight overlay system map

Files: `lib/src/filament/src/implementation/highlight_overlay_manager.dart`, `silhouette_view.dart`, `edge_detection_view.dart`, `materials/silhouette.mat`, `materials/edge_outline.mat`. Enabled per-viewer (`ThermionViewerFFI(..., createOverlay: true)` → `setHighlightOverlayEnabled(true)` at `thermion_viewer_ffi.dart:86-88`; default is `false`, `thermion_viewer_ffi.dart:42`), and auto-enabled lazily by the first `setStencilHighlight` (`ffi_view.dart:575-577`).

Architecture (two-and-a-half render passes, all via `RenderManager` render order 0/1/2, `ffi_view.dart:505-508`):

1. **Silhouette pass** (`SilhouetteView`, order 0): a second `View` + own scene, rendering per-entity "ghost" renderables (unlit white, `silhouette.mat`) that *reuse the target asset's vertex/index buffers* and are parented to the target entity so they follow transforms (`silhouette_view.dart:224-269`). Output: offscreen RGBA8 + DEPTH32F render target.
2. **Main pass** (order 1). In **composite mode** (macOS/iOS, i.e. whenever the view renders into a Flutter-provided render target) the main view is redirected into an internal SRGB8_A8 texture (`highlight_overlay_manager.dart:129-149, 233-262`).
3. **Edge-detection pass** (`EdgeDetectionView`, order 2): a fullscreen triangle running `edge_outline.mat`, sampling the silhouette texture 9× (8 neighbours + center) plus the main-scene texture once, and either compositing `mix(sceneColor, outlineColor, edge)` or emitting alpha-only edges (`materials/edge_outline.mat:29-76`).

### 2.1 Setup (once per enable)

`HighlightOverlayManager.create` builds 2 views, 2 scenes, 2 skyboxes, 1 camera, materials/instances, fullscreen-triangle VB/IB, samplers, a linear color grading + tone mapper (to avoid double tone-mapping, `edge_detection_view.dart:206-216`), and 2–3 render targets. All done through `withPointerCallback`/`withVoidCallback` render-thread round trips. This is heavyweight (~30+ awaited FFI round trips) but one-off; `_enableHighlightOverlay` also detaches and re-attaches views with explicit render orders (`ffi_view.dart:505-508`).

`addHighlight` (per highlighted entity/primitive): creates a material instance + entity + renderable builder round trips, parents to target. **Per call it also unconditionally re-uploads all 7 edge-material parameters** — `setOutlineParams` is called before the already-highlighted early-return (`highlight_overlay_manager.dart:319-325`), and `setStencilHighlight` calls `addHighlight` once per primitive of the entity (`ffi_view.dart:602-636`), so an N-primitive entity does N×7 `setParameter*` calls, each of which re-encodes the parameter name (`name.toNativeUtf8()`, `ffi_material.dart:103-110`). For primitives 2..N the silhouette work is then skipped (`_highlightedEntities.contains(target)`), which also means **only the first primitive's geometry is ever silhouetted** for a multi-primitive entity — a correctness gap that looks like an efficiency shortcut.

### 2.2 Per-frame cost (the core of the review)

Every rendered frame, for every swapchain, `RenderManager::render()` walks attached views in order and calls `mRenderer->render(view)` (`native/src/rendering/RenderManager.cpp:165-170`). With the overlay enabled that is 3 view renders where 1 used to be:

| Pass | Per-frame GPU work |
|---|---|
| Silhouette | Full-screen clear (RGBA8) + depth clear (DEPTH32F) + re-render of all highlighted geometry with the unlit silhouette material. When **nothing is highlighted** this still costs a full-screen color+depth clear and a render pass. |
| Main | Unchanged workload, but in composite mode targets an offscreen SRGB8_A8 texture instead of the swapchain. |
| Edge detection | Full-screen triangle, ~10 texture reads + 1 read + 1 write per pixel, transparent blending. Runs whether or not anything is highlighted. |

So the constant overhead of *having the overlay enabled* is roughly **2 extra full-screen passes + 2 extra full-screen attachments (RGBA8 + DEPTH32F + SRGB8_A8 in composite mode) of bandwidth per frame**, independent of highlight count. On a 4K framebuffer that is several hundred MB/s of avoidable traffic at 60 fps with zero highlights. History shows this is deliberate: `2ca9fc0b` *"remove hasHighlights() from View. This means the overlay will be rendered if enableHighlightOverlay() has been called, even if no assets are highlighted"*. The earlier design (b649a24e) implemented overlays with Flutter widgets and "showed bad performance", so the current architecture is itself the fix for a worse one — the remaining issue is only the no-highlight case.

Notably, `RenderManager` already has the cheap lever for this: `setRenderable(view, bool)` (`ffi_render_manager.dart:144-149`, `RenderManager.cpp:60-96`) marks views renderable or not, and empty view lists already skip begin/end frame (`RenderManager.cpp:117-144`). Skipping only the two overlay views when `highlightedEntities.isEmpty` (or when nothing moved, if desired) would recover most of the cost without touching resources.

### 2.3 Per-frame Dart/native churn

- **None per frame.** Neither view registers a frame callback; material params, textures, and viewport are only touched on `addHighlight`/`removeHighlight`/resize. This is the correct shape and matches how the rest of the codebase treats views.
- Resize path (`SilhouetteView.setViewport` → `_resizeRenderTarget`, `silhouette_view.dart:133-194`; manager `_resizeMainViewRenderTarget`, `highlight_overlay_manager.dart:264-291`): creates new textures/RT, rebinds, `flush()`es the render thread, then destroys old resources. Well-ordered (documented destruction rationale at `highlight_overlay_manager.dart:72-96`). One nit: `EdgeDetectionView.setViewport` re-sets all 7 material params on every resize (`edge_detection_view.dart:342-348` → `_updateEdgeMaterialParams`), including two texture rebinds — harmless at resize frequency.
- `highlightedEntities` getter wraps the set in a fresh `Set.unmodifiable` on every access (`highlight_overlay_manager.dart:108`) — allocation per query; queries are rare (tests/UI), so cosmetic.

### 2.4 Threading

All overlay orchestration is Dart-side on the platform isolate, marshalled to the render thread through the standard `withVoidCallback` request-id mechanism (same as every other system in the package). `FFIRenderManager` serialises attach/detach mutations through a static op-chain and snapshots attachment state before syncing (`ffi_render_manager.dart:96-200`) — multi-viewer races are explicitly handled and documented. No long-running work is done on the main thread; no locks are held across frames (`RenderManager::render` holds `mMutex` only for the duration of the render iteration, `RenderManager.cpp:190`).

### 2.5 Concrete overlay findings (ranked)

1. **Constant 2-pass full-screen cost even with zero highlights** (`RenderManager.cpp:165-170` + attach at `ffi_view.dart:506-508`; history `2ca9fc0b`). **Impact: high on mobile/web at high resolutions. Effort: small (S) — when `highlightedEntities` transitions empty↔non-empty, call `renderManager.setRenderable(silhouetteView/overlayView, …)` and restore the main view's render target (composite mode) accordingly; ~1 day including tests.**
2. **Composite mode always pays an offscreen main-scene texture + extra full-screen sample/copy** (`highlight_overlay_manager.dart:129-149`). **Impact: medium (one extra full-screen read+write per frame vs. direct-to-swapchain). Effort: medium (M) — only needed because the edge pass must read the scene; alternatives (blit instead of shader-composite when no highlights, or a Filament ` post-process`-style integration if upstream ever lands one). Pair with finding 1: with no highlights, render main directly to the Flutter RT and skip everything.**
3. **`addHighlight` re-uploads 7 material params per call and is called once per primitive** (`highlight_overlay_manager.dart:319-325`, `ffi_view.dart:602-636`, `toNativeUtf8` per param at `ffi_material.dart:103-110`); combined with per-entity keying, multi-primitive entities are only partially outlined. **Impact: correctness bug + minor churn. Effort: small (S) — key silhouettes per (entity, primitive) or pass all primitives in one call; set outline params once per `setStencilHighlight` invocation.**
4. **`setHighlightOverlayEnabled(false)` is a full destroy; `true` a full rebuild** (`ffi_view.dart:517-546` + `destroy()` at `highlight_overlay_manager.dart:356-393`) — there is no cheap pause/resume, which encourages apps to leave it enabled (and thus pay finding 1). **Impact: API shape. Effort: small (S) once finding 1's setRenderable lever exists.**
5. **Silhouette ghost AABB is captured once at add time** (`silhouette_view.dart:244-248`, `culling(true)`) — correct for static geometry, stale for skinned/morph-target meshes; not a perf issue but worth a doc comment. **Effort: trivial (doc) / M (if skinned support is wanted).**
6. **DEPTH32F for the silhouette depth attachment** (`silhouette_view.dart:89-96`) — an unlit opaque pass needs nowhere near 32-bit depth; DEPTH24/16 would halve depth bandwidth on most tilers. **Impact: small. Effort: trivial.**
7. **`removeStencilHighlight` removes by entity + child entities but `addHighlight` tracks per picked entity only** (`ffi_view.dart:645-654` vs `626-635`) — asymmetric bookkeeping; benign today.

### 2.6 Comparison with sibling systems

- **Grid overlay** (`grid_overlay.dart`, `materials/grid.mat`) and **translation axis** (`translation_axis.mat`): fully in-scene, analytic shaders — zero extra passes, LOD/fade computed per fragment. This is the cheaper pattern when the visual can be expressed procedurally; the highlight overlay cannot (arbitrary geometry outlines) and is right to use render targets.
- **Picking** (`ffi_view.dart:247-279`): bounded `kMaxPickRequests` ring buffer for in-flight picks — a good allocation-discipline convention both reviewed systems would do well to imitate where they keep per-call state (they currently don't keep any per-frame state, which is fine).
- **Wireframe/bounding-box helpers** (`thermion_viewer_ffi.dart:892-986`): same "ghost renderable parented to target" trick as the silhouette pass — the two could share a small factory (see §3).

---

## 3. Shared infrastructure / unification opportunities

The gizmo and overlay systems don't share code today, and mostly shouldn't — but three concrete overlaps exist:

1. **Ghost-renderable factory.** Silhouette entities (`silhouette_view.dart:246-260`), gizmo axis assets, wireframe boxes (`thermion_viewer_ffi.dart:892-986`) and bone overlays all do: create entity → build renderable with shared VB/IB → parent to target → track for disposal. One helper would remove four copies of the dispose-ordering pitfalls (and the gizmo's leak, finding §1.4-1, would have been caught once). Effort: **M**.
2. **"Follow target / constant screen size" transform update.** The gizmo's `update()` (distance-proportional scale, `gizmos.dart:426-438`) and translation-axis/grid fade logic solve the same camera-distance problem per system. A small camera-state cache (position + view/projection matrices refreshed once per frame or per camera-change notification) would serve gizmo, translation-axis, and any future screen-space widget, and fix the 2–3× redundant reads per event (§1.4-3). Effort: **S–M**.
3. **Picking.** Generation-1 gizmo used GPU `View::pick`; the current gizmo uses Dart screen-space math; the overlay doesn't pick. If the native gizmo path is deleted (§1.4-2), `Gizmo::pick`'s entity-matching logic (`Gizmo.hpp:163-218`) goes with it — no other consumer exists.

---

## 4. Recommendations

### Quick wins (≤ 1 day each)
1. Fix `TransformationGizmo.dispose()` to destroy assets/entities/material instances (§1.4-1). **S.**
2. Skip silhouette + edge passes when `highlightedEntities.isEmpty` via `RenderManager.setRenderable` (+ restore main view render target in composite mode) (§2.5-1). **S.**
3. Delete the four fully-commented-out gizmo files and decide the fate of the unused native `TGizmo` path + embedded gizmo glb blobs (§1.4-2). **S (deletion) / M (removal from bindings + hooks).**
4. Set outline params once per `setStencilHighlight` call, not per primitive (§2.5-3). **S.**
5. Cache camera matrices/position per event (or expose a single `getCameraFrame()` FFI call) to collapse the gizmo's redundant reads (§1.4-3). **S.**
6. Silhouette depth → DEPTH24; drop the per-call `setPriority(7)` in marker updates (§2.5-6, §1.4-4). **Trivial.**

### Structural (≥ 1 week)
7. Key silhouettes per primitive (or accept and document single-primitive outlines) and make highlight add/remove symmetric (§2.5-3/7). **M.**
8. Composite-mode fast path: when no highlights, render main directly to the Flutter RT (no offscreen SRGB8_A8, no edge pass) (§2.5-2). **M, builds on 2.**
9. Ghost-renderable factory + camera-state cache shared by gizmo/wireframe/bbox/silhouette (§3.1/3.2). **M.**
10. Give the gizmo a proper per-frame hook (app render hooks) instead of pull-based `update()` from input events (§1.5). **S–M.**

### Implementation status (2026-08-16 follow-up)

The six quick wins were implemented on `asb/gizmo-overlay-review`.

| # | Item | Status | Notes |
|---|---|---|---|
| 1 | Gizmo dispose leak | **Implemented** | `TransformationGizmo.dispose()` now destroys the loaded glb assets through `viewer.destroyAsset`, plus entities and material instances; idempotent. |
| 2 | Skip overlay passes when empty | **Implemented** | `FFIHighlightOverlayManager._applySuspension()` flips `setRenderable` on the silhouette/edge views at empty↔non-empty transitions — no destroy/rebuild. In composite mode the main view is pointed back at the Flutter-provided render target while suspended (new `FFIView.setRenderTargetDirect` bypasses the `setRenderTarget` interception). Structural item 8 (skipping the offscreen main-scene texture entirely) is still open. |
| 3 | Delete commented-out gizmo files | **Implemented (files only)** | The four fully-commented files are gone. The live native `TGizmo` path and the embedded glb blobs were intentionally retained (owner decision); removing them needs bindings + hooks work and is deferred. |
| 4 | Outline params once per call | **Implemented** | `setStencilHighlight` calls `setOutlineParams` once; `addHighlight` no longer takes color/width. The per-primitive keying half of structural item 7 also landed: silhouettes are deduplicated per (entity, primitive) instead of first-primitive-only. |
| 5 | Cache camera state per event | **Implemented (Dart-level)** | `GizmoCameraContext.fetch()` is called once per move/hover and shared by update/hover/drag. The single-FFI-call `getCameraFrame()` variant needs a new native API — deferred. |
| 6 | DEPTH24 + setPriority | **Implemented** | Silhouette depth is DEPTH24 (create and resize paths); the axis-marker `setPriority(7)` is set once at creation. |

**Fix required along the way:** `FilamentApp.capture` rendered every attached view, including non-renderable ones. While the overlay is suspended the edge view still points at the Flutter render target, so capture's render of it cleared the target after the main view had already drawn (all-zero captures). Capture now renders only views the frame loop would render (`RenderManager.isRenderable`) but still reads back every attached view.

**Pre-existing behavior found while verifying:** `setStencilHighlight` has always been a no-op on procedural (`createGeometry`) assets — `SceneAsset_getPrimitiveOffsetForEntity` returns -1 for Geometry-type assets (`native/src/c_api/TSceneAsset.cpp:260-268`), so stencil highlights only work on glTF assets loaded with `rebuildVertices: true`. Unchanged by this work; worth documenting or fixing separately.

**Verification:** `flutter analyze` — 0 errors, no new warnings. Full test suite — 42 passed, 1 pre-existing failure (`input_pipeline_test` toString case, fails on the clean tree too). Pixel-diff of `view_tests` captures against a clean-tree baseline: silhouette view byte-identical, main view ±1 LSB, composite view same content (per-pixel deltas ≤ 50/255 from rendering direct to the float Flutter target instead of through the SRGB8 composite — the intended change), after-overlay-disabled identical.

---

## 5. Verdict

**Gizmo: reasonable for now.** The current Dart implementation is light by construction (no per-frame work, math-based picking, shared cached material). Fix the dispose leak, delete the dead generations, and it's in good shape; the per-event FFI chatter is real but small and easy to trim later.

**Overlay: sound architecture, one thing worth fixing.** The two-pass silhouette/edge design is the right approach for arbitrary-geometry outlines (and already replaced a worse Flutter-widget implementation), resource lifetimes are carefully ordered, and per-frame Dart churn is zero. The one thing that needs fixing is the *unconditional* cost: two extra full-screen passes (plus an offscreen main-scene texture in composite mode) every frame purely because the overlay is enabled, even with nothing highlighted. That is a small, well-scoped fix (`setRenderable` gating) with a large payoff on mobile resolutions.

---

## Appendix: key file references

| Concern | Location |
|---|---|
| Current gizmo | `thermion_dart/lib/src/utils/src/gizmos.dart` |
| Gizmo input driving | `thermion_dart/lib/src/input/src/implementations/gizmo_attachment_delegate.dart:170-225` |
| Gizmo material | `materials/gizmo.mat` |
| Native (legacy) gizmo | `thermion_dart/native/src/scene/Gizmo.cpp`, `native/src/c_api/TGizmo.cpp` |
| Overlay manager | `thermion_dart/lib/src/filament/src/implementation/highlight_overlay_manager.dart` |
| Silhouette pass | `thermion_dart/lib/src/filament/src/implementation/silhouette_view.dart` |
| Edge pass | `thermion_dart/lib/src/filament/src/implementation/edge_detection_view.dart` |
| Overlay materials | `materials/silhouette.mat`, `materials/edge_outline.mat` |
| View wiring / attach order | `thermion_dart/lib/src/filament/src/implementation/ffi_view.dart:476-654` |
| Per-frame render loop | `thermion_dart/native/src/rendering/RenderManager.cpp:107-238` |
| Material packaging in build hook | `thermion_dart/hook/build.dart:130-145` |
