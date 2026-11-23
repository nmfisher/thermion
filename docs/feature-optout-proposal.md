# Proposal: compile-time feature opt-outs for native libraries

| | |
| --- | --- |
| Status | **Proposal only.** No code, build or test changes are made by this document. |
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
| `native/src/c_api/TSceneAsset.cpp` | `GltfSceneAsset` (`AssetLoader::createInstanceAsset`, `Animator`, `releaseSourceData`, entity/light/bone accessors) | `SceneAsset_createFromFilamentAsset`, `_getFilamentAsset`, `_createInstance`, `_getInstance`, `_releaseSourceData`, `_getBones/_getBoneCount` | `loadGltfFromBuffer`; `FFIAsset.createInstance/getInstance/releaseSourceData/getBones` |
| `native/src/c_api/TScene.cpp` | `Scene_addFilamentAsset` (`FilamentAsset::getEntities/getLightEntities`) | `Scene_addFilamentAsset` | no Dart caller (dead on the Dart side) |
| `native/src/c_api/TAnimationManager.cpp`, `native/src/scene/AnimationManager.cpp`, `native/src/components/{Gltf,Bone,Morph}AnimationComponentManager.cpp` | `gltfio::Animator` (`applyAnimation`, `updateBoneMatrices`, animation count/duration/name), `FilamentInstance::getAnimator()`, `FilamentAsset::getInstance()` | `AnimationManager_*` (24 functions + JobThread variants) | `FFIAnimationManager` (**created at init**, line 224), `FFIAsset` animation helpers |
| `native/src/scene/GltfSceneAsset.cpp`, `GltfSceneAssetInstance.cpp` + headers | `AssetLoader`, `Animator`, `FilamentAsset`, `FilamentInstance` | (used by `TSceneAsset.cpp`) | — |
| `native/src/c_api/ThermionDartJobThreadApi.cpp` | Job-thread wrappers for all of the above | `GltfAssetLoader_*JobThread`, `GltfResourceLoader_*JobThread`, `SceneAsset_createFromFilamentAssetJobThread`, `MaterialProvider_createMaterialInstanceJobThread`, `AnimationManager_*JobThread`, `FilamentAsset_getWireframeJobThread`, `Scene_addFilamentAssetJobThread` | all of the above (Dart always uses the JobThread variants) |

**Compile-time only (no symbol):** `TEngine.cpp` (seven gltfio includes,
`gltfio/math.h`), `TIndirectLight.cpp` (`FilamentAsset.h`, `FilamentInstance.h`),
`TTransformManager.cpp` (`gltfio/math.h`; none of its helpers — `toMat4`,
`toFloatArray`, … — are called anywhere in Thermion, so the include can simply
be dropped),
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
| `FilamentApp.parseGltf`, `GltfMeshData` | `FFIGltfMeshData.parse` → `GltfParser_parseBuffer` | **nothing**: this path uses the vendored `cgltf.h` only. Keep working when gltfio is off. |

**Verdict: opt-out as `features.gltf`.** When off, the hook drops
`gltfio_core`, `gltfio`, `uberarchive`, `dracodec`, `uberzlib` (and the
Windows-only `meshoptimizer`/`mikktspace` pragmas); `geometry` stays because
`TSurfaceOrientation`/`CustomGeometry` use it. Two things must be solved so
procedural apps keep working (§5.6): engine init must not create the loader,
and `createUnlitMaterialInstance` needs a non-gltfio fallback (an always-on
`unlit` built-in material). Independently of this proposal, `gltfio` (the
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

**Verdict: already opt-in.** Nothing new to expose. Two clean-ups fall out of
this work: (1) move `smol-v`, `matp` and the Windows `matp.lib`/`filamat.lib`
pragmas under the same conditions as the other platforms so the link lists
tell the truth; (2) when `features.ktx` and `features.gltf` are both off and
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

