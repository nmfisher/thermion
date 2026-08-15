# Proposal: unify the cgltf and Assimp mesh-import paths

Status: proposal, no code changed.
Branch: `feat/assimp-integration` (PR #195).
Date: 2026-08-15.

## Question

Thermion already parses glTF/GLB with cgltf. The new Assimp importer
(`model_import`) also parses model files into meshes. Should we reuse the
same concept, share code, or build one overarching model-file-parser
structure?

## Map of the paths today

There are **three** native mesh/scene producing paths, not two. The main
glTF path does not go through cgltf parsing in Thermion code at all — it
delegates to Filament's gltfio.

### Path A — full glTF scenes (the main path)

```
Dart viewer.loadGltf / loadGltfFromBuffer
  -> FFIFilamentApp.loadGltfFromBuffer        (lib/src/filament/src/implementation/ffi_filament_app.dart)
  -> GltfAssetLoader_createAsset              (native/src/c_api/TGltfAssetLoader.cpp)
     -> Filament gltfio::AssetLoader          (Filament's own glTF parser)
  -> GltfSceneAsset                           (native/src/scene/GltfSceneAsset.cpp)
```

- Produces: a full scene graph — `SceneAsset` with entities, transforms,
  materials, skinning, morph targets, animation.
- cgltf appears only in `GltfSceneAsset::rebuildVertexBuffers()`
  (`native/src/scene/GltfSceneAsset.cpp:271`): it re-reads the
  `cgltf_data` that gltfio kept as "source asset" and rebuilds
  VertexBuffers with position/normal/tangent/UV/joints/weights.
  This is a Filament-integration detail, not a standalone parser.
- Output type: native `GltfSceneAsset` (rich).

### Path B — cgltf mesh extraction (niche path)

```
Dart FilamentApp.parseGltf
  -> FFIGltfMeshData.parse                    (lib/src/filament/src/implementation/ffi_gltf_mesh_data.dart)
  -> GltfParser_parseBuffer                   (native/src/c_api/TGltfParser.cpp)
     -> cgltf_parse / cgltf_load_buffers / cgltf_validate
```

- Produces: flat vertex positions + uint32 indices + primitive type for
  **one** mesh (optionally filtered by mesh name). No normals, no UVs,
  no materials, no transforms.
- Stated purpose (see `interface/gltf_mesh_data.dart`): physics collision
  data. Today only tests consume it (`test/gltf_parser_tests.dart`); no
  production caller in the repo.
- Output type: Dart `GltfMeshData` (vertices/indices/primitiveType).

### Path C — the new Assimp importer (this PR)

```
Dart viewer.loadModel / loadModelFromBuffer
  -> GeometryUtils.parseModelFromBuffer       (lib/src/utils/src/geometry/utils.dart)
  -> ModelImporter.loadFromBuffer             (lib/src/filament/src/implementation/ffi_model_importer.dart)
  -> ModelImporter_loadFromBuffer             (native/src/c_api/model_import.cpp)
     -> Assimp::Importer::ReadFileFromMemory  (OBJ/FBX/glTF/STL/PLY/...)
  -> ImportedMesh.toGeometry
  -> viewer.createGeometry                    (same entry as procedural Geometry)
  -> GeometrySceneAsset                       (native/src/scene/GeometrySceneAsset.cpp)
```

- Produces: per-mesh `ImportedMesh` (name, materialName, positions,
  normals, 1 UV channel, triangle indices) -> Dart `Geometry` ->
  `GeometrySceneAsset` per mesh.
- Output type: one `GeometrySceneAsset` per mesh; no scene graph, no
  materials instantiated (materialName is read but unused downstream), no
  animation, no skinning, and **no node transforms applied** (meshes come
  out in local space — `aiScene::mRootNode` transforms are never read).

### Where they converge

- All three end at the same Filament primitives: `VertexBuffer` /
  `IndexBuffer` / `RenderableManager`.
- Path B and Path C both stop at "flat mesh arrays in Dart" before going
  back into native through `createGeometry`.
- Path A never round-trips through Dart.

## Where duplication is real — and where it is not

### Real, small duplications

1. **Triangle-strip expansion exists twice.**
   `expandTriangleStrip()` in `native/src/c_api/TGltfParser.cpp` and
   `GeometryUtils.expandTriangleStrip()` in
   `lib/src/utils/src/geometry/utils.dart`. Same algorithm, same winding
   comments, two languages. (Assimp does not need it — it triangulates
   natively.)
2. **Native→Dart mesh marshalling exists twice.**
   `FFIGltfMeshData.parse` and `ModelImporter._readMesh` both copy native
   float/int arrays into `Float32List`/`Uint32List` with the same
   allocate/copy/free pattern. ~60 lines each, structurally identical,
   different field sets.
3. **"Parse buffer → mesh list" API shape exists twice.**
   `parseGltf(data, {meshName})` vs `ModelImporter.loadFromBuffer(data,
   formatHint:)`. Same concept, different signatures and result types.

### Not duplication

- **Path A vs Path C are different products.** gltfio produces a scene:
  transforms, PBR materials, skinning, animation. The Assimp path
  produces raw geometry for formats gltfio cannot read (FBX/STL/OBJ/PLY).
  Replacing Path A with Assimp would lose materials/animation fidelity
  and triple the binary size for every user (Assimp is opt-in at link
  time today, ~1 MB+ per platform). Not desirable.
- **cgltf in `GltfSceneAsset` is not a parser we own.** It consumes the
  source-data handle gltfio already produced. Unifying it with Assimp
  would mean replacing gltfio. Out of scope.
- **UV handling differs by necessity.** glTF has top-left UV origin;
  OBJ/FBX mostly bottom-left. The `flipUvs` flag in
   `ImportedMesh.toGeometry` is format-specific logic, not shared logic.

### Gaps the comparison exposes (side finding)

- Assimp path applies no node transforms (flat OBJ/STL fine; FBX scenes
  will be wrongly composed).
- `ImportedMesh.materialName` is parsed but never used.
- Path B (`GltfMeshData`) has no production caller; it is a candidate for
  deprecation rather than unification.

## Option: one overarching structure

### Proposed shape

A single Dart-side facade plus a shared mesh-transfer struct at the FFI
boundary; parsers stay pluggable behind it.

```
lib/src/model_import/                         (new)
  model_file_importer.dart    - abstract ModelFileImporter
                               (Future<List<RawMesh>> parse(Uint8List data, {String? formatHint}))
  raw_mesh.dart               - shared result type: name, materialName,
                                vertices, normals, uvs, indices
  assimp_importer.dart        - wraps current ModelImporter FFI calls
  cgltf_importer.dart         - wraps current FFIGltfMeshData FFI calls
                                (or is deleted, see recommendation)
```

Native side (smaller change):

```
native/include/c_api/mesh_transfer.h          - one POD struct:
                                                TMeshData { name, materialName,
                                                vertices, indices, normals, uvs,
                                                indexCount... }
```

- `ModelImporter_get*` (7 getters) collapse into one
  `ModelImporter_getMesh(importer, index, TMeshData* out)` — one FFI
  crossing per mesh instead of five.
- `TGltfParser.cpp` either adopts `TMeshData` or is deleted.
- `expandTriangleStrip` keeps a single implementation in C++
  (`TGltfParser` or a small `native/src/utils/MeshUtils.cpp`); the Dart
  copy in `GeometryUtils` delegates or stays for pure-Dart geometry use.

### Concrete touch points

| File | Change |
| --- | --- |
| `lib/src/filament/src/implementation/ffi_model_importer.dart` | becomes `AssimpImporter`, returns `RawMesh` |
| `lib/src/filament/src/implementation/ffi_gltf_mesh_data.dart` | deleted or wrapped |
| `lib/src/utils/src/geometry/utils.dart` | `parseModelFromBuffer` routes through the facade |
| `native/src/c_api/model_import.cpp` | single `getMesh` out-struct API |
| `native/src/c_api/TGltfParser.cpp` | adopt shared struct or remove |
| bindings | regenerate (`make bindings`) |

### Rough effort

- Facade + `RawMesh` + migrate Assimp path: **1–2 days** including
  binding regeneration and test updates. Low risk — internal refactor,
  public API (`loadModel`, `parseModelFromBuffer`) unchanged.
- Folding `TGltfParser` in as well: **+0.5 day** if kept, or **−200
  lines** if deprecated (it has no production caller).
- Applying Assimp node transforms (fixing the flat-scene gap):
  **+1 day** — walk `mRootNode`, multiply `mTransformation` into
  vertices (or expose per-mesh 4×4 matrices and let Dart apply them).
  Independent of the unification; worth doing regardless.

## Recommendation

**Unify later, partially, and do not touch Path A.**

1. **Keep gltfio as the glTF engine.** It is the mature, full-featured
   path. Assimp for glTF would be a regression (materials, animation,
   skinning) and forces the Assimp link on everyone.
2. **Do the facade refactor as a follow-up PR, not in #195.** The PR is
   already carrying an importer, an opt-in link flag, and a bindings
   regen. The facade is a clean mechanical follow-up once it lands.
3. **In that follow-up, fold `GltfParser`/`GltfMeshData` into the facade
   or deprecate it.** It has no production caller; keeping two
   flat-mesh APIs alive is the actual duplication cost.
4. **Fix the Assimp node-transform gap soon.** It is a correctness issue
   for FBX, independent of any unification.
5. **Do not chase a shared native "model parser" interface.** cgltf
   inside `GltfSceneAsset` is gltfio plumbing; Assimp is a standalone
   importer. A C++ abstraction over both would be ceremony without a
   second consumer. The Dart facade plus one shared `TMeshData` struct
   captures all the real reuse.

Net: one public concept (`loadModel`), one internal facade, one mesh
transfer struct, two parser backends behind it. glTF stays on gltfio.
