# Game-Effect Shaders for Thermion (hit flash, dissolve, water, smoke, hologram, force field)

## Context

Thermion has no game-effect shaders — every custom material in the repo is editor/utility (grid, outline, wireframe, gizmo). We want visually appealing game VFX: **hit flash, dissolve/burn, water, smoke/fog, hologram, force field**. Decisions:

- **Example-level only** — no core engine changes, no new public API. Materials ship as standalone `.filamat` assets, demoed from `examples/dart/examples_lib`.
- **Pure shaders** — no particle system (vendored Filament has none; smoke is GPU-billboard shader work).
- **macOS desktop (Metal) first**, verified via the headless runner.

The full pipeline for this already exists and is proven by `proceduralquad`/`customattributes`/`viewspace`/`solidcolor`: author `.mat` → compile with `matc` → load bytes at runtime via `FilamentApp.createMaterial()` → drive uniforms via `MaterialInstance.setParameter*`. No runtime shader compilation exists, so matc is the iteration loop.

## Verified mechanics the plan relies on

| Mechanism | Where | Notes |
|---|---|---|
| `.mat` → `.filamat` | `materials/build.sh` `EXAMPLE_MATERIALS` array (line 44) | Compiles standalone all-backend `.filamat` into `examples/assets/` |
| Runtime material creation | `FilamentApp.createMaterial(Uint8List)` (interface `filament_app.dart:129`) | Accepts pre-compiled `.filamat` bytes |
| Asset loading in examples_lib | `FilamentApp.instance!.loadResource("$assetsDir/<name>.filamat")` (interface line 45); runner wires it to file I/O | `assetsDir` = `file://…/examples/assets` |
| Uniform setting | `MaterialInstance.setParameterFloat/Float2/3/4/Int/Bool/Texture` (`material.dart`) | BlendingMode is baked in `.mat`; `setTransparencyMode` runtime-only |
| Per-frame time | `registerRequestFrameHook` (`ffi_filament_app.dart:773-810`) — hooks run at top of `render()` only | `capture()` bypasses hooks; `beforeRender` param is **not awaited** (line 984) → for captures set params *before* calling capture (they persist on the instance) |
| Headless verify | `examples/dart/headless_runner/bin/run_example.dart` — `dart run <name> [w] [h]` → `output/<name>.png` | One capture after `setup()` returns |
| Custom vertex attrs / vertex-generated quads | `examples/assets/proceduralquad.mat` (quad from `getVertexIndex()`), `customattributes.mat` (`requires: [custom0]`, `getCustom0()`) | Precedents for smoke billboards |
| Geometry | `viewer.createGeometry(Geometry, materialInstances:[...])`; `GeometryUtils` has NO subdivided plane (plane() = 4 verts) | Water grid helper written example-side |
| `ExampleSetup` typedef | `registry.dart:33`: `Future<void> Function(ThermionViewer viewer, {required String assetsDir})` | |
| Windowed runners | `cli_windows` is Win32-only — unusable on macOS | Headless PNG loop is the macOS iteration vehicle |

All noise is **procedural** (hash/value-noise fbm in GLSL) — no texture assets needed. Fresnel = manual `pow(1 - |dot(normal, viewDir)|, power)`; view dir from `getWorldCameraPosition() - getWorldPosition().xyz` (pattern: `materials/bone_overlay.mat`). Normals reach the fragment shader via `variables` (bone_overlay pattern); `createGeometry` auto-generates tangent quaternions when normals exist, so include normals in custom geometry.

## New files

**Material sources + compiled artifacts** (`examples/assets/`): `hit_flash`, `hologram`, `force_field`, `dissolve_burn`, `water`, `smoke` — each `.mat` (authored) + `.filamat` (committed, built).

**Dart** (`examples/dart/examples_lib/lib/src/`):
- `game_effects_shared.dart` — `EffectClock` (Stopwatch-based; `tick()` for hooks, `setTime(t)` for golden stills), `subdividedPlane(width, depth, subX, subZ)` geometry builder, `dummyBillboardQuads(n)` (zeros vertices, indices 0..6n−1 — positions overridden in vertex shader; keep POSITION active per proceduralquad notes)
- `game_effects_hit_flash.dart`, `game_effects_hologram.dart`, `game_effects_force_field.dart`, `game_effects_dissolve_burn.dart`, `game_effects_water.dart`, `game_effects_smoke.dart` — one `setupX(viewer, {required assetsDir})` each

**Modified**:
- `examples/dart/examples_lib/lib/src/registry.dart` — add `'hit_flash'`, `'hologram'`, `'force_field'`, `'dissolve_burn'`, `'water'`, `'smoke'` to `registry`
- `examples/dart/examples_lib/lib/examples_lib.dart` — export the 7 new files
- `materials/build.sh` line 44 — extend `EXAMPLE_MATERIALS` with the 6 names

## Material designs

| Material | Shading / blending | Key uniforms | Technique |
|---|---|---|---|
| **hit_flash** | unlit / additive, depthWrite off, culling none | `flashColor` f4, `progress` f, `flashDuration` f | Quadratic ease-out fade; flat bright tint (swap onto entity — that's the effect). Dart drives 0→1 then restores |
| **hologram** | unlit / transparent, depthWrite off | `tintColor` f4, `time`, `fresnelPower/Strength`, `scanlineCount/Speed/Width`, `glitchAmount` | Fresnel rim + world-Y sin scanlines + subtle vertex X-jitter + flicker; premultiplied out |
| **force_field** | unlit / additive, depthWrite off | `color` f4, `time`, `fresnelPower`, `rippleCount/Speed/Width`, `noiseScale/Strength` | Fresnel rim × animated ripple bands (`sin(angle·N + y·2 − t·speed)`) + hash distortion |
| **dissolve_burn** | unlit / **masked**, depthWrite on | `baseColor` f4, `edgeColor` f4, `threshold`, `edgeWidth`, `edgeIntensity`, `noiseScale`, `time` | 3D value-noise fbm; `discard` below threshold (precedent: translation_axis/depth_sampler); emissive edge glow band at the burn front |
| **water** | lit / transparent, depthWrite off (fallback: unlit + manual specular) | `deepColor`/`shallowColor` f4, `time`, `waveHeight`, 3× (`waveDir` f3, `waveFreq`, `waveSpeed`), `specularIntensity`, `foamThreshold`, `foamColor` f4 | **Vertex**: 3 summed Gerstner waves on subdivided grid (~64×64), finite-difference normals (re-evaluate displaced height at ±ε). **Fragment**: fresnel-driven opacity, depth-proxy color mix, foam on crests, sun glint |
| **smoke** | unlit / additive, depthWrite off, `featureLevel: 1` | `color` f4, `time`, `puffCount`, `riseSpeed`, `expandSpeed`, `swirlAmount`, `baseSize`, `noiseScale/Strength` | Single draw, N quads generated in **vertex shader** from `getVertexIndex()` (proceduralquad pattern); seed = `vid/6` → staggered start, per-puff rise/expand/rotate; fragment: soft radial falloff × 2D fbm scrolling with time, height fade |

Scene composition per effect (camera, dark skybox vs IBL, lights) follows the existing examples in `examples_lib/lib/src/` (`materials_and_lighting.dart`, `lighting_setup.dart`). Additive materials (smoke, force_field, hit_flash) get near-black skyboxes; water/hologram get IBL (`default_env_ibl.ktx`).

## Implementation order

1. **hit_flash** — simplest; proves the whole pipeline end-to-end (`.mat` → matc → loadResource → createMaterial → params → PNG).
2. **hologram** → 3. **force_field** — view-dependent fresnel patterns.
4. **dissolve_burn** — masked blending + discard + fbm.
5. **water** — vertex-shader-heavy + `subdividedPlane` helper.
6. **smoke** — combines every technique; done last.

Then: registry/exports/build.sh wiring (can be incremental per effect), `flutter analyze`, full `make materials` multi-backend build.

## Iteration + verification loop (macOS)

Filament build (matc/resgen source): `/Volumes/T7 1/projects/filament/out/cmake-release/tools` (Ninja layout — binaries at `tools/matc/matc`, `tools/resgen/resgen`; `materials/build.sh` now resolves both layouts). Quote paths in shell — the volume name contains a space.

```bash
export FILAMENT_PATH="/Volumes/T7 1/projects/filament/out/cmake-release/tools"

# compile one material (fast path — Metal only)
"$FILAMENT_PATH/matc/matc" -a metal -o examples/assets/<name>.filamat examples/assets/<name>.mat

# render + capture
cd examples/dart/headless_runner && dart run bin/run_example.dart game_effects_<name> 768 768
open output/game_effects_<name>.png
```

- **Golden stills**: each setup sets a chosen "golden" time (e.g. `setParameterFloat('time', 2.0)`) before returning — parameters persist into the runner's capture; hooks are NOT needed for stills (capture bypasses them; `beforeRender` isn't awaited).
- **Animation sanity**: optional shared helper advances time and captures a small series (set param → `await capture()` → repeat) inside setup.
- **Live hit-flash timeline** (hook-driven swap): snapshot via `asset.getMaterialInstancesAsMap()`, swap to flash instance, animate `progress` in a `registerRequestFrameHook` (real `render()` calls fire hooks), restore via `setMaterialInstancesFromMap()`.
- `dart analyze` in `examples/dart/examples_lib` after each effect; final `FILAMENT_PATH="/Volumes/T7 1/projects/filament/out/cmake-release/tools" make materials` regenerates all-backend `.filamat` (this machine's matc lacks WebGPU, so the webgpu backend is skipped with a warning — rebuild with a `FILAMENT_SUPPORTS_WEBGPU=ON` matc to restore it).

## Risks / fallbacks

- **`blending: masked` + `discard`** on Metal — fallback: `blending: transparent` with alpha=0 instead of discard (or opaque+discard as in depth_sampler).
- **`shadingModel: lit` water double-lighting** — if lit fights the manual baseColor, switch to unlit + manual Blinn-Phong.
- **Smoke dummy geometry** — zeros positions must keep POSITION an active attribute (proceduralquad notes); `puffCount` must match `vertexCount/6`.
- **Gerstner normals** — verify no seams on grid edges; iterate at 32×32 before 64×64.
- **fbm quality (smoke)** — if "cotton balls", add octaves + domain-warped noise input.
- **Smoke vs background** — additive needs near-black skybox (in design).

## Out of scope (follow-ups)

- `game_effects` combined galleryScene for the web gallery; skills doc section; vertex-color shore foam / depth-based water color; overlay-renderable hit flash preserving PBR during flash.

## Worktree

All work is performed in a **local git worktree**, not the main checkout (which carries uncommitted `docs/agent-skills` work):

```bash
git worktree add ~/claude-worktrees/thermion-game-effects -b game-effect-shaders develop
```

(branch name `game-effect-shaders`, based off `develop`.) All changes are additive (new files) plus three small edits (`registry.dart`, `examples_lib.dart`, `build.sh`). The headless runner's repo-relative asset paths (`../../assets`) resolve identically inside the worktree, and `game_effects_plan.md` / compiled `.filamat` are committed from there.
