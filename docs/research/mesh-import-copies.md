# Mesh import: the native → Dart → native copies

Research note (2026-08-16, branch `feat/assimp-integration` @ `d12c5504`). No code
was changed; line numbers refer to that commit.

**Owner question:** are the `_copyFloats`/`_copyIndices` helpers (and the overall
native→Dart→native data flow in model import) necessary? What are the alternatives?

**TL;DR:** Vertex data is copied 3 times between parse and GPU upload, of which
the Dart-side copy (`_copyFloats`/`_copyIndices`) is the middle one. That copy is
not technically required — it exists because of a deliberate ownership contract:
`ModelImporter_getMesh` returns malloc'd buffers that `MeshData_dispose` frees
after every mesh, while `RawMesh` (the public `parse()` result) must outlive the
importer. Changing the contract (alternative b) removes one of the three copies
with no public API change. A fully native path (alternative c) removes all Dart
side copies but is a much bigger job. For typical meshes the copies cost a few
milliseconds of transient work; nothing here is a correctness problem.

---

## 1. The exact data flow, end to end

Production entry point: `loadModelFromBuffer`
(`thermion_dart/lib/src/viewer/src/ffi/src/thermion_viewer_ffi.dart:567`) →
`GeometryUtils.parseModelFromBuffer`
(`thermion_dart/lib/src/utils/src/geometry/utils.dart:396`) → `AssimpImporter().parse`
→ `RawMesh.toGeometry` → back in the viewer, `createGeometry`
(`thermion_dart/lib/src/filament/src/implementation/ffi_filament_app.dart:1282`).

One important fact that shapes everything below: the ffigen bindings are
generated with `isLeaf: true` (`thermion_dart_ffi.g.dart:399,409,872,3423,4077`),
and Dart ≥ 3.5 supports `TypedData.address` as an argument to leaf `@Native`
calls (SDK `dart:ffi` `Uint8ListAddress` etc. extensions). The VM pins the list
for the duration of the call and passes a pointer to its storage. So "passing a
Dart list into a leaf FFI call" is **zero-copy** in this codebase — there is no
hidden staging copy in `setBufferAt` or the orientation builder.

### Copy map (per mesh)

| # | Where | What | Kind |
|---|-------|------|------|
| 0 | `assimp_importer.dart:35-36` (`allocate` + `setAll`) | file bytes Dart → native | plain copy, avoidable (see §5) |
| 1 | `model_import.cpp:240-307` (`ModelImporter_getMesh`) | `aiMesh` arrays → flat `malloc` buffers | conversion, **required** |
| 2 | `assimp_importer.dart:70-73, 94-106` (`_copyFloats`/`_copyIndices`) | native buffers → Dart heap (`Float32List.fromList(view)`) | plain copy, **the one in question** |
| 3a | `raw_mesh.dart:93-100` (`_flipUVs`) | UVs into a new `Float32List` | plain copy, on by default |
| 3b | `raw_mesh.dart:68-75` (`indices.map((i) => i.toInt()).toList()`) | `Uint32List` → boxed growable `List<int>` for USHORT meshes | worst per-element copy in the pipeline |
| 4 | `ffi_filament_app.dart:1313,1317,1411-1415` (`makeUint32List(..)..setRange`) | `List<int>` indices → typed list for upload | plain copy |
| — | `ffi_filament_app.dart:1371-1400` (`setBufferAt`) | pinned Dart heap → Filament allocator (render thread) | GPU upload, unavoidable |

Steps that look like copies but are not:

- **Tangent generation round-trip** (`ffi_filament_app.dart:1298-1330`):
  positions/normals/uvs go in via `.address`
  (`ffi_surface_orientation.dart:83-102`), and the quaternions are written by
  native code directly into a Dart-allocated list
  (`ffi_surface_orientation.dart:30-50`). Two FFI crossings and native compute,
  but no staging buffer.
- **`setBufferAt`** (`ffi_vertex_buffer.dart:20-34`): `byteData.address` is a
  pinned pass-through; Filament's own copy into its allocator is the upload
  itself.
- **Dummy attributes** (`createDummyColors`/`createDummyUvs`, both default true
  via `utils.dart:403`): allocations and fills for the ubershader's UV0/UV1/COLOR
  slots, not copies of source data.
- **Bounding box** (`ffi_filament_app.dart:1418-1430`): a Dart loop over
  vertices — compute, not a copy.

### Copy #1 is a conversion, not a memcpy

`ModelImporter_getMesh` never block-copies: it walks every vertex to apply the
accumulated node transform and normal matrix (`model_import.cpp:61-79, 240-268`),
de-interleaves `aiVector3D` (12-byte xyz structs) into flat float arrays, strips
degenerate faces, and widens indices to `uint32_t` (`model_import.cpp:284-307`).
Even for identity transforms the de-interleave pass runs. This copy is required
by the format mismatch (`aiMesh` interleaved → flat float3/float2 that
`Geometry`/Filament expect); no alternative short of a stride-aware native
geometry path removes it.

### The cgltf path

`CgltfImporter.parse` (`cgltf_importer.dart:22-55`) shares `TMeshData` and makes
the same Dart copies (`Float32List.fromList(ref.vertices.asTypedList(...))`,
lines 38-43) and the same `MeshData_dispose`. It passes the *input* file bytes
by `.address` (line 28) — i.e. the cgltf path already avoids copy #0.

---

## 2. Why the Dart copy exists today

Three constraints pin the current design:

1. **The C API owns the buffers and frees them eagerly.** `MeshData_dispose`
   (`native/src/c_api/TMeshData.cpp`) `free()`s all six pointers and memsets the
   struct; `assimp_importer.dart:77` calls it after every mesh because…
2. **One `TMeshData` slot is reused for every mesh** (`assimp_importer.dart:56`).
   The native buffers are transient by construction — the next `getMesh` would
   overwrite the struct anyway.
3. **`RawMesh` is the public return type of `parse()` and must outlive the
   importer.** The importer is destroyed inside `parse()`
   (`assimp_importer.dart:86`), while callers keep `RawMesh`/`Geometry`
   indefinitely (`utils.dart:403`, then the asset in the viewer).

So the copy is an implementation choice that follows from the chosen ownership
contract (native frees after each mesh), not from any hard technical requirement.
`RawMesh`'s own doc states the contract explicitly: "All buffers are plain
Dart-owned copies; nothing points into native memory after the importer call
returns" (`raw_mesh.dart:10-11`), and `dispose()` is a no-op (line 91).

The keyword `pointer.asTypedList(count)` used inside `_copyFloats` already
produces a zero-copy native-backed view — it is the `Float32List.fromList(...)`
wrapper that materializes the copy.

---

## 3. The real cost

Per mesh, copy #2 duplicates roughly `32 B/vertex + 12 B/triangle`
(positions 12 + normals 12 + uvs 8; indices 4 × 3/tri), and copy #1 duplicates
the same again on the native side before it. All of it is transient: the native
buffers are freed per mesh, and the Dart lists are collectable once
`createGeometry` has uploaded them. The steady-state costs are:

- **Peak memory**: ~2× attribute bytes live at once (native copy + Dart copy),
  plus dummy attribute buffers.
- **Time**: two extra full passes over attribute data. For a 1M-vertex mesh
  (~32 MB) that is two ~32 MB passes; for typical (<100k vertex) meshes it is
  single-digit milliseconds. Assimp's own parse and tangent generation dominate
  wall-clock time in practice.
- **The one genuinely wasteful hot spot** is copy #3b: for any mesh with
  ≤ 65535 indices — nearly every real mesh — `raw_mesh.dart:72` iterates a
  `Uint32List` through `.map((i) => i.toInt()).toList()`, producing a growable
  `List<int>` of boxed ints, which copy #4 then unboxes again. This is inside
  `toGeometry`, independent of the FFI question, and fixable with
  `Uint16List.fromList(...)` with no API change (research-only observation; not
  changed here).

---

## 4. Lifetime/finalizer precedent in the codebase

There is **no `NativeFinalizer` usage anywhere in `thermion_dart/lib/src`**
(grep verified). The existing convention is explicit lifetime management:

- `FinalizableUint8List` (`bindings/src/ffi.dart:83-88`) only *implements*
  `Finalizable` — despite the name it registers nothing. It is a plain holder,
  kept alive in a manually-managed list (`ffi_filament_app.dart:1137-1179`) so
  the underlying native strings outlive the call that uses them.
- `TIndexBuffer`-style native handles are freed through explicit `destroy()`
  paths on the Dart wrappers.

So alternative (b) would either follow the explicit-dispose convention or
introduce the codebase's first `NativeFinalizer` (available in the SDK:
`dart:ffi` `NativeFinalizer`). Both are workable; the second is a new pattern
here.

---

## 5. Alternatives

### a. Keep as-is

- **Effort:** 0. **Risk:** 0.
- **Cost:** as stated in §3 — transient memory and a few extra passes; no
  correctness issue; no API impact.
- This is the right default until profiling shows otherwise.

### a+ (variant) Micro-fixes inside the current architecture

Three copies can be reduced with no architectural change (each is small,
independent, and research-only here):

1. Replace the boxed conversion in `raw_mesh.dart:72` with
   `Uint16List.fromList(indices)` — kills copy #3b's boxing.
2. Pass the file bytes by `data.address` in `assimp_importer.dart:35-42`
   (the binding is already leaf, `thermion_dart_ffi.g.dart:399`; the cgltf path
   already does this) — kills copy #0.
3. Reuse the two typed index lists made for the orientation builder
   (`ffi_filament_app.dart:1313/1317`) for the index buffer at 1411-1415, or
   generate quats from `trianglesUint16/32` — kills one instance of copy #4.

- **Effort:** hours. **Risk:** low (pure Dart-side changes, covered by existing
  model-import tests). **API impact:** none. **Web:** n/a (unchanged paths).

### b. Zero-copy views + transfer buffer ownership to `RawMesh`

Keep `pointer.asTypedList(count)` views instead of `.fromList(...)`; stop
calling `MeshData_dispose` per mesh; free the native buffers in
`RawMesh.dispose()` (and/or attach a `NativeFinalizer` as a safety net).

What has to change:

- `ModelImporter_getMesh` currently receives the caller's reused slot. Either
  allocate a `TMeshData` per mesh (small) or return buffers that outlive the
  struct — in practice: allocate the struct per mesh, hand ownership of its
  six pointers to the `RawMesh`, and let `RawMesh.dispose()` call
  `MeshData_dispose`.
- `RawMesh.dispose()` stops being a no-op; the doc line at `raw_mesh.dart:10-11`
  changes to describe borrowed memory.

- **Effort:** 1-2 days including tests (both importers, `MeshData_dispose`
  ownership semantics, memory-leak check).
- **Risk:** medium — use-after-free if a caller retains `positions` after
  `dispose()`; leak if a caller never disposes (mitigated by a finalizer, which
  would be this codebase's first). `toGeometry`'s `_flipUVs` copy stays for
  flipped meshes.
- **Public API:** unchanged in shape — `RawMesh.positions` remains a
  `Float32List` (views *are* `Float32List`s). Semantically, buffers go from
  "owned" to "borrowed until dispose".
- **Web:** no regression — `js_interop.dart` has no `TMeshData`/model-import
  symbols today, so model import is already native-only.
- **Payoff:** removes copy #2 only (one of three).

### c. Native-only path: parsed scene → geometry without crossing into Dart

Add a C API that builds the `VertexBuffer`/`IndexBuffer`/`SurfaceOrientation`
directly from the parsed mesh data, so `loadModelFromBuffer` never materialises
Dart attribute lists.

- **Effort:** 1-2 weeks — new C entry point(s) in `native/src/c_api/`, ffigen
  regen (`make bindings`), artifact rebuild + R2 republish (dispatched
  "Build Filament" run), plumbing for names/materials back to Dart, bounding
  box, dummy-attribute parity, and keeping `parse()`-based tests meaningful.
- **Risk:** highest — duplicates geometry-creation logic in C++ (currently all
  in `createGeometry`), must reproduce `flipUvs`/ubershader/dummy-buffer
  behaviour exactly, and every platform's artifact must be rebuilt.
- **Public API:** `loadModelFromBuffer`'s signature can stay; `parse()` (public)
  either keeps the copying path or grows a second implementation, so the fast
  path and the public data path can drift.
- **Web:** assimp does build for web (`build-libassimp.yml` has a web job), but
  the js_interop bindings have no model-import symbols — same gap as today.
- **Payoff:** removes copies #2, #3a, #3b and #4 and the orientation round-trip;
  keeps #1 (the required transform/conversion) and the GPU upload.

### d. `toGeometry` accepting native pointers

Subsumed by (b). If `RawMesh` holds native-backed views, `toGeometry` and
`createGeometry` work **unchanged**, because every downstream consumer already
passes lists by `.address` (leaf calls accept native-backed lists: `.address`
returns the list's own data pointer). Adding explicit `Pointer` fields to
`Geometry` would be public API churn for no extra benefit over (b).

### e. Other options found

- **(e1) Caller-provided arena:** Dart allocates the attribute buffers once per
  `parse()` and `getMesh` fills them (change the C signature to take output
  pointers). Removes per-mesh malloc/free churn but keeps both copies #1 and #2.
  Effort ~1 day; no `RawMesh` API change; C API + bindings change.
- **(e2) Borrow views straight into the live `aiScene`:** no copy #1 either,
  but the importer must then outlive every `RawMesh`, breaking `parse()`'s
  destroy-inside-parse structure, and the interleaved `aiVector3D` layout means
  consumers need stride support. Only pays off combined with (c).
- **(e3) Scoped (c): a native fast path for `loadModelFromBuffer` only**, while
  `parse()` keeps the Dart path for the public API. Effort ~3-5 days. Same
  artifact-rebuild cost as (c); smaller surface to keep in parity.

---

## 6. Recommendation

1. **Now:** keep the architecture (a), and land the (a+) micro-fixes — the
   boxed USHORT conversion in `raw_mesh.dart:72` is the only copy that is
   meaningfully worse than it needs to be, and it is a one-line, zero-risk fix.
2. **If profiling shows real cost on large meshes:** do (b). It is the only
   alternative with no public API change and removes the copy the owner asked
   about; the price is making `RawMesh.dispose()` meaningful.
3. **Reserve (c)/(e3)** for when a native geometry path is wanted for its own
   sake (streaming, background loading, huge meshes); on its own it is not
   worth 1-2 weeks plus an artifact republish to save milliseconds of
   transient work.

The copies are not *necessary*; they are the price of the current, simple
ownership contract ("native frees immediately, Dart owns everything it
returns"). That contract is a reasonable one to keep until measurements say
otherwise.
