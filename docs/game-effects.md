# Game-Effect Shaders — guide for contributors

Ten example-level Filament materials for common game VFX: **hit flash,
hologram, force field, dissolve/burn, water, smoke, fire, lava, shockwave,
shore waves**. Everything lives at
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
# one still. By default stills capture the animators' t=0 state; --time
# picks a specific point in the animation (each setup's intended "golden"
# time is noted in §6):
dart run bin/run_example.dart game_effects_water 768 768 --time 1.7

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

- **Vertex-stage `worldPosition` must only be displaced additively.**
  `material.worldPosition.xyz += offset` works; any form that *replaces*
  the position (or cancels it, e.g. `+= target - worldPosition.xyz`) is
  silently lost through this matc/Filament/Metal pipeline — the draw
  renders nothing (or flickers, depending on what the optimizer keeps).
  The smoke billboards therefore keep their CPU-side positions near the
  origin and the shader adds the full animated center + camera-facing
  corner offsets; the water grid adds its Gerstner displacement the same
  way. Custom `variables` (e.g. `surfaceNormal`, `objectPos`) do not have
  this problem — only `worldPosition` does.
- **`setParameterFloat*` on a uniform that is not declared in the `.mat`
  hard-crashes the native layer** (`PreconditionPanic: uniform named "…"
  not found` in `getFieldInfo`), killing the process mid-setup. If a
  render comes out as bare skybox with no geometry and the log ends
  abruptly, check for a Dart↔`.mat` parameter-name mismatch first.
- **Still mode runs the animators at the requested `--time`** (default 0),
  which overwrites any uniform values the setup applied — the "golden
  time" a setup sets on its instances only survives until the animator
  call. Pass `--time` explicitly to capture the state you want.
- `capture()` **bypasses `registerRequestFrameHook` hooks** (it calls the
  renderer directly), and its `beforeRender` callback is **not awaited**.
  That is why animation for stills/video goes through `effectAnimators`
  (below), and why stills need `--time`.
- **Destroying a MaterialInstance still assigned to a renderable
  deadlocks**, and Filament panics if a material is destroyed while
  instances remain alive. The runner therefore `exit(0)`s right after
  saving instead of tearing down.
- Do not put `skinning` in a material's `variantFilter` if it may be applied
  to skinned meshes — BusterDrone is skinned, and the engine aborts with
  `Requested variant (SKN) does not exist`.
- `.mat` `variables` are **float4** (use `.xyz`); fragment-stage `getUV0()`
  is only vec2 — pass extra per-fragment data via a custom `variables`
  channel instead. Vertex-stage `getPosition()` is **float4** (use `.xyz`).
- `GeometryUtils.sphere` has **radius 1.0** (not 0.5).
- `viewer.loadIbl()` installs its **own skybox** — call it *before*
  `setDarkSkybox` if you want the dark background to win.
- The colored skybox renders brighter than its linear values suggest
  (default exposure + tonemapping); `setDarkSkybox` uses deliberately tiny
  values (0.004–0.012) for this reason. The same tonemapping is why the
  FlightHelmet under `default_env_ibl.ktx` blows out to pure white — the
  hit-flash scene uses a dim directional light instead so the additive
  flash keeps contrast.
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
runner's still mode applies the animators at `--time` (default 0) before
capturing, and its `--video` mode steps `t` per frame before each capture.
Blending modes are baked into the `.mat` (`add`, `transparent`,
`opaque`); everything else is a uniform you can retune from Dart without
recompiling.

## 5. Shared helpers (`game_effects_shared.dart`)

| Helper | Purpose |
|---|---|
| `EffectClock` | Stopwatch-based clock with `tick()` (live hooks) and `setTime(t)` (deterministic stills) |
| `effectAnimators` | per-setup time→uniform closures consumed by the runner's still (`--time`) and video modes |
| `loadEffectMaterial(viewer, assetsDir, name)` | `.filamat` bytes → `MaterialInstance` |
| `setDarkSkybox(viewer)` | near-black navy skybox for additive scenes |
| `subdividedPlane(w, d, subX, subZ)` | flat XZ grid with normals/UVs (`GeometryUtils.plane` is only 4 verts) |
| `dummyBillboardQuads(n)` | near-degenerate mesh: 6 verts per puff placed at a small deterministic scatter (valid bounding volume, treatable as zero by the shader — see the worldPosition gotcha) |

---

## 6. The effects

### 6.1 hit_flash — `game_effects_hit_flash.dart`, `hit_flash.mat`

**Intent.** Damage feedback: a white-hot flash at the impact point with a
shockwave ring expanding outward across the mesh while a rim-weighted body
flash decays — the classic "I got hit" read. In the video a hit lands every
2.4s (0.55s flash, rotating through three impact points on the
camera-facing side, then the normal PBR look until the next hit).

**Build.** Unlit + **additive** blend, depthWrite off. The vertex stage
passes `worldNormal` via a `surfaceNormal` variable; the fragment computes
a cubic ease-out intensity from `progress`, a fresnel rim
(`pow(1 - |n·v|, 2)`), and an expanding gaussian **shockwave ring** at
`ringR = progress^0.7 * 1.3` world units from `hitPoint`. The flash color
mixes white-hot → `flashColor` over the first 55% of the flash. The flash
is a **material-instance swap**: snapshot originals
(`getMaterialInstancesAsMap`), swap in the flash, animate `progress` 0→1,
restore (`setMaterialInstancesFromMap`). The scene is lit by a **dim
directional light only** (no IBL) so the additive flash keeps contrast —
under the default IBL the helmet saturates to white and swallows the ring.

**Uniforms.** `flashColor` float4 (default orange 1.0/0.36/0.1), `hitPoint`
float3 (world), `progress` float (0 = impact instant, 1 = finished). Flash
duration, hit period and the impact-point list are Dart constants.

**Tuning.** Snappier ring → raise the `16.0` gaussian width or `1.55` ring
gain in the `.mat`; stronger directionality → move `hitPoint`; colored per
damage type → change `flashColor` at runtime. Golden still time: `--time
0.18`.

**Limitations / ideas.** The swap replaces the PBR look during the flash —
an *overlay* pass (duplicate renderable sharing the mesh, additive on top)
would keep the original visible. A screen-space chromatic pulse on impact
and a decal-style scorch mark are natural follow-ons.

### 6.2 hologram — `game_effects_hologram.dart`, `hologram.mat`

**Intent.** Sci-fi projection: translucent cyan shell with a readable
silhouette, fine scanlines sweeping upward, a bright scanning band
traveling up the model, occasional glitch bands that shear and split
chromatically, subtle flicker.

**Build.** Unlit + **transparent** blend (premultiplied output),
depthWrite off, double-sided so the back shell adds depth. The fragment
combines: a fresnel rim kept saturated (brighten via alpha, never mix
toward white — tonemapping desaturates brights); thin bright scanlines
(`smoothstep(0.30, 0.95, sin(y·count − t·speed))`); a gaussian **scanning
band** sweeping y over ~4.5s; gated **glitch bands** (~35% of 2.5Hz time
slices) that shear `worldPosition.x` in the vertex stage and add a
brightness pop + blue/red channel split in the fragment (the gate hash is
duplicated verbatim in both stages so they stay in sync); and a
two-frequency flicker. Applied to the skinned BusterDrone via material
swap.

**Uniforms.** `tintColor` (0.2, 0.85, 1.0), `time`, `fresnelPower` 2.5,
`fresnelStrength` 1.1, `scanlineCount` 70, `scanlineSpeed` 4.0,
`glitchAmount` 0.05. Golden still time: `--time 2.0` (band mid-model).

**Tuning.** More aggressive glitch → raise `glitchAmount` or lower the
`0.62` gate threshold; denser lines → higher `scanlineCount` (watch Moiré
on small meshes); the sweep speed is the `0.22` factor on `t`.

**Limitations / ideas.** A materialization wipe (discard below a
noise-edged Y threshold that rises with time) would give a "projector
boot-up"; chromatic fringing keyed on the fresnel; a faint projector cone
or ground disc as extra geometry.

### 6.3 force_field — `game_effects_force_field.dart`, `force_field.mat`

**Intent.** A shield bubble around a generator core: dark see-through
interior, bright fresnel silhouette with a hot rim lip, a hexagonal energy
lattice that shimmers and twinkles per cell, and expanding impact ripples
from periodic hits.

**Build.** Unlit + **additive**, depthWrite off, on a 48×64 sphere scaled
to radius 1.2. The lattice is a **proper hex distance function** over
longitude/latitude (columns offset half a cell, `max` of the two edge
planes), with a per-cell wobble that de-regularizes the grid (kills the
moiré the original two-grid `min` approximation suffered) and a pole fade
where the parametrization stretches. Energy flows along the lines
(`sin(hp.y·12 − t·2.2)`), cells twinkle with per-cell phase hashes, and
the rim gets a second `pow(…, 8)` hot lip. **Impact response:** the Dart
animator fires a hit every 1.9s from a rotating list of directions;
`hitAge` drives a gaussian ring expanding over the sphere's angular
distance from `hitDirection`, mixing the color toward white as it passes.
A plain white 0.4-scale cube sits inside as the core.

**Uniforms.** `baseColor` (0.30, 0.55, 1.0), `time`, `fresnelPower` 2.2,
`hexScale` 9.0, `hexStrength` 1.1, `hitDirection` float3 (unit),
`hitAge` float (seconds since hit). Golden still time: `--time 2.0`.

**Tuning.** Crisper cells → higher `hexScale` or tighten the `0.40–0.49`
smoothstep; stronger shield presence → the `1.35` rim gain or `0.10`
interior floor; ripple speed/decay → the `2.6` and `1.4` factors on
`hitAge`.

**Limitations / ideas.** The lattice still stretches near the poles — a
cube-map-projected or Voronoi lattice would be uniform;
`TransparencyMode.TWO_PASSES_TWO_SIDES` could give the back shell proper
presence; multiple simultaneous ripples (a small ring buffer of hit
directions/ages) for sustained fire.

### 6.4 dissolve_burn — `game_effects_dissolve_burn.dart`, `dissolve_burn.mat`

**Intent.** Death/teleport: the mesh is eaten away by irregular noise
while the receding front burns — white-hot at the very edge through orange
to deep red, with charred ground ahead of the front and occasional ember
sparks.

**Build.** Unlit + **opaque** with `discard` below the threshold (keeps
depth-writing correct, unlike alpha blending). The noise is 4-octave fbm
sampled in **object space** (pinned to the mesh — a moving model slides
*through* the burn, the burn never slides across the model), slowly
scrolling in Z via `time`. The fragment computes the normalized distance
`e` from the threshold over `edgeWidth` and builds a three-stop
**temperature gradient** (white-hot → `edgeColor` orange → deep red)
with combustion flicker; ahead of the front the surface darkens through a
`charr` gradient toward near-black with a faint red pre-glow, and rare
twinkling ember sparks sit right at the front. The video ramps
`threshold` 0→0.95 over a 3.5s loop.

**Uniforms.** `baseColor` (0.16, 0.13, 0.12 — char), `edgeColor`
(1.0, 0.45, 0.1), `threshold` 0.5, `edgeWidth` 0.13, `edgeIntensity` 3.0,
`noiseScale` 3.4, `time`. Golden still time: `--time 1.2`.

**Tuning.** Chunkier dissolution → lower `noiseScale`; hotter edge → raise
`edgeIntensity`/narrow `edgeWidth`; wider charred apron → raise the `2.5`
multiplier on `edgeWidth` in the `charr` smoothstep.

**Limitations / ideas.** Rising ember sparks (reuse the smoke billboard
system with an upward, shrinking preset) and ash fall are natural
follow-ons; a directional burn (bias the threshold by a world-space
gradient) would read as spreading fire rather than uniform decay.

### 6.5 water — `game_effects_water.dart`, `water.mat`

**Intent.** Stylized game water: rolling swells with visible crest/trough
relief, deep color looking down, sky-reflecting grazing angles, a sun
glitter path with real sparkle, whitecaps on the choppiest crests, and a
haze that melts the plane edge into the horizon.

**Build.** The heaviest vertex shader: four summed **Gerstner waves**
(~1×/2×/4×/7× frequency, rotated directions, per-wave steepness) displace a
16×16-unit, 200×200-vertex `subdividedPlane` — as a pure `+=` displacement
(see the worldPosition gotcha). Normals come from finite differences, and
the same differences feed **two foam inputs** packed into the variables'
`.w` channels: crest height and horizontal compression (where Gerstner
pinch concentrates is exactly where whitecaps live). The fragment shader
adds **three scrolled fbm detail-normal layers** (swell-ripple down to
near-pixel frequency — the fine layers are what make the glitter actually
sparkle, attenuated with distance to avoid aliasing), Schlick fresnel
deep→sky mixing, sun-side shading plus a crest-height lightening (the
crest/trough relief), a backlit subsurface glow on crests toward the sun,
dual-lobe sun glitter (broad sheen + tight fresnel-weighted sparkle), foam
from crest+chop broken by two noise octaves (which also flattens the
normals — foam is diffuse), and a distance haze fade. Unlit +
**transparent**, depthWrite on, double-sided.

**Uniforms.** `deepColor` (0.008, 0.058, 0.090, 0.94), `skyColor`
(0.36, 0.52, 0.72), `foamColor` (0.94, 0.98, 1.0), `sunDirection`
(−0.55, −0.35, −0.75), `time`, `waveHeight` 0.36, `waveFrequency` 1.25,
`waveSpeed` 1.6, `foamAmount` 1.0, `specularPower` 520 (tight-lobe),
`specularIntensity` 4.2, `detailStrength` 1.0, `sssStrength` 0.9. Camera
at (0, 1.8, 5). Golden still time: `--time 1.7`.

**Tuning.** Stormier → raise `waveHeight`/`waveFrequency` (watch grid
density); milder glints → lower `specularIntensity`; calmer detail →
lower `detailStrength`. The Gerstner directions/frequency ratios are
hard-coded in the `.mat` vertex block — parameterizing them is a
straightforward first improvement.

**Limitations / ideas.** "Sky reflection" is a flat color — the big upgrade
is real environment reflections (switch to `shadingModel : lit` with
`reflectionFactor`, or sample an IBL manually) or a planar reflection via a
render target. Depth-based color/soft shore foam needs a depth pre-pass or
shore-distance vertex attribute. Wispy foam streaks along wave faces would
need flow-map-style advection of the foam noise.

### 6.6 smoke — `game_effects_smoke.dart`, `smoke.mat`

**Intent.** A living smoke column: puffs spawn small and bright at the
base, rise, stretch vertically, spiral outward and bend with the wind while
thinning to wisps — one draw call, no particle system (the vendored
Filament has none).

**Build.** The cleverest bit is fully **GPU-generated geometry**: the CPU
mesh is `dummyBillboardQuads(40)` — 240 vertices sitting at a small
deterministic scatter near the origin (near-zero so the shader can treat
its displacement as purely additive, per the worldPosition gotcha, but
non-degenerate so the renderable's bounding volume keeps frustum culling
well-behaved). The vertex shader reconstructs everything from
`getVertexIndex()`: `vid / 6` is the puff, `vid % 6` picks from constant
quad corner/UV tables; per-puff hash seeds stagger lifetime and vary
rise/stretch/spin/brightness rates; `mod(time − seed·lifetime, lifetime)`
loops each puff independently. The puff center is a **cone + spiral +
wind bend** (`age·0.34` spiral radius, `age²·0.45` downwind drift) — this
is what makes it read as a plume rather than a vertical line of blobs.
Billboards face the camera by offsetting along the **rows of
`getViewFromWorldMatrix()`** (camera right/up in world space) — always as
additive displacements. The fragment shader shapes each quad with a
squared radial falloff × **domain-warped fbm** (warping removes the cottony
single-octave look), eases alpha in/out over the lifetime, and carries
age/brightness in the custom `quadData` variable's zw channels (fragment
`getUV0()` is vec2). Young puffs get a faint warm cast as if lit from the
fire below. Unlit + **additive**, depthWrite off — additive sidesteps
billboard sorting entirely (overlaps brighten instead of z-fighting).

**Uniforms.** `baseColor` (0.34, 0.36, 0.42), `time`, `puffCount` 40
(informational — must match the Dart constant you pass to
`dummyBillboardQuads`), `riseSpeed` 0.5, `expandSpeed` 0.22,
`swirlAmount` 1.1, `baseSize` 0.35, `noiseScale` 3.2, `lifetime` 4.5.
Camera at (0.35, 1.3, 3.6) focused slightly above the column base. Golden
still time: `--time 4.6` (fully populated column).

**Tuning.** Denser column → more puffs (bump the Dart constant —
`puffCount` is informational only); wind → the `age·age·0.45` term;
darker/sootier smoke → lower `baseColor` and consider `blending :
transparent` with sorted drawing; the noise warp strength is the `1.7`
multiplier on `warp`.

**Limitations / ideas.** No depth-fade (puffs cut hard against intersecting
geometry) — the proper fix is soft particles sampling the depth buffer
(see the `render_targets` example for depth access). Fog and rain presets
are parameter tweaks away.

### 6.7 fire — `game_effects_fire.dart`, `fire.mat`

**Intent.** A campfire-style flame: clustered tongues licking upward from a
bright base, white-hot through yellow and orange to red tips, with ember
sparks rising out of it.

**Build.** One draw call on `dummyBillboardQuads(36)`: the first 16 quads
are flame tongues, the remaining 20 are embers — the vertex shader branches
on `quadIndex < flameCount`. Tongues stand on their base (the corner table
maps y to [0,1]), each with its own height/flicker phase so tips never move
in lockstep, clustered tightly at the origin and sheared by wind
proportionally to height. The fragment shader scrolls domain-warped fbm
**downward** in noise-space (so its features read as licking upward), tapers
the width with height, lets the noise eat into the tip, and colors the
resulting heat field through a blackbody ramp (deep red → orange → yellow →
white). Embers rise from inside the flame with a sinusoidal wobble,
shrinking and cooling white → red, as soft squared dots. Unlit + **additive**.

**Uniforms.** `time`, `flameCount` 16, `emberCount` 20, `flameHeight` 1.15,
`flameWidth` 0.40, `noiseScale` 3.0, `scrollSpeed` 2.4, `windLean` 0.18,
`emberLifetime` 1.7. The counts must match the geometry passed to
`dummyBillboardQuads`. Golden still time: `--time 4.6`.

**Tuning.** Taller/lazier flames → raise `flameHeight`, lower
`scrollSpeed`; windier → `windLean`; hotter core → stretch the ramp stops
in the `.mat`.

**Limitations / ideas.** Layer the existing smoke system on top with an
upward preset for a smoky column; a flickering point light (driven from
Dart with the same fbm phase) lighting a surrounding scene would sell it
further.

### 6.8 lava — `game_effects_lava.dart`, `lava.mat`

**Intent.** A molten field: dark drifting crust with a network of glowing
cracks, hottest (yellow-white) in the fast-flowing centers.

**Build.** A vertex-displaced `subdividedPlane` (additive displacement
only): three slow drifting sine lumps form the crust swell, with
finite-difference normals. The fragment shader is an **inverted dissolve**:
a slowly drifting, domain-warped fbm crust field, where it dips below
threshold the molten interior shows through — modulated by a second,
fast-flowing fbm so the crack interiors visibly course. Temperature ramp
deep red → orange → yellow-white keyed on crack intensity; the crust is
very dark red-brown (exposure + ACES lift darks heavily — see the skybox
gotcha — so both crust and ramp stops are pushed darker/more saturated than
the intended read) with noise grain, gentle top-light shading and a red
reheat apron near cracks. Opaque, edge melts into the background.

**Uniforms.** `time`, `glowIntensity` 1.5, `crustScale` 1.0, `flowSpeed`
0.5, `swellHeight` 0.10. Golden still time: `--time 3.0`.

**Tuning.** More/denser cracks → lower the two smoothstop constants in
`crack`; faster crust drift → the `0.05/0.04` time factors; more violent
swell → `swellHeight`.

**Limitations / ideas.** Ember/smoke vents on the brightest cracks (reuse
the fire/smoke rigs); heat-haze refraction needs post-processing this
example level doesn't have.

### 6.9 shockwave — `game_effects_shockwave.dart`, `shockwave_ground.mat` + `shockwave_dome.mat`

**Intent.** An ultimate-style energy pulse: a sharp ring races out across
the ground while an energy dome expands out of the epicenter — one
coordinated event every 2.2s.

**Build.** Two materials on two geometries. The **ground ring** (flat
plane, additive): one wave per period, `waveR = age·speed`; a sharp
leading-edge gaussian with a softer wake behind it plus a trailing
secondary ring, broken into arcs by an angular fbm and roughened by churn
noise advected outward, fading with age. The **dome** (unit sphere, scaled
by the Dart animator to track the ring front): fresnel body + hot rim lip,
upward-flowing shimmer noise, exponential age fade — its **lower hemisphere
is discarded at y=0**, so the equator cut sits exactly on the ground plane
and the dome reads as rising out of it.

**Uniforms.** Ground: `time`, `period` 2.2, `waveSpeed` 3.6. Dome:
`baseColor`, `time`, `age` (seconds since pulse). The dome's scale is set
per-frame by the animator (`0.15 + age·waveSpeed·0.78`). Golden still
time: `--time 0.9`.

**Tuning.** Faster pulse → `waveSpeed`; sharper ring → the `3.4` gaussian
width; longer-lived dome → the `1.3` fade rate.

**Limitations / ideas.** Trigger the pulse from an actual game event (the
animator is trivially rewirable); ground scorch would want an alpha-blended
decal pass; multiple overlapping waves need a per-wave uniform array or a
ring buffer of ages.

### 6.10 shore_waves — `game_effects_shore_waves.dart`, `shore_waves.mat` + `sand.mat`

**Intent.** Waves arriving at a beach: swells shoal (grow) as they reach
the shallows, whitecap on the way in, then break into a foam line that
pulses along the shoreline and washes up onto wet sand.

**Build.** The trick that keeps this cheap: **the demo owns the scene
geometry, so the shoreline is an analytic function** — `z_shore(x) =
1.2 + 0.35·sin(0.6x + 1) + 0.15·sin(1.7x)` — and "shore distance" is just
that minus world z (no depth texture). The vertex shader runs three
Gerstner swells **traveling toward the shore** with a per-vertex amplitude:
growing through the shoaling zone, collapsing past the break. The fragment
shader mixes deep teal → turquoise by shore proximity, adds Schlick
fresnel, sun-side shading, two detail-normal layers and a glitter path
toward the beach. Foam has three sources: whitecaps (crest + pinch, as in
water), the **breaking line** — a gaussian band around the shoreline,
pulsing with swell arrival, textured with two anisotropic noise octaves
stretched along the shore — and a faint wash residue further up. The water
alpha-fades past the shoreline into a **sand plane** (`sand.mat`) that
reuses the same shoreline function for its wet band, so waterline and beach
stay in lockstep. Water: unlit + transparent, depthWrite on.

**Uniforms (water).** `deepColor` (0.012, 0.10, 0.15), `shallowColor`
(0.06, 0.50, 0.52), `skyColor` (0.40, 0.55, 0.68), `foamColor`
(0.94, 0.98, 1.0), `sunDirection` (−0.45, −0.35, −0.8), `time`,
`waveHeight` 0.30, `waveFrequency` 1.35, `waveSpeed` 1.5, `foamAmount` 1.0,
`detailStrength` 1.0. Sand: `sandColor` (0.76, 0.66, 0.50), `time`.
Camera at (0, 2.6, −5.6) looking shoreward. Golden still time:
`--time 2.0`.

**Tuning.** Bigger surf → `waveHeight`/`waveFrequency`; wider breaker →
the `0.70` band width; slower sets → the `2.4` pulse rate; the shoreline
curve itself is the `shoreZ` function (must stay identical in both `.mat`s).

**Limitations / ideas.** The swells don't actually refract/curve toward
the beach contour (real wave optics); wash-up is a fixed band rather than
advancing/retreating with each set; a swash line that runs up the sand
would need the sand material to animate its wet band with the same pulse
phase.

---

## 7. Suggested roadmap

1. **hit_flash**: overlay pass (keep PBR visible during the flash);
   screen-space chromatic pulse on impact.
2. **water**: IBL/lit reflections, depth-based color, shore foam,
   flow-advection for wispy foam streaks.
3. **smoke**: soft-particle depth fade; true alpha-blended variant.
4. **force_field**: multiple simultaneous ripples; cube-map-projected
   lattice.
5. **dissolve_burn**: directional burn gradient; ember sparks via the
   smoke system.
6. **hologram**: materialization wipe; projector cone/disc geometry.
7. **fire**: smoke cap via the smoke rig; flickering scene light driven
   from Dart.
8. **shockwave**: event-triggered pulses; overlapping waves.
9. **shore_waves**: wave refraction toward the beach contour; advancing
   swash line on the sand.
10. New effects from the same toolkit: lightning (ridged-noise bolt on a
    tall quad), frost/ice creep (worley inverse-dissolve), cloth/flags,
    grass, portal disc, heal circles.
11. Cross-cutting: a `game_effects` composite galleryScene for the web
    gallery; web verification (COOP/COEP, real Chrome) once a WebGPU matc is
    available; interactive parameter playground.

## 8. Commit map (as of writing)

- `d5e68e060` — `fix: make materials/build.sh work on macOS`
- `7061362fb` — the six materials + example setups + plan doc
- `7c976d39e` — `effectAnimators` + `--video` runner mode + hit_flash lighting
- (this branch) — full visual overhaul: 4-wave water with detail normals,
  foam from crest+chop, glitter path and horizon haze; smoke column with
  spiral/wind structure and domain-warped turbulence; hologram scanlines,
  sweep band and gated glitch; hex force field with hit ripples;
  two-tone dissolve front with char gradient; hit-flash shockwave ring;
  `--time` still mode; the additive-worldPosition fix that made GPU
  billboards render reliably.
