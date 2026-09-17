# Burley screen-space subsurface scattering

**Status: experimental implementation; material-model tests pass, one render-path
regression remains under investigation.** The previous Gaussian blurred painted
texture because it filtered albedo multiplied by lighting. The replacement
accumulates uncolored diffuse lighting, diffuses that quantity with the normalized
Christensen–Burley profile, and applies albedo at the receiving pixel. It operates
in linear HDR before TAA, bloom and color grading. It is a local screen-space
approximation, not a calibrated skin preset or a complete surface BSSRDF.

## Dependency and local build

This Thermion change depends on the separate
[Filament draft #6](https://github.com/nmfisher/filament/pull/6),
commit `18c1d84867f696c89cc71474abb482b63e9cdc4d`, based on upstream v1.76.0
(`813ff0c6a`). Its draft targets the fork's `sss-base/v1.76.0` branch.
The Thermion branch is `fix/pr353-sss`, stacked on PR #353's
`asb/sss-fullscreen-quad` branch. Apply the replacement there before considering
PR #353 for `develop`; the original beauty-image blur is superseded.

The engine and Thermion changes are separate, dependent drafts. Matching engine
release artifacts are not published, so this feature still requires a local
matching build. Stock builds reject enabling SSS. Do not release these material
packages against the stock engine artifacts.

The engine, headers, generated uberarchive header, ubershaders and material
compiler must all match. All scene surface materials need recompilation with
this compiler, even if they are not selected for scattering. Package version 76
alone does not establish compatibility with this engine extension.

The local macOS arm64 build used:

```sh
# In the Filament worktree:
cmake -S . -B out/sss -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DFILAMENT_SKIP_SAMPLES=ON \
  -DFILAMENT_BUILD_TESTING=OFF -DFILAMENT_SUPPORTS_VULKAN=OFF \
  -DFILAMENT_SUPPORTS_METAL=ON -DFILAMENT_SUPPORTS_OPENGL=ON \
  -DFILAMENT_SUPPORTS_WEBGPU=OFF -DFILAMENT_ENABLE_RTTI=ON \
  -DFILAMENT_ENABLE_EXCEPTIONS=ON
cmake --build out/sss --parallel 8 --target matc filament gltfio uberarchive \
  filameshio image ktxreader filament-iblprefilter

# In Thermion's thermion_dart directory:
python3 tool/sss_local.py /path/to/filament-worktree --test
```

The helper stages the matching libraries and headers and temporarily sets the
native build hook's `filament_path` user define. It restores `pubspec.yaml` after
the tests, including on failure. To run another consuming application, set:

```yaml
hooks:
  user_defines:
    thermion_dart:
      filament_path: /path/to/filament-worktree/stage
```

For material regeneration, build `matc` and `resgen` in `out/sss-tools` with the
same source and `FILAMENT_SUPPORTS_WEBGPU=ON`; point `FILAMENT_PATH` at a directory
containing those two executables and run top-level `make materials`. The existing
script needs Bash 4 and GNU sed (on macOS, the verification run temporarily
adapted its uppercase expansion and sed syntax). Run top-level `make bindings`
after changing the C API. Checked-in material blobs were rebuilt for all eight
backend variants; this is compilation coverage, not runtime coverage.

## API and rendering contract

```dart
await view.setSubsurfaceScatteringEnabled(true);
final sss = view.getSubsurfaceScattering()!;
await sss.addPrimitive(entity, primitiveIndex);
await sss.setParameters(const SubsurfaceScatteringParameters(
  diffusionDistanceRedMm: 0.6,
  diffusionDistanceGreenMm: 0.3,
  diffusionDistanceBlueMm: 0.15,
  metersPerUnit: 1.0,
  intensity: 1.0,
));
```

These renamed distances replace the previous `sigma*Mm` API. They are exponential
profile lengths, not Gaussian standard deviations. The engine feature marker is
`FILAMENT_HAS_DIFFUSE_SSS >= 2`; selected materials require `_sssBurleyEligible`.
The old Gaussian compiler/runtime/material artifacts are not compatible.

`addSkin(asset)` selects all eligible primitives and assigns them one transport
group. For mixed skin/eyes/clothing assets, select primitives explicitly. Separate
groups never exchange samples. Selection clones each primitive's own material
instance, retaining textures and vertex deformation. Edit the currently bound
instance while selected; removal restores the original. Remove selection before
asset destruction through lower-level APIs; viewer destruction handles this.

Four attachments come from the same opaque draw and actual scene depth:

| Attachment | Quantity |
|---|---|
| Original color | Ordinary shaded HDR color, including diffuse, specular and emission |
| Diffuse lighting, RGBA16F | Direct + indirect diffuse lighting before albedo; alpha holds selection strength |
| Guide, RGBA32F | View-space geometric normal and negative transport-group ID |
| Albedo, RGBA16F | `pixel.diffuseColor` at the receiving surface |

The uncolored term is accumulated directly in the lighting shaders. There is no
color/albedo division, including at zero albedo. Existing diffuse attenuation,
AO, sheen and clear-coat attenuation remain in that term. Recombination adds a
lighting correction to the original shaded color:

```
C = originalColor + albedo * globalStrength * materialStrength * (R * L - L)
```

This avoids subtracting and reconstructing specular/emission. At zero global
strength the engine skips the SSS variant, attachments and gather entirely.
Profile/selection changes clear temporal history. The manager owns no extra
public view slots or output targets. Debug outputs expose colored diffuse,
visible coverage and actual scene depth.

## Profile and spatial approximation

The normalized Christensen–Burley radial profile is

```
R(r,d) = (exp(-r/d) + exp(-r/(3*d))) / (8*pi*d*r)
CDF(r) = 1 - 0.25*exp(-r/d) - 0.75*exp(-r/(3*d))
```

The profile is truncated at `16*d`, and divided by its retained mass
`0.9963790093708328`. All RGB channels use common nearest texel positions. A 3×3
Gauss–Legendre quadrature integrates each noncentral pixel footprint; the singular
central cell is implicit in center-plus-weighted-differences accumulation.

Millimeters convert through explicit `metersPerUnit`. Projection uses the current
camera and reconstructed position; sampled depth goes directly into the inverse
of Filament's reversed [0,1] projection. Centered perspective and orthographic
cameras are covered. The distance measure is the local image-plane footprint,
not geodesic surface distance. Arbitrary projective matrices and steeply tilted
surfaces are unvalidated.

The full-resolution reference gather is capped at 32 pixels per axis. Samples
from other groups, incompatible normals or excessive normal-plane separation
are rejected. Rejected, offscreen and capped mass stays at the center. Thus a
constant lighting field stays constant; large projected profiles lose spreading.
This boundary rule is not a reciprocal, globally energy-conserving BSSRDF.
The gather is expensive and has not been optimized or performance qualified.

## Independent renderer comparison

The [packaged reference scripts and captured PNGs](../thermion_dart/tool/sss_blender/README.md)
recreate offline comparison viewers without machine-specific paths. The clearer
Cycles-only stencil demonstration is included alongside the matched ball and
flat-boundary fixtures. Actual Cycles 4.5.0 CPU renders use 4,096 samples for the
matched flat fixtures, 2,048 for the ball and 1,024 for the stencil, with no
denoising. The scripts can regenerate raw EXRs and packed Blender scenes locally;
these large intermediates and compiled helpers are not committed.

The reference uses **Cycles Burley**, replacing the earlier comparison against
unmatched Random Walk settings. In Cycles 4.5's live
[`bssrdf_setup_radius`](https://github.com/blender/blender/blob/v4.5.0/intern/cycles/kernel/closure/bssrdf.h)
path, Burley node radius × scale is divided by `4*pi`. The reference therefore
sets that product to `4*pi*d`, without fitting to Thermion's images. The older
albedo-dependent `bssrdf_burley_setup` helper is not called by this setup path.
The profile/truncation match does not imply equivalent curved-surface transport.

On the same 100 mm-radius grid ball, red-channel 10–90% edge widths are:

| Renderer | Off | dR = 0.6 mm | dR = 1.2 mm |
|---|---:|---:|---:|
| Thermion Burley | 2.666 px | 2.662 px | 2.663 px |
| Cycles Burley | 2.762 px | 2.763 px | 2.763 px |

The superseded Gaussian measured 4.907 and 7.764 px at its nominal 0.6/1.2 mm
sigmas. These are local display-space texture-sharpness measurements, not radius
estimates. The ball PNGs share Filament's ACES display transform; residual
baseline differences include BRDFs, texture filtering and raster/path sampling.

The separate flat fixtures test a painted edge in uniform light and a shadow
edge on uniform albedo. Texture stays unchanged across eight GPU
projection/distance/radius cases, including black albedo. The shadow spread
agrees with an independent angular integral of Burley within 1.063% of the
light-to-shadow contrast. RGB errors are at most 1.063%, 1.023%, 0.718%.

Normalized Thermion/Cycles shadow rows differ by at most 1.852% for d = 6.25 mm
and 1.436% for d = 12.5 mm (projected 1/2 pixels). Rows are normalized by each
renderer’s unscattered bright plateau, with no radius or edge-position fitting.
Cycles averages output pixel area; Thermion uses center receivers and inherits
PCF filtering in its input shadow. Those sampling differences and Monte Carlo
noise remain visible. Fixtures share physical dimensions, projection and light.

## Supported scope and verification

Initial scope: opaque standard-lit selection, one SSS view per engine, with
MSAA, fog, stereo, SSR and transparent/refractive composition disabled. Unsupported
selection and existing incompatible view settings are rejected. Subsequent scene
changes must continue to honor engine preconditions. Masked surfaces may occlude
selected objects, but cannot be selected. Custom surface shading and post-lighting
color are ineligible. Four simultaneous color attachments are required.

Apple M2 Pro / Metal regressions cover zero strength with post-processing on/off,
depth, coverage, occlusion, direct/indirect specular, emission, diffuse changes,
silhouettes, bones/morphs, independent texture/shadow boundaries, transport groups
and scene units. Measurements are written to
`thermion_dart/test/output/sss_replacement/audit.json`.

Current full run: **18/19 GPU tests pass**. Zero strength, hidden surfaces, direct
specular, emission, texture preservation and unit rescaling change zero pixels
above 1/255; all animated coverage comparisons have zero mismatches. Shared vs
separate transport groups differ by up to 0.11373 in the shadow fixture.

**Remaining failure:** enabling the SSS render variant changes five pixels in
an indirect-specular-only sphere. It also occurs with no selected materials,
and disappears in that unselected fixture when geometric specular AA is disabled.
The cause is not yet established. The strict regression remains unchanged and
failing; do not claim complete reflection identity or readiness to merge.

The independent CPU oracle `python3 tool/sss_reference.py` passes seven tests.
It integrates the radial survival probability over angle, independently of the
GPU's Cartesian quadrature. Flutter analysis has no errors and retains 47
pre-existing diagnostics. Engine desktop debug build and core utility tests
are also run; backend material compilation is not runtime coverage.

Hidden/offscreen transport and thin-object transmission are absent. Before
wider release, validate linear-HDR impulse error, temporal motion/TAA, a real
face, performance and other GPU backends. See the [historical audit](sss-audit-and-redesign.md)
for the rejected architectures and broader acceptance targets.
