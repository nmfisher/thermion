# Burley screen-space subsurface scattering

This experimental pass accumulates uncolored diffuse lighting, diffuses it
with the normalized Christensen–Burley profile, and applies albedo at the
receiving pixel. It runs in linear HDR before temporal antialiasing, bloom and
color grading. Its scope is local, visible-surface diffusion.

## Engine dependency

Thermion's Burley integration depends on
[Filament PR #6](https://github.com/nmfisher/filament/pull/6), ported to
upstream v1.77.2. The runtime, headers, packaged ubershaders and material
compiler must come from the matching fork build. Compile all surface materials
in an SSS view with that compiler, including the materials of occluders.
Stock Filament builds reject enabling SSS.

Use the matching `matc` for `FILAMENT_PATH=... make materials`. Thermion's
built-in helper packages are compiled on demand by the build hook using the
compiler from the pinned artifacts. Use `make bindings` after changing the C API.

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

These distances are the exponential lengths in the diffusion profile. The engine feature marker is
`FILAMENT_HAS_DIFFUSE_SSS >= 2`; selected materials require `_sssBurleyEligible`.
The old Gaussian compiler/runtime/material artifacts are not compatible.

`addSkin(asset)` selects all eligible primitives and assigns them one transport
group. For mixed skin/eyes/clothing assets, select primitives explicitly. Separate
groups never exchange samples. Selection clones each primitive's own material
instance, retaining textures and vertex deformation. Edit the currently bound
instance while selected; removal restores the original. Remove selection before
asset destruction through lower-level APIs; viewer destruction handles this.

The ordinary color pass supplies the original HDR scene. A second opaque pass
uses the same geometry, camera and material state to record diffuse lighting,
coverage and scene depth in three color attachments. Keeping the ordinary
shader variant for scene color preserves Metal's geometric specular AA.

| Attachment | Quantity |
|---|---|
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

The [historical reference scripts and captured PNGs](https://github.com/nmfisher/thermion/tree/851b329db6fc6d50d6e8d393d558f6b014a562fc/thermion_dart/tool/sss_blender)
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

The experimental path supports opaque standard-lit selection on Metal, Vulkan
and OpenGL, with one SSS view per engine. WebGPU currently rejects enabling
the effect because its depth attachment needs a compatible texture binding.
Configure the view with
MSAA, fog, stereo, SSR and transparent/refractive composition disabled. Unsupported
selection and existing incompatible view settings are rejected. Subsequent scene
changes must continue to honor engine preconditions. Masked surfaces may occlude
selected objects, but cannot be selected. Custom surface shading and post-lighting
color are ineligible. The diffuse pass requires three simultaneous color attachments.

Apple M2 Pro / Metal regressions cover zero strength with post-processing on/off,
depth, coverage, occlusion, direct/indirect specular, emission, diffuse changes,
silhouettes, bones/morphs, independent texture/shadow boundaries, transport groups
and scene units. Measurements are written to
`thermion_dart/test/output/sss_replacement/audit.json`.

The Metal suite and visual demo passed all 19 cases. Vulkan on a GTX 1080 and
OpenGL on Mesa llvmpipe each passed all 18 regression cases. The indirect-specular
fixture compares ordinary rendering with SSS enabled
both before and after selecting the sphere. It requires zero pixels above
1/255 with geometric specular AA. The CPU oracle runs with
`python3 tool/sss_reference.py` from `thermion_dart`.

Hidden and offscreen transport and thin-object transmission are outside this
experiment. Real-character visual quality, frame cost, temporal behavior and
additional GPU backends need qualification before production use.
