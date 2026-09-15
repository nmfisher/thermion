# Screen-space subsurface scattering (SSS) for skin

Implementation notes for the fullscreen-quad SSS pass added in
`thermion_dart`. This is step 1 of a two-step plan: a cheap, engine-agnostic
implementation that uses only public Filament APIs. A later step may move the
scattering into the Filament engine itself.

---

## Why screen space, and why a fullscreen quad

Filament v1.76.0 gives us nothing to build scattering from directly:

1. **No engine-side SSS.** Filament has exactly five shading models — `UNLIT`,
   `LIT`, `SUBSURFACE`, `CLOTH`, `SPECULAR_GLOSSINESS`. `SUBSURFACE` is
   Barre-Brisebois' cheap transmittance approximation, not diffusion; its own
   shader comment says the BTDF "is not physically based and does not represent
   a correct interpretation of transmission events". Filament issue #809 (open
   since 2019) records the maintainers stating that no SSS work is planned and
   that they take contributions; discussion #9531 asking for subsurfacence has
   no replies.
2. **No public post-process hook.** `filament/include/filament/View.h` only
   exposes `setPostProcessingEnabled(bool)`. `PostProcessManager` is internal,
   and `MaterialDomain::POST_PROCESS` materials cannot be run from the public
   API — there is no place to insert a custom fullscreen pass into Filament's
   own frame graph.
3. **Custom MRT outputs are UNLIT-only.** `MaterialBuilder` rejects extra
   outputs on anything but unlit surface materials, so a LIT skin material
   cannot write per-pixel "thickness" or "is skin" into a side buffer while the
   main pass renders.

So the effect has to be built out of ordinary `View`s that thermion's
`RenderManager` submits in a fixed order, sampling textures produced by earlier
views. That is exactly the structure thermion already uses for the highlight
overlay (`SilhouetteView` → `EdgeDetectionView`), so the SSS pass follows it.

## Pipeline

Five views are attached to the swapchain, submitted in this order by
`RenderManager` (it renders views 0..n in ascending render order):

| order | view                             | renders into                          |
|-------|----------------------------------|---------------------------------------|
| 0     | `SssSkinMaskView`                | skin coverage mask, full resolution   |
| 1     | the main view (redirected)       | scene colour + depth, full resolution |
| 2     | `SssBlurView` (horizontal)       | scatter buffer A, reduced resolution  |
| 3     | `SssBlurView` (vertical)         | scatter buffer B, reduced resolution  |
| 4     | `SssCompositeView`               | the main view's original target       |

Each pass view is a `View` whose scene holds a single oversized triangle drawn
with an orthographic camera covering clip space, so the material's `screenUV`
variable sweeps [0,1] exactly once across the output. This is the same
construction as `EdgeDetectionView`; `SssFullscreenPassView` holds the shared
scaffolding.

Enabling SSS **takes over the main view's render target**: the view is
redirected into an internal colour/depth pair so the later passes have
something to sample, and the composite pass writes to whatever the main view
was targeting before. That is also why SSS and the highlight overlay are
mutually exclusive — both want to redirect the main view. `enable()` throws a
descriptive `StateError` if the highlight overlay is already on.

### Pass 0 — skin mask

`SssSkinMaskView` re-renders the assets marked as skin as solid white into its
own render target (black clear). Because limitation 3 above means coverage
cannot be captured from the LIT main pass, the geometry is submitted a second
time with the already-embedded white unlit material. The geometry is *reused*,
not copied: `addSkin` pulls the asset's existing vertex/index buffers exactly as
`setStencilHighlight` does, so the asset must be loaded with
`accessibleGeometryBuffers`.

The mask view contains only the skin assets, so skin occluded by other geometry
is still marked as covered (see *Known weaknesses*).

### Passes 2 and 3 — separable, depth-aware, chromatic blur

One material (`materials/sss_blur.mat`) serves both directions; `direction`
selects the axis. For each tap `i` of a 9-tap symmetric Gaussian:

- the tap is weighted by `exp(-|depth_tap - depth_center| * depthFalloff)`, so
  colour does not bleed across silhouettes or in from the background. Depth is
  linearised to view-space distance before the difference is taken;
- the tap is weighted by the skin mask, so non-skin pixels contribute no
  scattered energy;
- each colour channel is sampled at its own radius — red furthest, blue least.
  This chromatic split is the main visual cue of skin.

The result is normalised by the weight that *survived* the depth and mask tests,
not by the raw kernel sum. Normalising by the raw sum leaves a dark rim just
inside the skin silhouette where most taps have been rejected.

The two passes run at reduced resolution (`blurResolutionScale`, default 0.5).
The horizontal pass reads the full-resolution scene colour; the vertical pass
reads the horizontal pass' output, so the Dart side scales the radius down by
the same factor for that pass to keep the radius meaning "full-resolution
screen pixels" in the public API.

### Pass 4 — composite

`materials/sss_composite.mat` lerps between the un-scattered scene colour and
the reduced-resolution scatter buffer. `scattered` is sampled at full
resolution with linear filtering, which is the upsample. The blend factor is
`intensity * mask`, so nothing outside the skin is touched.

Because the composite is the last pass and writes into a destination Filament
does not sRGB-encode for it (see below), it applies the sRGB transfer function
itself in the shader.

## Colour space

Every texture that carries colour — the scene colour target, both scatter
buffers — is `SRGB8_A8`. The GPU encodes on write and linearises on sample, so
every pass, including the blur, runs in linear space, and nothing in the chain
gets gamma-corrected twice. This matches what `HighlightOverlayManager` already
does for the main view target and is documented there as the fix for a
brightness shift.

The skin mask is plain `RGBA8` instead. It holds coverage, not radiance: 0 and
1 are both fixed points of the sRGB curve, and a plain UNORM target keeps the
values the mask is filtered between linear, so an sRGB format would only cost
bandwidth and precision here.

The destination the composite writes to is different: it is the main view's
previous target, normally thermion's swapchain, a linear RGBA8 target with
post processing off. The GPU does not encode on write there, so a linear value
would land in the framebuffer un-encoded and the final image would come out
darker than the same scene rendered without the effect — measured at a factor
of about 2.2 in the sRGB mid range before this was fixed. The composite
therefore ends with an explicit `linearToSrgb` on its RGB output. Alpha is
coverage and is left alone. Consequence: if you pass an `outputRenderTarget`
whose colour attachment is already an sRGB format to
`SubsurfaceScatteringManager.enable`, the composite will encode twice and the
result will be too bright. Pass a linear target there.

The trade-off is that 8-bit sRGB is LDR: highlights that bloom above 1.0 are
clipped before they are scattered, and sRGB quantisation can band inside very
wide, very soft scatter. An `RGBA16F` chain would fix both, at the cost of
doubled bandwidth in the buffers that are sampled most.

Filament's post-processing is disabled on every pass view: the pass outputs are
raw colour buffers that the next pass reads back, so tonemapping, bloom and
anti-aliasing would corrupt them.

### Filament gotcha: the pass materials must not use `blending: opaque`

Both pass materials are unlit, write the whole frame and need no blending, so
`blending: opaque` looks like the right choice. It silently produces an empty
frame: with `blending: opaque` the quad never rasterises, on the OpenGL backend
under llvmpipe at least. `blending: transparent` (what `edge_outline.mat` uses)
rasterises normally. With `depthWrite: false` and alpha 1.0 the two should be
equivalent, so this looks like a Filament bug rather than intended behaviour;
it is called out here because it cost real time to find and because it will
bite anyone who re-runs `matc` on these files after "simplifying" the blending
mode.

## Parameters

`SubsurfaceScatteringParameters`, reachable through
`view.getSubsurfaceScattering()` after enabling:

| parameter              | default | meaning                                                        |
|------------------------|---------|----------------------------------------------------------------|
| `radiusRed`            | 12.0    | red scatter radius, full-resolution screen pixels              |
| `radiusGreen`          | 7.0     | green scatter radius                                           |
| `radiusBlue`           | 4.0     | blue scatter radius                                            |
| `depthFalloff`         | 25.0    | inverse view-space distance; higher = tighter, less bleed      |
| `intensity`            | 0.9     | 0..1 lerp between un-scattered and scattered colour            |
| `blurResolutionScale`  | 0.5     | blur pass resolution relative to the main view, clamped 1/8..1 |
| `depthAware`           | true    | set false to ignore the depth buffer                           |
| `maskAware`            | true    | set false to scatter the whole frame                           |

Plus the material-level `depthRange` (near/far, from the view's camera) and
`orthographic` (auto-detected from the projection matrix), both supplied by the
manager.

## Usage

```dart
// The asset needs accessible geometry buffers, like setStencilHighlight.
final asset = await viewer.loadGltf(
  "file://$path",
  requiredGeometryCapabilities: const {SceneAssetGeometryCapability.accessibleGeometryBuffers},
);

await viewer.view.setSubsurfaceScatteringEnabled(true);

final sss = viewer.view.getSubsurfaceScattering()!;
await sss.addSkin(asset);
await sss.setParameters(SubsurfaceScatteringParameters(
  radiusRed: 14.0,
  radiusGreen: 8.0,
  radiusBlue: 5.0,
));

// later
await viewer.view.setSubsurfaceScatteringEnabled(false);
```

## Known weaknesses

- **No behind-geometry scattering.** Real SSS lets light wrap thin features and
  appear on geometry facing away from the light. A screen-space blur of the
  colour buffer cannot do either: it only averages what is already visible.
  Backlit ears and nostrils still need Filament's `SUBSURFACE` transmittance
  term, which this pass does not replace.
- **Silhouette scatter is one-sided.** The scatter source is the visible skin,
  so the glow cannot extend outside the skin's silhouette further than the
  kernel radius, and it is attenuated by the mask weighting near the edge.
  Adding a dilated mask would trade that back for a halo.
- **Occluded skin is still masked.** The mask view contains only skin, so skin
  hidden behind a wall still receives scatter. The depth-aware blur keeps the
  effect on the skin's own pixels, and the composite's mask gate keeps it off
  everything else, but a fully occlusion-aware mask would need the occluders
  rendered into the mask pass.
- **Blur buffers are LDR.** See *Colour space* above.
- **View budget.** Five views are attached to the swapchain and
  `RenderManager` takes at most eight, so at most three remain for other
  overlays. The highlight overlay uses three more, which is why the two are
  mutually exclusive here rather than merely awkward.
- **Ordering relative to TAA / DoF.** The composite pass writes straight to the
  output with post-processing disabled, so it sits *after* the main view's
  tonemapping and anti-aliasing. Consequences: the scatter is computed on
  already-tonemapped colour (not strictly correct, but stable), TAA's
  history-rejection does not see the scatter and will not smear it, and any
  depth-of-field or motion blur Filament applies inside the main view's
  post-process happens before the scatter, so blurred backgrounds will scatter
  their own softness into nearby skin.
- **Scene-scale dependent.** `depthFalloff` is in inverse view-space units, so
  a scene modelled in millimetres and a scene modelled in kilometres need
  different values. The radii are in screen pixels, so the physical scatter
  distance changes with zoom — the usual and accepted limit of screen-space SSS.

## What is verified, and on what

The native library and the Dart tests were built and run in this repository's
Linux container, on the OpenGL backend over Mesa llvmpipe (software rasteriser,
GL 4.5), Filament feature level 3, at 256x256. `dart test
test/subsurface_scattering_tests.dart` passes all five tests, including:

- enabling the pass and setting `intensity: 0` reproduces the frame rendered
  without the effect **bit-exactly** (0 differing pixels out of 65536), which
  exercises the whole chain — mask pass, redirected main view, both blurs,
  composite, sRGB encode — and proves the pass adds nothing when told to do
  nothing;
- switching `intensity` to 1 changes a substantial part of the frame and leaves
  the corners of the frame, which are background, untouched;
- parameters round-trip into the material instances and `blurResolutionScale`
  is clamped to 1/8..1.

Not verified here, and worth checking on a real GPU before shipping: any
backend except OpenGL/llvmpipe (Vulkan, Metal, WebGPU/WebGL — the material
blobs are compiled for all of them but none has been executed), MSAA and TAA
interaction, a real skin asset with a human-scale depth range, performance
(software rasteriser timings are meaningless), and the visual tuning of the
default radii, which were chosen to be sane for a 1000-pixel-wide viewport and
have only been seen at 256x256.

## Files

| file | role |
|------|------|
| `materials/sss_blur.mat` | separable, depth-aware, chromatic blur |
| `materials/sss_composite.mat` | composites scatter back over the scene |
| `thermion_dart/lib/src/filament/src/implementation/sss_fullscreen_pass_view.dart` | shared fullscreen-pass scaffolding, `SssBlurView`, `SssCompositeView` |
| `thermion_dart/lib/src/filament/src/implementation/sss_skin_mask_view.dart` | skin coverage mask |
| `thermion_dart/lib/src/filament/src/implementation/subsurface_scattering_manager.dart` | ordering, render targets, parameters |
| `thermion_dart/native/src/c_api/TMaterialInstance.cpp` | `Material_createSssBlurMaterial`, `Material_createSssCompositeMaterial` |
| `thermion_dart/native/src/c_api/ThermionDartRenderThreadApi.cpp` | their render-thread wrappers |
| `thermion_dart/test/subsurface_scattering_tests.dart` | pass chain, masking and parameter tests |
| `docs/screen-space-subsurface-scattering.md` | this document |

## References

- Jimenez et al., *Separable Subsurface Scattering* (Eurographics 2015) —
  <https://github.com/iryoku/separable-sss>
- Colin Barre-Brisebois, *Approximating Translucency for a Fast, Cheap and
  Convincing Subsurface Scattering Look* (GDC 2011) —
  <https://colinbarrebrisebois.com/2011/03/07/gdc-2011-approximating-translucency-for-a-fast-cheap-and-convincing-subsurface-scattering-look/>
- Penner & Borshukov, *Pre-Integrated Skin Shading* (GDC 2011)
- *Physically Based Shading in Theory and Practice* course notes —
  <https://blog.selfshadow.com/publications/s2015-shading-course/>
- Unreal Engine, *Subsurface Profile* —
  <https://dev.epicgames.com/documentation/en-us/unreal-engine/subsurface-profile-in-unreal-engine>
- Filament materials guide — <https://google.github.io/filament/Materials.html>
