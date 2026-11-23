# Compile-time feature opt-outs: `gltf`, `ktx`, `image_decoding`

| | |
| --- | --- |
| Status | **Implemented** (`feature-opt-libs`, delivered as three stacked PRs: self-sufficient `ffigen_js` regeneration; prep cleanups + single-sourced Windows link list; the opt-outs themselves). This document describes the final design; the per-round implementation log that used to live in §10 has been folded into the sections below. |
| Filament | v1.77.2 (`filament.version`); the library map in §3 is pinned to it |
| Supersedes | The open ideas in `.tickets/the-0rkw.md` (optional libraries for binary size) |

## 1. Summary

Every native build of `thermion_dart` links one C++ wrapper
(`libthermion_dart`) against the same Filament archive set. An app that only
draws procedural geometry still compiles in the glTF loader, its animation
stack, Draco, the KTX/Basis texture decoders and the PNG/JPEG decoder, because
Thermion's own C++ references them. Removing a `-l` flag alone does not change
the binary: static archives only contribute the object files that something
references. The size is in the references.

Three **opt-out** user defines (default: everything on, so existing apps are
unchanged) remove those references at compile time:

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
   already used for `runtime_materials` (`TMaterialCompiler.cpp`): the same C
   symbols are exported, they return null/0, so the Dart FFI bindings are
   byte-for-byte the same and `dlopen`/wasm load never sees a missing symbol;
3. `Thermion_getEnabledFeatures()` lets Dart report what the loaded build has
   (`FilamentApp.instance!.supports(ThermionFeature.gltf)`), and the affected
   Dart APIs throw `UnsupportedError` instead of returning garbage.

Measured on the stripped Linux x64 release `libthermion_dart.so` (§7):
`gltf: false` alone saves **1.03 MB (13 %)**, all three off **2.15 MB
(27 %)**. Android arm64 is not measured yet (§8).

| Library | Verdict | Dropped by |
| --- | --- | --- |
| `gltfio` (`gltfio_core`, `uberarchive`; the full `gltfio` archive is unreferenced and always dropped) | **opt-out** | `features.gltf` |
| `dracodec` | opt-out, only *through* `features.gltf` (gltfio's `AssetLoader` always calls it; no direct Thermion reference) | `features.gltf` |
| `stb` | **opt-out** | `features.image_decoding` |
| `ktxreader` | **opt-out** | `features.ktx` |
| `basis_transcoder` | opt-out, only *through* `features.ktx` (no client but ktxreader) | `features.ktx` |
| `image` (`LinearImage`, `Ktx1Bundle`) | **keep** — core data type; only the `Ktx1Bundle` entry points move under `features.ktx` | — |
| `filamat` + `matp` | already opt-in (`runtime_materials`) | — |
| `filameshio` | already gone (#287) | — |

## 2. What is linked today

### 2.1 Native hook (`thermion_dart/hook/build.dart`, the `libs` list)

| Archive | Condition | Needed by |
| --- | --- | --- |
| `filament`, `backend`, `utils`, `filabridge`, `filaflat`, `geometry`, `filament-iblprefilter` | always | core engine; `geometry` also by `TSurfaceOrientation` / `CustomGeometry` |
| `gltfio_core`, `uberarchive`, `dracodec`, `uberzlib` (Windows: + `meshoptimizer`, `mikktspace`) | `features.gltf` | every glTF wrapper and the ubershader provider (§3.1) |
| `gltfio` (full archive) | never | nothing. Thermion only uses `gltfio_core` symbols; dropped from the desktop list |
| `ktxreader`, `basis_transcoder` | `features.ktx` | `TTexture.cpp` (`Ktx1Reader`, `Ktx2Reader`) |
| `stb` | `features.image_decoding` | `TTexture.cpp` `Image_decode` (`stbi_load_from_memory`) |
| `image` | always | `LinearImage` (public `createImage`/`setLinearImage`/`loadImage`), `Ktx1Bundle`, ktxreader |
| `z`, `smol-v` | always | inflate (`z`); `filaflat::DictionaryReader` decodes every material package with `smolv` — `smol-v` is core, never gated |
| `ibl` | always | nothing in Thermion sources; pulls 0 bytes |
| `zstd` | `!linux` | `filament::ZstdHelper` / `MaterialParser` — core; on Linux the combined `libfilamat.a` is the provider |
| `matp`, `filamat`, `shaders` (+ the Windows glslang/SPIRV split) | `runtime_materials`, plus `filamat` in debug (matdbg, not on Windows) and on Linux (zstd provider) | `TMaterialCompiler.cpp` (guarded by `THERMION_ENABLE_RUNTIME_MATERIALS`); `TMaterialPackage.cpp` uses only the header constant `filamat::MaterialVersion` |
| `matdbg`, `fgviewer` | debug on macOS/Android/Linux | Filament debug builds only |

Platform extras (`bluegl`/`bluevk`, Android `GLESv3`/`EGL`/`perfetto`, Linux
`drm`/`EGL`/`GL`/`gbm`, Windows system import libraries and
`vulkan-1`/`dxgi`/`d3d11`, `webgpu_dawn`/`abseil` for the WebGPU backend) are
core and unaffected.

The list is the single source of truth for every platform, Windows included
(§4.4).

### 2.2 Web (`thermion_dart/native/web/CMakeLists.txt`)

`gltfio_core filament backend geometry mikktspace dracodec ibl-lite ktxreader
filaflat filabridge image utils stb uberzlib uberarchive meshoptimizer
basis_transcoder basis_encoder z zstd png`, plus `matp filamat shaders smol_v`
under `THERMION_ENABLE_RUNTIME_MATERIALS`. The CMake file has the same three
`option(THERMION_ENABLE_<FEATURE>)` switches as the hook (default ON), but
every published engine zip is built with all of them ON (§4.6).

### 2.3 Precedent: `runtime_materials`

`runtime_materials` is the mechanism this design generalises: the hook passes
a define and conditional `libs` entries; `TMaterialCompiler.cpp` compiles the
real implementation or a complete stub set; Dart feature-detects through
`MaterialCompiler_isSupported()` and throws `UnsupportedError`; the web build
selects a separate engine variant.

## 3. Library → dependency chain map

Terms:

- **link-time reference**: Thermion code uses a symbol defined in the archive.
  This pulls object files into the binary and breaks if the archive is removed
  without a guard.
- **compile-time reference**: an `#include` of the library's header. Headers
  always ship in the Filament artifact; guards drop the include too so a
  disabled feature cannot re-introduce a link reference by accident.
- **Dart chain**: the public Dart API(s) that end in the C entry point. The
  generated bindings (`lib/src/bindings/src/thermion_dart_{ffi,js_interop}.g.dart`)
  look every symbol up lazily on first call, so one binding file must serve
  every feature combination, on native and web.

### 3.1 `gltfio` — `gltfio_core` + `uberarchive`

`gltfio_core` is Filament's glTF runtime: `AssetLoader`, `ResourceLoader`,
`Animator`, `FilamentAsset`/`FilamentInstance`, `MaterialProvider` and its
`UbershaderProvider`, the `TextureProvider` interface with `StbProvider` /
`Ktx2Provider`, and the cgltf-based `AssetLoaderExtended` (meshopt, tangents).
`uberarchive` holds the ubershader material package. The full `gltfio` archive
only adds `createFilamentMaterialProvider` (the filamat-backed compiler),
which Thermion never calls. Transitive dependencies: `dracodec`,
`meshoptimizer`/`mikktspace` (Windows libs), `uberzlib`, and — through the
texture providers — `stb`, `ktxreader`, `basis_transcoder`.

| Thermion reference | C entry points | Dart chain |
| --- | --- | --- |
| `TGltfAssetLoader.cpp` (`createUbershaderProvider`, `AssetLoader::create/destroy`) | `GltfAssetLoader_*` | `FFIFilamentApp.create` (at engine init), `loadGltfFromBuffer`, `destroy` |
| `TGltfResourceLoader.cpp` (`ResourceLoader`, `createStbProvider`, `createKtx2Provider`) | `GltfResourceLoader_*` | `loadGltfFromBuffer` |
| `TFilamentAsset.cpp` (`getResourceUris`, `getEntities`, `getWireframe`) | `FilamentAsset_*` | `loadGltfFromBuffer`, wireframe utilities |
| `TMaterialProvider.cpp` (`gltfio::MaterialProvider`, `MaterialKey`) | `MaterialProvider_createMaterialInstance` | `createUbershaderMaterialInstance`/`createUbershaderMaterial`, `createUnlitMaterialInstance` |
| `TSceneAsset.cpp` — **glTF-specific entry points only** (`GltfSceneAsset`, `Animator`, bone accessors). `SceneAsset_createFromBuffers`, shared entity/light/camera access, instancing and `SceneAsset_destroy` are core procedural code and stay live (Pattern B, D1) | `SceneAsset_createFromFilamentAsset`, `_getFilamentAsset`, `_releaseSourceData`, `_getBones*`; `_createInstance`/`_getInstance` keep their geometry branches | `loadGltfFromBuffer`; `FFIAsset` instancing / `releaseSourceData` / bones |
| `TScene.cpp` (`Scene_addFilamentAsset`) | `Scene_addFilamentAsset` | no Dart caller |
| `TAnimationManager.cpp`, `scene/AnimationManager.cpp`, `components/{Gltf,Bone,Morph}AnimationComponentManager.cpp` (`gltfio::Animator`) | `AnimationManager_*` | `FFIAnimationManager` (created at init), `FFIAsset` animation helpers |
| `scene/GltfSceneAsset(.Instance).cpp` | (used by `TSceneAsset.cpp`) | — |
| `ThermionDartJobThreadApi.cpp` | the `*JobThread` twins of all of the above | Dart always calls the JobThread variants; each wrapper calls the sync entry point, so guarding the sync function guards both |

| Dart API | Needs gltfio for |
| --- | --- |
| `FilamentApp.loadGltfFromBuffer`, `ThermionViewer.loadGltf*`, `ThermionViewerWidget.assetPath` | the loader, resource loader, asset wrapper |
| `FilamentApp.createUbershaderMaterialInstance`, `createUbershaderMaterial` | the ubershader provider |
| `FilamentApp.createUnlitMaterialInstance` (used by the bounding-box helpers, `TextureProjection` and explicit `createGeometry` materials) | the ubershader's unlit variant → replaced by the precompiled fallback (§5.6) |
| `AnimationManager` gltf/bone/morph APIs, `Asset.getInstance/createInstance/releaseSourceData/getBones/getMorphTarget…` | `Animator`, instancing |
| `FilamentApp.parseGltf`, `GltfMeshData` (`GltfParser_parseBuffer`) | **nothing in gltfio itself**, but the `cgltf_*` functions it calls are compiled inside `gltfio_core`. `TGltfParser.cpp` therefore compiles the vendored `cgltf.h` (`CGLTF_IMPLEMENTATION`) when `THERMION_ENABLE_GLTF` is 0; glTF builds keep using gltfio_core's copy. Works in every build. |

Compile-time-only includes were dropped or made independent of gltfio:
`TEngine.cpp`, `TIndirectLight.cpp`, `scene/GeometrySceneAsset.*`,
`include/scene/SceneAsset.hpp` (`filament/Box.h` instead); the two
`gltfio/math.h` helpers `TTransformManager.cpp` actually uses
(`decomposeMatrix`/`composeMatrix`, header-only inline) were hoisted into the
neutral `native/include/MathUtils.hpp`; the unused
`include/material/FileMaterialProvider.hpp` (derived from
`gltfio::MaterialProvider`) was deleted.

**Verdict: opt-out as `features.gltf`.** Drops `gltfio_core`, `uberarchive`,
`dracodec`, `uberzlib` and the Windows-only `meshoptimizer`/`mikktspace`.
`geometry` stays (`TSurfaceOrientation`/`CustomGeometry`). Two things keep
procedural apps working: engine init must not need gltfio (§5.5) and
`createUnlitMaterialInstance` needs a non-gltfio material (§5.6).

### 3.2 `stb`

`stb_image` in `libstb.a`. Link-time reference: `TTexture.cpp` → `Image_decode`
(`stbi_load_from_memory`) only; gltfio reaches it through `createStbProvider`.
Dart chain: `FilamentApp.decodeImage` → `Image_decode` → `LinearImage` →
`Texture.setLinearImage`/`loadImage` (background images, PNG skyboxes,
`TexturedQuad.setImage`, the Flutter plugin's image helpers).
`createImage(w, h, c)` (`Image_createEmpty`) does not need stb.
**Verdict: opt-out as `features.image_decoding`.**

### 3.3 `image`

`libimage.a`: `LinearImage` (shared pixel buffer), `Ktx1Bundle`/`Ktx2Bundle`
(container parsing), colour transforms. References in `TTexture.cpp`:
`Image_createEmpty`, `Image_get*`, `Image_destroy`, `Texture_loadImage`,
`Ktx1Bundle_*` (`loadKtx`/IBL from KTX1), `Image_decode`. **Verdict: keep
(core).** `LinearImage` is the public currency for pixel data (9 KB
marginal); only the `Ktx1Bundle` entry points move under `features.ktx`.

### 3.4 `ktxreader`

`libktxreader.a`: `Ktx2Reader` (KTX2 → GPU texture incl. Basis/ASTC),
`Ktx1Reader` (KTX1 cubemaps with an async upload callback). References:
`TTexture.cpp` → `Ktx2Reader_createTexture`, `Ktx1Reader_createTexture`;
gltfio through `createKtx2Provider`. Dart chain: `FilamentApp.loadKtx2`;
`FilamentApp.loadKtx`/`createIblFromKtx` → `ffi_ktx1_bundle.dart` →
`Ktx1Bundle_*` → `Ktx1Reader_createTexture` (skyboxes and IBLs from KTX).
**Verdict: opt-out as `features.ktx`**, together with `basis_transcoder`.

### 3.5 `basis_transcoder`

Binomial's Basis Universal transcoder. No Thermion-side reference; pulled
transitively by `ktxreader` (≈ 1.4 MB). Exposing it as its own key would let
users build a `ktxreader` that cannot load any real KTX2 file.
**Verdict: opt-out only through `features.ktx`.**

### 3.6 `draco` (`dracodec`)

Google's Draco mesh decoder. gltfio's `AssetLoader` references
`draco::Decoder` unconditionally (≈ 1.0 MB); there is no Filament build option
to remove it. Keeping glTF while dropping Draco would mean patching Filament.
**Verdict: opt-out only through `features.gltf`.**

### 3.7 `filamat` (+ `matp`, `shaders`, `smol-v`, `zstd`)

The material compiler (≈ 31 MB combined archive) and `matp`, the `.mat`
parser behind `matc`. Link-time reference: `TMaterialCompiler.cpp` only,
guarded by `THERMION_ENABLE_RUNTIME_MATERIALS`. Core Filament reaches the
zstd part of the combined archive, which is why Linux always lists `filamat`
(only the zstd members are extracted; it is free). `smol-v` is **core**
(`filaflat::DictionaryReader` decoder) and stays unconditional. The Windows
`matp.lib`/`filamat.lib`/glslang entries follow the same `runtimeMaterials`
condition as the other platforms (§4.4), and the macro is a value check with a
header default of 0 (§5.1, D3). **Verdict: already opt-in; nothing new to
expose.**

### 3.8 `filameshio`

`.filamesh` reader (≈ 54 KB). Nothing links it since #287; only residue in
`.gitattributes`, the native-only macOS test target and the artifact zips.
**Verdict: already gone.** Not staging unused archives in the zips is a
`scripts/` change unrelated to this design.

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
              └─ ktxreader ─ basis_transcoder┘
uberarchive ─┘
image (LinearImage, Ktx1Bundle)  core, except Ktx1Bundle entry points → features.ktx
filamat / matp / shaders         runtime_materials (existing) + debug (matdbg) + Linux (zstd)
smol-v                           core (filaflat::DictionaryReader)
z, zstd                          core (material packages, KTX1 inflate)
filameshio                       nothing
* Windows libs only
```

| Library | Archive(s) removed from the link line | Guard macro | Stub behaviour |
| --- | --- | --- | --- |
| gltfio | `gltfio_core`, `uberarchive`, `dracodec`, `uberzlib`, (`meshoptimizer`, `mikktspace` on Windows) | `THERMION_ENABLE_GLTF` | loaders/providers return null; `*JobThread` variants complete their callback with null; animation functions return 0/null |
| stb | `stb` | `THERMION_ENABLE_IMAGE_DECODING` | `Image_decode` returns null |
| ktxreader, basis_transcoder | `ktxreader`, `basis_transcoder` | `THERMION_ENABLE_KTX` | `Ktx2Reader_createTexture`, `Ktx1Reader_createTexture`, `Ktx1Bundle_create` return null; bundle getters return 0 |

## 4. `features` user define for `hook/build.dart`

### 4.1 Shape

One map under the existing `hooks.user_defines.thermion_dart`, next to
`backend`, `runtime_materials`, `materials` and `plugins`:

```yaml
# consuming app's pubspec.yaml
hooks:
  user_defines:
    thermion_dart:
      features:
        gltf: false             # default true
        ktx: false              # default true
        image_decoding: false   # default true
```

| Decision | Precedent / reason |
| --- | --- |
| A `features` **map**, not three top-level booleans | the `materials` map (`selectBuiltInMaterials`); the top-level namespace does not grow one key per library |
| **Opt-out** semantics: absent key = enabled | every existing app keeps today's binary; opposite polarity to `runtime_materials` (opt-in) because these features are on today |
| Values must be unquoted YAML booleans; anything else is a **hard error** naming the key | `materials.<key> must be true or false` (`MaterialToolsError`); silently ignoring `gltf: "false"` would ship a fatter binary than asked for |
| Unknown key inside `features` = **warning** | `Unknown key materials.$key`; forward compatibility with older hook versions |
| No per-OS map in v1 | `backend` supports per-OS maps, but a Flutter app ships one codebase to all platforms; can be added later without breaking the flat form |

`draco`, `basis_transcoder`, `filameshio`, `image`, `filamat` get no keys: §3
shows they are transitive-only, core, already gated, or already absent.

### 4.2 Parsing and validation (`lib/src/hooks/feature_flags.dart`)

`resolveFeatures(raw, onWarning)` → `({bool gltf, bool ktx, bool imageDecoding})`;
null → all true; non-map → throw; unknown keys → `onWarning`; non-bool →
throw naming the key. Resolved once, early (next to `backend`, before the web
branch) so both branches see it. Cross-feature rules:

- `gltf: true` together with `ktx: false` or `image_decoding: false` is a
  **hard error in v1** (D2, §5.3): Filament v1.77.2's `ResourceLoader`
  reports zero async progress when the provider map is empty, so Dart's
  polling loop would spin forever, and a missing provider merely logs and
  skips the texture. `ktx`/`image_decoding` remain independently switchable
  when `gltf: false`.
- `gltf: false` implies Draco, `uberzlib` and the Windows meshopt/tangent
  libs drop regardless of other keys — they have no other client.
- `runtime_materials` is orthogonal (filamat never references gltfio).

Unit-tested by `test/feature_flags_test.dart` (pure Dart, no native build).

### 4.3 Hook effects (native branch)

```dart
final features = resolveFeatures(input.userDefines['features'], onWarning: logger.warning);

// Defaults: pass nothing when enabled, so an all-default build's compile
// command is IDENTICAL to before (important for build caching, §4.5).
// Disabled features pass an explicit 0; the C headers default to 1 (§5.1).
defines.addAll(disabledFeatureDefines(features));
// if (!features.gltf) -> -DTHERMION_ENABLE_GLTF=0, etc.
```

The `libs` list becomes conditional — order otherwise unchanged (GNU ld
left-to-right resolution):

```dart
if (features.gltf) "gltfio_core",
// "gltfio" (full archive): dropped entirely, nothing references it (§3.1).
if (features.imageDecoding) "stb",
if (features.ktx) ...["ktxreader", "basis_transcoder"],
if (features.gltf) ...["dracodec", "uberzlib", "uberarchive"],
// image, z, zstd, smol-v, geometry, filamat rules: unchanged.
```

Because the archives are *removed*, a guard missed during implementation is a
**link error in CI**, not a silent `dlopen` failure on a user's device — the
same fail-fast property `runtime_materials` has.

When `gltf` is off the hook also compiles the unlit fallback material
(§5.6) with the version-matched matc/resgen pipeline it already uses for the
opt-in helper materials, links the generated `.c` and defines
`UNLIT_FALLBACK_ENABLED`. Default builds never run that step.

### 4.4 Windows

Windows has one link list too. `native/include/ThermionWin32.h` no longer
contains `#pragma comment(lib, ...)` directives (it only includes
`ThermionFeatures.h`); every Windows input — system import libraries,
`bluegl`/`bluevk`, the `filamat` shader-compiler split (`shaders`,
`OSDependent`, `glslang`, `SPIRV*`, `spirv-cross-*`), `meshoptimizer`/
`mikktspace`, `vulkan-1`/`dxgi`/`d3d11` — lives in the same `libs` list as the
other platforms, and the hook passes that list to CBuilder's `libraries` for
Windows. Each feature condition is therefore written once:

```dart
if (targetOS == OS.windows) ...["Shlwapi", "opengl32", "gdi32", "user32", "shell32", "dwmapi", "comctl32"],
"filament",
if (targetOS == OS.windows) ...["bluevk", "bluegl"],
...
if (runtimeMaterials || targetOS == OS.linux || (buildMode == BuildMode.debug && targetOS != OS.windows)) "filamat",
if (runtimeMaterials && targetOS == OS.windows) ...["shaders", "OSDependent", "glslang", "SPIRV", ...],
if (features.gltf) ...[
  "gltfio_core",
  "dracodec",
  if (targetOS == OS.windows) ...["meshoptimizer", "mikktspace"],
],
if (features.ktx) ...["ktxreader", "basis_transcoder"],
if (features.imageDecoding) "stb",
if (targetOS == OS.windows) ...["vulkan-1", "dxgi", "d3d11"],
```

Default Windows link inputs are the same archives under the same conditions as
the old pragma list; they now arrive on the link line instead. The CBuilder
`libraries` path still needs a Windows runner to compile-check (§8).

### 4.5 Caching and artifact identity

- Native Filament archives are feature-agnostic (selection happens at
  *Thermion* compile/link time), so **no new artifact variants** and no
  `getLibDir` changes.
- `defines` are part of the `CBuilder` build identity, so toggling a feature
  rebuilds `libthermion_dart` with no extra cache-key work; passing defines only
  for *disabled* features keeps default builds byte-identical and
  cache-compatible with the previous hook.
- The `materials` manifest is unaffected for default builds; the unlit
  fallback blob (§5.6) is compiled **only when `features.gltf: false`** (D5).

### 4.6 Web

The web engine is a **prebuilt** `thermion_dart-<version>-web<suffix>.zip`
(`web_artifacts.dart`) whose C is compiled by `native/web/CMakeLists.txt` at
publication time; variants already multiply (`-main-thread`,
`-runtime-materials`, `-webgpu`). A zip per feature subset would mean up to 8×
more variants — rejected.

v1 behaviour:

- the hook parses `features` on web too and logs a **warning** when any
  feature is disabled ("web engines are prebuilt with all features;
  `features.*` only affects native builds");
- `native/web/CMakeLists.txt` has the same three `option(THERMION_ENABLE_<FEATURE>)`
  (default ON), so a `-slim` variant can later be published as **one** extra
  suffix, exactly like `-runtime-materials`;
- wasm dead-code-eliminates unreferenced archives, so the win on web comes
  from the same C guards whenever a slim variant ships.

**Web engine release is a dependency of the probe (D4).** Dart calls
`Thermion_getEnabledFeatures()` at init (§6), so every supported browser
engine variant must export it before the Dart code ships: (1) the probe is
in the web CMake sources (always compiled); (2) rebuild and publish all
variant zips at a new `native/web/web.version`; (3) merge the Dart changes
pinned to that version. Compatibility path for older engines (cached zips, a
pinned older `web.version`): Dart resolves the symbol **lazily inside a
try/catch**; if it is absent the bitmask defaults to **all features enabled**
(true for every pre-probe engine) and a one-line warning notes the legacy
engine. `runtimeMaterialsSupported` keeps using `MaterialCompiler_isSupported()`.

## 5. C guard and stub design

### 5.1 Macro convention

`native/include/ThermionFeatures.h` is included by every guarded translation
unit and by `ThermionWin32.h`:

```c
#pragma once
// The hook passes -DTHERMION_ENABLE_<FEATURE>=0 only for DISABLED features;
// enabled/default builds pass nothing, so their compile commands are unchanged.
#ifndef THERMION_ENABLE_GLTF
#define THERMION_ENABLE_GLTF 1
#endif
#ifndef THERMION_ENABLE_KTX
#define THERMION_ENABLE_KTX 1
#endif
#ifndef THERMION_ENABLE_IMAGE_DECODING
#define THERMION_ENABLE_IMAGE_DECODING 1
#endif
// Runtime material compilation is opt-in: the header defaults it to 0 and
// the hook passes -DTHERMION_ENABLE_RUNTIME_MATERIALS=1 only when enabled.
#ifndef THERMION_ENABLE_RUNTIME_MATERIALS
#define THERMION_ENABLE_RUNTIME_MATERIALS 0
#endif
```

All four switches are **value macros**, so `#if` typos fail loudly with
`-Wundef` instead of silently disabling a feature. The three opt-out switches
default to 1; `THERMION_ENABLE_RUNTIME_MATERIALS` is opt-in and defaults to 0.
The runtime-materials macro moved from presence semantics (`#ifdef`, undefined
when off) to value checks in **one atomic migration** covering every guard at
once (D3): `TMaterialCompiler.cpp` (`#if`), `TThermionFeatures.cpp`, the web
CMake and the macOS test CMake (`=0`/`=1` via `$<BOOL:...>`). The hook still
passes `=1` only when enabled, so default compile commands are unchanged.

Web: `native/web/CMakeLists.txt` maps its `option()`s to the same
`target_compile_definitions`, so one macro set serves both build systems.

### 5.2 Guard patterns

**Pattern A — whole-file split** (files whose entire content is the feature):
real implementation under `#if THERMION_ENABLE_X`, complete `extern "C"` stub
set under `#else`, as `TMaterialCompiler.cpp` does. Applies to
`TGltfAssetLoader.cpp`, `TGltfResourceLoader.cpp`, `TFilamentAsset.cpp`,
`TMaterialProvider.cpp`, `TAnimationManager.cpp` (create/destroy/update stay
real there: `AnimationManager` is a zero-cost shell without gltf, so
`RenderManager` can still tick it, §5.5).

**Pattern B — local guards** (files mixing core and feature code):
`TSceneAsset.cpp` keeps `SceneAsset_createFromBuffers`, instancing, entity
access and destroy live and stubs only the glTF-only entry points/branches
(D1); `TScene.cpp` `Scene_addFilamentAsset`; `TTexture.cpp` `Image_decode`
(image_decoding) and `Ktx1Bundle_*`/`Ktx1Reader_*`/`Ktx2Reader_*` (ktx).
`LinearImage` stays core.

**Pattern C — class-level guards** (C++ internals, no C symbols):
`GltfSceneAsset(.Instance)`, the three animation component managers and
`AnimationManager`'s gltfio members compile out; their headers keep
ctor/dtor/update in every build.

Stub rules (so the binary stays loadable and the Dart bindings stay valid):

- every `EMSCRIPTEN_KEEPALIVE` symbol in the corresponding `c_api/*.h` is still
  exported with the exact signature;
- pointer-returning functions return `nullptr`; counts/sizes/booleans return
  `0`; `void` functions are no-ops; `const char*` getters return `nullptr`;
- **callbacks are still invoked**: the `*JobThread` variants in
  `ThermionDartJobThreadApi.cpp` just call the sync entry point inside a
  lambda, so guarding the sync function guards them automatically and Dart's
  `withPointerCallback` completes with null instead of hanging. A sync entry
  point that receives a caller callback must fire it too —
  `Ktx1Reader_createTexture`'s stub calls `onTextureUploadComplete(requestId)`
  because the caller releases borrowed bundle memory in it, exactly as
  `GltfResourceLoader_addResourceData`'s stub invokes `onRelease`.
  `ThermionDartJobThreadApi.cpp` itself needs **no** guards.

Includes of feature headers move under the same guard. Compile-time-only
includes (§3.1) are dropped.

### 5.3 Mixed configurations: gltf on, ktx/image_decoding off — **deferred (D2)**

v1 rejects these combinations at hook time (§4.2). Two Filament v1.77.2
behaviours make the naive provider guard unsafe:

1. `ResourceLoader::asyncGetLoadProgress` returns **0 forever when the
   provider map is empty** — with both decoders off, Dart's async polling
   never completes, *including for a model with no textures at all*;
2. for a MIME type with **no registered provider**, the resource loader logs
   and skips that texture; the load "succeeds" with missing textures instead
   of giving Dart a load error.

Guarded registration remains the intended implementation once the combination
is enabled — `TGltfResourceLoader.cpp` (the file's own TODO asks for this):

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

**Acceptance criteria before this combination may be enabled** (sync
`loadResources` and async paths both):

- a **textureless** glTF asset loads to completion (progress reaches 1.0,
  Dart's poll terminates) even when the provider map is empty — needs a
  Thermion-side completion check that does not rely on Filament's progress;
- an asset that **requires a disabled decoder** fails with a clear,
  propagated load error naming the MIME type and the `features.*` key — needs
  a Thermion-side pre-check of the asset's texture MIME types (via cgltf) or
  an equivalent completion/failure signal, since Filament only logs.

### 5.4 What each disabled feature exports (stub contract)

| Macro = 0 | Symbols kept (all stubbed) | Behaviour |
| --- | --- | --- |
| `THERMION_ENABLE_GLTF` | `GltfAssetLoader_*`, `GltfResourceLoader_*`, `FilamentAsset_*`, `MaterialProvider_*`, `AnimationManager_*`, `Scene_addFilamentAsset` (+ every `*JobThread` twin); **glTF-only** `SceneAsset_*` entry points (`_createFromFilamentAsset`, `_getFilamentAsset`, `_releaseSourceData`, `_getBones/_getBoneCount/_getBoneName`) | create/load return null (callbacks fired with null); getters return 0/null; animation apply/update are no-ops. The remaining `SceneAsset_*` entry points (`_createFromBuffers`, entity/light/camera access, `_createInstance`/`_getInstance` for geometry assets, `_destroy`, …) keep their **real implementations** (D1) |
| `THERMION_ENABLE_KTX` | `Ktx1Bundle_*`, `Ktx1Reader_createTexture`, `Ktx2Reader_createTexture` (+JobThread) | create returns null (`Ktx1Reader_createTexture` first fires `onTextureUploadComplete(requestId)` if given); `isCubemap`/`getSphericalHarmonics` return 0 |
| `THERMION_ENABLE_IMAGE_DECODING` | `Image_decode` | returns null; `Image_createEmpty`/`Image_get*`/`Texture_loadImage` **unaffected** (core `image` archive) |

`GltfParser_parseBuffer` (vendored cgltf, `TGltfParser.cpp`) is **not**
guarded: `parseGltf`/`GltfMeshData` keep working in every build.

Every guard must still return on every path: the `#else` branch of a stub has
to sit *outside* the feature `#if` of a non-void function. Apple Clang and the
Android NDK build with `-Werror=return-type`, so a nested `#if` that leaves a
`gltf: false` build without a `return` is a hard compile error on macOS, iOS
and Android (and UB elsewhere). The Linux CI syntax check compiles every
translation unit in each valid feature configuration with that flag.

### 5.5 Engine init must not force gltfio

`FFIFilamentApp.init` creates the loader and animation manager
unconditionally, and keeps doing so in every build:

- C: `GltfAssetLoader_create`'s stub returns an `UnlitFallbackProvider`
  carrying the engine (§5.6), so `GltfAssetLoader_getMaterialProvider` hands
  Dart a non-null provider handle in every build; `AnimationManager_create`
  under `!THERMION_ENABLE_GLTF` returns a zero-cost object whose
  `tick`/`addAnimation` do nothing (Pattern C), so
  `RenderManager_addAnimationManager` at init stays valid;
- Dart: `createUnlitMaterialInstance` goes through the same context-free
  `MaterialProvider_createMaterialInstance` entry point in every build (no
  Dart branch on `supports(gltf)`); glTF loading is guarded by
  `checkSupported`. Init logs one warning on a slim build naming what is
  unavailable.

### 5.6 Procedural-only apps: the unlit material fallback

`createUnlitMaterialInstance()` (the bounding-box helpers,
`TextureProjection`, explicit materials passed to `createGeometry`) maps to
the **gltfio ubershader's unlit variant** in a default build — the one real
functional dependency of "no glTF" code on gltfio.
(`createGeometry(...)` *without* `materialInstances` is not on this path:
`GeometrySceneAsset` passes `materialInstanceCount = 0` to
`RenderableManager`, which uses Filament's engine default material, an 80 %
white lit material, in every build.)

With gltf off the material comes from a **precompiled package built only when
gltf is off** (D5):

1. `hook/materials/unlit_fallback.mat`: unlit, opaque, single-sided, depth
   tested and written, with the one parameter `baseColorFactor`. It neither
   requires nor reads vertex colours: `createUnlitMaterialInstance()` asks for
   `hasVertexColors: false`, the ubershader picks its no-`COLOR` variant for
   that, and procedural geometry may declare no colour attribute at all
   (`VertexBufferBuilder` renderables) or leave the buffer zero-filled
   (`Geometry(..., createDummyColors: false)`), which `* getColor()` would
   turn into black;
2. the hook compiles it with the version-matched matc/resgen pipeline it
   already uses for the opt-in helper materials (never by filamat at
   runtime), links the generated `.c` and defines `UNLIT_FALLBACK_ENABLED`;
   `TMaterialInstance.cpp` exposes it as the `BUILT_IN_UNLIT_FALLBACK`
   built-in factory. Default builds are untouched: no compiler step, no
   bytes;
3. `MaterialProvider_createMaterialInstance`'s stub builds the package on
   first use from the engine its `UnlitFallbackProvider` carries, caches the
   `Material` (destroyed with the loader by `GltfAssetLoader_destroy`) and
   returns an instance with `baseColorFactor` initialised to **opaque white**
   — a `.mat` uniform parameter is zero-initialised otherwise, and
   `UbershaderProvider` starts at white. Same semantics as the ubershader path:
   white until the caller sets `baseColorFactor`, vertex colours ignored.

`createUbershaderMaterialInstance` (explicit ubershader requests, any `unlit`
value) still throws `UnsupportedError` on a slim build (§6.2). Cost: one
small package (≈ 109 KB for the opengl+vulkan pair) in slim builds only.
Decoupling `createUnlitMaterialInstance` from the ubershader in **default**
builds too is a separate follow-up.

### 5.7 Link-time verification

Valid v1 configurations — 5 of the 2³: all-on, `gltf: false` alone, and
`gltf: false` with `ktx: false` and/or `image_decoding: false`; the
`gltf: true` + decoder-off combinations are rejected by the hook (D2). For
each, build `libthermion_dart` with the corresponding defines and reduced
`libs` list. Success criteria:

1. link succeeds (no undefined Filament symbols) — proves the guards cover
   every reference in §3;
2. `nm -D --defined-only` exports the **same symbol set** as the default
   build — proves Dart bindings/`dlopen`/wasm stay valid;
3. a smoke test: create engine, procedural geometry + unlit material, render
   one frame — proves §5.5/§5.6;
4. a **slim-build procedural test** (D1): on the `gltf: false` build, create
   procedural geometry via `SceneAsset_createFromBuffers`, instance it,
   render and pixel-assert, read entities/bounding box, destroy it — proves
   the shared `TSceneAsset.cpp` entry points stay live and only the glTF
   branches are stubbed.

CI runs criterion 4 plus the `features` parsing tests on a Linux and a macOS
slim build (`.github/workflows/run-dart-tests.yml`, `dart-tests-slim`) and
checks the slim library against the entry points in the generated FFI
bindings (§8). On Linux `--no-undefined` (`-Wl,-z,defs`) makes criterion 1
strict; macOS/Windows linkers are strict by default. Android additionally
needs the `dlopen` smoke test because its linker resolves lazily (the
perfetto precedent in `hook/build.dart`).

## 6. Dart surface

### 6.1 One C probe

```c
// c_api/ThermionFeatures.h (always compiled, never guarded)
EMSCRIPTEN_KEEPALIVE uint32_t Thermion_getEnabledFeatures();
// bit 0: GLTF, bit 1: KTX, bit 2: IMAGE_DECODING, bit 3: RUNTIME_MATERIALS
```

Returns the compile-time bitmask. The generated bindings serve every feature
combination because the symbol exists in every build made from this design
onward; older prebuilt web engines do not export it (§4.6, D4).
`MaterialCompiler_isSupported()` stays as-is (bit 3 mirrors it).

### 6.2 Public API

```dart
enum ThermionFeature { gltf, ktx, imageDecoding, runtimeMaterials }

abstract class FilamentApp {
  bool supports(ThermionFeature feature);   // reads the cached bitmask once
}
```

Affected APIs **throw `UnsupportedError` naming the `features.*` key**, never
return garbage (`FFIFilamentApp.checkSupported`):

| Dart API | Off-feature behaviour |
| --- | --- |
| `loadGltfFromBuffer`, `ThermionViewer.loadGltf*`, `ThermionViewerWidget.assetPath` | `UnsupportedError` (`features.gltf`) |
| `createUbershaderMaterialInstance` / `createUbershaderMaterial` (any `unlit` value) | `UnsupportedError` (`features.gltf`) |
| `createUnlitMaterialInstance`, `createGeometry` (with or without a material) | **keep working** via §5.6 / Filament's default material |
| `AnimationManager` gltf/bone/morph APIs; `Asset.getBones/getBoneCount/getBoneNames/releaseSourceData/getGltfAnimationNames/getGltfAnimationDuration` | `UnsupportedError` naming the calling API and `features.gltf` — checked **before** the asset type, so a procedural asset on a slim build reports the disabled feature instead of "no animations" |
| `Asset.createInstance/getInstance` on **procedural** assets | **keep working** (D1) |
| `Asset.removeMorphAnimationComponent` and friends on the destroy path | **keep working** as no-ops: `FFIAsset`'s destroy calls them for every asset type, procedural geometry included; the C stubs are no-ops. The glTF/bone component removals are skipped without gltf so they do not log bogus failures |
| `loadKtx`, `loadKtx2`, `createIblFromKtx`, `Ktx1Bundle` | `UnsupportedError` (`features.ktx`) |
| `decodeImage` | `UnsupportedError` (`features.image_decoding`) |
| `createImage`, `Texture.setLinearImage/loadImage`, `parseGltf`/`GltfMeshData` | unchanged, always available |

The Flutter plugin needs no API change; `ThermionViewerWidget` surfaces the
same `UnsupportedError` through its existing error builder.

### 6.3 Why stubs *and* Dart guards

Either alone would keep a slim build loadable, but both are needed:

- stubs alone: Dart callers would get null handles and fail with obscure
  null-pointer errors deep in FFI code;
- Dart guards alone: any missed Dart path (or a user calling raw bindings)
  hits a missing symbol at first call on native, and a **load-time failure**
  on wasm if the symbol is referenced in the JS interop glue.

Stubs make the binary structurally valid; Dart guards make failures
diagnosable. Same division of labour as `runtime_materials`.

## 7. Measured sizes (Linux x64, release, stripped)

Release Filament v1.77.2, Linux x64, the package's 13 helper materials
enabled in every build (so symbol sets compare like for like), `-Wl,-z,defs`.
Stripped with `strip`.

| Build | `Thermion_getEnabledFeatures` | unstripped `.so` | stripped `.so` | stripped saving |
| --- | --- | --- | --- | --- |
| default (all on) | `0x7` | 10.28 MB | 7.84 MB | — |
| `gltf: false` (ktx, image_decoding on) | `0x6` | 8.94 MB | 6.81 MB | **1.03 MB / 0.99 MiB (−13 %)** |
| all three off | `0x0` | 7.75 MB | 5.69 MB | **2.15 MB / 2.05 MiB (−27 %)** |

Symbol sets (`nm -D --defined-only`): every C entry point declared in
`c_api/*.h` is present in all three builds (the same 7 names are
declared-but-never-defined in all of them, pre-existing drift unrelated to
this work: `Camera_setProjectionMatrix`, `LightManager_rgbToColorTemperature`,
`MaterialProvider_create`, `RenderableManager_getCulling`,
`RenderableManager_getPriority`, `Renderer_setFrameInterval`,
`Texture_getUsage`). The only non-mangled differences are the intended ones:
`UBERARCHIVE_PACKAGE` only in default; `UNLIT_FALLBACK_PACKAGE` and the 36
`cgltf_*` functions only in slim.

**Object-file closure estimate** (why gltfio looked bigger than it is):
indexing every member of every `.a` with `nm` and computing the transitive
closure of undefined symbols from each feature's root symbols models GNU ld
member extraction without `--gc-sections`: gltfio as linked today ≈ 4.4 MB
(gltfio_core 1.4, basis_transcoder 1.4, dracodec 1.0, geometry-tangents 0.3,
stb 0.12, meshoptimizer/mikktspace/ktxreader/uberzlib < 0.2), ktxreader +
Ktx1Bundle ≈ 1.5 MB, stb ≈ 0.12 MB, filamat + matp ≈ 41 MB. The measured
`gltf: false` saving is 1.0 MB rather than 4.4 MB because the model counts
object files the linker never extracts and lumps `basis_transcoder`/`stb`
(still linked when the decoders stay on) into the glTF closure. Treat the
closure numbers as an upper bound only; the stripped `.so` is the claim.

The headline numbers are Linux x64 only. Android arm64 (APK/AAB) and iOS are
not measured yet (§8); debug builds differ (matdbg/fgviewer, no
`--gc-sections`).

## 8. Verification, CI and open items

Verified locally on Linux x64 (`xvfb-run` + llvmpipe) for the default, the
`gltf: false` and the all-off builds: all link; `dart analyze` clean of new
issues; `test/slim_build_test.dart` passes 4/4 on both slim builds and skips
all 4 on the default build; the default regression set (geometry, instancing,
asset, glTF/bone/morph animation, KTX upload lifetime, image,
`feature_flags_test`) is unchanged. Every translation unit was also compiled
with `-fsyntax-only -Werror=return-type -Wundef` in each valid feature
configuration.

CI (`.github/workflows/run-dart-tests.yml`):

- `test/feature_flags_test.dart` runs with the pure-Dart test list;
- `dart-tests-slim` (Linux + macOS) rewrites the package's `hooks:` block with
  `features: {gltf: false, ktx: false, image_decoding: false}`, rebuilds, runs
  `slim_build_test.dart` + `feature_flags_test.dart` and — on Linux — checks
  that the slim library exports every entry point named in the generated FFI
  bindings. The macOS runner is what makes the `-Werror=return-type` guarantee
  real; a future unguarded gltfio/ktxreader/stb reference is a link error here
  instead of landing on `develop`.

Open items (none block merging the native opt-outs):

| Item | Where it lands |
| --- | --- |
| **Android arm64 measurement** (D5): stripped `libthermion_dart.so` and packaged size next to the default, plus the `dlopen` smoke test | CI follow-up; decides whether the saving is advertised for Android/iOS |
| **Web engine republication** (D4): every supported variant with `Thermion_getEnabledFeatures`, new `native/web/web.version`, then retire the lazy legacy fallback | publication workflow; until then the fallback treats older engines as "all features on", which is true for every existing engine |
| **Windows**: the `CBuilder(libraries:)` link path and the unlit fallback on D3D need a Windows runner | `dart-tests` (Windows) once the PR tests are unpaused; the feature conditions themselves are platform-neutral |
| `gltf: true` with a decoder off | §5.3 acceptance criteria |
| Optional `-slim` web engine variant | §4.6 |
| Decouple `createUnlitMaterialInstance` from the ubershader in default builds | separate follow-up (§5.6) |
| Stop staging unused archives in the artifact zips | `scripts/` change, unrelated |

Risks and mitigations:

| Risk | Mitigation |
| --- | --- |
| A future contributor adds an unguarded gltfio/ktxreader/stb reference | the reduced link line fails `dart-tests-slim` immediately; headers are guarded too, so the include itself disappears |
| A guard leaves a non-void function without a return on some path | Apple Clang (`-Werror=return-type`) on the macOS slim job; Linux syntax check with the same flag |
| Stub signature drift vs. headers | stubs live next to the real implementation under the same header contract; the slim job diffs exports against the bindings |
| Users disable a feature their code uses | `UnsupportedError` names the exact `features.*` key; `supports()` allows graceful fallback |
| glTF loads with missing texture providers | combination rejected at hook time (D2) |
| Filament upgrade changes transitive deps | re-run the closure script per artifact bump; §3 is pinned to v1.77.2 |
| Per-OS feature demand later | flat schema extends to per-OS maps without breaking (§4.1) |
| Dart init requires a probe older web engines lack | lazy lookup + all-enabled default (§4.6, D4) |

## 9. Settled review decisions

| # | Decision | Where it lands |
| --- | --- | --- |
| D1 | Procedural scene assets stay in the core: `TSceneAsset.cpp` uses local guards (Pattern B), not a whole-file stub; shared `SceneAsset_createFromBuffers`, entity access, instancing and destruction stay live. A slim-build test creates, instances, renders and destroys procedural geometry. | §3.1, §5.2, §5.4, §5.7, §6.2 |
| D2 | Mixed builds (`gltf: true` with `ktx: false` or `image_decoding: false`) are **deferred**: hard error at hook time in v1. Re-enabling requires defined + tested completion for textureless assets and a clear propagated failure for assets needing a disabled decoder, sync and async. | §4.2, §5.3, §5.7, §7 |
| D3 | `THERMION_ENABLE_RUNTIME_MATERIALS` moved from presence semantics to value checks in **one atomic migration** covering every guard; the header defaults it to 0. `smol-v` stays **unconditional** (core `filaflat::DictionaryReader` decoder). | §3.7, §4.4, §5.1 |
| D4 | The web engine release is a **dependency of the probe**: rebuild and publish every supported web variant with `Thermion_getEnabledFeatures` and advance `native/web/web.version` before Dart requires it. Legacy engines get a lazy-lookup fallback: missing symbol → all features enabled + warning. | §4.6, §6.1, §8 |
| D5 | **Prototype first**: the native `gltf: false` build was proven on Linux before the schema/API rollout; the unlit fallback blob is **precompiled and built only when gltf is off** (an unconditional blob would add a matc/resgen step to default apps that skip it today). Android arm64 is measured before any size saving is advertised for mobile. | §4.5, §5.6, §7, §8 |
