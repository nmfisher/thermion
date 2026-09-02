import 'dart:convert';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gltf_animation");
  await testHelper.setup();

  test('getGltfAnimationNames returns the names of all animations in a gltf asset', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb");
      final animationNames = await cube.getGltfAnimationNames();
      expect(animationNames.length, 2);
      expect(animationNames.first, "Animation 1");
    });
  });

  test('play/stop gltf animation', () async {
    await ViewerBuilder(testHelper, bg: kRed).setCameraLookAt(Vector3(3, 4, 15), focus: Vector3.zero()).execute((
      result,
    ) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb", addToScene: true);

      await testHelper.capture(viewer.view, "play_gltf_animation_0");
      final duration = await cube.getGltfAnimationDuration(0);
      final durationNanos = (duration * 1_000_000_000).toInt();

      final halfDurationNanos = durationNanos ~/ 2;
      await cube.playGltfAnimation(0);

      // call update manually so the animation start time is recorded as
      // 1 nanosecond. This won't have moved because it's effectively the
      // first frame
      await FilamentApp.instance!.animationManager.update(1);
      await testHelper.capture(viewer.view, "play_gltf_animation_1");

      // update the animation manager
      await FilamentApp.instance!.animationManager.update(halfDurationNanos);
      await testHelper.capture(viewer.view, "play_gltf_animation_2");

      await FilamentApp.instance!.animationManager.update(durationNanos);
      await testHelper.capture(viewer.view, "play_gltf_animation_3");

      // stop the animation
      await cube.stopGltfAnimationByName("Animation 1");
      // update the animation manager by another second
      await FilamentApp.instance!.animationManager.update(durationNanos + 1);
      // cube should still be at maximum height
      await testHelper.capture(viewer.view, "stop_gltf_animation");
    });
  });

  test('play gltf animation with faster speeds', () async {
    await ViewerBuilder(testHelper, bg: kRed).execute((result) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb", addToScene: true);

      final animationNames = await cube.getGltfAnimationNames();

      expect(animationNames.first, "Animation 1");

      // Test double speed (2.0x)
      await testHelper.capture(viewer.view, "gltf_animation_speed_2x_rest");
      await cube.playGltfAnimation(0, speed: 2.0);
      // need to call update manually so the animation start time is recorded as
      // 3 seconds
      await FilamentApp.instance!.animationManager.update(1_000_000_000);
      // this won't have moved because it's effectively the first frame
      await testHelper.capture(viewer.view, "gltf_animation_speed_2x_start");

      // update the animation manager by 1 second
      await FilamentApp.instance!.animationManager.update(2_000_000_000);
      // cube should be at maximum height (since speed is 2.0x, 0.5s real time =
      // 1s animation time)
      await testHelper.capture(viewer.view, "gltf_animation_speed_2x_1s");

      // stop the animation
      await cube.stopGltfAnimation(0);
    });
  });

  test('play gltf animation with slower speeds', () async {
    await ViewerBuilder(testHelper, bg: kRed).execute((result) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb", addToScene: true);

      final animationNames = await cube.getGltfAnimationNames();

      expect(animationNames.first, "Animation 1");

      // Test half speed (0.5x)
      await testHelper.capture(viewer.view, "gltf_animation_speed_0.5x_rest");
      await cube.playGltfAnimation(0, speed: 0.5);
      // need to call update manually so the animation start time is recorded as
      // 1 second
      await FilamentApp.instance!.animationManager.update(1_000_000_000);
      // this won't have moved because it's effectively the first frame
      await testHelper.capture(viewer.view, "gltf_animation_speed_0.5x_start");

      // update the animation manager by 1 second
      await FilamentApp.instance!.animationManager.update(2_000_000_000);
      // cube should be halfway to maximum height (since speed is 0.5x)
      await testHelper.capture(viewer.view, "gltf_animation_speed_0.5x_1s");

      // stop the animation
      await cube.stopGltfAnimation(0);
    });
  });

  test('play gltf animation with loop', () async {
    await ViewerBuilder(testHelper).addSun().setCameraLookAt(Vector3(3, 4, 15), focus: Vector3.zero()).execute((
      result,
    ) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb", addToScene: true);

      final duration = await cube.getGltfAnimationDuration(0);
      final durationNanos = (duration * 1_000_000_000).toInt();
      final halfDurationNanos = durationNanos ~/ 2;

      await cube.playGltfAnimation(0, loop: true);
      final am = FilamentApp.instance!.animationManager;

      // First update records the animation start time; elapsed = 0.
      await am.update(1);

      // should show cube at rest
      await testHelper.capture(viewer.view, "gltf_loop_1");

      // should show cube at max Y-axis
      await am.update(halfDurationNanos);
      await testHelper.capture(viewer.view, "gltf_loop_2");

      // should show cube at max X-axis (subtract 1000 because)
      await am.update(durationNanos - 10000);
      await testHelper.capture(viewer.view, "gltf_loop_3");

      await am.update(durationNanos + (halfDurationNanos ~/ 2));
      await testHelper.capture(viewer.view, "gltf_loop_4");
    });
  });

  test('crossfade animations', () async {
    await ViewerBuilder(testHelper).addSun().setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero()).execute((
      result,
    ) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb", addToScene: true);
      await cube.playGltfAnimation(0);
      await FilamentApp.instance!.animationManager.update(1);
      await FilamentApp.instance!.animationManager.update(500_000_000);
      await testHelper.capture(viewer.view, "gltf_crossfade_animation1");
      await cube.playGltfAnimation(1, crossfade: 0.5, replaceActive: true);
      await FilamentApp.instance!.animationManager.update(510_000_000);
      await FilamentApp.instance!.animationManager.update(750_000_000);

      await testHelper.capture(viewer.view, "gltf_crossfade_animation2");
    });
  });

  // Regression for the setGltfAnimationTime render-thread bug. setGltfAnimationTime
  // previously applied morph-target weights synchronously on the caller's thread,
  // tripping Filament's backend "isThisThread(mThreadId)" assertion (a DEBUG-only
  // check) for any glTF animation that drives morph weights — every call panicked.
  // cube_with_morph_targets.glb has morph targets but its animations only drive
  // translation/rotation/scale, so it never exercised the morph path; this asset's
  // sole animation targets the mesh 'weights' path, so scrubbing it does. In a debug
  // build this test panicked before the render-thread dispatch fix and passes after.
  test('setGltfAnimationTime on a morph-weight animation', () async {
    await ViewerBuilder(testHelper, bg: kRed).setCameraLookAt(Vector3(0, 0, 4), focus: Vector3.zero()).execute((
      result,
    ) async {
      final viewer = result.viewer;
      // The asset is constructed in-memory (a glb whose only animation targets
      // the mesh 'weights' path) rather than shipped as a file — see
      // _buildMorphWeightAnimGlb below.
      final asset = await viewer.loadGltfFromBuffer(_buildMorphWeightAnimGlb(), addToScene: true);

      final duration = await asset.getGltfAnimationDuration(0);
      expect(duration, greaterThan(0));

      // Each call applies the animation's morph weights; pre-fix this panicked
      // in debug on the very first call.
      await asset.setGltfAnimationTime(0, duration / 2);
      await testHelper.capture(viewer.view, "set_gltf_animation_time_mid");

      await asset.setGltfAnimationTime(0, duration);
      await testHelper.capture(viewer.view, "set_gltf_animation_time_end");
    });
  });
}

// Builds a minimal glTF binary (.glb) in memory: a single triangle with two
// morph targets, plus one animation whose only channel targets the mesh
// 'weights' path. That channel is what routes applyAnimation through
// RenderableManager::setMorphWeights (the path that must run on the render
// thread) — the smallest possible asset that exercises it.
Uint8List _buildMorphWeightAnimGlb() {
  // Buffer layout (all float32): base positions, target0 positions, target1
  // positions, animation input times, animation output weights.
  final base = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
  final target0 = Float32List.fromList([0, 0, 0, 2, 0, 0, 0, 1, 0]); // stretch +X
  final target1 = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 2, 0]); // stretch +Y
  final animIn = Float32List.fromList([0, 1]);
  // 2 keyframes x 2 targets: t=0 -> weights [0,0], t=1 -> weights [1,0].
  final animOut = Float32List.fromList([0, 0, 1, 0]);

  final bin = Uint8List(
    base.lengthInBytes + target0.lengthInBytes + target1.lengthInBytes + animIn.lengthInBytes + animOut.lengthInBytes,
  );
  var off = 0;
  for (final list in [base, target0, target1, animIn, animOut]) {
    bin.setRange(off, off + list.lengthInBytes, list.buffer.asUint8List(list.offsetInBytes, list.lengthInBytes));
    off += list.lengthInBytes;
  }

  // Accessors: 0 POSITION, 1/2 morph target positions, 3 anim input, 4 anim output.
  final gltf = {
    'asset': {'version': '2.0'},
    'scene': 0,
    'scenes': [
      {
        'nodes': [0],
      },
    ],
    'nodes': [
      {'mesh': 0},
    ],
    'meshes': [
      {
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'targets': [
              {'POSITION': 1},
              {'POSITION': 2},
            ],
            'material': 0,
          },
        ],
      },
    ],
    'materials': [
      {
        'pbrMetallicRoughness': {
          'baseColorFactor': [1, 1, 1, 1],
          'metallicFactor': 0.0,
          'roughnessFactor': 1.0,
        },
      },
    ],
    'animations': [
      {
        'name': 'MorphWeightAnim',
        'samplers': [
          {'input': 3, 'output': 4, 'interpolation': 'LINEAR'},
        ],
        'channels': [
          {
            'sampler': 0,
            'target': {'node': 0, 'path': 'weights'},
          },
        ],
      },
    ],
    'buffers': [
      {'byteLength': bin.length},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 36, 'target': 34341}, // ARRAY_BUFFER
      {'buffer': 0, 'byteOffset': 36, 'byteLength': 36, 'target': 34341},
      {'buffer': 0, 'byteOffset': 72, 'byteLength': 36, 'target': 34341},
      {'buffer': 0, 'byteOffset': 108, 'byteLength': 8},
      {'buffer': 0, 'byteOffset': 116, 'byteLength': 16},
    ],
    'accessors': [
      {
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'bufferView': 0,
        'min': [0, 0, 0],
        'max': [1, 1, 0],
      },
      {'componentType': 5126, 'count': 3, 'type': 'VEC3', 'bufferView': 1},
      {'componentType': 5126, 'count': 3, 'type': 'VEC3', 'bufferView': 2},
      {
        'componentType': 5126,
        'count': 2,
        'type': 'SCALAR',
        'bufferView': 3,
        'min': [0.0],
        'max': [1.0],
      },
      {'componentType': 5126, 'count': 4, 'type': 'SCALAR', 'bufferView': 4},
    ],
  };

  final json = Uint8List.fromList(utf8.encode(jsonEncode(gltf)));
  final jsonPad = (4 - json.length % 4) % 4;
  final binPad = (4 - bin.length % 4) % 4;
  final total = 12 + 8 + json.length + jsonPad + 8 + bin.length + binPad;

  final out = ByteData(total);
  out.setUint32(0, 0x46546C67, Endian.little); // 'glTF'
  out.setUint32(4, 2, Endian.little); // version
  out.setUint32(8, total, Endian.little);
  var cursor = 12;
  out.setUint32(cursor, json.length + jsonPad, Endian.little);
  out.setUint32(cursor + 4, 0x4E4F534A, Endian.little); // 'JSON'
  out.buffer.asUint8List(cursor + 8, json.length).setAll(0, json);
  cursor += 8 + json.length + jsonPad;
  out.setUint32(cursor, bin.length + binPad, Endian.little);
  out.setUint32(cursor + 4, 0x004E4942, Endian.little); // 'BIN\0'
  out.buffer.asUint8List(cursor + 8, bin.length).setAll(0, bin);
  return out.buffer.asUint8List(out.offsetInBytes, out.lengthInBytes);
}
