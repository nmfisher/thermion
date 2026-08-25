# Game-Effect Shaders — guide for contributors

Eighteen example-level Filament effects for common game VFX: **hit flash,
hologram, force field, dissolve/burn, water, smoke, fire, lava, shockwave,
shore waves, wetness, crystal/ice, snow accumulation, damage decals, portal,
electricity, invisibility cloak, and an energy-weapon suite**. Everything lives at
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
- **Fragment-stage `getWorldPosition()` is VIEW-relative on this pipeline**
  (and `getWorldFromModelMatrix()` returns garbage for `createGeometry`
  meshes). Never do world-space math on it. Instead pipe position through
  a custom `variables` channel written in the vertex stage:
  - created geometry at the identity transform (planes): `material.worldPos.xyz = getPosition().xyz;`
  - transformed assets (the helmet): `material.worldPos.xyz = (getWorldFromModelMatrix() * vec4(getPosition().xyz, 1.0)).xyz;`
  - when only a fresnel is needed (the shockwave dome), skip position
    entirely: transform the normal by `getViewFromWorldMatrix()` in the
    vertex stage and dot it with the view axis `(0, 0, 1)`.
  Mixing spaces silently breaks anything distance-based — this was the
  root cause of the hit-flash ring never rendering.
- **`pow(x, 2.0)` is undefined for `x < 0`** and produces NaN on this
  Metal backend — one NaN kills the whole fragment (and blending against
  it). Gaussians written as `exp(-pow(d, 2.0))` over a *sign-changing*
  `d` (rings, bands) therefore never render. Always use `exp(-d * d)` with
  `d` computed on its own line.
- **Additive-blend materials pass through the engine's HDR exposure before
  tonemapping** — an effective ~100–300× lift on `rgb * alpha` — while
  `transparent` and `opaque` materials render in the plain 0–1 range.
  Tune additive materials with artistic 0–4 amplitude and a final
  `* 0.05`-ish scale factor (see `hit_flash.mat` / `shockwave_ground.mat`);
  a "reasonable-looking" 0.2 output saturates to pure white and the ACES
  curve desaturates it on top. Camera EV does **not** help (it only scales
  photometric lights); color-grading exposure does, but rescaling in the
  shader is simpler.
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
recompiling. Each setup enables the post-processing stack through
`enableVfxPost`, with effect-specific bloom strength: emissive fire/lava/
shockwave get a stronger halo, while water, smoke, and shore use restrained
bloom so highlights soften without flattening the image.

## 5. Shared helpers (`game_effects_shared.dart`)

| Helper | Purpose |
|---|---|
| `EffectClock` | Stopwatch-based clock with `tick()` (live hooks) and `setTime(t)` (deterministic stills) |
| `effectAnimators` | per-setup time→uniform closures consumed by the runner's still (`--time`) and video modes |
| `loadEffectMaterial(viewer, assetsDir, name)` | `.filamat` bytes → `MaterialInstance` |
| `setDarkSkybox(viewer)` | near-black navy skybox for additive scenes |
| `enableVfxPost(viewer, bloomStrength)` | enables AA/tonemapping/bloom with a per-effect glow strength |
| `subdividedPlane(w, d, subX, subZ)` | flat XZ grid with normals/UVs (`GeometryUtils.plane` is only 4 verts) |
| `dummyBillboardQuads(n)` | near-degenerate mesh: 6 verts per puff placed at a small deterministic scatter (valid bounding volume, treatable as zero by the shader — see the worldPosition gotcha) |

---

## 6. The effects

### 6.1 hit_flash — `game_effects_hit_flash.dart`, `hit_flash.mat`

**Intent.** Damage feedback: a white-hot flash at the impact point with a
saturated shockwave ring expanding outward across the mesh while a
rim-weighted body flash decays — the classic "I got hit" read. In the video
a hit lands every 2.4s (0.55s flash, rotating through three impact points on
the camera-facing side, then the normal PBR look until the next hit).

**Build.** Unlit + **additive** blend, depthWrite off, back-face culled,
using Filament's two-pass one-sided transparency. The vertex stage
passes the world normal and true world position (model matrix × object
position — see the view-space gotcha) via `variables`. The fragment
computes a fast cubic-decay body flash weighted to the silhouette, a
**localized hotspot** at `hitPoint` (dies fastest — it's what says "hit
HERE"), and a **shockwave ring** whose radius sweeps from ~0.25 (the impact
point sits just inside the surface) to ~1.4 (the mesh's far side) over the
flash, with a sharp leading edge and a tight warm wake behind it. The ring
color is an *oversaturated* version of `flashColor` — bright additive
values get desaturated toward white by the tonemapper, so the sweep needs
excess input to read as colored. Output is scaled ~0.05 for the additive
HDR exposure path (see the gotcha). The original PBR helmet remains in the
scene; a coincident second copy carries the flash as a true overlay. Its
vertices are lifted by `normalOffset`, while the two-pass depth path keeps
the complex glTF's internal submeshes from showing through as an X-ray.
The scene uses a warm key and cool point fill so the resting helmet stays
readable between hits.

**Uniforms.** `flashColor` float4 (default orange 1.0/0.36/0.1), `hitPoint`
float3 (world), `progress` float (0 = impact instant, 1 = finished), and
`normalOffset` (0.006). Flash duration, hit period and the impact-point list
are Dart constants.

**Tuning.** Snappier ring → raise the `15.0` width base or `1.15` travel in
the `.mat`; stronger directionality → move `hitPoint`; colored per-damage
type → change `flashColor` at runtime. Golden still time: `--time 0.22`
(ring mid-sweep across the face).

**Limitations / ideas.** The example duplicates the glTF because the viewer
does not yet expose a shared-geometry overlay renderable. A screen-space
chromatic pulse and a decal-style scorch mark are natural follow-ons.

### 6.2 hologram — `game_effects_hologram.dart`, `hologram.mat`

**Intent.** Sci-fi projection: translucent cyan shell with a readable
silhouette, fine scanlines sweeping upward, a bright scanning band
traveling up the model, occasional glitch bands that shear and split
chromatically, subtle flicker with rare dropouts.

**Build.** Unlit + **transparent** blend (premultiplied output),
depthWrite off, double-sided so the back shell adds depth. The fragment
combines: a fresnel rim kept saturated (brighten via alpha, never mix
toward white — tonemapping desaturates brights); two scanline layers
(a dense fine set plus a slow coarse set); a gaussian **scanning band**
with a soft haze and a sharp trailing bar sweeping y over ~4.8s; gated
**glitch bands** (~36% of 2.5Hz time slices) — two bands tear in different
directions, each with a complementary chromatic split (blue-fringed one
way, red-fringed the other); and a two-frequency flicker with rare
single-frame dropouts. The gate hash is duplicated verbatim in both stages
so the vertex shear and fragment flare stay in sync. A slight hue journey
runs up the projection: deeper blue at the base, near-white cyan at the
crown. Applied to the skinned BusterDrone via material swap. A separate
additive `hologram_projector.mat` disc beneath the drone supplies concentric
rings, radial spokes, a rotating acquisition sweep, and a physical visual
source; the camera drifts on a subtle orbit during video.

**Uniforms.** `tintColor` (0.2, 0.85, 1.0), `time`, `fresnelPower` 2.5,
`fresnelStrength` 1.35, `scanlineCount` 70, `scanlineSpeed` 4.0,
`glitchAmount` 0.09. Golden still time: `--time 2.2` (glitch slice active,
band mid-model).

**Tuning.** More aggressive glitch → raise `glitchAmount` or lower the
`0.72` gate threshold; denser lines → higher `scanlineCount` (watch Moiré
on small meshes); the sweep speed is the `0.21` factor on `t`.

**Limitations / ideas.** A materialization wipe (discard below a
noise-edged Y threshold that rises with time) would give a projector boot-up;
a translucent volumetric cone between the new emitter and drone is the next
scene-layer improvement.

### 6.3 force_field — `game_effects_force_field.dart`, `force_field.mat`

**Intent.** A shield bubble around a generator core: dark see-through
interior, bright fresnel silhouette with a hot rim lip, a curved energy
lattice with pulses running along its lines, and an impact response — a
splash at the hit site, then a sharp expanding ring (with a trailing echo)
that flares the lattice as it crosses.

**Build.** Unlit + **additive**, depthWrite off, on a 48×64 sphere scaled
to radius 1.2, front-face shell only so the back grid cannot muddy the read.
The lattice is two warped families of thin spherical arcs with directional
power flow and brighter intersections; unlike the original spherical hex
mapping it neither pinches into giant polar cells nor reveals the source
triangulation. The impact response adds a directional splash, a sharp
angular ring, a trailing echo, and nine rotating arc sparks around the ring,
all flaring the lattice as they pass. A dedicated `force_core.mat` shades a
rotating low-poly crystal with animated energy scans instead of relying on a
featureless default white cube.

**Uniforms.** `baseColor` (0.30, 0.55, 1.0), `time`, `fresnelPower` 2.2,
`hexScale` 16 (arc density), `hexStrength` 1.25,
`hitDirection` float3 (unit), `hitAge` float (seconds since hit). Golden
still time: `--time 2.25` (ripple mid-expansion).

**Tuning.** Denser arcs → higher `hexScale`; stronger shield presence →
the rim gains or final additive scale; ripple speed/decay → the `2.05` and
`0.75` factors on `hitAge`.

**Limitations / ideas.** Multiple simultaneous ripples (a small ring buffer
of hit directions/ages) would support sustained fire; a real protected PBR
subject inside the shell would give the shield stronger gameplay context.

### 6.4 dissolve_burn — `game_effects_dissolve_burn.dart`, `dissolve_burn.mat`

**Intent.** Death/teleport: the mesh is eaten away by irregular noise
while the receding front burns — white-hot at the very edge through orange
to deep red, with charred ground just ahead of the front and occasional
ember sparks.

**Build.** Unlit + **opaque** with `discard` below the threshold (keeps
depth-writing correct, unlike alpha blending). The noise is 4-octave fbm
sampled in **object space** (pinned to the mesh — a moving model slides
*through* the burn, the burn never slides across the model), slowly
scrolling in Z via `time`. The fragment computes the normalized distance
`e` from the threshold over `edgeWidth` and builds a three-stop
**temperature gradient** (white-hot → `edgeColor` orange → deep red) with
two-octave combustion flicker; ahead of the front the surface darkens
through a `charr` gradient concentrated in a band about 3× the edge width,
and rare twinkling ember sparks sit right at the front. The video ramps
`threshold` 0→0.95 over a 3.5s loop.

**Uniforms.** `baseColor` (0.10, 0.075, 0.06 — char), `edgeColor`
(1.0, 0.45, 0.1), `threshold` 0.5, `edgeWidth` 0.065, `edgeIntensity` 1.35,
`noiseScale` 3.4, `time`. Golden still time: `--time 1.2`.

**Tuning.** Chunkier dissolution → lower `noiseScale`; hotter edge → raise
`edgeIntensity`/narrow `edgeWidth`; wider charred apron → raise the `3.0`
multiplier on `edgeWidth` in the `charr` smoothstep.

**Limitations / ideas.** Rising ember sparks (reuse the smoke billboard
system with an upward, shrinking preset) and ash fall are natural
follow-ons; a directional burn (bias the threshold by a world-space
gradient) would read as spreading fire rather than uniform decay.

### 6.5 water — `game_effects_water.dart`, `water.mat`

**Intent.** Stylized game water: rolling swells with visible crest/trough
relief, deep color looking down with drifting current variation,
sky-reflecting grazing angles, a directional sun glitter path with real
sparkle, whitecaps on the choppiest crests, and a rim that melts into the
horizon.

**Build.** The heaviest vertex shader: five summed **Gerstner waves**
(~1×/2×/4×/7×/11× frequency, rotated directions, per-wave steepness pushed
high enough for sharp crests without looping) displace a 24×24-unit,
240×240-vertex `subdividedPlane` — as a pure `+=` displacement
(see the worldPosition gotcha). Normals come from finite differences, and
the same differences feed **two foam inputs** packed into the variables'
`.w` channels: crest height and horizontal compression (where Gerstner
pinch concentrates is exactly where whitecaps live). The fragment shader
adds **three scrolled fbm detail-normal layers** (attenuated with distance
to avoid aliasing), Schlick fresnel deep→sky mixing over a large-scale
**current-noise body color**, sun-side shading plus crest lightening, a
backlit subsurface glow on crests toward the sun, dual-lobe sun glitter —
broad sheen plus a fresnel-weighted sparkle that is both twinkle-hashed
and **gated into a wedge pointing at the sun** so it reads as a glitter
path — and foam from crest+chop broken by two noise octaves (foam also
flattens the normals — foam is diffuse, and carries its own shadow tint).
The horizon **fades alpha to zero** at the rim so the plane edge never
reads as a disc against the skybox. Unlit + **transparent**, depthWrite
on, double-sided.

**Uniforms.** `deepColor` (0.008, 0.058, 0.090, 0.94), `skyColor`
(0.36, 0.52, 0.72), `foamColor` (0.94, 0.98, 1.0), `sunDirection`
(−0.55, −0.35, −0.75), `time`, `waveHeight` 0.27, `waveFrequency` 1.12,
`waveSpeed` 1.6, `foamAmount` 0.72, `specularPower` 520 (tight-lobe),
`specularIntensity` 2.5, `detailStrength` 0.82, `sssStrength` 0.9. Camera
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

**Intent.** A living gray smoke column: puffs spawn small and dense at the
base, rise and accelerate, stretch vertically, spiral outward and bend with
the wind while thinning to wisps — one draw call, no particle system (the
vendored Filament has none).

**Build.** Fully **GPU-generated geometry**: the CPU mesh is
`dummyBillboardQuads(64)` — near-zero (but non-degenerate) vertices whose
displacement the shader treats as purely additive (see the worldPosition
gotcha). The vertex shader reconstructs everything from `getVertexIndex()`:
`vid / 6` is the puff, `vid % 6` picks from constant quad corner/UV tables;
per-puff hash seeds stagger lifetime and vary rise/stretch/spin/brightness;
`mod(time − seed·lifetime, lifetime)` loops each puff independently. The
puff center is a **cone + spiral + wind bend** (`age·0.36` spiral radius,
`age²·0.62` downwind drift) — this is what makes it read as a plume rather
than a vertical line of blobs. Billboards face the camera along the rows
of `getViewFromWorldMatrix()`. The fragment shader shapes each quad with a
radial falloff × **vertically-squashed, double domain-warped fbm** (the
squash stretches features into rising wisps; the double warp tears the
edges), eases alpha in/out over the lifetime, and carries age/brightness
in the custom `quadData` variable's zw channels. Young puffs get a warm
cast as if lit from the fire below and scatter more light at their tops;
old puffs cool toward blue-gray translucency. **Unlit + transparent**
(premultiplied): overlapping puffs build to denser gray instead of
additively washing to white (the additive version was a white blob).

**Uniforms.** `baseColor` (0.23, 0.25, 0.30 — blue-gray), `time`, `puffCount` 64
(informational — must match the Dart constant you pass to
`dummyBillboardQuads`), `riseSpeed` 0.42, `expandSpeed` 0.105,
`swirlAmount` 1.35, `baseSize` 0.18, `noiseScale` 3.4, `lifetime` 5.2,
`originHeight` 0, `opacity` 1.
Camera at (0.35, 1.3, 3.6) focused slightly above the column base. Golden
still time: `--time 4.6` (fully populated column).

**Tuning.** Denser column → more puffs (bump the Dart constant —
`puffCount` is informational only); wind → the `age·age·0.62` term;
darker/sootier smoke → lower `baseColor`; the noise warp strength is the
`1.7` multiplier on `warp`.

**Limitations / ideas.** No depth-fade (puffs cut hard against intersecting
geometry) — the proper fix is soft particles sampling the depth buffer
(see the `render_targets` example for depth access). The single-draw-call
order is unsorted, which alpha blending mostly forgives for soft puffs.
Fog and rain presets are parameter tweaks away.

### 6.7 fire — `game_effects_fire.dart`, `fire.mat`

**Intent.** A campfire-style flame: two rings of tongues (a tight hot core
and a looser skirt) licking upward from a granular white-hot ember bed,
through yellow and orange to saturated red tips, with ember sparks (a few
big ones) rising out of it.

**Build.** One draw call on `dummyBillboardQuads(48)`: the first 12 quads
are flame tongues, the remaining 36 are embers — the vertex shader branches
on `quadIndex < flameCount`. The first, broad quad is a coherent
noise-eroded flame body; narrower licks layer over it. Tongues stand on their base, each with its own
height/flicker phase and a slowly wandering cluster center so the fire
breathes rather than flickering in place; the cluster is sheared by wind
proportionally to height. The fragment shader scrolls domain-warped fbm
**downward** in noise-space through a vertically-squashed domain (tall
narrow licks), tapers the width with height, lets the noise eat aggressively
into the tip so it ends in separated licks, adds a **granulated ember bed**
at the base, and colors the heat field through a blackbody ramp (deep red →
orange → yellow → white) with saturated red at the dying tips and a whisper
of blue where cold fuel enters at the very base. Embers rise from inside
the flame with a sinusoidal wobble, stretching into little streaks,
flickering, and cooling white → red; a few (1 in 10) run big. A second draw
reuses `smoke.mat` as a raised, lower-opacity combustion plume, while
`fire_ground.mat` adds a pulsing coal/crack bed under the flame. Unlit +
**additive** with the HDR-path output scale for flame, embers, and ground.

**Uniforms.** `time`, `flameCount` 12, `emberCount` 36, `flameHeight` 1.12,
`flameWidth` 0.27, `noiseScale` 3.4, `scrollSpeed` 2.5, `windLean` 0.22,
`emberLifetime` 1.9. The counts must match the geometry passed to
`dummyBillboardQuads`. Golden still time: `--time 4.6`.

**Tuning.** Taller/lazier flames → raise `flameHeight`, lower
`scrollSpeed`; windier → `windLean`; hotter core → stretch the ramp stops
in the `.mat`.

**Limitations / ideas.** A flickering point light driven from the same phase
and nearby receiving geometry would sell the heat in a gameplay scene;
soft-particle depth intersection remains the main smoke limitation.

### 6.8 lava — `game_effects_lava.dart`, `lava.mat`

**Intent.** A molten field: dark drifting crust broken by a **connected
web** of glowing cracks (like real cooling lava), hottest (yellow-white) in
the fast-flowing channels, with a red reheat halo bleeding into the crust.

**Build.** A vertex-displaced `subdividedPlane` (additive displacement
only): three slow drifting sine lumps form the crust swell, with
finite-difference normals. The cracks are the **ridges of two domain-warped
fbm fields, combined with `max()`** — ridge lines form a connected,
branching web rather than the isolated blobs a plain threshold produced.
A wider, dimmer ridge halo gives the reheat apron. Crack interiors are
modulated by two scrolled flow noises; their sharpest lobes (`flow²`)
drive near-white hot cores, so the hottest points visibly course along the
channels. Temperature ramp deep red → orange → yellow-white keyed on crack
intensity + core; the crust is very dark red-brown (exposure + ACES lift
darks heavily — see the skybox gotcha — so both crust and ramp stops are
pushed darker/more saturated than the intended read) with two octaves of
grain, gentle top-light shading, and a slow regional convection pulse.
Opaque, edge melts into the background.

**Uniforms.** `time`, `glowIntensity` 1.12, `crustScale` 1.0, `flowSpeed`
0.5, `swellHeight` 0.14. Golden still time: `--time 3.0`.

**Tuning.** More/denser cracks → raise the `0.80/0.84` ridge thresholds;
faster crust drift → the `0.05/0.04` time factors; more violent swell →
`swellHeight`.

**Limitations / ideas.** Ember/smoke vents on the brightest cracks (reuse
the fire/smoke rigs); heat-haze refraction needs post-processing this
example level doesn't have.

### 6.9 shockwave — `game_effects_shockwave.dart`, `shockwave_ground.mat` + `shockwave_dome.mat`

**Intent.** An ultimate-style energy pulse: a hot flash at the epicenter,
then a sharp arc-broken ring racing out across the ground while an energy
dome expands out of the epicenter — one coordinated event every 2.2s.

**Build.** Two materials on two geometries. The **ground ring** (flat
plane at the identity transform, so its vertex stage passes
`getPosition()` straight through as world position — see the view-space
gotcha): one wave per period, `waveR = age·speed`, with a sharp leading
edge whose width relaxes as the ring travels (constant readability, not
constant world width), a trailing secondary ring, a lingering energy fill
behind the front, a hot **epicenter flash** at the instant of the pulse,
angular fbm breaking the ring into arcs with contrast pushed so the gaps
go fully dark, and outward-advected churn noise on the front. The **dome**
(unit sphere, scaled by the Dart animator to track the ring front):
fresnel body + hot rim computed **in the vertex stage** from the
view-space normal (no fragment position needed — see the gotcha),
upward-flowing vertical streak noise, and a hot **equator lip** where the
dome meets the ground; its **lower hemisphere is discarded at y=0** in
object space (scale-invariant), so the equator cut sits exactly on the
ground plane. Both are additive with the HDR-path output scale.

**Uniforms.** Ground: `time`, `period` 2.2, `waveSpeed` 3.6. Dome:
`baseColor`, `time`, `age` (seconds since pulse). The dome's scale is set
per-frame by the animator (`0.15 + age·waveSpeed·0.78`). Golden still
time: `--time 0.55` (ring mid-frame, arcs legible).

**Tuning.** Faster pulse → `waveSpeed`; sharper ring → the `4.6` width
base; longer-lived dome → the `1.3` fade rate.

**Limitations / ideas.** Trigger the pulse from an actual game event (the
animator is trivially rewirable); ground scorch would want an alpha-blended
decal pass; multiple overlapping waves need a per-wave uniform array or a
ring buffer of ages.

### 6.10 shore_waves — `game_effects_shore_waves.dart`, `shore_waves.mat` + `sand.mat`

**Intent.** Waves arriving at a beach: swells shoal (grow) as they reach
the shallows, whitecap on the way in, then break into a foam line that
**travels toward the shore** in pulses and washes up onto wet sand whose
swash line runs up and back in lockstep.

**Build.** The trick that keeps this cheap: **the demo owns the scene
geometry, so the shoreline is an analytic function** — `z_shore(x) =
1.2 + 0.35·sin(0.6x + 1) + 0.15·sin(1.7x)` — and "shore distance" is just
that minus world z (no depth texture). The vertex shader runs three
Gerstner swells **traveling toward the shore** with a per-vertex amplitude:
growing through the shoaling zone, collapsing past the break. The fragment
shader mixes deep teal → turquoise by shore proximity (a deliberately
tight transition), adds Schlick fresnel, sun-side shading, two
detail-normal layers and glitter toward the beach. Foam has three sources:
whitecaps (crest + pinch, as in water), the **breaking line** — a gaussian
band around the shoreline whose pulse crest travels **toward the shore**
(`sin(t·3 + depth·2.8 + along-shore wobble)`, so the break line advances
unevenly rather than blinking in place), textured with two anisotropic
noise octaves stretched along the shore — a second, lower irregular breaker
approaching behind it, and a wash residue further up.
The waterline itself is noise-fingered (jagged, not straight) and
alpha-fades past the shoreline into a **land-side sand plane** (`sand.mat`)
that is clipped by the same analytic contour, preventing displaced troughs
from exposing false sand islands. Its swash band center oscillates
with the *same phase* as the breaker pulse runs up the sand, trailed by a
damp apron and foam speckle at its leading edge, so waterline, breaker and
swash all stay in lockstep. Water: unlit + transparent, depthWrite on.

**Uniforms (water).** `deepColor` (0.008, 0.07, 0.12), `shallowColor`
(0.025, 0.30, 0.34), `skyColor` (0.075, 0.14, 0.22), `foamColor`
(0.40, 0.52, 0.58), `sunDirection` (−0.45, −0.35, −0.8), `time`,
`waveHeight` 0.24, `waveFrequency` 1.35, `waveSpeed` 1.5, `foamAmount` 0.72,
`detailStrength` 0.78. Sand: `sandColor` (0.085, 0.050, 0.022), `time`
(driven by the same animator, phase-locked). Camera at (0, 4.5, −4.8) looking
shoreward. Golden still time: `--time 2.0`.

**Tuning.** Bigger surf → `waveHeight`/`waveFrequency`; wider breaker →
the `0.38` band width; slower sets → the `3.0` pulse rate; the shoreline
curve itself is the `shoreZ` function (must stay identical in both
`.mat`s).

**Limitations / ideas.** The swells don't actually refract/curve toward
the beach contour (real wave optics); foam advection (flow-map style)
would give trailing streaks behind the break line.

### 6.11 wetness — `game_effects_wetness.dart`, `wetness.mat`

**Intent.** Rain-soaked aggregate with irregular pooled water rather than a
uniformly glossy surface. The wet areas have a second clear-coat lobe, tight
grazing reflections, multiple independently timed ripple fields, and rough
grit visible beneath the water.

**Build.** Manually lit unlit material on a dense ground grid. Four-octave fbm
defines puddles; two aggregate scales break up the substrate; three hashed cell
grids spawn rings without CPU particles. Puddle coverage drives base-color
darkening, grazing reflection, specular streaks, and micro-glitter together.
This manual path is intentional: custom lit variants fail to load on the
current feature-level-1 Metal runtime. Golden still: `--time 2.35`.

### 6.12 crystal_ice — `game_effects_crystal_ice.dart`, `crystal_ice.mat`

**Intent.** A faceted hero ice crystal with a cool inner volume, spectral
edge separation, and energized fissures that travel through the silhouette.

**Build.** A deliberately coarse 12×18 sphere makes the macro facets read;
3D Voronoi provides inner crystalline breakup, two intersecting analytic
fracture families form the cracks, and a view-dependent cyan/violet fresnel
creates the refractive read without requiring a screen-color texture. Golden
still: `--time 1.8`.

### 6.13 snow_accumulation — `game_effects_snow_accumulation.dart`, `snow_accumulation.mat`

**Intent.** Snow that gathers from above on a complex asset instead of a
white material cross-fade.

**Build.** A manually lit material combines world-normal slope, object-space
height, wind-scale noise, and a moving accumulation line. Covered areas get a
broad diffuse snow response; exposed areas remain a dark metal/oxide substrate.
Fine frost cells add sparse cool sparkle. The manual light model avoids the
same custom-lit Metal variant limitation noted for wetness. Golden still:
`--time 1.5`.

### 6.14 damage_decals — `game_effects_damage_decals.dart`, `damage_decals.mat`

**Intent.** A readable sequence of projectile impacts with permanent damage
and short-lived thermal response.

**Build.** Four independently timed analytic decals combine asymmetric holes,
beveled rims, soot gradients, and nine seeded fracture rays per impact. The
fresh hit blooms white-orange and cools while the crater and scorch remain.
The showcase bakes the receiver and decals into one procedural material; a
game integration would feed the same masks through its decal/DBuffer pass.
Golden still: `--time 2.05`.

### 6.15 portal_rift — `game_effects_portal_rift.dart`, `portal_rift.mat`

**Intent.** A portal that reads as depth, flow, and dangerous boundary energy,
not a flat rotating texture.

**Build.** Polar fbm warps counter-rotating tunnel rings and spiral filaments;
hashed star motes reinforce parallax; separate rim and corona profiles create
the high-energy lip. `openAmount` collapses the horizontal axis for a staged
slit-to-disc opening and closing. Golden still: `--time 2.2`.

### 6.16 electricity — `game_effects_electricity.dart`, `electricity.mat`

**Intent.** A coherent lightning discharge with a stepped trunk, visible side
forks, a hard HDR core, and softer ionized air.

**Build.** Sixty-four degenerate CPU quads become oriented bolt segments in the
vertex shader. A stable multi-frequency path is perturbed at an 18 Hz cadence;
the remaining segments form three-link branches on alternating sides. Fragment
distance shapes the core and halo in one additive draw. Golden still:
`--time 1.7`.

### 6.17 invisibility_cloak — `game_effects_invisibility_cloak.dart`, `invisibility_cloak.mat`

**Intent.** Restrained active camouflage that almost disappears at rest but
gives gameplay-readable chromatic edges and intermittent hardware faults.

**Build.** Transparent, depth-write-off shading keeps only a faint body while
fresnel supplies the silhouette. Scan faults, cellular breakup, a traveling
interference band, and small normal-direction vertex shimmer spike during a
periodic disruption envelope. Golden still: `--time 2.15`.

### 6.18 energy_weapon — `game_effects_energy_weapon.dart`, `energy_weapon.mat`

**Intent.** A complete shot lifecycle: pre-charge, muzzle bloom, plasma beam,
traveling core structure, impact orb, and expanding shock shell.

**Build.** One wide additive pass shares a single coordinate system for muzzle,
beam, and impact. Dart drives the fire envelope over a 2.6 s cycle; the shader
derives pre-charge and impact timing from the same clock, adding a turbulent
envelope around a tight blue core, traveling packets, an expanding muzzle ring,
and polar impact rays. The single pass avoids cross-mesh transform drift and is
straightforward to connect to weapon events. Golden still: `--time 1.2`.

---

## 7. Suggested roadmap

1. **hit_flash**: overlay pass (keep PBR visible during the flash);
   screen-space chromatic pulse on impact.
2. **water**: IBL/lit reflections, depth-based color, flow-advection for
   wispy foam streaks.
3. **smoke**: soft-particle depth fade.
4. **force_field**: multiple simultaneous ripples; cube-map-projected
   lattice.
5. **dissolve_burn**: directional burn gradient; ember sparks via the
   smoke system.
6. **hologram**: materialization wipe; projector cone/disc geometry.
7. **fire**: smoke cap via the smoke rig; flickering scene light driven
   from Dart.
8. **shockwave**: event-triggered pulses; overlapping waves.
9. **shore_waves**: wave refraction toward the beach contour; foam
   advection behind the break line.
10. New effects from the same toolkit: cloth/flags, grass, heal circles,
    volumetric fog shafts, stylized clouds, and caustic projectors.
11. Cross-cutting: a `game_effects` composite galleryScene for the web
    gallery; web verification (COOP/COEP, real Chrome) once a WebGPU matc is
    available; interactive parameter playground.

## 8. Commit map (as of writing)

- `d5e68e060` — `fix: make materials/build.sh work on macOS`
- `7061362fb` — the six materials + example setups + plan doc
- `7c976d39e` — `effectAnimators` + `--video` runner mode + hit_flash lighting
- `a5fdbe2b2` / `a82173a5c` — first visual overhaul + fire/lava/shockwave/
  shore waves
- (this branch) — visual-quality overhaul round two: hit flash with a real
  orange shockwave ring + localized hotspot (and the view-space
  `getWorldPosition` / negative-`pow` / additive-HDR-exposure fixes that
  had silently killed it), hex force field at readable scale with
  splash+ring+echo impact, two-band glitch hologram, gray alpha-blended
  smoke column, two-ring fire with granular ember bed and red tips,
  ridged-web lava with flowing hot cores, crisper dissolve front, arc-
  broken shockwave with epicenter flash + streaked dome, traveling breaker
  with phase-locked sand swash, water with currents/textured foam/
  directional glitter path/fading horizon.
