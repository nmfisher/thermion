---
name: thermion-animation
description: >
  Play and control 3D animation in Thermion: glTF animation clips (play, stop,
  loop, crossfade, speed, reverse, scrubbing), manual morph target / blend
  shape weights, and bone/skeletal animation (bone inspection, BoneAnimationData,
  bone transforms). Includes the critical rule that animations must be ticked
  every frame with animationManager.update and that update takes an absolute
  monotonic clock rather than a delta. Use when playing, pausing, blending,
  scrubbing, or hand-driving character animation.
  Triggers: animation, animations, play
  animation, gltf animation, animation clip, morph target, blend shape, morph
  weights, bone, skeleton, skeletal animation, skinning, crossfade, animation
  speed, loop, scrub, animation manager, reset pose.
---

Thermion supports three kinds of animation, all reached through the
`ThermionAsset` returned by `loadGltf`:

1. **glTF animations** — clips baked into the file,
2. **morph targets** — manually driving blend-shape weights,
3. **bone animation** — hand-built per-bone frame data.

## glTF animation clips

```dart
final asset = await viewer.loadGltf('assets/character.glb');

// Attach an animation component if the asset might not have one:
await asset.addAnimationComponent();

final names = await asset.getGltfAnimationNames(); // e.g. ["Walk", "Run"]
final duration = await asset.getGltfAnimationDuration(0); // seconds

await asset.playGltfAnimation(
  0,
  loop: true,
  crossfade: 0.2,       // seconds to blend in from the current pose
  replaceActive: true,  // stop other clips (default)
  speed: 1.0,           // playback rate multiplier
  startOffset: 0.0,     // begin at this time within the clip
  reverse: false,
);
// or by name:
await asset.playGltfAnimationByName('Walk', loop: true);

await asset.stopGltfAnimation(0);
await asset.stopGltfAnimationByName('Walk');
```

## Ticking: `animationManager.update` — the part everyone misses

Playing a clip does nothing visible until **you advance the clock every
frame**:

```dart
// Flutter: a ticker/timer each frame:
final animationManager = viewer.app.animationManager;
await animationManager.update(elapsedNanos);

// Pure Dart / headless: inside the render loop:
await app.animationManager.update(clockNanos);
```

The argument is an **absolute monotonic clock in nanoseconds**, not a delta —
`update` computes elapsed time as `clock - firstClock`. Accumulate it:

```dart
final dtNanos = (1e9 / fps).round();
var clockNanos = 0;
for (var i = 0; i < frameCount; i++) {
  clockNanos += dtNanos;               // advance by one frame's worth
  await app.animationManager.update(clockNanos); // must increase each call
  // ...render/capture the frame...
}
```

Start the clock at `dtNanos` (not 0) on the first frame so the manager's
"first call" sentinel triggers exactly once. With `speed: s`, use
`dtNanos = (1e9 / fps * s).round()`.

The first `update()` after `playGltfAnimation` applies animation frame 0 —
no extra priming call is needed.

## Scrubbing

`setGltfAnimationTime(index, seconds)` jumps to a specific time. It is
dispatched on the render thread and is safe for morph-target animations.
For continuous playback, prefer `playGltfAnimation` + `animationManager.update`
and control time via `speed`/`startOffset` (or `reverse`) — calling
`setGltfAnimationTime` every frame works but re-scrubs the whole clip each
call.

## Morph targets (blend shapes)

```dart
// Discover every renderable entity with morph targets. Each set exposes the
// exact target order as well as optional glTF names.
final morphs = (await asset.getMorphTargetSets()).single;
// e.g. MorphTarget(index: 0, name: "Open")

await morphs.setWeight("Open", 1.0); // leaves other targets unchanged
await morphs.setWeightAt(1, 0.5);    // works for unnamed targets

// Full-pose updates require exactly one value per target, in target order.
await morphs.setAllWeights(List.filled(morphs.targets.length, 0.0));
```

Keyframed morph animation: build a `MorphAnimationData` and
`await asset.setMorphAnimationData(data, targetMeshNames: [...])`;
clear with `asset.clearMorphAnimationData(entity)`. Active animations overwrite
manual weights on their next tick; clear the custom animation before taking
persistent manual control. When custom animations overlap, the most recently
added animation has priority. Weight changes only show once animation frames
tick (`update` as above).

## Bones / skeletal

```dart
final bones = await asset.getBones();          // List<ThermionEntity>
final boneNames = await asset.getBoneNames();  // aligned List<String>
final count = await asset.getBoneCount();

// Hand-animate: reset to rest pose FIRST, then enqueue animation data.
await asset.resetBones();
await asset.addBoneAnimation(boneAnimationData,
    fadeInInSecs: 0.2, fadeOutInSecs: 0.2, loop: true);

// Or pose a bone directly:
await asset.setBoneTransform(boneIndex, Matrix4.compose(...));
```

`BoneAnimationData(bones, frameData, frameLengthInMs:, space:)` — the `Space`
enum selects how frame rotations are interpreted: `Space.Bone` (default,
rotation around each bone's rest-position local axes),
`Space.ParentWorldRotation` (BVH-style), plus `Space.World` / `Space.Model`.
`resetToRestPose(asset)` is the manager-level equivalent of `resetBones`.

## Gotchas

- **No ticking, no motion** — `playGltfAnimation` alone renders the rest pose.
  Call `animationManager.update` every frame.
- `update` takes an **absolute clock** (accumulate!), and the value must
  increase between calls.
- `setGltfAnimationTime` is render-thread-dispatched and safe for morph
  animations; use it to scrub to an exact time, `playGltfAnimation` +
  `update` for continuous playback (thermion.dev/animations).
- Don't call animation methods while the app is backgrounded (render thread
  paused) — see the "Animations when backgrounded" note at
  https://thermion.dev/filament/.
- Morph weights are an all-targets array — to activate one target, zero the
  rest.
- `resetBones()` before `addBoneAnimation`, or results are unpredictable.
- Per-frame `speed`-scaled dt: `(1e9 / fps * speed).round()`.

## References

- `references/flutter-animation-player.dart` — Flutter app listing an asset's
  clips by name with play/stop/crossfade controls.
- `references/dart-animation-render.dart` — pure-Dart render loop with the
  accumulated-clock update pattern, capturing animated frames to PNGs.

## Docs

- https://thermion.dev/animations/ — animations, morph targets, bones
