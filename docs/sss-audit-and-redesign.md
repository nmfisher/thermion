# PR 353: rendering audit and replacement design

Status: the old architecture below was rejected and replaced locally. The new
engine pass and Thermion integration are implemented; current behavior, build
dependency, GPU results and remaining limits are documented in
[screen-space-subsurface-scattering.md](screen-space-subsurface-scattering.md).
The findings below describe the superseded implementation. The proposed richer
profile API and rollout criteria remain design targets, not claims of completed
cross-platform or production validation.


The current replacement addresses this finding with explicit post-scatter albedo,
normalized Christensen–Burley diffusion, and separate painted-edge/shadow-edge
GPU tests. The new ball keeps its 2.66 px texture transition; the flat shadow
profile matches the independent analytic integral within 1.1% and the matched
Cycles Burley render within 1.9%. See the current implementation document above
for the radius conversion and the remaining five-pixel specular-AA regression.
The analysis and proposed Gaussian design below are retained as history; they
do not describe the current profile or attachment contract.

## Resolved material-model failure in the intermediate Gaussian

The 2026-09-17 Cycles comparison exposed a problem in the intermediate Gaussian replacement as well.
Fixing depth reconstruction repaired the Gaussian's physical scale but did not
validate the material model. Both direct and indirect diffuse inputs already
contain `pixel.diffuseColor`. The gather therefore convolves colored outgoing
diffuse radiance: approximately `G * (albedo * lighting)`. It cannot distinguish
texture detail from an equivalent lighting variation in that input buffer.

At a central grid edge in the existing 640-pixel ball renders, the display-space
red-channel 10–90% transition is 2.67 pixels with Thermion SSS off, 4.91 pixels at
0.6 mm, and 7.76 pixels at 1.2 mm. Cycles measures 2.76, 2.75, and 2.76 pixels.
This is a local texture-sharpness measurement, not a physical radius estimate.
It averages rows 316–324, normalizes using columns 310–314 and 327–332, and
interpolates the threshold crossings. Reproduction and original-image crops:
`/private/tmp/thermion-sss-blender/audit_texture_edge.py` and
`/private/tmp/thermion-sss-blender/texture-edge-audit.html`.

Cycles 4.5 [records albedo at the camera-side surface hit and uses a unit-weight
diffuse closure at the random-walk exit](https://github.com/blender/blender/blob/v4.5.0/intern/cycles/kernel/integrator/subsurface.h).
Its [walk coefficients depend on that albedo and radius](https://github.com/blender/blender/blob/v4.5.0/intern/cycles/kernel/integrator/subsurface_random_walk.h).
This differs materially from filtering neighboring pixels' shaded albedos.
Neither this observation nor Cycles' behavior establishes that all texture
diffusion is wrong. The spatial interpretation of albedo must be defined.
[HDRP exposes post-scatter and split pre/post-scatter texturing](https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.high-definition/Runtime/Material/SubsurfaceScattering/SubsurfaceScattering.hlsl),
demonstrating an explicit choice missing from the current prototype.

The Gaussian plane regression expects a black/white material edge to blur. It
tests the implemented filter and caught the depth error; it is not an independent
skin-model test. Before treating this implementation as ready, separate albedo
from diffuse lighting, define their roles in the chosen scattering model, and
validate a texture edge under uniform illumination separately from a shadow edge
on uniform material. Use a documented profile and radius convention; merely
moving albedo outside the same Gaussian does not establish Cycles agreement.
Specular separation and visibility fixes remain useful integration work.

Audit target: PR head `468d9618e1b061320fbe4a03dea45a3e1ab59bd4` plus the
uncommitted repairs in `/private/tmp/thermion-pr353-review`, branch
`fix/pr353-sss`. GPU measurements: Apple M2 Pro / Metal, 2026-09-16.
Do not generalize these measurements to untested backends.

## Findings and evidence

### 1. The input is the wrong lighting quantity

`materials/sss_blur.mat` samples the completed scene color. The composite mixes
that filtered image back into the completed image. This spreads specular
reflections and emission as well as diffuse light. With post-processing enabled
it also filters after Filament's tone/color mapping. Converting sRGB values back
to linear does not undo a tone curve, clipped highlights, bloom, or color grading.
RGBA16F storage does not restore that information either.

This is the principal reason that a grid and its highlights look smeared. Smaller
radii can hide the symptom but cannot give the pass the lighting data it lacks.

Some diffusion of *diffuse* texture/color is legitimate. Preserving every albedo
edge is not a universal physical requirement. The hard requirements are that
surface reflections remain separate, transport distances have a defined scale,
and the diffusion operates on a defined linear-light quantity.

### 2. Visibility is wrong, independently of the kernel

The skin-only mask scene does not contain opaque occluders. Consequently skin
behind a foreground object marks that object's pixels as eligible for scattering.
Comparing depth between foreground pixels cannot detect the absent skin identity.
An asset-wide selection also cannot distinguish skin, eyes, teeth, and clothing
within one renderable. The replacement must select material primitives.

The repaired mask has an additional reproducible coverage failure. A transformed,
rotated white cuboid covers 4,934 pixels in the ordinary scene capture, but the
mask disagrees at **30,604 of 65,536 pixels**. Its capture shows a large polygon
instead of the cuboid. This establishes failure of the current mask path; it does
not establish whether material substitution, compiled variants, or view state is
the underlying cause. The earlier animation tests only asserted changing pixels.
They did not prove that mask pixels followed the visible surface.

In a separate scene, a checkerboard object fully hides the selected skin sphere.
Enabling SSS changes **26,471 foreground pixels** by more than 1/255, with a
maximum channel difference of **0.20392**. Expected: zero. Both mask faults can
contribute to this measurement; the skin-only visibility error also follows
directly from the scene construction.

### 3. Depth input is not established

The external scene depth attachment, sampled through the existing blur shader
with zero radius and all rejection disabled, reads zero across the diagnostic
image, both with and without post-processing. AA is explicitly disabled and the
main view is captured before sampling. This is an end-to-end failure of the
current depth-consumption path, not proof of a particular driver fault.

Exact Filament v1.76.0 source also shows why assuming the external attachment is
the post-processing depth is unsafe: `RendererUtils::colorPass` allocates its own
depth resource, `Renderer.cpp` resolves that internal depth for post-processing,
and forwards the final **color** resource to the imported view target. When color
is rendered through an intermediate target, merely attaching a sampleable depth
texture to the destination does not export internal scene depth into it.
The no-post-processing zero-depth case still needs isolation; do not claim the
post-processing explanation alone accounts for both measurements.

### 4. The filter has no coherent spatial contract

- Radii are fixed screen pixels, so the apparent material changes with distance,
  field of view, output resolution, and asset units.
- RGB colors are read at three different positions, while all three use depth
  and mask from the red position. A valid red tap does not imply valid green/blue
  taps. The shader's comment claiming no visible gain from correct checks is false.
- Linear texture sampling can interpolate across invalid geometry *before* a
  nearest surface/depth check. Acceptance must account for the sampling footprint.
- A half-resolution intermediate plus bilinear upsampling adds uncontrolled
  filtering to the nominal profile and misaligns silhouettes with full-resolution
  compositing. Full resolution is required for the correctness baseline.
- The default 90% mix and broad Gaussian spread much of the local signal. Ignoring
  interpolation and boundary rejection, the two-pass kernel leaves only
  `0.1 + 0.9 * 0.227027^2 = 0.1464` of an impulse at its original texel. This is
  illustrative of the aggressive filter, not a measurement of the final image.
- Renormalizing surviving taps avoids some dark edges but alters the profile
  near boundaries. It does not repair visibility, spectral leakage, or recover
  offscreen/hidden light transport.

### Historical captures and current acceptance

The original failure captures remain locally under `test/output/sss_audit/`.
They were produced from the repaired implementation, not an untouched PR build.
`tool/sss_audit_test.dart` now runs the replacement regression suite; its captures
are under `test/output/sss_replacement/`. The obsolete beauty-blur pipeline and
its shaders have been deleted, so the historical failure suite no longer runs
against the replacement API.

## Historical first replacement design (superseded by Burley)

Implement **opaque diffuse screen-space diffusion inside Filament's frame graph**.
This is a local surface diffusion approximation, not full volumetric transport.
Thin-ear transmission, hidden surfaces, and offscreen illumination require
additional information and are not reconstructed by this first implementation.

For each visible opaque pixel retain two independently accumulated quantities:

```
D = linear HDR outgoing diffuse radiance (direct + indirect, including albedo)
B = linear HDR bypass radiance (specular, coat, emission, non-SSS contributions)
C = B + (1 - strength) * D + strength * diffuse(D, profile, visibility)
```

Use Filament's existing exposure convention consistently in both buffers. No
transfer function or tone curve is applied between lighting and recombination.
Do not reconstruct D by subtracting two separately rendered beauty images, or
recover irradiance by dividing final color by a near-zero albedo.

V1 deliberately diffuses outgoing diffuse radiance, including its pigment
variation. This is a specified approximation. If a later skin model splits
pigment between entry and exit, it must emit the corresponding lighting terms
directly and add a separate reference; a sharpen pass is not a substitute.

### Buffers and visibility

| Resource | Required meaning |
|---|---|
| Diffuse | RGBA16F, linear HDR D, zero for non-participating surfaces |
| Bypass | RGBA16F, complete unfiltered B; non-SSS pixels retain ordinary shading |
| Depth | Actual opaque pass depth with the renderer's projection convention |
| Guide | Nearest visible primitive's transport-group/profile ID, geometric normal, strength |
| Scatter | Full-resolution linear HDR diffusion result |

Produce the guide with the same opaque visibility, depth, camera jitter, skinning,
morphs, vertex deformation, culling, and material coverage as the color pass.
Non-SSS opaque geometry must write ID zero and occlude selected skin. Primitive
membership belongs to the material/renderable data, not a second skin-only scene.
Different objects default to different transport groups; explicitly join only
surfaces intended to exchange light. Do not silently merge all skin into one group.

Use nearest guide reads. The correctness gather uses point color reads at those
same positions. Any bilinear optimization must validate its contributing texels.
Reject other groups/profiles and incompatible reconstructed surface geometry.
Depth rejection should use a world-distance scale relative to the profile;
account for smooth surface slope so a tilted plane does not become a hard edge.
Geometric normals gate transport; normal-map detail must not break the surface
into false boundaries.

V1 scope: opaque dielectric standard-lit participating materials, single-sample,
full resolution. Non-participating opaque objects may use their normal materials.
Reject unsupported participating material models explicitly. Cutouts,
transparency/refraction, fog, stereo, and MSAA need separately validated integration
before claiming support; do not silently render them through an incorrect ordering.

### Diffusion profile and scale

Use a normalized, nonnegative radial RGB profile. Start with a direct 2D gather
as the quality reference. A sum of normalized radial Gaussians is a convenient
reference representation:

```
R_c(r) = sum_j a_jc * exp(-r*r / (2*sigma_jc*sigma_jc)) / (2*pi*sigma_jc*sigma_jc)
sum_j a_jc = 1
```

The `sigma` values are standard deviations in millimeters, not arbitrary pixel
radii or unqualified mean free paths. The test coefficients are synthetic and
must not ship as a validated human-skin preset. A production preset needs a cited
profile fit and validation against a suitable face asset/reference render.

Convert millimeters using explicit `metersPerUnit`. Project the footprint using
the current projection and view-space position, refreshed every frame. For
centered perspective axes, `sigma_px = sigma_world * abs(P_axis) * viewport_axis /
(2 * abs(clip_w))`; orthographic `clip_w` is constant. General custom projections
require the local projection Jacobian. Integrate the near-center pixel footprint
and truncated tail rather than point-sampling a singular or subpixel profile.

All RGB weights use **common sample positions**. Normalize each channel before
visibility rejection. Return rejected/offscreen tap mass to the center. This
preserves a constant field and avoids introducing background color, but is an
explicit boundary approximation, not a globally energy-conserving, reciprocal
BSSRDF. Keep the original guide for every pass.

A later two-pass implementation must be fitted and compared with this radial
reference. Multiplying two independently mixed 1D Gaussian kernels introduces
cross terms and is not the same as a sum of radial Gaussians. Either scatter each
Gaussian separately then sum, or use a documented separable approximation with
measured error. Do not adopt a generic Gaussian merely because it fits two passes.

### Frame order and concrete engine changes

```
opaque visibility + split direct/indirect lighting
        -> diffuse diffusion -> HDR recombination
        -> supported transparent/fog composition
        -> TAA -> remaining Filament post-processing -> output conversion
```

This cannot be installed as another Dart `View`. Filament v1.76.0 has no public
insertion point exposing these buffers. Material custom outputs are restricted
to opaque unlit materials; custom surface shading handles direct-light evaluation
and is not a complete split direct+indirect lighting interface.

Implement the dependency in a narrowly scoped Filament patch:

1. Add opt-in primitive/profile data and a lighting variant that accumulates
   diffuse and bypass separately. Cover `surface_shading_model_standard.fs` direct
   lighting and `surface_light_indirect.fs` indirect lighting, including existing
   diffuse attenuation and AO. Verify D+B matches the ordinary shader with SSS off.
2. Extend color-pass resources and material compiler output declarations for the
   required attachments. Emit visibility guides from that same draw path. Select
   exact guide formats after checking simultaneous attachment limits and format
   support on each backend; capability detection is mandatory.
3. Add diffusion/recombination in `PostProcessManager`/`RendererUtils` and wire it
   through `details/Renderer.cpp`. Disable early color-grading subpasses/custom
   tone resolves while these HDR inputs are needed. For initial opaque-only
   validation, disable incompatible fog/transparency/refraction paths explicitly.
   Supporting them later needs an opaque/blended pass split, not just inserting
   a filter after today's combined color pass. Recombine before TAA; invalidate
   history on profile/material changes.
4. Expose typed options to Thermion after the engine contract passes. Rebuild
   matching Filament libraries, headers, matc/ubershaders and material blobs, then
   run root `make materials` and `make bindings`. Shader-package version equality
   alone is insufficient evidence that a patched compiler/runtime pair matches.

Do not replace glTF materials with a white override, consume four extra public
view slots, or make this effect own the application's final render target.
Filament owns transient buffers and pass lifetime. Thermion owns profile handles
and selection. Proposed API: register an RGB diffusion profile; bind it and a
transport-group ID per renderable primitive; configure strength and scene units
per view. No screen-pixel radii, `maskAware=false`, or `depthAware=false` production
escape hatches. Strength zero bypasses allocation/passes and uses ordinary shading.

At 1080p, each additional RGBA16F full-resolution buffer costs about 15.8 MiB;
two additional buffers alone cost about 31.6 MiB before guides/temporaries. The
reference gather is intentionally expensive. Profile CPU/GPU time and memory on
target devices before selecting packing, sample count, or reduced-resolution
optimizations. None of those optimizations belong in the correctness baseline.

If maintaining this engine patch is unacceptable, choose a separately scoped
material/preintegrated skin approximation with explicit limitations. Stock
Filament's `subsurface` shading model is not a drop-in lateral diffusion pass.
Do not retain the beauty-image blur under the same physical claim.

## Acceptance and rollout

The original `tool/sss_reference.py` ran seven numerical contracts for the proposed
math: zero strength, specular/emission bypass, constant HDR fields, visible
non-skin identity, RGB group/depth rejection, normalized chromatic impulse, and
projection scaling. This reference is a flat-surface discrete model, not a
replacement renderer and not evidence that the GPU implementation passes.

Before production use, require these actual renderer checks:

| Test | Acceptance |
|---|---|
| D+B, zero strength | Matches ordinary rendering within quantified attachment rounding; no extra tone mapping |
| Specular/emissive-only fixture | Unchanged highlights, even at maximum strength |
| Hidden skin and visible non-skin | No changes above 1/255 in opaque LDR captures; separate HDR tolerance |
| Asymmetric silhouette, bones, morphs | Guide agrees with visible primitive coverage, not merely changing pixels |
| Thin/interleaved RGB surfaces | No invalid source texel contributes to any channel |
| Depth, PP on/off, orthographic/perspective | Valid guide reconstruction agrees with known geometry |
| Constant HDR field, impulse | DC preserved; measured RGB profile matches the reference and declared approximation error |
| Distance, FOV, resolution, unit changes | Projected profile follows the physical footprint; scene rescaling preserves appearance |
| Animated/jittered camera | No lagging mask, halo, or stale profile history |
| Real face, matched lighting | Sharp surface reflections; plausible diffuse spread; no silhouette contamination |
| Metal, Vulkan, GL/WebGL, WebGPU | Actual supported-device rendering checks, not compilation alone |

Land separately, with explicit dependencies: (1) engine lighting/visibility split
and identity tests; (2) diffusion against the reference; (3) Thermion bindings,
selection, lifecycle and replacement of the five-view implementation; (4) optional
optimization/expanded coverage. Do not merge PR 353 as the foundation while these
contracts remain unmet. The existing local repairs remain available for comparison.

## Source anchors

- [Separable SSS paper and reference resources](https://www.cg.tuwien.ac.at/research/publications/2015/Jimenez_SSS_2015/): radial diffusion and separable approximation.
- [Reference implementation](https://github.com/iryoku/separable-sss/blob/master/SeparableSSS.h): pre-tonemap placement, projection/depth scaling, common offsets with RGB weights, and rejected-sample center replacement.
- [Filament v1.76.0 renderer](https://github.com/google/filament/blob/v1.76.0/filament/src/details/Renderer.cpp): intermediate target selection, internal resolved depth, post-processing and final color forwarding.
- [Filament v1.76.0 color pass](https://github.com/google/filament/blob/v1.76.0/filament/src/RendererUtils.cpp): depth/resource creation and color attachment setup.
- [Direct lighting](https://github.com/google/filament/blob/v1.76.0/shaders/src/surface_shading_model_standard.fs), [indirect lighting](https://github.com/google/filament/blob/v1.76.0/shaders/src/surface_light_indirect.fs): diffuse/specular accumulation before summation.
- [MaterialBuilder restrictions](https://github.com/google/filament/blob/v1.76.0/libs/filamat/src/MaterialBuilder.cpp) and [material authoring](https://github.com/google/filament/blob/v1.76.0/docs/Materials.md.html): custom outputs and surface-shading scope.
