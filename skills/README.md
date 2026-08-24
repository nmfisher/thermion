# Thermion agent skills

Installable [agent skills](https://code.claude.com/docs/en/skills) that teach AI
assistants to write correct [Thermion](https://thermion.dev) code — the calls,
parameter names, and footguns that aren't guessable from a generic 3D API.

Each skill is self-contained: inline snippets plus bundled runnable examples,
covering the **Flutter** (`thermion_flutter`) and **pure Dart** (`thermion_dart`,
including headless/offscreen rendering) surfaces equally.

## Install

Copy the skill directories you want into your project's `.claude/skills/` (or
your agent harness's equivalent):

```bash
cp -r path/to/thermion/skills/thermion-lighting  your_project/.claude/skills/
cp -r path/to/thermion/skills/thermion-animation your_project/.claude/skills/
# ...or all of them:
cp -r path/to/thermion/skills/. your_project/.claude/skills/
```

Each skill directory contains a `SKILL.md` (the instructions your agent reads)
and a `references/` folder with complete example programs.

## Skills

| Skill | Use it for |
|---|---|
| `thermion-getting-started` | First scene: viewer creation (ViewerWidget / `createViewer` / headless `FFIFilamentApp`), glTF + IBL + skybox + sun, camera, dispose lifecycle |
| `thermion-loading-gltf` | Loading glTF/GLB, `loadGltf` parameters, entity queries, bounding boxes, GPU instancing, cleanup, visibility layers |
| `thermion-transforms-hierarchy` | Positioning and moving objects — everything is `Matrix4` (there are no `setPosition`/`setRotation` helpers), scene-graph parenting, local vs world transforms |
| `thermion-lighting` | `DirectLight` sun/point/spot, light color & intensity units, IBL, skybox, background color/image |
| `thermion-shadows` | Enabling shadows, shadow types (PCF/VSM/DPCF/PCSS), per-light and per-renderable cast/receive, `ShadowOptions` and cascades |
| `thermion-animation` | glTF animation playback, the `animationManager.update` clock, morph targets, bone/skeletal animation — and the `setGltfAnimationTime` thread-safety trap |
| `thermion-materials` | PBR ubershader (metallic/roughness/emissive/clearcoat/…), unlit & wireframe, parameter setters, textures, swapping materials on assets |
| `thermion-geometry` | Procedural geometry without glTF: `GeometryUtils` primitives, custom vertex/index buffers, `createGeometry` |
| `thermion-camera-input` | Camera `lookAt`/projection/exposure, orbit & free-flight controls, input handlers and sensitivity |
| `thermion-picking-selection` | Click/tap picking via `View.pick`, stencil-pixel highlight outlines, gizmos |
| `thermion-post-processing` | Post-processing toggle, anti-aliasing, bloom, color grading & tone mappers, fog, ambient occlusion |
| `thermion-headless-capture` | Pure-Dart offscreen rendering: headless swapchain, rendering to PNG, render loops |

## Version

These skills reflect the Thermion API on the `develop` branch as of **August
2026**. The API evolves — for the latest reference see [thermion.dev](https://thermion.dev)
and the `examples/` directories in the [thermion repository](https://github.com/nmfisher/thermion).
