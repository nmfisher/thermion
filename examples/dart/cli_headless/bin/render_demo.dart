// Headless renderer: produces a looping demo video of the BusterDrone under a
// Filament HDRI skybox, with the camera smoothly orbiting + dollying while the
// glTF animation plays.
//
// Resolution + aspect are selectable via `--preset` (desktop 16:9 or iphone
// portrait); each preset renders into its own output/frames_<preset>/ folder.
// Encode each separately with ffmpeg (<preset> = desktop | iphone):
//
//   ffmpeg -framerate 120 -i output/frames_<preset>/frame_%04d.png \
//     -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" -crf 18 \
//     output/drone_demo_<preset>.mp4
//
//   ffmpeg -i output/drone_demo_<preset>.mp4 \
//     -vf "fps=30,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
//     output/drone_demo_<preset>.gif
//   # (add scale=W:-1 or scale=-1:H inside the -vf to resize; for the tall
//   #  portrait preset, cap height e.g. scale=-1:800 to keep the gif sane)
//
// All motion is periodic over one full clip (t in [0,1)), so the loop is seamless
// — handy for a gif.

import 'dart:io' as io;
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

// ---------------------------------------------------------------------------
// Tunable parameters
// ---------------------------------------------------------------------------
const int fps = 120;
// Long enough to capture the drone's full glTF animation (CINEMA_4D_Basis,
// ~25s) end-to-end at authored (1x) speed. -> 3000 frames at 120fps.
const int durationSeconds = 25;

// Output resolution + framing presets. Switch with `--preset=<name>`; each
// preset renders into its own output/frames_<name>/ folder so they coexist.
//   desktop: 16:9 1280x720 (landscape — README/web).
//   iphone:  19.5:9 1170x2532 (portrait — iPhone 15 Pro point resolution).
// All framing is per-preset: a tall portrait frame is much narrower
// horizontally, so the drone (wider than it is tall) needs a larger orbit
// radius plus a gentler dolly to stay framed without clipping at the sides.
class _Preset {
  const _Preset(this.name, this.width, this.height, this.vfovDegrees,
      this.radiusCenter, this.radiusAmplitude, this.heightCenter, this.heightAmplitude);
  final String name;
  final int width;
  final int height;
  final double vfovDegrees;
  final double radiusCenter;
  final double radiusAmplitude;
  final double heightCenter;
  final double heightAmplitude;
  double get aspect => width / height;
}

const Map<String, _Preset> presets = {
  'desktop': _Preset('desktop', 1280, 720, 45.0, 4.0, 1.3, 0.8, 0.5),
  'iphone': _Preset('iphone', 1170, 2532, 45.0, 10.5, 0.4, 1.0, 0.3),
};
const String defaultPreset = 'desktop';

const String droneAsset = 'examples/assets/BusterDrone/scene.gltf';

// Each environment is an HDRI converted to KTX (IBL + skybox) via Filament's
// cmgen. Override at runtime with `--env=<name>`.
const String defaultEnv = 'the_sky_is_on_fire';
const Map<String, _Env> envs = {
  'lightroom_14b': _Env('examples/assets/lightroom_14b/lightroom_14b'),
  'studio_small_02': _Env('examples/assets/studio_small_02/studio_small_02'),
  'the_sky_is_on_fire':
      _Env('examples/assets/the_sky_is_on_fire/the_sky_is_on_fire'),
  'syferfontein_18d_clear':
      _Env('examples/assets/syferfontein_18d_clear/syferfontein_18d_clear'),
};

class _Env {
  const _Env(this.prefix);
  final String prefix;
  String get skybox => '${prefix}_skybox.ktx';
  String get ibl => '${prefix}_ibl.ktx';
}

// The BusterDrone's native bounding box (object-space, as reported by
// Filament's gltfio loader). Used to normalize the asset into a unit cube so
// the camera math below is scale-free. Deterministic for this glTF.
//   center (-0.001, -47.52, 0.0), extent (155.88, 65.30, 180.0)
final Aabb3 droneBox = Aabb3.minMax(
  Vector3(-77.94, -80.17, -90.0),
  Vector3(77.94, -14.87, 90.0),
);

// Camera motion. All orbit/dolly parameters are per-preset (see _Preset) so
// framing adapts to the aspect ratio; the integer cycle counts below are shared
// so the motion is periodic over one clip -> seamless loop. The drone is
// normalized to a unit cube at the origin first, so these are small fixed values.
const int dollyCycles = 2; // dolly periods per clip (integer => seamless)
const int heightCycles = 1; // height periods per clip
const int orbitTurns = 1; // full revolutions per clip
final Vector3 focus = Vector3(0.0, 0.0, 0.0); // drone look-at (post-normalize)

const double iblIntensity = 30000.0;

// glTF animation playback. The BusterDrone's only animation ("CINEMA_4D_Basis",
// index 0) drives the rotors/rig. We activate it (looping) and advance it on the
// render thread each frame. Note: setGltfAnimationTime() applies morph weights
// synchronously off the render thread and trips Filament's backend thread
// assertion on this asset — so we use animationManager.update(dt) instead,
// which advances active animations on the render thread. dt = 1/fps plays the
// animation at its authored (1x) speed.
const int gltfAnimIndex = 0;
const double animSpeed = 1.0; // animation playback speed multiplier

// Supplemental point lights. The sunset IBL sets the mood; these add crisp,
// moving specular highlights on the drone's metal as the camera orbits. Each is
// a fixed world-space position; intensity is luminous flux in lumens.
class _PointLight {
  _PointLight(this.position, this.color, this.intensity, this.falloff);
  final Vector3 position;
  final LinearColor color;
  final double intensity; // lumens
  final double falloff; // world units
}

final List<_PointLight> pointLights = [
  _PointLight(Vector3(3.5, 2.5, 2.0), LinearColor(1.0, 0.82, 0.55), 90000, 8.0), // warm key
  _PointLight(Vector3(-3.2, 1.6, -1.5), LinearColor(0.55, 0.72, 1.0), 60000, 8.0), // cool fill
  _PointLight(Vector3(0.0, 3.8, -3.5), LinearColor(1.0, 1.0, 1.0), 70000, 8.0), // white rim
];

// ---------------------------------------------------------------------------

Future<void> main(List<String> argv) async {
  // Resolve the repo root from this script's location (bin/render_demo.dart ->
  // ../../../../), so the script works regardless of the cwd it's launched from.
  final scriptDir = p.dirname(io.Platform.script.toFilePath());
  final repoRoot = p.normalize(p.join(scriptDir, '..', '..', '..', '..'));
  final assetUri = (String rel) =>
      'file://${p.join(repoRoot, rel)}';

  // Resolution + framing preset. `--preset=<name>` selects one.
  final presetName = argv.any((a) => a.startsWith('--preset'))
      ? argv.firstWhere((a) => a.startsWith('--preset')).split('=')[1]
      : defaultPreset;
  final preset = presets[presetName] ??
      (throw ArgumentError(
          'Unknown preset "$presetName". Available: ${presets.keys}'));
  final width = preset.width;
  final height = preset.height;
  print('Preset: $presetName (${width}x$height, '
      'aspect ${preset.aspect.toStringAsFixed(3)})');

  final framesDir =
      io.Directory(p.join(scriptDir, '..', 'output', 'frames_${preset.name}'));
  if (framesDir.existsSync()) {
    framesDir.deleteSync(recursive: true);
  }
  framesDir.createSync(recursive: true);

  await FFIFilamentApp.create(
    config: FFIFilamentConfig(
      // The default loader does raw File(path) and chokes on the `file://`
      // scheme, so strip it (matching the test harness's loadResourceBytes).
      loadResource: (uri) async {
        final path = uri.replaceAll('file://', '');
        return io.File(path).readAsBytes();
      },
    ),
  );
  final app = FilamentApp.instance!;
  final sc = await app.createHeadlessSwapChain(width, height);

  final viewer = ThermionViewerFFI(app: app as FFIFilamentApp);
  await viewer.initialized;
  // Attach the view to the swapchain so rendering has a target.
  await app.renderManager.attach(viewer.view, sc);

  // Disable frustum culling so the drone never pops out near frame edges.
  await viewer.view.setFrustumCullingEnabled(false);
  await viewer.setViewport(width, height);
  // ACES tone mapping for filmic, non-blow-out highlights.
  final builder = await viewer.view.createColorGradingBuilder();
  final toneMapper = await ToneMapper.aces(app);
  final colorGrading = await builder.toneMapper(toneMapper).build();
  await builder.dispose();
  await toneMapper.dispose(); // builder disposed; grading holds a copy
  await viewer.view.setColorGrading(colorGrading);

  // Environment: HDRI skybox + image-based lighting. `--env=<name>` selects one.
  // `--no-skybox` skips the visible skybox (background goes black) but keeps the
  // IBL for lighting — handy for measuring the subject's silhouette/framing
  // without a busy background.
  final noSkybox = argv.contains('--no-skybox');
  final envName = argv.any((a) => a.startsWith('--env'))
      ? argv.firstWhere((a) => a.startsWith('--env')).split('=')[1]
      : defaultEnv;
  final env = envs[envName] ??
      (throw ArgumentError('Unknown env "$envName". Available: ${envs.keys}'));
  print('Environment: $envName${noSkybox ? " (no skybox)" : ""}');
  if (!noSkybox) {
    await viewer.loadSkybox(assetUri(env.skybox));
  }
  await viewer.loadIbl(assetUri(env.ibl), intensity: iblIntensity);

  // Subject: the BusterDrone.
  final drone = await viewer.loadGltf(assetUri(droneAsset), releaseSourceData: true);

  // Normalize the drone into a unit cube centered at the origin. Don't use
  // drone.transformToUnitCube(): its getBoundingBox() reads the root entity,
  // which has no renderable component and yields a bogus box for this asset.
  // Pass the known native box to the transform manager instead.
  app.transformManager.transformToUnitCube(drone.entity, droneBox);

  // Activate the drone's animation (rotors). We advance it on the render thread
  // each frame via animationManager.update() — see the note on gltfAnimIndex.
  await drone.playGltfAnimation(gltfAnimIndex, loop: true, speed: animSpeed);
  final animDuration = await drone.getGltfAnimationDuration(gltfAnimIndex);

  final camera = await viewer.getActiveCamera();
  // Explicit vertical FOV makes the framing math deterministic. The lightroom
  // cyclorama is a very bright HDR capture, so we keep Filament's default
  // exposure (EV100 ~8.3): the background reads as a soft dark-gray studio and
  // the drone's full tonal range (dark camera/gimbal through white arms) is
  // preserved. Opening up clips the cyclorama AND washes the light drone body
  // into the background (verified via histogram sweeps).
  await camera.setProjectionFromVerticalFieldOfView(
      preset.vfovDegrees, 0.1, 1000.0, width / height);

  // Supplemental point lights (key/fill/rim) for moving highlights on the drone.
  for (final l in pointLights) {
    await viewer.addDirectLight(DirectLight.point(
      color: l.color,
      intensity: l.intensity,
      position: l.position,
      falloffRadius: l.falloff,
    ));
  }
  print('Added ${pointLights.length} point lights.');

  // Optional `--frames N` to render a subset (smoke-test framing/lighting).
  final argFrames = argv.any((a) => a.startsWith('--frames'))
      ? int.parse(argv.firstWhere((a) => a.startsWith('--frames')).split('=')[1])
      : null;

  final up = Vector3(0.0, 1.0, 0.0);
  final frameCount = argFrames ?? fps * durationSeconds;

  // Per-frame animation dt: advance the animation by one frame's worth at the
  // authored speed (1/fps * animSpeed). Well within int32 range.
  final animDtNanos = ((1e9 / fps) * animSpeed).round();
  // update() treats its arg as an ABSOLUTE monotonic clock (elapsed = clock -
  // firstClock), not a delta — so we accumulate a synthetic clock that advances
  // by animDtNanos each frame. Start at animDtNanos (not 0) so the manager's
  // "startTime == 0" first-call sentinel triggers exactly once.
  var animClockNanos = 0;
  print('Animation $gltfAnimIndex (duration ${animDuration.toStringAsFixed(2)}s) '
      'at ${animSpeed}x -> dt ${(animDtNanos / 1e6).toStringAsFixed(1)}ms/frame');

  print('Rendering $frameCount frames at ${width}x$height (${fps}fps, '
      '${durationSeconds}s)...');

  // The engine now applies animation-frame-0 on the first update() call (it
  // no longer stamps-and-skips), so no priming is needed: frame 0 of the loop
  // is the true first animation frame.
  for (var i = 0; i < frameCount; i++) {
    final t = i / frameCount; // [0, 1)

    final angle = 2.0 * math.pi * orbitTurns * t;
    final radius = preset.radiusCenter +
        preset.radiusAmplitude * math.cos(2.0 * math.pi * dollyCycles * t);
    final y = preset.heightCenter +
        preset.heightAmplitude * math.sin(2.0 * math.pi * heightCycles * t);

    final pos = Vector3(radius * math.cos(angle), y, radius * math.sin(angle));
    await camera.lookAt(pos, focus: focus, up: up);

    // Advance the glTF animation (rotors) on the render thread for this frame.
    // Pass the accumulated clock (see note above) — update() computes elapsed
    // time from it, so it must increase each frame.
    animClockNanos += animDtNanos;
    await app.animationManager.update(animClockNanos);

    final result = await app.capture(
      sc,
      view: viewer.view,
      pixelDataFormat: PixelDataFormat.RGBA,
      pixelDataType: PixelDataType.FLOAT,
    );
    final pixels = result.first.$2;

    final png = await pixelBufferToPng(
      pixels,
      width,
      height,
      hasAlpha: true,
      isFloat: true,
    );
    final outPath = p.join(framesDir.path, 'frame_${i.toString().padLeft(4, '0')}.png');
    await io.File(outPath).writeAsBytes(png);

    if (i % 15 == 0) {
      print('  frame ${i.toString().padLeft(4, '0')}/$frameCount '
          '(r=${radius.toStringAsFixed(2)})');
    }
  }

  print('Done. Frames in ${framesDir.path}');
  // Hard-exit: Filament's teardown races gltfio material-instance destruction
  // and panics ("N instances still alive") on this asset. It's harmless — the
  // frames are already flushed — but noisy, so we skip it with a clean exit.
  io.exit(0);
}
