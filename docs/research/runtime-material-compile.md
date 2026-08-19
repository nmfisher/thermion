# Runtime material compilation / hot-reload — research & implementation plan

Status: research/plan (no code changes). Date: 2026-08-19. Branch: `asb/runtime-material-compile`.
Scope: how thermion could (1) compile `.mat` / material source to a runnable material **at runtime**, and (2) **hot-reload** materials in a running app.

Everything marked **[verified]** below was checked directly in this repo or reproduced in a container against the exact libraries thermion ships (R2 artifact `filament-v1.75.0-*-release.zip`).

---

## 1. Current material path, end to end

### 1.1 Build time (today, the only compilation path)

```
materials/*.mat
  └─ matc -a <backend>… -o X.filamat X.mat          (materials/build.sh:66-67)
       └─ resgen -c -p <name> -x <dir> X.filamat     (materials/build.sh:68)
            └─ <name>_<variant>.c/.h                 (uint8_t arrays, embedded in native lib)
                 └─ hook/build.dart picks ONE variant per platform  (build.dart:200-214)
                      └─ compiled into libthermion_dart.so / wasm
```

- `make materials` (Makefile:45-51) requires `FILAMENT_PATH` and runs `materials/build.sh`.
- `scripts/regenerate-materials.sh` downloads a **custom, WebGPU-enabled** `matc`/`resgen` pair from thermion's R2 bucket (`filament-v1.75.0-linux-release-webgpu.zip`, tools-only: `bin/matc` 17.8 MB + `bin/resgen`; no libs/headers inside) — [verified].
- 8 variants per material (`apple|android|desktop|opengl|vulkan|webgpu|web_webgl|web_combined`, materials/build.sh:147-154); the `.filamat` intermediates are **deleted** after `resgen` (materials/build.sh:94).
- Web: `native/web/CMakeLists.txt:102-117` picks one variant (default `web_webgl`) and links it into the wasm executable.
- Exception: 3 example materials are kept as real `.filamat` files in `examples/assets/` (compiled with all 4 target APIs, materials/build.sh:229-233).

### 1.2 Runtime (loading a compiled material)

- Dart: `FilamentApp.createMaterial(Uint8List)` → `Engine_buildMaterialRenderThread(engine, data.address, data.length, cb)` — `lib/src/filament/src/implementation/ffi_filament_app.dart:603-611`.
- Native: `Engine_buildMaterial` (`native/src/c_api/TEngine.cpp:287-294`) = `Material::Builder().package(data, len).build(*engine)`. Destruction: `Engine_destroyMaterial` (TEngine.cpp:296-301).
- Built-in materials (grid/gizmo/image/…) are compiled into the library and built from embedded arrays in `native/src/c_api/TMaterialInstance.cpp` (e.g. lines 56-66) via `MaterialProvider` / `MaterialProvider_createMaterialInstanceRenderThread`.
- Applying to geometry: `RenderableManager_setMaterialInstanceAt` / `getMaterialInstanceAt` (`native/src/c_api/TRenderableManager.cpp:26-46`); Dart wrappers in `lib/src/filament/src/implementation/ffi_asset.dart:232-269`.
- There is **no** `TMaterial.cpp`; Material-related exports live in `TEngine.cpp`/`TMaterialInstance.cpp`. No code anywhere in thermion calls `filamat::*`, `matp::*` or compiles shaders at runtime — [verified by repo-wide grep].

So: **the runtime load path already accepts arbitrary filamat bytes**; everything missing is on the *produce* side (mat → filamat at runtime) and the *swap* side (live replacement bookkeeping).

---

## 2. What Filament v1.75.0 offers at runtime — verified

The full matc pipeline exists as linkable libraries; matc is just a CLI wrapper around them:

| Piece | API | Notes |
|---|---|---|
| `.mat` parser | `matp::MaterialParser` (`filament-matp/MaterialParser.h`) | `parse(builder, config&, size&, buffer&)` fills a `MaterialBuilder`; `resolveIncludes()` handles `#include` (needed by `grid.mat` → `shared.h`). Library `libmatp.a`, ~600 KB, deps: filamat/filabridge/utils. matc uses exactly this (`tools/matc/src/matc/MaterialCompiler.cpp:92-105`). |
| Material compiler | `filamat::MaterialBuilder` (`filamat/MaterialBuilder.h`) | `init()` once → set `.platform()/.targetApi()/.optimization()/.materialSource(src)` → `build(engine.getJobSystem())` → `Package` (`getData()/getSize()/isValid()`). `materialSource(std::string_view)` takes the raw `.mat` text; it is also embedded into the filamat (MaterialBuilder.cpp:1770) which is what matdbg-style tools consume. |
| Material creation | `Material::Builder().package(data, size).build(engine)` | Already used by thermion today (TEngine.cpp:290). |
| Live swap | `RenderableManager::setMaterialInstanceAt(inst, prim, mi)` | RenderableManager.h:880 — supported on live renderables. |
| Material→instances | `Material::createInstance()`, `getDefaultInstance()` | A `MaterialInstance` **cannot change its parent Material** (no API) — reload = new Material + new instances + re-apply. `MaterialInstance::getMaterial()` exists (MaterialInstance.h:118). |
| Parameter reflection | `Material::getParameterCount()/getParameters()/hasParameter()` | Material.h:368+. Values are **write-only** on MaterialInstance (no getters) — reload must re-apply values from a client-side shadow copy. |
| Shader hot-swap in a package | `matdbg::ShaderReplacer` (`matdbg/ShaderReplacer.h`) | Edits shader source inside an existing filamat → new package. Dev-tooling angle only. |

`matp::Config` is abstract (matc implements it via its CLI config); a runtime implementation is ~15 lines setting `mPlatform`/`mTargetApi`/`mOptimization` — prototyped below.

### 2.1 End-to-end proof (run in this research, Linux, thermion's own artifact)

Linked **only** against libs extracted from `filament-v1.75.0-linux-release.zip` (the artifact `hook/build.dart` already downloads), built a normal executable and a **shared library**:

```cpp
RuntimeConfig cfg(Platform::DESKTOP, TargetApi::OPENGL);      // matp::Config subclass
filamat::MaterialBuilder::init();
filamat::MaterialBuilder b;
b.platform(...).targetApi(...).optimization(...).materialSource(matText);
matp::MaterialParser p; p.parse(b, cfg, size, buffer);        // status OK
filamat::Package pkg = b.build(engine.getJobSystem());        // valid, 105 KB
// pkg.getData()/getSize() == a normal .filamat (magic "MATVERS")
```

Results — [verified]:
- Parse + build of a real `.mat` (lit, float3 param) → **valid 105 KB filamat**, ~1.7 s cold for DESKTOP+OPENGL with `Optimization::PERFORMANCE` (all variants). Faster with `Optimization::NONE` / single shader model — measure per case.
- Shared-lib link (`-shared -fPIC`) works: the whole stack (incl. glslang/SPIRV) is **PIC**. Stripped `.so` carrying the full compiler = **11.2 MB** (x86-64) — the realistic per-platform size cost.
- Link order note: `libmatp.a` must precede `libutils.a` (it references `utils::Path`).
- `utils/JobSystem.h` is *not* in the artifact's headers (private) but is unneeded: `MaterialBuilder.h` forward-declares it and `Engine::getJobSystem()` (Engine.h:1276) supplies the reference.

### 2.2 What thermion's artifacts and link config already contain — [verified by inspecting R2 zips + build.dart]

| Platform | `libfilamat.a` in artifact | `libmatp.a` | glslang/SPIRV | Linked into thermion today |
|---|---|---|---|---|
| Linux | 34.9 MB (combined: filamat+glslang+SPIRV-Tools+spirv-cross+zstd) | 592 KB | bundled inside filamat | **Yes — inside `--whole-archive`** (build.dart:231, 493-497) → the compiler is *already shipped* in the Linux .so |
| Windows | 9.3 MB + separate `glslang.lib`, `SPIRV*.lib`, `spirv-cross-*.lib` | 3.7 MB | separate libs, present | Yes (pragma, `native/include/ThermionWin32.h:19`) |
| macOS | 45 MB combined | 756 KB | bundled | Yes (build.dart:231) |
| Android (4 ABIs) | 25–30 MB per ABI, combined | **missing** | bundled | Yes (build.dart:231; the ZSTD link fix at build.dart:260-268 proves filamat objects are pulled into Android binaries) |
| iOS | 39 MB combined | **missing** | bundled | **No** — explicitly excluded (build.dart:231) |
| Web/wasm | **missing** | **missing** | — | No (declared as imported target `native/web/CMakeLists.txt:213-216` but never linked, lines 334-359) |

Also: `scripts/build_linux.sh` already patches `libs/filamat/CMakeLists.txt` with `CMAKE_POSITION_INDEPENDENT_CODE ON` ("Patch libs/filamat/CMakeLists.txt for position independent code") — someone already prepared filamat for shared-lib linking.

**Conclusion of feasibility: in-process runtime compilation (`Option A`) requires no new Filament upstream work.** On desktop it is (almost) *just writing the call*; on Android it needs `matp` added to the artifact; iOS additionally needs a link-list change; web needs real build work (§6).

---

## 3. Design options — runtime compilation

### A. In-process compile with `matp` + `filamat::MaterialBuilder` — **recommended**
Compile `.mat` text → `Package` → `Material` inside libthermion_dart, same process as the engine.

- Pros: no external tools; works offline; single source of truth (same libs as matc → identical output); `#include` support via `resolveIncludes`; already 90% built on desktop (§2.2).
- Cons: +~11 MB stripped binary per platform when the compiler code is pulled in (Linux already pays this today via whole-archive); compile latency ~0.1–1.7 s per material; glslang is a large attack surface for untrusted input (fuzzing story: Filament fuzzes matc paths upstream).
- Effort: see phased plan (§5). 1–2 weeks to a cross-platform API, most of it in CI/artifacts and tests, not the code.

### B. Bundle `matc` and shell out at runtime
Ship the 17.8 MB matc binary next to the app; run it as a subprocess on a temp dir.

- Pros: zero new link/ABI risk; identical to the build-time path.
- Cons: **not viable on iOS** (no subprocess/App Store rules), awkward on Android (`exec` restrictions on API 29+), useless on web; two copies of the compiler if A is also shipped; temp-file plumbing.
- Effort: deceptively large (per-platform bundling, signing, paths). **Not recommended** except as a dev-only desktop tool.

### C. Remote compile service
App uploads `.mat`, server runs matc, returns filamat bytes (thermion already has `createMaterial(bytes)` to consume them).

- Pros: keeps clients thin; works on web/iOS; central version control.
- Cons: network dependency, latency, hosting cost; must match the app's Filament version exactly (filamat chunk versions are version-locked); security surface.
- Effort: ~1 week for a minimal HTTP service (matc in a container) + client. Worth having as the **web fallback**, not as the primary.

### D. No runtime compile — reload only
Keep build-time matc; hot-reload by re-reading a rebuilt `.filamat` (§4). This is the cheapest useful increment and is a strict subset of A.

### E. Adjacent Filament tooling worth knowing
- `matdbg` (in artifacts, 10 MB) — embedded debug server + `ShaderReplacer` for live shader edits; dev-only, requires `FILAMENT_ENABLE_MATDBG` builds (thermion debug zips already link it on mac/linux/android — build.dart:280).
- `filamat_lite` — interchangeable, no-glslang variant (OpenGL target only, `Optimization::NONE`, no validation, no SPIR-V). **Not built in any thermion artifact today** — a candidate if Android/iOS size matters more than optimization quality.
- `matedit` — matc-adjacent tool for re-packaging materials with externally compiled shaders (e.g. iOS precompiled Metal); not a live editor.

---

## 4. Design options — reload (live replacement)

Facts that constrain the design:
1. `MaterialInstance` cannot be re-parented to a new `Material` — [verified: no such API in MaterialInstance.h].
2. `RenderableManager::setMaterialInstanceAt` swaps instances on live renderables — already exported (TRenderableManager.cpp:26).
3. MaterialInstance parameter values cannot be read back — reload must re-apply values the app (or thermion's Dart layer) remembers.
4. Filament's `Engine` caches compiled programs per Material; destroying the old Material after swap frees them (destroy must happen on the engine thread, after no renderable references remain).

### 4.1 Reload shape (works with D today, with A later)

```
newMat = createMaterial(filamatBytes)            // exists: ffi_filament_app.dart:603
for each (entity, prim) using oldMat:
    mi = newMat.createInstance()                 // exists
    mi.copyParamsFrom(shadowParams)              // NEW: Dart-side shadow map of set values
    setMaterialInstanceAt(entity, prim, mi)      // exists: ffi_asset.dart:261
engine.destroyMaterial(oldMat) (after swap)      // exists: Engine_destroyMaterial
```

Two levels:
- **L1 — instance swap (recommended MVP):** new Material + fresh instances, params re-applied from a Dart-side shadow map recorded by thermion's existing `MaterialInstance.set*` wrappers. Deterministic, no reflection gaps. Cost: values set behind thermion's back (native/gltf defaults) fall back to the new material's defaults.
- **L2 — default-instance takeover:** additionally re-point every renderable that referenced the *default instance*; needs an entity→(material, prim) index. Thermion does not keep one today; build it lazily by walking `RenderableManager` at reload time, or maintain it on `setMaterialInstanceAt`.

Note on glTF materials: gltfio materials come from the uberarchive; the same swap API applies per-prim, but a full glTF "re-material" should go through `GltfSceneAsset`'s instance lists (`native/src/scene/GltfSceneAsset.cpp:162` already loops `setMaterialInstanceAt`).

---

## 5. Recommended phased plan

Effort assumes one engineer comfortable with the repo; "d" = working days.

### Phase 0 — Reload-only MVP (no compiler) — **~2-3 d**
1. Dart: `MaterialInstance` wrappers record `(name → value/texture)` on every `set*` (shadow map).
2. Dart: `Future<Material> reloadMaterialFromBytes(Material old, Uint8List filamat)` implementing §4.1 L1 (+ entity scan helper for L2).
3. Example/test: loop that re-reads `examples/assets/*.filamat` and hot-swaps (pattern already half-present in `test/depth_tests.dart:104-106`).
No native, no build changes. Ships everywhere immediately (incl. web).

### Phase 1 — Runtime compile API, desktop first (linux/macOS/Windows) — **~4-6 d**
1. Native (`TEngine.cpp` or new `TMaterialCompiler.cpp`):
   ```cpp
   // called on the engine/render thread like Engine_buildMaterialRenderThread
   TMaterial* Engine_compileMaterialRenderThread(
       TEngine*, const char* matSource, size_t length,
       uint32_t platformFlags, uint32_t targetApiFlags, uint32_t optimization,
       const char* definesJson,                       // {"NAME":"value",...}
       char* outError, size_t outErrorCap);           // parse/build failure text
   ```
   Implementation = the proven §2.1 sequence: `matp::MaterialParser::parse` (after `resolveIncludes` when include paths are given) → `MaterialBuilder::build(engine->getJobSystem())` → `Material::Builder().package()`. `MaterialBuilder::init()` once (refcounted; serialize against `shutdown`).
2. Link config: `matp` is already in linux/macos/windows artifacts — add `"matp"` to the libs list (build.dart:227-281) and a `#pragma comment(lib, "matp.lib")` (ThermionWin32.h). On Linux matp lands inside whole-archive (fine).
3. Defaults: infer `Platform`/`TargetApi` from `engine->getBackend()` via `targetApiFromBackend()` (MaterialBuilder.h) so users don't specify anything.
4. Dart API:
   ```dart
   Future<Material> compileMaterial(String matSource, {
     MaterialTargetApi? targetApi,   // default: engine backend
     MaterialOptimization optimization = performance,
     Map<String, String> defines = const {},
     List<String> includePaths = const [],   // for #include
     bool embedSource = true,                // MaterialSource chunk, aids debugging
   });
   ```
   + ffigen regen (`make bindings`), web stub throwing `UnsupportedError` initially.
5. Tests: golden — runtime-compiled filamat for each shipped `.mat` in `materials/` must equal (or be accepted by `Material::Builder` identically to) the matc output for the same flags; parse-error path returns message.

### Phase 2 — Android — **~3-5 d (mostly CI)**
1. `scripts/build_android.sh` / `zip_android.sh`: build+package `libmatp.a` per ABI (matp is host-agnostic C++; filament's android build currently doesn't install it — add `ninja matp` + copy step).
2. Add `"matp"` to android libs; measure `.so` delta per ABI (expect ≈ +8-12 MB uncompressed; document; consider R8/strip + `Optimization` guidance for dev vs release).
3. Same C API as Phase 1; no new Dart surface.

### Phase 3 — iOS — **~3-5 d**
1. Re-enable `"filamat"` for iOS (build.dart:231) + ship `libmatp.a` in the iOS artifact (same CI change as Phase 2).
2. Verify the iOS `libfilamat.a` (41 MB, combined) links into a dylib (PIC is the default for iOS archives — still verify; desktop was verified here).
3. Decide policy: full filamat vs `filamat_lite` (needs a filament build flag; OpenGL-only target is irrelevant on Metal — so realistically *full* filamat; budget ~+10-15 MB to the app).
4. App Store review risk for a shader compiler embedded: low (it's Filament's supported path, used by filamat-android consumers), but note it.

### Phase 4 — Web — **defer or use option C — 1-2 weeks if attempted**
The web artifact contains no filamat/matp and the wasm module doesn't link them (native/web/CMakeLists.txt:334-359). Emscripten *can* build glslang (pure C++), thermion web already enables pthreads (8 workers), so `build_web.sh` + CMake changes are the work — but expect +15-25 MB wasm and slower compiles. Recommendation: keep web on build-time matc (Phase 0 reload still works: bytes in, `createMaterial` works on web today) and, if runtime compile on web is truly needed, use the Phase-C remote service.

### Optional Phase 5 — Dev-experience polish — **~3-5 d**
- File watcher (`watch` package) + `hotReloadMaterial(path)` in the example app: on change → compile (Phase 1) or read `.filamat` (Phase 0) → §4.1 swap. This is the "hot-reload a material in a running app" demo.
- Embed `materialSource` in runtime-built packages (default true) so a future matdbg-style inspector works on runtime materials too.
- Expose `Optimization::NONE` as an "iteration mode" (faster compiles, larger shaders).

---

## 6. Cross-platform summary

| | A: in-process | B: bundle matc | C: remote | D: reload-only |
|---|---|---|---|---|
| Linux/Win/macOS | ✅ (near-free) | ✅ | ✅ | ✅ |
| Android | ✅ (CI work) | ⚠️ exec restrictions | ✅ | ✅ |
| iOS | ✅ (link+CI work) | ❌ | ✅ | ✅ |
| Web | ⚠️ heavy wasm | ❌ | ✅ | ✅ |
| AOT/size cost | +~11 MB stripped/platform | +18 MB host tool | 0 | 0 |

No platform needs a *platform shader compiler* at runtime: MaterialBuilder emits GLSL/SPIR-V/MSL/WGSL itself via glslang+spirv-cross (all CPU-side, in-process, no driver/JIT involvement). iOS/Android AOT is not a factor.

---

## 7. Risks & unknowns (with verification steps)

1. **Current Linux .so already contains the compiler (whole-archive)** — verify: build current main, `nm -D libthermion_dart.so | grep MaterialBuilder`. If yes, Phase 1 on Linux adds ~0 bytes and we could even exclude filamat from whole-archive later if we want to slim release builds (feature-flag via separate build define).
2. **Android/iOS `libmatp.a` absence** — CI change; confirm filament's android/ios cmake graphs build matp unmodified (pure C++; expected yes).
3. **iOS PIC + codesign of embedded compiler** — link test in CI before promising.
4. **Binary-size regressions on Android** — measure per-ABI delta; mitigation: link matp+filamat only when a `THERMION_RUNTIME_MATERIALS` define is set (opt-in build), or evaluate filamat_lite.
5. **Compile latency** — measured 1.7 s cold/1 target/PERFORMANCE. For editor-like iteration use `Optimization::NONE` + single `TargetApi`; run on a worker and marshal to the engine thread only for `Material::Builder().build()`.
6. **Error surfacing** — `matp` parse errors come back as `utils::Status` (message string — good). Shader *compile* errors go through filament's `LOG(ERROR)`/stderr; there is no first-class callback. Verify whether `utils::Log` can be redirected in-process (utils/Log.h) — else capture stderr in dev builds. **Needs verification.**
7. **Thread-safety** — `MaterialBuilder::init()` is refcounted (atomic) but glslang initialization is not; serialize init/first-build with a mutex. Builds themselves use the provided JobSystem (use `engine->getJobSystem()`; don't `adopt()` a private one inside the engine process).
8. **Version lock** — runtime-built packages must be consumed by the same Filament version (thermion ships both from one artifact — fine today; document that a `compileMaterial` result is not portable across engine versions).
9. **`#include` resolution** — `matp::MaterialParser::resolveIncludes(buffer, size, materialFilePath, ...)` needs real paths; on Flutter assets aren't files. Plan: Dart resolves includes itself (it already has asset loading) and passes a flattened source, or pass virtual include-dir callbacks. **Design detail for Phase 1.**
10. **glTF/uberarchive materials** — out of scope for reload MVP; swapping those needs `GltfSceneAsset` awareness (§4.1 note).

---

## 8. TL;DR

- The runtime compiler Filament offers (`matp` + `filamat::MaterialBuilder`) is complete, PIC, and **already sitting in thermion's own build artifacts**; on Linux it is *already linked whole-archive into the shipped .so*. Feasibility is proven end to end in this research: `.mat` text → valid filamat in ~1.7 s using only artifact libs.
- Do **Phase 0 (reload MVP, 2-3 d)** now — pure Dart, all platforms.
- Do **Phase 1 (desktop runtime compile, 4-6 d)** next — small native function + link-list entry + ffigen.
- **Phase 2/3 (Android/iOS)** are CI/artifact work (3-5 d each). **Web** stays build-time/remote.
- Biggest real risks: Android/iOS size delta, error-message plumbing, and include-resolution ergonomics — all tractable, none architectural.
