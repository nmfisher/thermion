# Game-Effect Shaders — guide for contributors

Six example-level Filament materials for common game VFX: **hit flash,
hologram, force field, dissolve/burn, water, smoke**. Everything lives at
example level — no engine changes, no new public API. This document explains
what each effect is meant to read as, how it is built, how to render and
iterate, and where the interesting improvement opportunities are.

Original design rationale: [`game_effects_plan.md`](../game_effects_plan.md)
(repo root). Branch: `game-effect-shaders` (off `develop`).

---

## 1. Where things live

| What | Where |
|---|---|
| Material sources (Filament `.mat` DSL) | `examples/assets/<name>.mat` |
| Compiled materials (committed) | `examples/assets/<name>.filamat` |
| Scene setups (one per effect) | `examples/dart/examples_lib/lib/src/game_effects_<name>.dart` |
| Shared helpers + animators | `examples/dart/examples_lib/lib/src/game_effects_shared.dart` |
| Registry entries (`game_effects_*`) | `examples/dart/examples_lib/lib/src/registry.dart` |
| Headless renderer (stills + video) | `examples/dart/headless_runner/bin/run_example.dart` |
| Material build script | `materials/build.sh` (via `make materials`) |
| Rendered PNGs / MP4s (local, not committed) | `examples/dart/headless_runner/output/` |

Shared demo assets (FlightHelmet, BusterDrone, IBLs) are in `examples/assets/`.

## 2. Environment

- **matc/resgen** come from a local Filament build:
  `FILAMENT_PATH="/Volumes/T7 1/projects/filament/out/cmake-release/tools"`
  (Ninja layout — binaries at `tools/matc/matc`, `tools/resgen/resgen`; the
  volume name contains a space, so quote it).
- This machine's matc has **no WebGPU support** — `make materials` skips the
  `_webgpu`/`_web_combined` variants and the webgpu backend in example
  `.filamat`s with a warning. Committed webgpu blobs are left untouched.
  Rebuilding Filament with `FILAMENT_SUPPORTS_WEBGPU=ON` restores them.
- `dart pub get` is needed **per package** (`examples_lib` and
  `headless_runner`) in a fresh checkout/worktree. The first run of an
  example also runs the native build hook (minutes); later runs are fast
  unless native inputs changed.

## 3. Render and iterate

All commands from `examples/dart/headless_runner/`:

```bash
# one still (deterministic "golden time" baked into the setup)
dart run bin/run_example.dart game_effects_water 768 768

# a video (animators drive time; ffmpeg encodes)
dart run bin/run_example.dart game_effects_water 768 768 --video 6 30

# static analysis
cd ../examples_lib && dart analyze
```

Fast material-only iteration (skip `make materials`, Metal only):

```bash
"$FILAMENT_PATH/matc/matc" -a metal \
  -o examples/assets/<name>.filamat examples/assets/<name>.mat
```

Full multi-backend rebuild: `FILAMENT_PATH=… make materials` from the repo
root.

### Gotchas learned the hard way

- `capture()` **bypasses `registerRequestFrameHook` hooks** (it calls the
  renderer directly), and its `beforeRender` callback is **not awaited**.
  That is why animation for stills/video goes through `effectAnimators`
  (below), and why setups set a fixed golden time directly.
- **Destroying a MaterialInstance still assigned to a renderable
  deadlocks**, and Filament panics if a material is destroyed while
  instances remain alive. The runner therefore `exit(0)`s right after
  saving instead of tearing down.
- Do not put `skinning` in a material's `variantFilter` if it may be applied
  to skinned meshes — BusterDrone is skinned, and the engine aborts with
  `Requested variant (SKN) does not exist`.
- `.mat` `variables` are **float4** (use `.xyz`); fragment-stage `getUV0()`
  is only vec2 — pass extra per-fragment data via a custom `variables`
  channel instead.
- `GeometryUtils.sphere` has **radius 1.0** (not 0.5).
- `viewer.loadIbl()` installs its **own skybox** — call it *before*
  `setDarkSkybox` if you want the dark background to win.
- The colored skybox renders brighter than its linear values suggest
  (default exposure + tonemapping); `setDarkSkybox` uses deliberately tiny
  values (0.004–0.012) for this reason.
- `highlight_effects` hangs in the headless runner (pre-existing, unrelated
  to this work); `load_gltf` and all `game_effects_*` examples work.

## 4. Architecture in one paragraph

A `.mat` source is compiled offline by matc into a self-contained
`.filamat`; the setup loads those bytes with
`FilamentApp.instance!.loadResource(...)` → `createMaterial(bytes)` →
`createInstance()`, sets uniforms via `MaterialInstance.setParameter*`, and
either swaps the instance onto a loaded glTF asset
(`setMaterialInstanceForAll`) or creates geometry with it
(`viewer.createGeometry(Geometry, materialInstances: [...])`). Each setup
also registers a **time animator** — a `Future<void> Function(double t)` in
`effectAnimators` — mapping wall-clock seconds to uniform writes; the
runner's still mode uses the golden time the setup already applied, and its
`--video` mode steps `t` per frame before each capture. Blending modes are
baked into the `.mat` (`add`, `transparent`, `opaque`); everything else is
a uniform you can retune from Dart without recompiling.

## 5. Shared helpers (`game_effects_shared.dart`)

| Helper | Purpose |
|---|---|
| `EffectClock` | Stopwatch-based clock with `tick()` (live hooks) and `setTime(t)` (deterministic stills) |
| `effectAnimators` | per-setup time→uniform closures consumed by the runner's video mode |
| `loadEffectMaterial(viewer, assetsDir, name)` | `.filamat` bytes → `MaterialInstance` |
| `setDarkSkybox(viewer)` | near-black navy skybox for additive scenes |
| `subdividedPlane(w, d, subX, subZ)` | flat XZ grid with normals/UVs (`GeometryUtils.plane` is only 4 verts) |
| `dummyBillboardQuads(n)` | degenerate mesh: 6 zeroed verts per puff; positions generated in the vertex shader |

---

## 6. The effects

### 6.1 hit_flash — `game_effects_hit_flash.dart`, `hit_flash.mat`

**Intent.** Damage feedback: the whole mesh pulses bright, strongest at the
silhouette, then fades — the classic "I got hit" flash. In the video it
repeats every 2.4s (0.55s flash, then the normal PBR look until the next
hit).

**Build.** Unlit + **additive** blend, depthWrite off. The vertex stage
passes `worldNormal` via a `surfaceNormal` variable; the fragment computes a
quadratic ease-out intensity from `progress` and multiplies by a fresnel rim
(`pow(1 - |n·v|, 2)`), so the flash reads as a shockwave wrapping the
silhouette rather than a flat tint. The flash is a **material-instance
swap**: snapshot originals (`getMaterialInstancesAsMap`), swap in the flash,
animate `progress` 0→1, restore (`setMaterialInstancesFromMap`). The
swap/restore state machine lives in the animator closure.

**Uniforms.** `flashColor` float4 (default warm orange 1.0/0.3/0.1),
`progress` float (0 = full flash, 1 = gone). Flash duration and hit period
are Dart constants (0.55s / 2.4s).

**Tuning.** Brighter flash → raise the `0.35` floor or lower the rim
exponent in the `.mat`; snappier feel → shorter `flashDuration` constant or
cubic ease; colored per damage type → just change `flashColor` at runtime.

**Limitations / ideas.** The swap replaces the PBR look during the flash —
an *overlay* pass (duplicate renderable sharing the mesh, additive on top)
would keep the original visible; a localized flash (pass an impact point +
world-space distance falloff) would read even better.

### 6.2 hologram — `game_effects_hologram.dart`, `hologram.mat`

**Intent.** Sci-fi projection: translucent cyan shell, glowing rim,
scanlines sweeping upward, occasional horizontal glitch bands, subtle
flicker.

**Build.** Unlit + **transparent** blend (premultiplied output), depthWrite
off, double-sided so the back shell adds depth. Fresnel rim brightens the
silhouette; scanlines are `sin(worldY * count − t * speed)` shaped by
`smoothstep`; the vertex shader offsets `worldPosition.x` inside narrow
moving Y-bands (`step(0.97, fract(y * 6 + t * 0.7))`) for glitch shear.
Applied to the skinned BusterDrone via material swap.

**Uniforms.** `tintColor` (0.2, 0.85, 1.0), `time`, `fresnelPower` 2.5,
`fresnelStrength` 0.9, `scanlineCount` 40, `scanlineSpeed` 3.0,
`glitchAmount` 0.015.

**Tuning.** The color must stay saturated — tonemapping desaturates brights,
so the shader scales the tint by fresnel instead of mixing toward white
(earlier version mixed 25% white and read cream). More aggressive glitch →
raise `glitchAmount` or widen the band threshold.

**Limitations / ideas.** A materialization wipe (discard below a noise-edged
Y threshold that rises with time) would give a "projector boot-up"; chromatic
fringing on the rim; scanline Moiré at high `scanlineCount` on small meshes.

### 6.3 force_field — `game_effects_force_field.dart`, `force_field.mat`

**Intent.** A shield bubble around a generator core: dark see-through
interior, bright fresnel silhouette rim, hexagonal energy lattice, a ripple
sweeping pole-to-pole.

**Build.** Unlit + **additive**, depthWrite off, on a 48×64 sphere scaled to
radius 1.2 (`GeometryUtils.sphere` is radius 1.0). The hex lattice is
approximated by two overlapping skewed grids over longitude/latitude
(`min` of two `abs(fract − 0.5)` fields) — cheap, seamless enough at this
density. The overall amplitude multiplies by fresnel so the lattice
concentrates near the rim; a `sin(latitude * rippleCount − t * speed)` band
sweeps the surface. A plain white 0.4-scale cube sits inside as the core.

**Uniforms.** `baseColor` (0.4, 0.7, 1.0), `time`, `fresnelPower` 2.0,
`rippleCount` 6, `rippleSpeed` 3.0, `hexScale` 9.0, `hexStrength` 0.9.

**Tuning.** Crisper cells → higher `hexScale` or sharpen the two
`smoothstep`s; stronger shield presence → raise the leading `1.8` amplitude
or the `0.3` interior floor.

**Limitations / ideas.** The pseudo-hex stretches at the poles — a real
Voronoi or cube-map-projected lattice would be uniform; an impact response
(uniform hit position + expanding bright ring) is the obvious next feature;
`TransparencyMode.TWO_PASSES_TWO_SIDES` could give the back shell proper
presence.

### 6.4 dissolve_burn — `game_effects_dissolve_burn.dart`, `dissolve_burn.mat`

**Intent.** Death/teleport: the mesh is eaten away by irregular noise while
the receding front glows like embers.

**Build.** Unlit + **opaque** with `discard` below the threshold (keeps
depth-writing correct, unlike alpha blending). 3D value noise (hash +
trilinear smoothstep interpolation) driven through 3-octave fbm over world
position, slowly scrolling in Z via `time`. Fragments within `edgeWidth` of
the threshold get an additive emissive term in `edgeColor`, scaled by
`edgeIntensity` — the glowing burn front. The video ramps `threshold`
0→0.95 over a 3.5s loop.

**Uniforms.** `baseColor` (0.35, 0.3, 0.28 — charred), `edgeColor`
(1.0, 0.45, 0.1), `threshold` 0.45, `edgeWidth` 0.08, `edgeIntensity` 2.5,
`noiseScale` 4.0, `time`.

**Tuning.** Chunkier dissolution → lower `noiseScale` (or drop an fbm
octave); hotter edge → raise `edgeIntensity`/narrow `edgeWidth`; slower
creep → shrink the Z-scroll factor (currently 0.15).

**Limitations / ideas.** Noise is sampled in **world** space, so a moving
model slides through the pattern — switching to `getPosition()` (object
space) pins the burn to the mesh. Natural follow-ons: rising ember sparks
(reuse the smoke billboard system with an upward, shrinking preset) and ash
fall.

### 6.5 water — `game_effects_water.dart`, `water.mat`

**Intent.** Stylized game water: rolling swells, deep color looking down,
sky-reflecting grazing angles, sun glints, foam on crests.

**Build.** The heaviest vertex shader: three summed **Gerstner waves**
(height + horizontal choppiness, directions hard-coded normalized pairs at
1×/2.1×/3.7× frequency) displace a 12×12-unit, 96×96-vertex
`subdividedPlane`; normals come from finite differences (re-evaluating the
displaced surface at ±0.08 in X and Z — `cross(sz, sx)` points up). The
fragment shader mixes `deepColor`→`skyColor` by fresnel^3, adds a Blinn-Phong
sun glint against `sunDirection`, and puts foam on crests gated by drifting
2D fbm. Unlit + **transparent**, depthWrite on, double-sided.

**Uniforms.** `deepColor` (0.02, 0.09, 0.14, 0.92), `skyColor`
(0.35, 0.55, 0.75), `foamColor` (0.92, 0.97, 1.0), `sunDirection`
(−0.45, −0.8, −0.35), `time`, `waveHeight` 0.18, `waveFrequency` 1.6,
`waveSpeed` 1.5, `foamAmount` 0.55, `specularPower` 140,
`specularIntensity` 1.4. Camera at (0, 2.2, 5).

**Tuning.** Stormier → raise `waveHeight`/`waveFrequency` (watch grid
density: >0.25 height on 96×96 starts to facet); milder glints → lower
`specularIntensity` or soften `specularPower`. The Gerstner directions/
frequency ratios are hard-coded in the `.mat` vertex block — parameterizing
them is a straightforward first improvement.

**Limitations / ideas.** "Sky reflection" is a flat color — the big upgrade
is real environment reflections (switch to `shadingModel : lit` with
`reflectionFactor`, or sample an IBL manually) or a planar reflection via a
render target. Depth-based color/soft shore foam needs a depth pre-pass or
shore-distance vertex attribute. A high-frequency normal-map detail layer
(two scrolled noise normals) would add shimmer without more geometry.

### 6.6 smoke — `game_effects_smoke.dart`, `smoke.mat`

**Intent.** A living smoke column: puffs spawn, rise, expand, swirl, and
fade — one draw call, no particle system (the vendored Filament has none).

**Build.** The cleverest bit is fully **GPU-generated geometry**: the CPU
mesh is `dummyBillboardQuads(24)` — 144 zeroed vertices whose only job is
keeping POSITION bound. The vertex shader reconstructs everything from
`getVertexIndex()`: `vid / 6` is the puff, `vid % 6` picks from constant
quad corner/UV tables; per-puff hash seeds stagger lifetime and vary
rise/expand/swirl rates; `mod(time − seed*lifetime, lifetime)` loops each
puff independently. Billboards face the camera by offsetting the puff's
world center along the **rows of `getViewFromWorldMatrix()`** (camera
right/up in world space — assigning view-space coords to `worldPosition`
would double-transform). The fragment shader shapes each quad with a squared
radial falloff × drifting fbm, and eases alpha in/out over the lifetime
(fade rides the custom `quadData` variable's Z, since fragment `getUV0()`
is vec2). Unlit + **additive**, depthWrite off — additive sidesteps
billboard sorting entirely (overlaps brighten instead of z-fighting).

**Uniforms.** `baseColor` (0.45, 0.47, 0.52), `time`, `puffCount` 24 (must
match the dummy geometry), `riseSpeed` 0.45, `expandSpeed` 0.25,
`swirlAmount` 1.2, `baseSize` 0.3, `noiseScale` 3.5, `lifetime` 4.0.
Camera at (0, 1.4, 4) focused slightly above the column base.

**Tuning.** Denser column → more puffs (bump both the Dart constant and
`puffCount`); wind → add a constant XZ drift to `center`; darker smoke →
lower `baseColor` and consider `blending : transparent` with sorted
drawing for a sootier look.

**Limitations / ideas.** No depth-fade (puffs cut hard against intersecting
geometry) — the proper fix is soft particles sampling the depth buffer
(see the `render_targets` example for depth access). The fbm is 3 octaves of
value noise; domain warping would remove the slightly "cottony" look. Fog
and rain presets are parameter tweaks away.

---

## 7. Suggested roadmap

1. **hit_flash overlay pass** (keep PBR visible) + impact-point localization.
2. **water**: IBL/lit reflections, depth-based color, shore foam.
3. **smoke**: soft-particle depth fade; true alpha-blended variant.
4. **force_field**: hit-point ripple response; better lattice.
5. **dissolve_burn**: object-space noise; ember sparks via the smoke system.
6. **hologram**: materialization wipe.
7. Cross-cutting: a `game_effects` composite galleryScene for the web
   gallery; web verification (COOP/COEP, real Chrome) once a WebGPU matc is
   available; interactive parameter playground.

## 8. Commit map (as of writing)

- `d5e68e060` — `fix: make materials/build.sh work on macOS`
- `7061362fb` — the six materials + example setups + plan doc
- `7c976d39e` — `effectAnimators` + `--video` runner mode + hit_flash lighting
