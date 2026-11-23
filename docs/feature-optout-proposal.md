# Proposal: compile-time feature opt-outs for native libraries

| | |
| --- | --- |
| Status | **Implementing on `feature-opt-libs`** (round 3). The native `gltf: false` prototype, the `features` schema, the C guards/probe, the unlit fallback, the Dart `supports()`/`UnsupportedError` surface and the slim-build test are landed; §10 records what the Linux proof measured, where the implementation deviated from this text, and what remains (Android arm64 measurement, CI wiring, web engine republication). |
| Branch | `feature-opt-libs` (branched from `origin/develop` at `9029ba90`) |
| Filament | v1.77.2 (`filament.version`) |
| Supersedes | The open ideas in `.tickets/the-0rkw.md` (optional libraries for binary size). This document uses the real link list and measured archive closures. |

## 1. Summary

Every native build of `thermion_dart` links one C++ wrapper
(`libthermion_dart`) against the same Filament archive set on every platform.
An app that only draws procedural geometry still compiles in the glTF loader,
its animation stack, Draco, the KTX/Basis texture decoders and the PNG/JPEG
decoder, because Thermion's own C++ references them. Removing a `-l` flag
alone does not change the binary: static archives only contribute the object
files that something references. The size is in the references.

This proposal adds three **opt-out** user defines (default: everything on, so
existing apps are unchanged):

```yaml
hooks:
  user_defines:
    thermion_dart:
      features:
        gltf: false            # no glTF loading, glTF animation, ubershader materials
        ktx: false             # no KTX1/KTX2/Basis textures
        image_decoding: false  # no PNG/JPEG decoding (stb)
```

For each one:

1. the hook stops passing the archives that only that feature needs, so a
   missed guard fails at **link time**, not at `dlopen`;
2. every Thermion translation unit that references those archives is guarded
   by a `THERMION_ENABLE_<FEATURE>` macro and falls back to the stub pattern
   already used by `TMaterialCompiler.cpp` (`runtime_materials`): the same C
   symbols are exported, they return null/0, so the Dart FFI bindings are
   byte-for-byte the same and `dlopen`/wasm load never sees a missing symbol;
3. a new `Thermion_getEnabledFeatures()` C function lets Dart report what the
   loaded build has (`FilamentApp.instance!.supports(ThermionFeature.gltf)`),
   and the affected Dart APIs throw `UnsupportedError` instead of returning
   garbage.

Of the eight libraries in scope:

| Library | Verdict | Marginal cost when referenced (Linux x64 release, see §7) |
| --- | --- | --- |
| `gltfio` (`gltfio_core`, `gltfio`, `uberarchive`) | **opt-out** (`features.gltf`) | ≈ 4.4 MB including everything it drags in (Draco, KTX/Basis, stb) |
| `stb` | **opt-out** (`features.image_decoding`) | ≈ 0.12 MB |
| `image` | **keep** (core data type `LinearImage`; 9 KB marginal) | ≈ 0.01 MB |
| `ktxreader` | **opt-out** (`features.ktx`) | ≈ 0.08 MB (+ `basis_transcoder` 1.4 MB) |
| `basis_transcoder` | **opt-out**, but only *through* `features.ktx` (no direct Thermion reference) | ≈ 1.4 MB |
| `draco` (`dracodec`) | **opt-out**, but only *through* `features.gltf` (no direct Thermion reference; gltfio's `AssetLoader` always calls it) | ≈ 1.0 MB |
| `filamat` (+ `matp`) | **already opt-in** (`runtime_materials`); two forced-link cases remain and are cost-free | ≈ 41 MB when `runtime_materials: true` |
| `filameshio` | **already gone** (#287); nothing links it, 0 bytes | 0 |

The headline saving for a procedural-only app (all three off) is roughly
**4.6 MB of object code** on Linux x64 (Filament's part only; Thermion's own
guarded wrappers add a little more, not measured). The per-feature numbers
overlap: dropping glTF alone also drops Draco and the glTF texture providers.

## 2. What is linked today

All of the following is forced by `thermion_dart/hook/build.dart` (native) or
`thermion_dart/native/web/CMakeLists.txt` (web) and does not depend on what the
app calls.

### 2.1 Native hook (`hook/build.dart`, the `libs` list, lines 316-395)

| Archive | Condition today | Needed by |
| --- | --- | --- |
| `filament`, `backend`, `utils`, `filabridge`, `filaflat`, `geometry`, `filament-iblprefilter` | always | core engine; `geometry` also by `TSurfaceOrientation` / `CustomGeometry` |
| `gltfio_core` | always | every glTF wrapper (§3.1) |
| `gltfio` (full archive) | `!android && !ios` | **nothing.** Thermion only uses `gltfio_core` symbols (`createUbershaderProvider`, never `createFilamentMaterialProvider`). Pulls 0 bytes today. |
| `uberarchive` | always | the ubershader material blob used by `TGltfAssetLoader.cpp` (`UBERARCHIVE_DEFAULT_DATA`) |
| `dracodec` | always | gltfio `AssetLoader` (Draco-compressed glTF meshes) |
| `ktxreader` | always | `TTexture.cpp` (`Ktx1Reader`, `Ktx2Reader`) and gltfio's `createKtx2Provider` |
| `basis_transcoder` | always | `ktxreader` (KTX2 with BasisLZ/ASTC payloads, KTX1 with Basis payload) |
| `stb` | always | `TTexture.cpp` `Image_decode` (`stbi_load_from_memory`) and gltfio's `createStbProvider` |
| `image` | always | `LinearImage` (public `createImage`/`setLinearImage`/`loadImage` APIs), `Ktx1Bundle`, ktxreader |
| `z`, `uberzlib` | always | ktxreader/gltfio inflate (system `z` is free; `uberzlib` is 3 KB when pulled) |
| `ibl` | always | **nothing** in Thermion sources (no `#include <ibl/...>`); pulls 0 bytes |
| `smol-v` | always | **core**: `filaflat::DictionaryReader` calls `smolv::Decode` for every material package (53 KB pulled even with no features); `filamat` only adds the encoder side |
| `zstd` | `!linux` | `filament::ZstdHelper` / `MaterialParser` (`ZSTD_*`) — core; on Linux the combined `libfilamat.a` is the provider |
| `matp`, `filamat`, `shaders` | `runtime_materials`, plus `filamat` in **debug** (matdbg `ShaderReplacer`) and on **Linux** (zstd provider) | `TMaterialCompiler.cpp` (guarded by `THERMION_ENABLE_RUNTIME_MATERIALS`); `TMaterialPackage.cpp` uses only the header constant `filamat::MaterialVersion` |
| `matdbg`, `fgviewer` | debug on macOS/Android (and Linux debug via `libraries`) | Filament debug builds only |
| `meshoptimizer`, `mikktspace` | Windows only (`#pragma comment(lib)` in `native/include/ThermionWin32.h`) | gltfio (meshopt extension, tangents) |

Platform extras (`bluegl`/`bluevk`, Android `GLESv3`/`EGL`/`perfetto`, Linux
`drm`/`EGL`/`GL`/`gbm`, `webgpu_dawn`/`abseil` for the WebGPU backend) are
core and unaffected by this proposal.

Windows differs in one way: `ThermionWin32.h` links `matp.lib` and
`filamat.lib` unconditionally (lines 14-15), regardless of `runtime_materials`.
As with every archive, this costs nothing unless referenced, but the pragma
should move under the same `THERMION_ENABLE_RUNTIME_MATERIALS` guard as the
glslang/SPIRV pragmas below it for consistency (§5.5).

### 2.2 Web (`native/web/CMakeLists.txt`, `target_link_libraries`, lines 365-407)

`gltfio_core filament backend geometry mikktspace dracodec ibl-lite ktxreader
filaflat filabridge image utils stb uberzlib uberarchive meshoptimizer
basis_transcoder basis_encoder z zstd png`, plus `matp filamat shaders smol_v`
under `THERMION_ENABLE_RUNTIME_MATERIALS`. The engine is published prebuilt in
a small set of variants (default, main-thread, runtime-materials, WebGPU), so
web users cannot opt out per app; §4.6 explains how the schema treats web.

### 2.3 What already works as a precedent

`runtime_materials` is the exact mechanism this proposal generalises:

- hook: `defines["THERMION_ENABLE_RUNTIME_MATERIALS"] = "1"` and conditional
  `libs` entries (`hook/build.dart` lines 236-240, 324-343);
- C: `TMaterialCompiler.cpp` compiles the real implementation under
  `#ifdef THERMION_ENABLE_RUNTIME_MATERIALS` and a complete stub set under
  `#else` (lines 665-740), so every `MaterialCompiler_*` symbol exists;
- Dart: `MaterialCompiler_isSupported()` backs `runtimeMaterialsSupported`,
  and `compileMaterialSource`/`compileMaterialPackage` throw
  `UnsupportedError` when it is 0 (`ffi_filament_app.dart` lines 707, 792);
- web: `option(THERMION_ENABLE_RUNTIME_MATERIALS)` selects a separate engine
  zip; the default engine dead-code-eliminates the unreferenced archive.

## 3. Library → dependency chain map

Terms used below:

- **link-time reference**: Thermion code uses a symbol defined in the archive.
  This is what pulls object files into the binary and what breaks if the
  archive is removed from the link line without a guard.
- **compile-time reference**: an `#include` of the library's header. The
  headers always ship inside the Filament artifact, so these never break; they
  are listed only so the guards can also drop the include (keeps a disabled
  feature from accidentally re-introducing a link-time reference later).
- **Dart chain**: the public Dart API(s) that end in the C entry point. Dart
  bindings (`lib/src/bindings/src/thermion_dart_ffi.g.dart`, generated by
  ffigen from `native/include/c_api/*.h`) look every symbol up lazily on first
  call, so a *missing* symbol fails at the first Dart call, not at library
  load. Stubs (§5) make this moot, but it explains why the symbol set must not
  change per build: one generated binding file serves every feature
  combination, on native and web.

### 3.1 `gltfio` — `gltfio_core` + `gltfio` + `uberarchive`

**What it is.** `gltfio_core` is Filament's glTF runtime: `AssetLoader`,
`ResourceLoader`, `Animator`, `FilamentAsset`/`FilamentInstance`, the
`MaterialProvider` interface and its `UbershaderProvider`, the `TextureProvider`
interface with `StbProvider`/`Ktx2Provider`, and the cgltf-based
`AssetLoaderExtended` (meshopt, tangents). `uberarchive` holds the ubershader
material package (`UBERARCHIVE_DEFAULT_DATA`). The full `gltfio` archive only
adds `createFilamentMaterialProvider`, which compiles glTF materials through
`filamat::MaterialParser`; Thermion never calls it.

**Transitive dependencies.** `dracodec` (every `AssetLoader` references
`draco::Decoder`), `meshoptimizer` + `geometry`'s `TangentSpaceMeshWrapper` +
`mikktspace` (via `AssetLoaderExtended`/`Utility.cpp`), `uberzlib`, and —
through the two texture providers — `stb`, `ktxreader` and `basis_transcoder`.

**Link-time references (C):**

| File | Uses | C entry points | Reached from Dart |
| --- | --- | --- | --- |
| `native/src/c_api/TGltfAssetLoader.cpp` | `createUbershaderProvider(engine, UBERARCHIVE_DEFAULT_DATA, UBERARCHIVE_DEFAULT_SIZE)`, `AssetLoader::create/destroy`, `AssetLoader::createAsset` | `GltfAssetLoader_create`, `_destroy`, `_load`, `_getMaterialProvider` (+`*JobThread`) | `FFIFilamentApp.create` (**at engine init**, lines 205-212), `loadGltfFromBuffer` (1462-1570), `destroy` (442) |
| `native/src/c_api/TGltfResourceLoader.cpp` | `ResourceLoader`, `createStbProvider`, `createKtx2Provider`, `addTextureProvider`, `addResourceData`, `asyncBeginLoad/asyncUpdateLoad/asyncGetLoadProgress`, `loadResources` | `GltfResourceLoader_*` | `FFIFilamentApp.loadGltfFromBuffer` |
| `native/src/c_api/TFilamentAsset.cpp` | `FilamentAsset::getResourceUris/Count`, `getEntities/Count`, `getWireframe`, `getSourceAsset` | `FilamentAsset_*` | `loadGltfFromBuffer` (`getResourceUris`), wireframe utilities |
| `native/src/c_api/TMaterialProvider.cpp` | `gltfio::MaterialProvider`, `MaterialKey`, `UvMap`, `AlphaMode` → `createMaterialInstance` | `MaterialProvider_createMaterialInstance` (+`*JobThread`) | `createUbershaderMaterialInstance`, `createUbershaderMaterial`, **`createUnlitMaterialInstance`** |
| `native/src/c_api/TSceneAsset.cpp` — **glTF-specific entry points only**; the rest of the file (`SceneAsset_createFromBuffers`, shared entity/light/camera access, instancing, `SceneAsset_destroy`, …) is core procedural code and is **not** guarded (§5.2 Pattern B, decision D1) | `GltfSceneAsset` (`AssetLoader::createInstanceAsset`, `Animator`, `releaseSourceData`, bone accessors) | `SceneAsset_createFromFilamentAsset`, `_getFilamentAsset`, `_releaseSourceData`, `_getBones/_getBoneCount/_getBoneName`; `_createInstance`/`_getInstance` stay live for geometry assets (the `GltfSceneAsset` branch inside them is guarded) | `loadGltfFromBuffer`; `FFIAsset.createInstance/getInstance/releaseSourceData/getBones` |
| `native/src/c_api/TScene.cpp` | `Scene_addFilamentAsset` (`FilamentAsset::getEntities/getLightEntities`) | `Scene_addFilamentAsset` | no Dart caller (dead on the Dart side) |
| `native/src/c_api/TAnimationManager.cpp`, `native/src/scene/AnimationManager.cpp`, `native/src/components/{Gltf,Bone,Morph}AnimationComponentManager.cpp` | `gltfio::Animator` (`applyAnimation`, `updateBoneMatrices`, animation count/duration/name), `FilamentInstance::getAnimator()`, `FilamentAsset::getInstance()` | `AnimationManager_*` (24 functions + JobThread variants) | `FFIAnimationManager` (**created at init**, line 224), `FFIAsset` animation helpers |
| `native/src/scene/GltfSceneAsset.cpp`, `GltfSceneAssetInstance.cpp` + headers | `AssetLoader`, `Animator`, `FilamentAsset`, `FilamentInstance` | (used by `TSceneAsset.cpp`) | — |
| `native/src/c_api/ThermionDartJobThreadApi.cpp` | Job-thread wrappers for all of the above | `GltfAssetLoader_*JobThread`, `GltfResourceLoader_*JobThread`, `SceneAsset_createFromFilamentAssetJobThread`, `MaterialProvider_createMaterialInstanceJobThread`, `AnimationManager_*JobThread`, `FilamentAsset_getWireframeJobThread`, `Scene_addFilamentAssetJobThread` | all of the above (Dart always uses the JobThread variants) |

**Compile-time only (no symbol):** `TEngine.cpp` (seven gltfio includes,
`gltfio/math.h`), `TIndirectLight.cpp` (`FilamentAsset.h`, `FilamentInstance.h`),
`TTransformManager.cpp` (`gltfio/math.h`; none of its helpers — `toMat4`,
`toFloatArray`, … — are called anywhere in Thermion, so the include can simply
be dropped; **correction during implementation (§10):** `decomposeMatrix` /
`composeMatrix` *are* called there. They are header-only `inline` functions, so
this is still compile-time only — the include stays, nothing is linked),
`scene/GeometrySceneAsset.cpp/.hpp` (`MaterialProvider.h`),
`include/scene/SceneAsset.hpp` (`FilamentAsset.h`),
`include/material/FileMaterialProvider.hpp` (unused class deriving from
`gltfio::MaterialProvider`; delete or guard).

**Dart chain (public API):**

| Dart API | Implementation | Needs gltfio for |
| --- | --- | --- |
| `FilamentApp.loadGltfFromBuffer`, `ThermionViewer.loadGltf/loadGltfFromBuffer`, `ThermionViewerWidget.assetPath` | `FFIFilamentApp.loadGltfFromBuffer`, `ThermionViewerFfi.loadGltfFromBuffer` | the loader, resource loader, asset wrapper |
| `FilamentApp.createUbershaderMaterialInstance`, `createUbershaderMaterial` | `FFIFilamentApp.createUbershaderMaterialInstance` | the ubershader provider |
| `FilamentApp.createUnlitMaterialInstance` | same | same |
| `createGeometry(geometry)` **without** `materialInstances`, `Asset.getBoundingBoxAsset()` (`_createBoundingBox`), `TextureProjection`, `examples/flutter/materials_and_textures`, `examples/dart/.../game_effects_cosmic` | `createUnlitMaterialInstance` | **indirect**: procedural code depends on the glTF ubershader material today |
| `AnimationManager.*` (gltf/bone/morph animation), `Asset.getInstance/createInstance/releaseSourceData/getBones/getMorphTarget…` | `FFIAnimationManager`, `FFIAsset` | `Animator`, instancing |
| `FilamentApp.parseGltf`, `GltfMeshData` | `FFIGltfMeshData.parse` → `GltfParser_parseBuffer` | **Nothing in gltfio itself**, but **correction during implementation (§10):** the `cgltf_*` functions it calls are compiled inside Filament's `gltfio_core` archive, so this *is* a link-time reference to an archive that drops with `features.gltf`. Resolved by compiling the vendored `cgltf.h` (`CGLTF_IMPLEMENTATION`) in `TGltfParser.cpp` when `THERMION_ENABLE_GLTF` is 0. Keeps working when gltfio is off. |

**Verdict: opt-out as `features.gltf`.** When off, the hook drops
`gltfio_core`, `gltfio`, `uberarchive`, `dracodec`, `uberzlib` (and the
Windows-only `meshoptimizer`/`mikktspace` pragmas); `geometry` stays because
`TSurfaceOrientation`/`CustomGeometry` use it. Two things must be solved so
procedural apps keep working (§5.6): engine init must not create the loader,
and `createUnlitMaterialInstance` needs a non-gltfio fallback (a precompiled
`unlit` built-in material, built only in slim builds — §5.6, D5). Independently of this proposal, `gltfio` (the
full archive) can be removed from the desktop link list today because nothing
references it.

### 3.2 `stb`

**What it is.** `stb_image` compiled into `libstb.a` by Filament. Decodes
PNG/JPEG/BMP/GIF/etc. from memory.

**Link-time references:** `TTexture.cpp` → `Image_decode`
(`stbi_load_from_memory`, `stbi_image_free`) only. gltfio reaches it through
`createStbProvider` (`StbProvider.cpp` lives in `gltfio_core` and references
the same `stbi_*` symbols).

**Compile-time only:** `#include <third_party/stb/stb_image.h>`
(`TTexture.cpp`; header copied into every artifact by the build scripts).

**Dart chain:** `FilamentApp.decodeImage(data)` → `FFIFilamentApp.decodeImage`
→ `Image_decode` (line 607) → `LinearImage` → `Texture.setLinearImage` /
`loadImage`; `Ktx1Bundle`-free. Users of `decodeImage`: background images,
skyboxes built from PNG, `TexturedQuad.setImage`, the Flutter plugin's
image-loading helpers. Note that `createImage(w, h, c)` (`Image_createEmpty`,
`LinearImage`) does **not** need stb.

**Verdict: opt-out as `features.image_decoding`.** Drops `stb`. With gltfio on
and `image_decoding` off, `TGltfResourceLoader.cpp` must not register the
`image/png`/`image/jpeg` provider (the TODO in that file, lines 64-70, asks
for exactly this).

### 3.3 `image`

**What it is.** Filament's `libimage.a`: `LinearImage` (shared pixel buffer),
`Ktx1Bundle`/`Ktx2Bundle` (container parsing), colour transforms
(`toLinear`, `sRGBToLinear`, header-only templates).

**Link-time references:** `TTexture.cpp` — `Image_createEmpty`, `Image_get*`,
`Image_destroy`, `Texture_loadImage` (`LinearImage` constructors/accessors);
`Ktx1Bundle_*` (`image::Ktx1Bundle`, used for `loadKtx`/IBL from KTX1);
`Image_decode` (`LinearImage` + the header-only transforms). Also every
archive that handles textures (`ktxreader`, `filament-iblprefilter`).

**Dart chain:** `FilamentApp.createImage`, `Texture.setLinearImage`,
`Texture.loadImage`, `FilamentApp.loadKtx`/`createIblFromKtx`
(`ffi_ktx1_bundle.dart` → `Ktx1Bundle_*`), `decodeImage`.

**Verdict: keep (core).** `LinearImage` is the public currency for pixel data
in the Dart API, independent of any decoder; its marginal cost is 9 KB. Only
the `Ktx1Bundle` entry points move under `features.ktx`.

### 3.4 `ktxreader`

**What it is.** `libktxreader.a`: `Ktx2Reader` (KTX2 → GPU texture, including
Basis Universal and ASTC transcode), `Ktx1Reader` (KTX1 cubemaps → texture
with async upload callback).

**Link-time references:** `TTexture.cpp` → `Ktx2Reader_createTexture`
(`ktxreader::Ktx2Reader`, lines 133-178) and `Ktx1Reader_createTexture`
(`ktxreader::Ktx1Reader::createTexture`, lines 180-214). gltfio reaches it
through `createKtx2Provider`.

**Dart chain:** `FilamentApp.loadKtx2` → `Ktx2Reader_createTextureJobThread`
(`ffi_filament_app.dart` 1963-1975); `FilamentApp.loadKtx` / `createIblFromKtx`
→ `ffi_ktx1_bundle.dart` (`Ktx1Bundle_create/isCubemap/getSphericalHarmonics`)
→ `Ktx1Reader_createTexture` → `Texture.loadKtx`; skyboxes and IBLs from KTX.

**Verdict: opt-out as `features.ktx`** (together with `basis_transcoder`, which
has no other client). With gltfio on and `ktx` off, do not register the
`image/ktx2` provider.

### 3.5 `basis_transcoder`

**What it is.** `libbasis_transcoder.a`: Binomial's Basis Universal
transcoder. KTX2 files store payload data in BasisLZ or ASTC form; KTX1 files
may carry Basis payloads. `ktxreader` is the only Thermion-side client; the
`basis_encoder` archive exists only on web and is referenced by nothing.

**Link-time references:** none in Thermion. Pulled transitively by
`ktxreader::Ktx2Reader::load` / `Ktx1Reader::createTexture` (1.4 MB, the
largest single contributor after Draco in the glTF closure).

**Dart chain:** same as ktxreader.

**Verdict: opt-out, but not independently.** Exposing `basis_transcoder` as its
own key would let users build a `ktxreader` that cannot load any real KTX2
file. It drops with `features.ktx`.

### 3.6 `draco` (`dracodec`)

**What it is.** `libdracodec.a`: Google's Draco mesh decoder. glTF files using
`KHR_draco_mesh_compression` need it; `gltfio::AssetLoader` references
`draco::Decoder` unconditionally (there is no Filament build option to remove
Draco from gltfio).

**Link-time references:** none in Thermion. Pulled by `gltfio_core`'s
`AssetLoader.cpp`/`AssetLoaderExtended.cpp` (≈ 1.0 MB).

**Dart chain:** same as gltfio.

**Verdict: opt-out, but only through `features.gltf`.** Keeping glTF support
while dropping Draco would require patching Filament's `AssetLoader` (an
upstream fork to maintain) for a ≈ 1 MB gain; not recommended.

### 3.7 `filamat` (+ `matp`, `shaders`, `smol-v`, `zstd`)

**What it is.** Filament's material compiler (`MaterialBuilder`, glslang,
SPIRV-Tools, spirv-cross; ≈ 31 MB in the combined archive) and `matp`, the
`.mat` parser behind `matc` (≈ 0.6 MB). `shaders` provides the generated
shader chunks `CodeGenerator` emits; `smol-v` is the shader compressor.

**Link-time references:** `TMaterialCompiler.cpp` only, already guarded by
`THERMION_ENABLE_RUNTIME_MATERIALS` (stubs at lines 665-740).
`TMaterialPackage.cpp` reads `filamat::MaterialVersion`, a `constexpr` in
`filamat/MaterialVersion.h` — no symbol. Core Filament reaches the **zstd**
part of the combined archive (`filament::ZstdHelper`, `filaflat`/`MaterialParser`
→ `ZSTD_*`), which is why Linux (whose artifact does not ship `libzstd.a`)
always lists `filamat`; that rule costs nothing because only the zstd members
are extracted. Debug builds reference `matdbg`, whose `ShaderReplacer` needs
`filamat::Chunk`.

**Dart chain:** `FilamentApp.compileMaterialSource/compileMaterialPackage` →
`MaterialCompiler_*` (guarded), `FilamentApp.materialVersion` →
`Material_getSupportedVersion` (header constant, works in every build).

**Verdict: already opt-in.** Nothing new to expose. Clean-ups, corrected by
review decision D3: (1) **`smol-v` stays unconditional** — the core material
reader (`filaflat::DictionaryReader`) uses its decoder in every build, so it
must not move under `runtime_materials`; only `matp` and the Windows
`matp.lib`/`filamat.lib` pragmas move under the same conditions as the other
platforms so the link lists tell the truth (the pragma guards remain
**presence checks**, see §5.1 — the macro stays undefined when off);
(2) when `features.ktx` and `features.gltf` are both off and
`runtime_materials` is off, the Linux "zstd provider" rule is the only reason
left to list `filamat` — keep it (it is free) rather than special-casing the
artifact.

### 3.8 `filameshio`

**What it is.** `libfilameshio.a` (≈ 54 KB): reader for Filament's `.filamesh`
mesh format, used by Filament's own `filamesh` tool and sample apps.

**Link-time references:** none. Removed from the hook by #287
(`23d9922a build: drop unused imageio, tinyexr and filameshio libs`); not in
`ThermionWin32.h`; not in the web `target_link_libraries`. Residue only:
`.gitattributes` LFS entries for `native/web/lib/*/libfilameshio.a`, the
native-only test targets in `native/test/macos/{CMakeLists.txt,Makefile}`, and
the artifact zips (the build scripts copy every `*.a` Filament produced).

**Dart chain:** none.

**Verdict: already gone; 0 bytes.** No action for the opt-out mechanism. If
the artifact download size matters, stop staging `libfilameshio.a` (and the
other unused archives: `ibl`, `viewer`, `filamentapp*`, `assimp`, `camutils`,
`imagediff`, `gtest`, `benchmark*`, `imgui`, `filagui`) into the zips — that
is a `scripts/` change unrelated to this proposal.

### 3.9 Summary

```
                      features.gltf        features.ktx      features.image_decoding
                      ─────────────        ────────────      ───────────────────────
gltfio_core ─┬─ dracodec                   (via Ktx2Provider) (via StbProvider)
             ├─ meshoptimizer*             │                  │
             ├─ geometry (tangents)        │                  │
             ├─ mikktspace*                │                  │
             ├─ uberzlib                   │                  │
             └─ stb ───────────────────────┼──────────────────┘
             └─ ktxreader ─ basis_transcoder ┘
uberarchive ─┘
image (LinearImage, Ktx1Bundle)  core, except Ktx1Bundle entry points → features.ktx
filamat / matp / shaders         features.runtime_materials (existing) + debug (matdbg) + Linux (zstd)
smol-v                           core (filaflat::DictionaryReader)
z, zstd                          core (material packages, KTX1 inflate)
filameshio                       nothing
* Windows pragmas only
```

| Library | Archive(s) removed from the link line | Guard macro | Stub behaviour |
| --- | --- | --- | --- |
| gltfio | `gltfio_core`, `gltfio`, `uberarchive`, `dracodec`, `uberzlib`, (`meshoptimizer`, `mikktspace` on Windows) | `THERMION_ENABLE_GLTF` | loaders/providers return null; `*JobThread` variants complete their callback with null; animation functions return 0/null |
| stb | `stb` | `THERMION_ENABLE_IMAGE_DECODING` | `Image_decode` returns null |
| ktxreader, basis_transcoder | `ktxreader`, `basis_transcoder` | `THERMION_ENABLE_KTX` | `Ktx2Reader_createTexture`, `Ktx1Reader_createTexture`, `Ktx1Bundle_create` return null; bundle getters return 0 |
| image | — | — | — |
| draco | with gltfio | — | — |
| filamat | unchanged | `THERMION_ENABLE_RUNTIME_MATERIALS` (existing) | existing |
| filameshio | already absent | — | — |

## 4. `userDefines` schema for `hook/build.dart`

### 4.1 Shape

One new top-level key under the existing `hooks.user_defines.thermion_dart`
map, alongside `backend`, `runtime_materials`, `materials` and `plugins`:

```yaml
# consuming app's pubspec.yaml
hooks:
  user_defines:
    thermion_dart:
      features:
        gltf: false             # default true
        ktx: false              # default true
        image_decoding: false   # default true
      runtime_materials: false  # existing key, unchanged (default false)
```

Design decisions, each following an existing precedent in the hook:

| Decision | Precedent |
| --- | --- |
| A `features` **map**, not three top-level booleans | `materials` map (`built_in_materials.dart` `selectBuiltInMaterials`); keeps the top-level namespace from growing one key per library forever |
| **Opt-out** semantics: absent key = enabled | every existing app keeps today's binary; opposite polarity to `runtime_materials` (opt-in) because these features are on today |
| Values must be unquoted YAML booleans; anything else is a **hard error** naming the key | `materials.<key> must be true or false` (`MaterialToolsError`). Stricter than `runtime_materials`' warn-and-continue, because silently ignoring `gltf: "false"` would ship a 4 MB fatter binary than the user asked for |
| Unknown key inside `features` = **warning**, not error | `Unknown key materials.$key` warning; forward compatibility with older hook versions |
| No per-OS map (`features: {android: ...}`) in v1 | `backend` supports per-OS maps, but a Flutter app ships one Dart codebase to all platforms; per-OS feature sets would make `supports()` platform-dependent for no measured need. Can be added later without breaking the flat form |

`draco`, `basis_transcoder`, `filameshio`, `image`, `filamat` deliberately get
**no keys**: §3 shows they are either transitive-only, core, already gated by
`runtime_materials`, or already absent. Exposing them would let users express
broken combinations (ktxreader without a transcoder, gltfio without Draco).

### 4.2 Parsing and validation (new helper, e.g. `lib/src/hooks/feature_flags.dart`)

```dart
// Modeled on selectBuiltInMaterials / resolveBackend.
typedef ThermionFeatures = ({bool gltf, bool ktx, bool imageDecoding});

ThermionFeatures resolveFeatures(Object? raw, {required void Function(String) onWarning}) {
  // null -> all true.
  // non-map -> throw (same style as MaterialToolsError).
  // unknown keys -> onWarning('Unknown key features.$key ...').
  // non-bool values -> throw naming key and expected type.
}
```

Resolved once, early — next to the `backend` resolution (before the web
branch), so both branches see it. Cross-feature rules:

- `gltf: true` together with `ktx: false` or `image_decoding: false` is a
  **hard error in v1** (review decision D2): the combination is deferred
  until completion semantics are defined and tested (§5.3). Filament
  v1.77.2's `ResourceLoader` returns **zero async progress when the provider
  map is empty**, so Dart's polling loop would spin forever — even for an
  *untextured* model — and a missing provider merely logs and skips the
  texture, which never surfaces the promised load error to Dart. The error
  message names both keys and points at §5.3. `ktx`/`image_decoding` remain
  independently switchable when `gltf: false`.
- `gltf: false` implies Draco, meshoptimizer/mikktspace (Windows pragmas) and
  `uberzlib` drop regardless of other keys — they have no other client.
- `runtime_materials: true` is orthogonal; no interaction rules needed
  (filamat never references gltfio).

### 4.3 Hook effects (native branch)

```dart
final features = resolveFeatures(input.userDefines['features'], onWarning: logger.warning);

// Defaults: pass nothing when enabled, so an all-default build's compile
// command is IDENTICAL to today's (important for build caching, §4.5).
// Disabled features pass an explicit 0; the C headers default to 1 (§5.1).
if (!features.gltf) defines['THERMION_ENABLE_GLTF'] = '0';
if (!features.ktx) defines['THERMION_ENABLE_KTX'] = '0';
if (!features.imageDecoding) defines['THERMION_ENABLE_IMAGE_DECODING'] = '0';
// v1 (decision D2, §5.3): gltf on + a decoder off is rejected before any
// build work — resolveFeatures throws naming both keys.
```

The `libs` list (lines 316-395) becomes conditional — order otherwise
unchanged (GNU ld left-to-right resolution):

```dart
if (features.gltf) "gltfio_core",
// "gltfio" (full archive): drop entirely, nothing references it (§3.1).
if (features.imageDecoding) "stb",
if (features.ktx) ...["ktxreader", "basis_transcoder"],
if (features.gltf) ...["dracodec", "uberzlib", "uberarchive"],
// image, z, zstd, smol-v, geometry, filamat rules: unchanged (§3.3, §3.7).
```

Because the archives are *removed*, a guard missed during implementation is a
**link error in CI**, not a silent `dlopen` failure on a user's device. This is
the same fail-fast property `runtime_materials` already has.

### 4.4 Windows

`ThermionWin32.h` gains the same guards around the corresponding
`#pragma comment(lib, ...)` lines:

```c
#if THERMION_ENABLE_GLTF
#pragma comment(lib, "gltfio_core.lib")
#pragma comment(lib, "dracodec.lib")
#pragma comment(lib, "uberarchive.lib")
#pragma comment(lib, "uberzlib.lib")
#pragma comment(lib, "meshoptimizer.lib")
#pragma comment(lib, "mikktspace.lib")
#endif
#if THERMION_ENABLE_KTX
#pragma comment(lib, "ktxreader.lib")
#pragma comment(lib, "basis_transcoder.lib")
#endif
#if THERMION_ENABLE_IMAGE_DECODING
#pragma comment(lib, "stb.lib")
#endif
```

and the unconditional `matp.lib`/`filamat.lib` pragmas (lines 14-15) move
under the existing `#if defined(THERMION_ENABLE_RUNTIME_MATERIALS)` block
(§2.1 consistency fix). That block stays a **presence check**: the macro is
undefined when `runtime_materials` is off (D3, §5.1), never defined to 0.

### 4.5 Caching and artifact identity

- Native Filament archives are feature-agnostic (all features compiled in,
  selection happens at *Thermion* compile/link time), so **no new artifact
  variants** and no `getLibDir` changes — unlike `webgpu`, which needs a
  different Filament build.
- `defines` are already part of the `CBuilder` build identity, so toggling a
  feature rebuilds `libthermion_dart` without any extra cache-key work.
- Passing defines only for *disabled* features (§4.3) keeps default builds
  byte-identical and cache-compatible with today's hook.
- The built-in materials manifest (`materials` key, matc/resgen pipeline) is
  unaffected for default builds; the `unlit` fallback blob (§5.6) is
  compiled by that same pipeline **only when `features.gltf: false`** (D5),
  as a precompiled blob — never by `filamat` at runtime, and never in
  default builds.

### 4.6 Web

The web engine is a **prebuilt** `thermion_dart-<version>-web<suffix>.zip`
(`web_artifacts.dart`); its C is compiled by `native/web/CMakeLists.txt` at
publication time, and variants already multiply (`-main-thread`,
`-runtime-materials`, `-webgpu`, combinations). Publishing a zip per feature
subset would mean up to 8× more variants — rejected.

v1 behaviour:

- the hook parses `features` on web too, but if any feature is disabled it
  logs a **warning**: "web engines are prebuilt with all features;
  `features.*` only affects native builds" (and, once §6 lands, Dart's
  `supports()` still reports the truth from the loaded engine);
- `native/web/CMakeLists.txt` gains the same
  `option(THERMION_ENABLE_GLTF ...)` etc. as the existing
  `THERMION_ENABLE_RUNTIME_MATERIALS` option, defaulting ON, so a
  `-slim` variant (all three off) can be published later as **one** extra
  suffix if demand appears, exactly like `-runtime-materials` was added;
- wasm already dead-code-eliminates unreferenced archives, so the *default*
  web engine only pays for what the prebuilt C references — the win on web
  comes from the same C guards, whenever a slim variant is shipped.

**Web engine release is a hard dependency of the probe (decision D4).**
Dart calls `Thermion_getEnabledFeatures()` during initialization (§6), so
**every currently supported browser engine archive** — default,
`-main-thread`, `-runtime-materials`, `-webgpu` and their combinations —
must export the new symbol *before* the Dart code that requires it ships.
This holds even though v1 adds **zero** slim web variants. Required sequence:

1. add the probe to `native/web/CMakeLists.txt`'s sources (always compiled);
2. rebuild and publish **all** existing variant zips at a new
   `native/web/web.version` (the publication workflow already commits that
   file);
3. only then merge the Dart `supports()`/init changes pinned to that
   `web.version`.

Compatibility path for older engines (cached zips under
`.dart_tool/thermion_dart/web/<version>`, or a pinned older `web.version`):
Dart resolves the `Thermion_getEnabledFeatures` symbol **lazily inside a
try/catch**; if it is absent, the bitmask defaults to **all features
enabled** (which is true of every pre-probe engine) and a one-line warning
notes the legacy engine. `runtimeMaterialsSupported` keeps using
`MaterialCompiler_isSupported()` as today, so legacy behaviour is unchanged.

## 5. C guard and stub design

### 5.1 Macro convention

New header `native/include/ThermionFeatures.h`, included by every guarded
translation unit (and by `ThermionWin32.h`):

```c
#pragma once
// Feature switches. The hook passes -DTHERMION_ENABLE_<FEATURE>=0 only for
// DISABLED features (hook/build.dart); enabled/default builds pass nothing,
// so their compile command lines are unchanged.
#ifndef THERMION_ENABLE_GLTF
#define THERMION_ENABLE_GLTF 1
#endif
#ifndef THERMION_ENABLE_KTX
#define THERMION_ENABLE_KTX 1
#endif
#ifndef THERMION_ENABLE_IMAGE_DECODING
#define THERMION_ENABLE_IMAGE_DECODING 1
#endif
// THERMION_ENABLE_RUNTIME_MATERIALS is deliberately NOT defaulted here
// (decision D3): it keeps its existing presence semantics — defined (=1)
// when runtime_materials is enabled, UNDEFINED when off.
```

Two deliberate differences from the existing `TMaterialCompiler.cpp` style
(`#ifdef`): value macros with header defaults **for the three new switches
only**, because (a) `ThermionWin32.h` must see the same defaults for its
pragmas, and (b) `#if` typos fail loudly with `-Wundef` instead of silently
disabling a feature.

**`THERMION_ENABLE_RUNTIME_MATERIALS` must stay undefined when off
(decision D3).** Its existing guards are presence checks —
`#ifdef` in `TMaterialCompiler.cpp` and `#if defined(...)` in
`ThermionWin32.h` (line 16, the glslang/SPIRV compiler pragmas). Defining it
to `0` would still select the real compiler and the Windows compiler
pragmas under those checks. So `ThermionFeatures.h` gives it **no default**,
and the hook keeps today's behaviour: pass `=1` only when enabled, pass
nothing otherwise. Migrating every guard to value checks (`#if`) is allowed
only as a single atomic change that migrates *all* of them (C, Windows
header, web CMake) together — not as optional per-file cleanup.

Web: `native/web/CMakeLists.txt` maps its `option()`s to the same
`target_compile_definitions`, so one macro set serves both build systems.

### 5.2 Guard patterns

Three patterns cover every reference in §3:

**Pattern A — whole-file split** (for files whose entire content is the
feature): copy `TMaterialCompiler.cpp`'s layout — real implementation under
`#if THERMION_ENABLE_X`, complete `extern "C"` stub set under `#else`. Applies
to `TGltfAssetLoader.cpp`, `TGltfResourceLoader.cpp`, `TFilamentAsset.cpp`,
`TMaterialProvider.cpp`, `TAnimationManager.cpp`.

**Not** `TSceneAsset.cpp` (review decision D1): the file implements
`SceneAsset_createFromBuffers` plus the shared entity/light/camera accessors,
instancing and `SceneAsset_destroy` used by *procedural* assets. A whole-file
stub would break `createGeometry` even with a working unlit fallback (§5.6).
It uses Pattern B instead: only the glTF-specific entry points
(`SceneAsset_createFromFilamentAsset`, `_getFilamentAsset`,
`_releaseSourceData`, `_getBones/_getBoneCount/_getBoneName`, and the
`GltfSceneAsset` branches inside otherwise-shared functions) are guarded;
everything else compiles unconditionally.

Stub rules (so the binary stays loadable and the Dart bindings stay valid):

- every `EMSCRIPTEN_KEEPALIVE` symbol in the corresponding `c_api/*.h` header
  is still exported, with the exact signature;
- pointer-returning functions return `nullptr`; counts/sizes/booleans return
  `0`; `void` functions are no-ops; `const char*` getters return `nullptr`;
- `*_isSupported`-style probes return 0 (new: `GltfAssetLoader_isSupported`,
  or the single `Thermion_getEnabledFeatures` of §6 — one probe is enough);
- **JobThread variants delegate to the sync stub and still invoke the
  callback** (`PROXY(callback(nullptr))` / `onComplete(requestId)`), because
  every `*JobThread` wrapper in `ThermionDartJobThreadApi.cpp` just calls the
  sync entry point inside a lambda (e.g. lines 2180-2195). Guarding the sync
  functions therefore guards the JobThread API automatically — the Dart
  `withPointerCallback` completes with null instead of hanging forever.
  `ThermionDartJobThreadApi.cpp` itself needs **no** guards.

**Pattern B — local guards** (for files that mix core and feature code):
`TTexture.cpp` (`Image_decode` body, `Ktx1Bundle_*`, `Ktx1Reader_*`,
`Ktx2Reader_*`), `TSceneAsset.cpp`'s glTF-specific entry points (see Pattern A
note above), `TGltfResourceLoader.cpp`'s provider registration (§5.3),
`TScene.cpp` (`Scene_addFilamentAsset`), `ThermionWin32.h` pragmas (§4.4).
Includes of feature headers move under the same guard so a disabled build
cannot accidentally re-introduce a link reference.

**Pattern C — class-level guards** (C++ internals, no C symbols):
`scene/GltfSceneAsset.cpp`, `GltfSceneAssetInstance.cpp`,
`scene/AnimationManager.cpp`, `components/{Gltf,Bone,Morph}AnimationComponentManager.cpp`
and their headers. These are only reachable through Pattern-A entry points,
which return null when disabled; guard the whole class body and leave a
minimal stub where a base-class vtable must still exist (e.g.
`AnimationManager` is created unconditionally at init — see §5.5 — so its
constructor/destructor/tick survive as no-ops when gltf is off).
`include/material/FileMaterialProvider.hpp` (unused) is deleted or guarded
outright.

Compile-time-only includes (§3.1 list: `TEngine.cpp`, `TIndirectLight.cpp`,
`TTransformManager.cpp`, `GeometrySceneAsset`, `SceneAsset.hpp`) are dropped
or guarded; none contributes symbols, but dropping them keeps the disabled
build honest.

### 5.3 Mixed configurations: gltf on, ktx/image_decoding off — **deferred (D2)**

**Settled decision D2: v1 rejects these combinations at hook time** (§4.2).
Two Filament v1.77.2 behaviours make the naive provider guard unsafe:

1. `ResourceLoader::asyncGetLoadProgress` returns **0 forever when the
   provider map is empty** — with both decoders off, Dart's async polling
   (`GltfResourceLoader_asyncGetLoadProgress`) never completes, *including
   for a model with no textures at all*;
2. for a MIME type with **no registered provider**, the resource loader logs
   and skips that texture; the load "succeeds" with missing textures instead
   of giving Dart the load error §4.2 used to promise.

Guarded registration remains the intended implementation **once the
combination is enabled in a later version** —
`TGltfResourceLoader.cpp` registration block (the file's own TODO, lines
64-70, asks for this):

```c
#if THERMION_ENABLE_IMAGE_DECODING
    auto stbDecoder = gltfio::createStbProvider(engine);
    gltfResourceLoader->addTextureProvider("image/png", stbDecoder);
    gltfResourceLoader->addTextureProvider("image/jpeg", stbDecoder);
#endif
#if THERMION_ENABLE_KTX
    auto ktxDecoder = gltfio::createKtx2Provider(engine);
    gltfResourceLoader->addTextureProvider("image/ktx2", ktxDecoder);
#endif
```

`createStbProvider`/`createKtx2Provider` live in `gltfio_core`, so with gltf
on the archives stay linked; only the provider *references* to `stb` /
`ktxreader` / `basis_transcoder` disappear, which is exactly what lets the
hook drop those archives (§4.3).

**Acceptance criteria before this combination may be enabled** (all must be
implemented and tested, for **both** the sync `loadResources` path and the
async `asyncBeginLoad/asyncUpdateLoad/asyncGetLoadProgress` path):

- a **textureless** glTF asset loads to completion (progress reaches 1.0,
  Dart's poll terminates) even when the provider map is empty — requires a
  Thermion-side completion check that does not rely on Filament's progress
  alone;
- an asset that **requires a disabled decoder** fails with a **clear,
  propagated load error** naming the MIME type and the `features.*` key —
  not a log-and-skip. This needs a Thermion-side pre-check of the asset's
  texture MIME types against the registered providers (via cgltf, which is
  already vendored) or an equivalent completion/failure signal, since
  Filament itself only logs.

### 5.4 What each disabled feature exports (stub contract)

| Macro = 0 | Symbols kept (all stubbed) | Behaviour |
| --- | --- | --- |
| `THERMION_ENABLE_GLTF` | `GltfAssetLoader_*`, `GltfResourceLoader_*`, `FilamentAsset_*`, `MaterialProvider_*`, `AnimationManager_*`, `Scene_addFilamentAsset` (+ every `*JobThread` twin); **glTF-only** `SceneAsset_*` entry points (`_createFromFilamentAsset`, `_getFilamentAsset`, `_releaseSourceData`, `_getBones/_getBoneCount/_getBoneName`) | create/load return null (callbacks fired with null); getters return 0/null; animation apply/update are no-ops. The remaining `SceneAsset_*` entry points (`_createFromBuffers`, entity/light/camera access, `_createInstance`/`_getInstance` for geometry assets, `_destroy`, …) keep their **real implementations** (D1) — they are not stubs |
| `THERMION_ENABLE_KTX` | `Ktx1Bundle_*`, `Ktx1Reader_createTexture`, `Ktx2Reader_createTexture` (+JobThread) | create returns null; `isCubemap`/`getSphericalHarmonics` return 0 |
| `THERMION_ENABLE_IMAGE_DECODING` | `Image_decode` (+JobThread if present) | returns null; `Image_createEmpty`/`Image_get*`/`Texture_loadImage` **unaffected** (core `image` archive) |

`GltfParser_parseBuffer` (vendored cgltf, `TGltfParser.cpp`) is **not**
guarded: `parseGltf`/`GltfMeshData` keep working in every build.

### 5.5 Engine init must not force gltfio

`FFIFilamentApp.init` creates the loader and animation manager
unconditionally (lines 205-224). With Pattern-A stubs this already *works*
(`gltfAssetLoader` handle is null, `AnimationManager` is a no-op shell), but
the proposal makes it explicit:

- C: `AnimationManager_create` under `!THERMION_ENABLE_GLTF` returns a
  zero-cost object whose `tick`/`addAnimation` do nothing (Pattern C), so
  `RenderManager_addAnimationManager` at init stays valid;
- Dart: `init` skips `GltfAssetLoader_createJobThread` and
  `GltfAssetLoader_getMaterialProvider` when `!supports(ThermionFeature.gltf)`
  (§6), storing null — one fewer job-thread round-trip at startup.

### 5.6 Procedural-only apps: the unlit material fallback

Today `createGeometry(...)` without explicit material instances,
`Asset.getBoundingBoxAsset()`, `TextureProjection` and several examples all
reach `createUnlitMaterialInstance()` → the **gltfio ubershader**
(`ffi_filament_app.dart` line 957). With gltf off that path would return
null and procedural apps would break — the one real functional dependency
of "no glTF" code on gltfio.

Fix, using machinery that already exists, **compiled only when glTF is off**
(review decision D5):

1. add `hook/materials/unlit.mat` — a minimal unlit, vertex-color-capable
   material with the same parameter names the ubershader path sets
   (`baseColorFactor`, `hasVertexColors` equivalents);
2. the hook's built-in materials pipeline (`built_in_materials.dart`,
   version-matched matc/resgen from R2 — **not** runtime filamat) compiles it
   into a precompiled resgen blob **only when `features.gltf: false`**,
   exactly like the opt-in `unlit_fixed_size` material is today
   (`TMaterialInstance.cpp`'s `RESGEN_FACTORY(UNLIT_FIXED_SIZE)` under
   `UNLIT_FIXED_SIZE_ENABLED`; the new one sits under
   `UNLIT_FALLBACK_ENABLED`, set by the hook iff gltf is off). Default
   builds are untouched: making the blob unconditional would add a
   material-compiler (matc/resgen) step to every default app that currently
   skips that work (D5);
3. `createUnlitMaterialInstance`'s entry point creates instances from the
   precompiled blob instead of the ubershader provider when
   `!THERMION_ENABLE_GLTF`. The Dart API is unchanged;
   `createUbershaderMaterialInstance` (explicit ubershader requests) still
   returns null / throws (§6). **Implemented in Dart, not in
   `MaterialProvider_createMaterialInstance`'s stub (§10):** that C entry
   point has no `Engine`, which `Material::Builder::build` needs, so the
   fallback branches in `FFIFilamentApp.createUnlitMaterialInstance` and builds
   the blob through the existing `Material_createBuiltInJobThread(engine,
   BUILT_IN_UNLIT_FALLBACK)` path — no new C symbol; the stub stays a plain
   null-returning stub.

Cost: one small precompiled material package (single-digit KB) in slim
builds only, no new archives, no compiler dependency for default apps.
Decoupling `createUnlitMaterialInstance` from the ubershader for **default**
builds too remains worthwhile (it removes a hidden gltfio dependency that
exists today), but is a separate follow-up, not part of the opt-out work
(D5).

### 5.7 Link-time verification

For each **valid v1** feature combination — 5 of the 2³: all-on,
`ktx: false` and/or `image_decoding: false` with `gltf: false` (3 combos),
and `gltf: false` alone; the `gltf: true` + decoder-off combos are rejected
by the hook (D2, §5.3) — CI builds `libthermion_dart`
with the corresponding defines and the reduced `libs` list. Success criteria:

1. link succeeds (no undefined Filament symbols) — proves the guards cover
   every reference in §3;
2. `nm -D --defined-only` exports the **same symbol set** as the default
   build (the stub contract) — proves Dart bindings/`dlopen`/wasm stay valid;
3. a smoke test app: create engine, `createGeometry` + unlit material,
   render one frame — proves §5.5/§5.6;
4. a **slim-build procedural test** (required by review D1): on the
   `gltf: false` build, create procedural geometry via
   `SceneAsset_createFromBuffers`, instance it (`SceneAsset_createInstance` /
   `getInstance`), render a frame, read its entities/bounding box, and destroy
   it — proves the shared `TSceneAsset.cpp` entry points stay live and only
   the glTF branches are stubbed (§5.2).

On Linux, `--no-undefined` at link time makes criterion 1 strict; on
macOS/Windows the linker is strict by default. Android additionally needs
the `dlopen` smoke test because its linker resolves lazily-ignored symbols
differently (the perfetto precedent, hook lines 344-353).

## 6. Dart surface

### 6.1 One new C probe

```c
// c_api/ThermionFeatures.h (new, tiny; always compiled, no guards)
EMSCRIPTEN_KEEPALIVE uint32_t Thermion_getEnabledFeatures();
// bit 0: GLTF, bit 1: KTX, bit 2: IMAGE_DECODING, bit 3: RUNTIME_MATERIALS
```

Returns the compile-time bitmask. Regenerate the ffigen bindings once; the
generated files serve every feature combination because the symbol always
exists (§5.2) in every build made **from this proposal onward**. Older
prebuilt web engines do not export it: all supported web variants must be
rebuilt/published and `web.version` advanced before Dart requires the probe,
with the lazy-lookup fallback for legacy engines — see §4.6 (decision D4).
`MaterialCompiler_isSupported()` stays as-is (bit 3 mirrors it).

### 6.2 Public API

Following the exact `runtimeMaterialsSupported` precedent
(`filament_app.dart` line 177, `ffi_filament_app.dart` line 707):

```dart
enum ThermionFeature { gltf, ktx, imageDecoding, runtimeMaterials }

abstract class FilamentApp {
  // existing: bool get runtimeMaterialsSupported;
  bool supports(ThermionFeature feature);   // reads the cached bitmask once
}
```

Behaviour of affected APIs when the feature is off — **throw
`UnsupportedError` with an actionable message**, never return garbage
(the `compileMaterialSource` precedent, `ffi_filament_app.dart` line 792):

| Dart API | Off-feature behaviour |
| --- | --- |
| `loadGltfFromBuffer`, `ThermionViewer.loadGltf*`, `ThermionViewerWidget.assetPath` | `UnsupportedError('this build has gltf support disabled (features.gltf)')` |
| `createUbershaderMaterialInstance` / `createUbershaderMaterial` | `UnsupportedError` |
| `createUnlitMaterialInstance`, `createGeometry` (no material) | **keep working** via §5.6 fallback |
| `AnimationManager` gltf/bone/morph APIs, `Asset.getBones/releaseSourceData` | `UnsupportedError` (glTF-asset-only surfaces; the guards are belt-and-braces) |
| `Asset.createInstance/getInstance` on **procedural** assets (`SceneAsset_createFromBuffers`) | **keep working** — shared `TSceneAsset.cpp` code stays live (D1, §5.2) |
| `loadKtx`, `loadKtx2`, `createIblFromKtx` | `UnsupportedError('... features.ktx')` |
| `decodeImage` | `UnsupportedError('... features.image_decoding')` |
| `createImage`, `Texture.setLinearImage/loadImage`, `parseGltf`/`GltfMeshData` | unchanged, always available |

`init` checks the bitmask before creating the loader (§5.5). The Flutter
plugin needs no API change; `ThermionViewerWidget` surfaces the same
`UnsupportedError` through its existing error builder when `assetPath` is
used on a slim build.

### 6.3 Why stubs *and* Dart guards

Either alone would keep a slim build loadable, but both are needed:

- stubs alone: Dart callers would get null handles and fail with obscure
  null-pointer errors deep in FFI code;
- Dart guards alone: any missed Dart path (or a user calling raw bindings)
  hits a missing symbol at first call on native, and a **load-time failure**
  on wasm if the symbol is referenced in the JS interop glue.

Stubs make the binary structurally valid; Dart guards make failures
diagnosable. Same division of labour as `runtime_materials` today.

## 7. Measured sizes

> **These Linux archive numbers are an estimate, not a shipping claim**
> (review decision D5). Before any size saving is advertised or a rollout
> step merges, measure the **stripped `libthermion_dart.so` and the packaged
> app size** (APK/AAB) for the prototype build (§8 step 2) on an actual
> target — **Android arm64** first. The object-file closure model below
> ignores `--gc-sections`, LTO and packaging compression.

Method: `.scratch/closure_size.py` indexes every member of every `.a` in the
**Linux x64 release** Filament v1.77.2 artifact with `nm`, then computes the
transitive closure over undefined symbols from each feature's root symbols
(demangled), modelling GNU ld member extraction without LTO/`--gc-sections`.
"Marginal" subtracts the always-linked core closure (engine, backend, utils,
filaflat/filabridge, geometry, bluegl/bluevk, ibl, image, smol-v, zstd ≈
9.2 MB). Object-file bytes are an upper bound on `.text` contribution; the
final `.so` is smaller after `--gc-sections`, but relative numbers hold.

| Closure | Marginal KB | Breakdown (KB) |
| --- | --- | --- |
| gltfio (all providers, as linked today) | **4389** | gltfio_core 1419, basis_transcoder 1396, dracodec 998, geometry-tangents 327, stb 124, meshoptimizer 57, ktxreader 36, mikktspace 26, uberzlib 3 |
| gltfio without texture providers (`gltf: true, ktx: false, image_decoding: false` — **not buildable in v1**, deferred by D2/§5.3; informational only) | 2772 | gltfio_core 1359, dracodec 998, geometry 327, meshoptimizer 57, mikktspace 26, uberzlib 3 |
| ktxreader + Ktx1Bundle | **1523** | basis_transcoder 1396, ktxreader 83, image(Ktx1Bundle) 44 |
| stb (`Image_decode`) | **124** | stb 124 |
| image (`LinearImage` only) | **9** | image 9 |
| dracodec alone | 998 | (subset of the gltfio closure) |
| filamat + matp (`runtime_materials: true`) | **40935** | filamat 31070, matdbg 8702, matp 567, zstd 452, shaders 141 |
| filameshio | **0** | not referenced |

Notes:

- `uberarchive`'s 248 KB blob does not appear in the closure table because
  the root-symbol model starts from functions; it is pulled by
  `TGltfAssetLoader.cpp`'s data reference and drops with `features.gltf`
  too. All-off saving is therefore ≈ **4.6 MB** (4389 + 248), plus the
  guarded Thermion wrappers themselves (not measured).
- The per-feature numbers **overlap**: basis_transcoder is shared by the
  gltfio and ktx closures; stb likewise. All-off ≈ gltfio-closure + ktx-only
  remainder (Ktx1Bundle 44 + ktxreader 47) ≈ 4.4 MB + 0.25 MB blob.
- Debug builds differ (matdbg/fgviewer, no `--gc-sections`); the mechanism
  is identical, numbers would need re-measuring per artifact.
- The `gltfio` full archive (84 KB) contributes **0** bytes today —
  confirming §3.1's "remove it regardless" note.

## 8. Rollout, risks, open questions

Implementation order, revised by review decisions D4/D5 (each step
independently mergeable; **the prototype gates the rest**):

1. **Free wins, no schema**: drop the unreferenced `gltfio` archive from the
   desktop link list; move Windows `matp`/`filamat` pragmas under the
   existing `#if defined(THERMION_ENABLE_RUNTIME_MATERIALS)` block (macro
   stays undefined when off, D3); drop unused gltfio includes
   (`TTransformManager.cpp`, `FileMaterialProvider.hpp`). `smol-v` stays
   unconditional (D3).
2. **Native `gltf: false` prototype (D5) — before any schema/API rollout**:
   hand-built `libthermion_dart` with `THERMION_ENABLE_GLTF=0` and the
   reduced link line, **texture decoders left available** (`ktx` and
   `image_decoding` on, so the D2 deferral is not in play). Includes the
   §5.2 Pattern-B/C guards, the §5.5 init change and the **conditional**
   unlit fallback blob (§5.6: precompiled, requested only when gltf is off).
   Run the §5.7 criteria (incl. the procedural create/instance/render/destroy
   test) and **measure the stripped `.so` and packaged app size on Android
   arm64** (§7 caveat). The Linux closure numbers are only the estimate that
   motivates the prototype; its measured results decide whether to proceed.
3. **Feature probe publication (D4)**: add `Thermion_getEnabledFeatures` to
   the web CMake sources, rebuild/publish **all** supported web variants,
   advance `native/web/web.version`; then land the Dart `supports()`/init
   changes with the legacy-engine fallback (§4.6).
4. **Schema + `features.ktx` / `features.image_decoding`** (with
   `gltf: false`; mixed combos rejected per D2): smallest guard surface
   (`TTexture.cpp`), exercises the schema/stub/probe pipeline end-to-end.
5. **`features.gltf` productised**: the prototype's guards hardened —
   Pattern A/B/C files of §5.2, Dart `UnsupportedError` guards, full §5.7 CI
   matrix.
6. Optional: publish a `-slim` web engine variant (§4.6).

Risks and mitigations:

| Risk | Mitigation |
| --- | --- |
| A future contributor adds an unguarded gltfio reference | the reduced link line fails CI immediately (§5.7); headers are guarded too, so the include itself disappears |
| Stub signature drift vs. headers | symbol-set diff in CI (§5.7 criterion 2); stubs live next to the real implementation in the same file, same header contract |
| Users disable a feature their code uses | `UnsupportedError` names the exact `features.*` key (§6.2); `supports()` allows graceful fallback |
| glTF loads with missing texture providers (mixed configs) | combination rejected at hook time in v1 (D2); enabling it later requires the §5.3 completion/failure criteria, tested sync and async |
| Filament upgrade changes transitive deps (e.g. gltfio stops using Draco) | re-run `.scratch/closure_size.py` per artifact bump; the map in §3 is version-pinned to v1.77.2 |
| Per-OS feature demand later | flat schema extends to per-OS maps without breaking (§4.1) |
| Dart init requires a probe older web engines lack | all supported web variants rebuilt/published and `web.version` advanced **before** the Dart probe lands; lazy lookup + all-enabled default for legacy engines (§4.6, D4) |

Open questions (deliberately not decided here):

- Should `features.gltf: false` also strip the *Dart* glTF API surface via
  tree-shaking hints? Not needed for size (Dart AOT already shakes unused
  code) and it would fork the public interface — rejected for v1.
- Should the artifact zips stop staging unused archives (§3.8)? Worth ~40 MB
  of *download*, orthogonal to binary size; separate `scripts/` change.
- iOS numbers: measure on-device per combination before advertising savings
  for iOS; Android arm64 is measured by the prototype (§8 step 2, D5). Linux
  numbers remain an estimate for everything else.

## 9. Settled review decisions (round 2)

Points from the design review (`.scratch`/incoming `review.md`, round 2) and
where each is folded in. These are **settled** — implement them as written,
do not re-open them during implementation.

| # | Decision | Where it lands |
| --- | --- | --- |
| D1 | Procedural scene assets stay in the core: `TSceneAsset.cpp` uses local guards (Pattern B), not a whole-file stub; shared `SceneAsset_createFromBuffers`, entity access, instancing and destruction stay live. A slim-build test creates, instances, renders and destroys procedural geometry. | §3.1, §5.2, §5.4, §5.7 (criterion 4), §6.2 |
| D2 | Mixed builds (`gltf: true` with `ktx: false` or `image_decoding: false`) are **deferred**: hard error at hook time in v1. Filament v1.77.2 stalls async progress at 0 with an empty provider map (even textureless assets) and log-and-skips missing providers. Re-enabling requires defined+tested completion for textureless assets and a clear propagated failure for assets needing a disabled decoder, sync and async. | §4.2, §4.3, §5.3, §5.7, §7 (informational row), §8 risk table |
| D3 | `THERMION_ENABLE_RUNTIME_MATERIALS` keeps presence semantics: **undefined when off**, `=1` when on; no default in `ThermionFeatures.h`. Defining it to 0 would still enable the real compiler and Windows compiler pragmas under their `#ifdef`/`#if defined` guards. A value-check migration is only allowed as one atomic change covering every guard. `smol-v` stays **unconditional** (core `filaflat::DictionaryReader` decoder). | §3.7, §4.4, §5.1 |
| D4 | The web engine release is a **dependency of the probe**: rebuild and publish every currently supported web variant with `Thermion_getEnabledFeatures` and advance `native/web/web.version` before Dart requires it (even with zero slim web variants in v1). Legacy engines get a lazy-lookup fallback: missing symbol → all features enabled + warning. | §4.6, §6.1, §8 (rollout + risk table) |
| D5 | **Prototype first**: start with a native `gltf: false` build, texture decoders left available, and measure the stripped library + packaged size on a real target (Android arm64) before rolling out schema/API; the Linux archive model is an estimate. The unlit fallback blob is **precompiled and built only when gltf is off** — an unconditional blob in the hook would add a matc/resgen dependency to default apps that skip it today. | §4.5, §5.6, §7 (caveat), §8 (rollout order, open questions) |

## 10. Implementation log (round 3, `feature-opt-libs`)

Implementation of §4–§6 as settled in §9, in commit order. Each step was
verified on Linux x64 (release Filament v1.77.2 artifact, `xvfb-run` +
llvmpipe for anything that renders).

| Step | Commit | What landed |
| --- | --- | --- |
| 1 | `hook: features user defines` | `lib/src/hooks/feature_flags.dart` (`resolveFeatures`, D2 rule, `disabledFeatureDefines`, web warning), conditional `libs` in `hook/build.dart`, full-archive `gltfio` dropped, `test/feature_flags_test.dart` (11 cases) |
| 2 | `native: THERMION_ENABLE_* guards` | `native/include/ThermionFeatures.h`, probe `c_api/ThermionFeatures.h` + `TThermionFeatures.cpp`, Pattern A/B/C guards, `ThermionWin32.h` pragmas, web CMake options, compile-time-only includes dropped, `FileMaterialProvider.hpp` deleted |
| 3 | `hook: precompiled unlit fallback` | `hook/materials/unlit_fallback.mat`, `compileUnlitFallbackMaterial` (only when `gltf: false`), `BUILT_IN_UNLIT_FALLBACK`, `UNLIT_FALLBACK_ENABLED`, bindings regenerated |
| 4 | `dart: supports() + UnsupportedError` | `ThermionFeature`, `FilamentApp.supports`, legacy-engine fallback (D4), init/destroy skip the loader (§5.5), `checkSupported` on every affected API, fallback in `createUnlitMaterialInstance` |
| 2b | `native: compile the vendored cgltf` | Fix for the one missed link reference found by the first slim link (below) |
| 5 | `test: slim-build test` | `test/slim_build_test.dart` (§5.7 criterion 4) |

### 10.1 Where the implementation deviates from the text above

All found while proving the build; the relevant sections carry a short
"correction" note.

1. **`TGltfParser.cpp` links against gltfio_core after all** (§3.1 said
   `parseGltf` needs nothing from gltfio). `GltfParser_parseBuffer` calls
   `cgltf_parse`/`cgltf_free`/…, and Filament compiles cgltf inside
   `libgltfio_core.a`. The first `gltf: false` link (`-Wl,-z,defs`) failed on
   exactly these 9 symbols and nothing else — the rest of the §3 map held.
   Fix: `#define CGLTF_IMPLEMENTATION` in `TGltfParser.cpp` only when
   `THERMION_ENABLE_GLTF` is 0 (glTF builds keep using gltfio_core's copy, so
   there is never a duplicate). `parseGltf`/`GltfMeshData` work in every build
   as intended.
2. **`TTransformManager.cpp` does use `gltfio/math.h`** (`decomposeMatrix`,
   `composeMatrix`). They are header-only `inline` functions — still no
   link-time reference — so the include stays instead of being dropped.
3. **The unlit fallback branches in Dart, not in
   `MaterialProvider_createMaterialInstance`'s stub** (§5.6 item 3): that C
   entry point receives no `Engine`, which `Material::Builder::build` needs.
   `FFIFilamentApp.createUnlitMaterialInstance` builds the precompiled
   package through the existing `Material_createBuiltInJobThread(engine,
   BUILT_IN_UNLIT_FALLBACK)` path and caches the `Material`; no new C symbol,
   the stub stays a plain null-returning stub. Measured fallback package:
   109 KB for the opengl+vulkan pair (§5.6 guessed single-digit KB).
4. **Morph component add/remove stay unguarded** in Dart: `FFIAsset`'s
   destroy path calls `removeMorphAnimationComponent` for *every* asset type,
   procedural geometry included. The C stubs are no-ops, so these keep
   working; the asset-facing animation APIs (gltf/bone/morph getters and
   players) throw `UnsupportedError`. The destroy path skips the glTF/bone
   component removals without gltf so it does not log bogus failures.
5. **JS interop bindings were extended by hand** (`Thermion_getEnabledFeatures`,
   `BUILT_IN_UNLIT_FALLBACK`) in ffigen_js's exact output form: `ffigen_js`
   needs the emscripten sysroot that only CI has. The native bindings were
   regenerated with ffigen and formatted; the only diff is the two additions.

### 10.2 Linux x64 proof (§5.7 criteria 1–4)

Configuration: release Filament v1.77.2, Linux x64, the package's own 13
helper materials enabled in both builds (so symbol sets compare like for
like), `-Wl,-z,defs`.

| Build | Links | `Thermion_getEnabledFeatures` | unstripped `.so` | stripped `.so` | `.text` |
| --- | --- | --- | --- | --- | --- |
| default (all on) | yes | `0x7` | 10,281,248 B | 7,841,736 B | 7,698,235 B |
| `gltf: false` (ktx, image_decoding on) — the §8 step 2 prototype | **yes**, no undefined symbols | `0x6` | 8,941,064 B | 6,808,152 B | 6,673,703 B |
| all three off | **yes** | `0x0` | 7,747,736 B | 5,689,696 B | 5,550,691 B |

- Criterion 2 (symbol set): `nm -D --defined-only` — every C entry point
  declared in `c_api/*.h` is present in both builds (the same 7 names are
  declared-but-never-defined in both, pre-existing drift unrelated to this
  work: `Camera_setProjectionMatrix`, `LightManager_rgbToColorTemperature`,
  `MaterialProvider_create`, `RenderableManager_getCulling`,
  `RenderableManager_getPriority`, `Renderer_setFrameInterval`,
  `Texture_getUsage`). The only non-mangled differences are exactly the
  intended ones: `UBERARCHIVE_PACKAGE` only in default; `UNLIT_FALLBACK_PACKAGE`
  and the 36 `cgltf_*` functions only in slim. 263 mangled C++ symbols
  disappear with gltfio (gltfio_core, Draco, meshoptimizer, mikktspace,
  ubershader), 41 appear (template instantiations + cgltf).
- Criterion 3/4 (runtime): `xvfb-run dart test test/slim_build_test.dart` on
  the `gltf: false` build — all 4 tests pass: `supports()` reports the
  opt-outs; glTF-only Dart APIs throw `UnsupportedError` naming
  `features.gltf`; a procedural cube (no explicit material → unlit fallback)
  renders against the background (pixel-asserted), instances through the
  shared `SceneAsset_*` entry points (`createInstance`/`getInstance`/
  `getInstances`, bounding boxes intact), and destroys; an explicit
  procedural material from `createUnlitMaterialInstance` works too.
- **Size, measured vs estimated:** the Linux stripped saving of
  `gltf: false` is ≈ **1.0 MB (−13 %)**, not the ≈ 4.4 MB of §7 — the closure
  model counts object files the linker never extracts and lumps
  `basis_transcoder`/`stb` (still linked here, decoders on) into the glTF
  closure. All three off saves ≈ **2.15 MB (−27 %)** stripped. §7 stays an
  estimate; the Android arm64 measurement (D5) is the number that decides the
  rollout. The all-off build also has the same C entry-point set as the
  default build, which proves the `TTexture.cpp` KTX/stb stubs (§5.4) cover
  every decoder reference.
- Default-build regression set on the same machine
  (`xvfb-run dart test -j 1` over geometry, instancing, asset, glTF/bone/morph
  animation, KTX upload lifetime, image, `slim_build_test` and
  `feature_flags_test`): **58 passed, 9 skipped** — the skips are the four
  slim tests (correctly skipped on a gltf-enabled build) plus five
  pre-existing skips.

### 10.3 Follow-ups (not in this round)

- **Android arm64 measurement (D5)** — CI follow-up: build the `gltf: false`
  APK/AAB on arm64, record stripped `libthermion_dart.so` and packaged size
  next to the default, and run the `dlopen` smoke test (Android's linker
  resolves lazily, see §5.7). Decide rollout step 5 on that number.
- **Linux slim CI job**: run `xvfb-run dart test test/slim_build_test.dart`
  after rewriting the package pubspec's `hooks:` block with
  `features: {gltf: false}` (the `skip_native_build` job already rewrites
  that block the same way). Optionally a second job for the all-off variant.
- **Web (D4)**: before this branch merges, republish every supported web
  engine variant with `Thermion_getEnabledFeatures` and advance
  `native/web/web.version`; until then Dart's lazy fallback treats an older
  engine as "all features on", which is true for every existing engine, so
  nothing breaks either way. Regenerate the JS interop bindings in CI
  (`make dart-bindings`) to confirm the hand-added entries.
- Windows: the pragma guards compile-check only on a Windows runner (CI).
