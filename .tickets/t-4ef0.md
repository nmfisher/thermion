---
id: t-4ef0
status: closed
deps: []
links: []
created: 2026-01-14T09:18:24Z
type: task
priority: 2
assignee: Nick Fisher
---
# overlay-dart

# Plan: Replace OverlayComponentManager with Dart Implementation

## Goal
Replace the C++ `OverlayComponentManager` with a pure Dart implementation to reduce complexity and eliminate C++/Dart boundary crossing for overlay logic.

## Current State
- C++ `OverlayComponentManager` in `native/include/components/OverlayComponentManager.hpp` handles:
  - Two-pass rendering: silhouette pass -> edge detection pass
  - Material creation (silhouette + edge_outline)
  - Render targets, views, scenes, cameras, skyboxes
  - Fullscreen quad for edge detection
  - Entity tracking and transform parenting

## FFI Bindings Available
Most required FFI bindings already exist:
- `Material_createSilhouetteMaterialRenderThread`, `Material_createEdgeOutlineMaterialRenderThread`
- `Texture_buildRenderThread` (supports R8, RGBA8, DEPTH32F formats)
- `RenderTarget_createRenderThread`
- `Engine_createScene`, `Engine_createView`, `Engine_createCamera`
- `View_setRenderTarget`, `View_setPostProcessing`, `View_setShadowsEnabled`, `View_setFrustumCullingEnabled`
- `Skybox_setColor`, `Scene_setSkybox`
- `Camera_setProjection` (supports orthographic)
- `VertexBufferBuilder_*`, `IndexBufferBuilder_*`
- `MaterialInstance_setParameterTexture`, `MaterialInstance_setParameterFloat2`, etc.
- `RenderableBuilder_*`
- `TransformManager_setParent`

## Missing FFI Binding (Must Add First)
**`Engine_buildColoredSkybox`** - Create a skybox with a solid color (no cubemap texture)

Current `Engine_buildSkybox` requires a texture, but for clearing render targets we need:
```cpp
Skybox::Builder().color({r, g, b, a}).build(*engine)
```

### Step 0: Add colored skybox C API
**Files to modify:**
- `native/include/c_api/TEngine.h` - Add declaration
- `native/src/c_api/TEngine.cpp` - Add implementation
- `native/include/c_api/ThermionDartRenderThreadApi.h` - Add render thread variant
- `native/src/c_api/ThermionDartRenderThreadApi.cpp` - Add render thread implementation
- Regenerate FFI bindings

```cpp
// TEngine.h
EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildColoredSkybox(TEngine *tEngine, float r, float g, float b, float a);

// TEngine.cpp
EMSCRIPTEN_KEEPALIVE TSkybox *Engine_buildColoredSkybox(TEngine *tEngine, float r, float g, float b, float a) {
    auto *engine = reinterpret_cast<Engine *>(tEngine);
    auto *skybox = filament::Skybox::Builder()
        .color({r, g, b, a})
        .build(*engine);
    return reinterpret_cast<TSkybox *>(skybox);
}

// ThermionDartRenderThreadApi.h
EMSCRIPTEN_KEEPALIVE void Engine_buildColoredSkyboxRenderThread(
    TEngine *tEngine, float r, float g, float b, float a,
    void (*onComplete)(TSkybox *)
);
```

## Implementation Plan

### Step 1: Create `HighlightOverlayManager` Dart class
**File:** `thermion_dart/lib/src/filament/src/overlay/highlight_overlay_manager.dart`

```dart
class HighlightOverlayManager {
  final ThermionViewer viewer;

  // Materials (created once, reused)
  Pointer<TMaterial>? _silhouetteMaterial;
  Pointer<TMaterial>? _edgeMaterial;

  // Silhouette pass resources
  Pointer<TTexture>? _silhouetteTexture;
  Pointer<TTexture>? _silhouetteDepth;
  Pointer<TRenderTarget>? _silhouetteTarget;
  Pointer<TScene>? _silhouetteScene;
  Pointer<TView>? _silhouetteView;
  Pointer<TSkybox>? _silhouetteSkybox;

  // Overlay (edge detection) pass resources
  Pointer<TTexture>? _overlayTexture;
  Pointer<TTexture>? _overlayDepth;
  Pointer<TRenderTarget>? _overlayTarget;
  Pointer<TScene>? _overlayScene;
  Pointer<TView>? _overlayView;
  Pointer<TSkybox>? _overlaySkybox;
  Pointer<TCamera>? _overlayCamera;
  int _overlayCameraEntity = 0;
  Pointer<TMaterialInstance>? _edgeMaterialInstance;

  // Fullscreen quad
  Pointer<TVertexBuffer>? _quadVB;
  Pointer<TIndexBuffer>? _quadIB;
  int _quadEntity = 0;

  // Tracking
  final Map<int, _SilhouetteComponent> _highlights = {};
  int _width = 0;
  int _height = 0;
  bool _initialized = false;

  // Outline settings
  double outlineWidth = 2.0;
  double outlineR = 1.0, outlineG = 0.5, outlineB = 0.0;
}
```

### Step 2: Implement initialization
```dart
Future<void> initialize(int width, int height, {int? hardwareTextureId}) async {
  if (_initialized) return;

  _width = width;
  _height = height;

  // Create materials
  _silhouetteMaterial = await _createSilhouetteMaterial();
  _edgeMaterial = await _createEdgeMaterial();

  // Create silhouette pass resources
  await _createSilhouetteRenderTargets();
  await _createSilhouetteView();

  // Create overlay pass resources
  await _createOverlayRenderTargets(hardwareTextureId);
  await _createOverlayView();
  await _createFullscreenQuad();

  _initialized = true;
}
```

### Step 3: Implement render target creation
```dart
Future<void> _createSilhouetteRenderTargets() async {
  // R8 format for silhouette (single channel)
  _silhouetteTexture = await Texture_buildRenderThread(
    engine, width, height, 1, 1,
    TextureUsage.COLOR_ATTACHMENT | TextureUsage.SAMPLEABLE,
    0, SamplerType.SAMPLER_2D, TextureFormat.R8
  );

  // DEPTH32F for depth
  _silhouetteDepth = await Texture_buildRenderThread(
    engine, width, height, 1, 1,
    TextureUsage.DEPTH_ATTACHMENT,
    0, SamplerType.SAMPLER_2D, TextureFormat.DEPTH32F
  );

  _silhouetteTarget = await RenderTarget_createRenderThread(
    engine, width, height, _silhouetteTexture, _silhouetteDepth
  );
}
```

### Step 4: Implement view creation with skybox clearing
*(Depends on Step 0 - `Engine_buildColoredSkyboxRenderThread`)*

```dart
Future<Pointer<TSkybox>> _createColoredSkybox(double r, double g, double b, double a) async {
  return withPointerCallback((cb) =>
    Engine_buildColoredSkyboxRenderThread(_engine, r, g, b, a, cb));
}

Future<void> _createSilhouetteView() async {
  _silhouetteScene = Engine_createScene(engine);

  // Black skybox to clear render target
  _silhouetteSkybox = await _createColoredSkybox(0.0, 0.0, 0.0, 1.0);
  Scene_setSkybox(_silhouetteScene!, _silhouetteSkybox!);

  _silhouetteView = await Engine_createViewRenderThread(engine);
  View_setScene(_silhouetteView!, _silhouetteScene!);
  View_setViewport(_silhouetteView!, 0, 0, _width, _height);
  View_setRenderTarget(_silhouetteView!, _silhouetteTarget!);
  View_setPostProcessing(_silhouetteView!, false);
  View_setShadowsEnabled(_silhouetteView!, false);
}

Future<void> _createOverlayView() async {
  _overlayScene = Engine_createScene(engine);

  // TRANSPARENT skybox to clear overlay (fixes tinting bug!)
  _overlaySkybox = await _createColoredSkybox(0.0, 0.0, 0.0, 0.0);
  Scene_setSkybox(_overlayScene!, _overlaySkybox!);

  // Orthographic camera for fullscreen quad
  _overlayCameraEntity = EntityManager_createEntity(entityManager);
  _overlayCamera = await Engine_createCameraRenderThread(engine, _overlayCameraEntity);
  Camera_setProjection(_overlayCamera!, ProjectionType.ORTHO, -1, 1, -1, 1, 0, 1);

  _overlayView = await Engine_createViewRenderThread(engine);
  View_setScene(_overlayView!, _overlayScene!);
  View_setCamera(_overlayView!, _overlayCamera!);
  View_setViewport(_overlayView!, 0, 0, _width, _height);
  View_setRenderTarget(_overlayView!, _overlayTarget!);
  View_setPostProcessing(_overlayView!, false);
  View_setShadowsEnabled(_overlayView!, false);
  View_setFrustumCullingEnabled(_overlayView!, false);
}
```

### Step 5: Implement fullscreen quad
```dart
Future<void> _createFullscreenQuad() async {
  // Fullscreen triangle (more efficient than quad)
  final positions = Float32List.fromList([
    -1.0, -1.0, 0.5,
     3.0, -1.0, 0.5,
    -1.0,  3.0, 0.5,
  ]);
  final indices = Uint16List.fromList([0, 1, 2]);

  // Build vertex buffer
  final vbBuilder = VertexBufferBuilder_create();
  VertexBufferBuilder_vertexCount(vbBuilder, 3);
  VertexBufferBuilder_bufferCount(vbBuilder, 1);
  VertexBufferBuilder_attribute(vbBuilder, VertexAttribute.POSITION, 0,
    AttributeType.FLOAT3, 0, 12);
  _quadVB = await VertexBufferBuilder_buildRenderThread(vbBuilder, engine);
  await VertexBuffer_setBufferAtRenderThread(engine, _quadVB!, 0, positions.buffer, ...);

  // Build index buffer
  final ibBuilder = IndexBufferBuilder_create();
  IndexBufferBuilder_indexCount(ibBuilder, 3);
  IndexBufferBuilder_bufferType(ibBuilder, IndexType.USHORT);
  _quadIB = await IndexBufferBuilder_buildRenderThread(ibBuilder, engine);
  await IndexBuffer_setBufferRenderThread(engine, _quadIB!, indices.buffer, ...);

  // Create edge material instance
  _edgeMaterialInstance = await Material_createInstanceRenderThread(_edgeMaterial!);
  _updateEdgeMaterialParams();

  // Build renderable
  _quadEntity = EntityManager_createEntity(entityManager);
  final rb = RenderableBuilder_create(1);
  RenderableBuilder_geometry(rb, 0, PrimitiveType.TRIANGLES, _quadVB!, _quadIB!, 0, 3);
  RenderableBuilder_material(rb, 0, _edgeMaterialInstance!);
  RenderableBuilder_culling(rb, false);
  RenderableBuilder_castShadows(rb, false);
  RenderableBuilder_receiveShadows(rb, false);
  await RenderableBuilder_buildRenderThread(rb, engine, _quadEntity);

  Scene_addEntity(_overlayScene!, _quadEntity);
}

void _updateEdgeMaterialParams() {
  // Set silhouette texture sampler
  MaterialInstance_setParameterTexture(_edgeMaterialInstance!, "silhouette",
    _silhouetteTexture!, sampler);

  // Set texel size
  MaterialInstance_setParameterFloat2(_edgeMaterialInstance!, "texelSize",
    1.0 / _width, 1.0 / _height);

  // Set outline color and width
  MaterialInstance_setParameterFloat3(_edgeMaterialInstance!, "outlineColor",
    outlineR, outlineG, outlineB);
  MaterialInstance_setParameterFloat(_edgeMaterialInstance!, "outlineWidth",
    outlineWidth);
}
```

### Step 6: Implement addHighlight/removeHighlight
```dart
Future<void> addHighlight(int targetEntity, Pointer<TVertexBuffer> vb,
    Pointer<TIndexBuffer> ib, int indexCount) async {
  if (_highlights.containsKey(targetEntity)) return;

  // Create silhouette material instance
  final silhouetteMi = await Material_createInstanceRenderThread(_silhouetteMaterial!);

  // Create silhouette entity
  final silhouetteEntity = EntityManager_createEntity(entityManager);

  // Build silhouette renderable (same geometry, silhouette material)
  final rb = RenderableBuilder_create(1);
  RenderableBuilder_geometry(rb, 0, PrimitiveType.TRIANGLES, vb, ib, 0, indexCount);
  RenderableBuilder_material(rb, 0, silhouetteMi);
  RenderableBuilder_culling(rb, true);
  RenderableBuilder_castShadows(rb, false);
  RenderableBuilder_receiveShadows(rb, false);
  await RenderableBuilder_buildRenderThread(rb, engine, silhouetteEntity);

  // Parent to target entity (follows transforms)
  TransformManager_setParent(transformManager, silhouetteEntity, targetEntity);

  // Add to silhouette scene
  Scene_addEntity(_silhouetteScene!, silhouetteEntity);

  _highlights[targetEntity] = _SilhouetteComponent(silhouetteEntity, silhouetteMi);
}

Future<void> removeHighlight(int targetEntity) async {
  final component = _highlights.remove(targetEntity);
  if (component == null) return;

  Scene_removeEntity(_silhouetteScene!, component.entity);
  // ... destroy renderable, material instance, entity
}
```

### Step 7: Integrate with FFIView
**File:** `thermion_dart/lib/src/filament/src/implementation/ffi_view.dart`

Replace `overlayManager` pointer with `HighlightOverlayManager` instance:

```dart
HighlightOverlayManager? _highlightOverlay;

@override
Future<void> enableHighlightOverlay({int? hardwareTextureId}) async {
  _highlightOverlay ??= HighlightOverlayManager(this);
  await _highlightOverlay!.initialize(
    viewportWidth, viewportHeight,
    hardwareTextureId: hardwareTextureId
  );
}

@override
Future<void> disableHighlightOverlay() async {
  await _highlightOverlay?.dispose();
  _highlightOverlay = null;
}

@override
Future<void> addStencilHighlight(ThermionEntity entity, ...) async {
  final vb = getVertexBuffer(entity);
  final ib = getIndexBuffer(entity);
  await _highlightOverlay?.addHighlight(entity.id, vb, ib, indexCount);
}
```

### Step 8: Update render loop
In the render method, render both views:
```dart
if (_highlightOverlay?.hasHighlights == true) {
  // Render silhouette pass first
  await Renderer_renderRenderThread(renderer, _highlightOverlay!.silhouetteView);
  // Render edge detection pass
  await Renderer_renderRenderThread(renderer, _highlightOverlay!.overlayView);
}
```

## Files to Modify/Create

1. **CREATE:** `thermion_dart/lib/src/filament/src/overlay/highlight_overlay_manager.dart`
   - New Dart class implementing all overlay logic

2. **MODIFY:** `thermion_dart/lib/src/filament/src/implementation/ffi_view.dart`
   - Replace `Pointer<TOverlayManager>` with `HighlightOverlayManager`
   - Update `enableHighlightOverlay`, `disableHighlightOverlay`, `addStencilHighlight`, etc.

3. **DELETE (eventually):** C++ OverlayComponentManager code
   - `native/include/components/OverlayComponentManager.hpp`
   - `native/include/c_api/TOverlayManager.h`
   - `native/src/c_api/TOverlayManager.cpp`
   - Related render thread API functions

## Benefits
- Single language (Dart) for overlay logic
- Easier debugging
- No render thread callbacks needed for simple operations
- Cleaner resource management with Dart async/await
- Transparent skybox fix included (fixes tinting bug)

## Migration Strategy
1. Implement Dart `HighlightOverlayManager` alongside existing C++ version
2. Test with existing highlight tests
3. Switch `ffi_view.dart` to use Dart implementation
4. Remove C++ code once validated
