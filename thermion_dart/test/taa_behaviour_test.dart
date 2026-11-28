@Timeout(const Duration(minutes: 5))
import 'dart:math';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

/// Behavioural TAA tests. TAA output depends on frame history, jitter and the
/// GPU, so these compare configurations against each other within one run
/// instead of against golden images. Nothing is written to the golden output.
void main() async {
  final testHelper = TestHelper('taa_behaviour');
  await testHelper.setup();

  ViewerBuilder scene() => ViewerBuilder(testHelper)
      .setRenderTargetEnabled(true)
      // TAA (like FXAA) is a post-process; the builder disables it by default.
      .setPostProcessing(true)
      .addCube()
      .addCube(position: Vector3(2.5, 0, -2))
      .addCube(position: Vector3(-2.5, 0.5, -3))
      .setCameraLookAt(Vector3(0, 2, 8));

  Future<Uint8List> frame(View view) async =>
      (await testHelper.capture(view, null, pixelDataType: PixelDataType.UBYTE)).values.first;

  Future orbit(Camera camera, double degrees) async {
    final r = degrees * pi / 180;
    await camera.lookAt(Vector3(8 * sin(r), 2, 8 * cos(r)), focus: Vector3(0, 0, -1));
  }

  List<double> average(List<Uint8List> frames) {
    final out = List<double>.filled(frames.first.length, 0);
    for (final f in frames) {
      for (var i = 0; i < f.length; i++) {
        out[i] += f[i];
      }
    }
    return [for (final v in out) v / frames.length];
  }

  /// Mean |a - ref| over RGB, restricted to pixels near an edge in [ref].
  double edgeError(Uint8List a, List<double> ref, int w, int h) {
    double lum(List<num> px, int x, int y) {
      final i = (y * w + x) * 4;
      return 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2];
    }

    var sum = 0.0;
    var n = 0;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final l = lum(ref, x, y);
        final g =
            (lum(ref, x + 1, y) - l).abs() +
            (lum(ref, x, y + 1) - l).abs() +
            (lum(ref, x - 1, y) - l).abs() +
            (lum(ref, x, y - 1) - l).abs();
        if (g < 20) continue;
        final i = (y * w + x) * 4;
        sum += (a[i] - ref[i]).abs() + (a[i + 1] - ref[i + 1]).abs() + (a[i + 2] - ref[i + 2]).abs();
        n += 3;
      }
    }
    return sum / n;
  }

  /// Mean absolute luminance gradient: higher means crisper edges.
  double gradientEnergy(List<double> px, int w, int h) {
    double lum(int x, int y) {
      final i = (y * w + x) * 4;
      return 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2];
    }

    var sum = 0.0;
    for (var y = 0; y < h - 1; y++) {
      for (var x = 0; x < w - 1; x++) {
        final l = lum(x, y);
        sum += (lum(x + 1, y) - l).abs() + (lum(x, y + 1) - l).abs();
      }
    }
    return sum / ((w - 1) * (h - 1));
  }

  /// Converge, orbit 30 degrees over 20 frames, stop, and return the edge error
  /// of the first frame after the stop relative to the converged image.
  Future<double> errorAfterTurn(TemporalAntiAliasingOptions options) async {
    late double error;
    await scene().execute((result) async {
      final view = result.viewer.view;
      final camera = await view.getCamera();
      final vp = await view.getViewport();
      await view.setAntiAliasing(false, false, true);
      await view.setTemporalAntiAliasingOptions(options);
      await orbit(camera, 0);
      for (var i = 0; i < 30; i++) {
        await frame(view);
      }
      for (var i = 1; i <= 20; i++) {
        await orbit(camera, 30.0 * i / 20);
        await frame(view);
      }
      final firstAfterStop = await frame(view);
      final held = <Uint8List>[];
      for (var i = 0; i < 80; i++) {
        held.add(await frame(view));
      }
      error = edgeError(firstAfterStop, average(held.sublist(60)), vp.width, vp.height);
    });
    return error;
  }

  /// Converged, jitter-averaged image for the given AA setup.
  Future<(List<double>, int, int)> converged({required bool taa, double sharpness = 0}) async {
    late (List<double>, int, int) out;
    await scene().execute((result) async {
      final view = result.viewer.view;
      final vp = await view.getViewport();
      await view.setAntiAliasing(false, false, taa);
      await view.setTemporalAntiAliasingOptions(TemporalAntiAliasingOptions(sharpness: sharpness));
      final frames = <Uint8List>[];
      for (var i = 0; i < 60; i++) {
        frames.add(await frame(view));
      }
      out = (average(frames.sublist(40)), vp.width, vp.height);
    });
    return out;
  }

  test('TAA changes edge pixels', () async {
    final (off, w, h) = await converged(taa: false);
    final (on, _, _) = await converged(taa: true);
    var changed = 0;
    for (var i = 0; i < off.length; i += 4) {
      if ((off[i] - on[i]).abs() + (off[i + 1] - on[i + 1]).abs() + (off[i + 2] - on[i + 2]).abs() > 3) changed++;
    }
    print('pixels changed by TAA: $changed of ${w * h}');
    expect(changed, greaterThan(0));
  });

  test('higher TAA feedback settles faster after a camera turn', () async {
    final slow = await errorAfterTurn(const TemporalAntiAliasingOptions(feedback: 0.04));
    final fast = await errorAfterTurn(const TemporalAntiAliasingOptions(feedback: 0.3));
    print('edge error after turn: feedback 0.04 = $slow, feedback 0.3 = $fast');
    expect(fast, lessThan(slow));
  });

  test('TAA sharpness increases edge contrast', () async {
    final (soft, w, h) = await converged(taa: true, sharpness: 0);
    final (sharp, _, _) = await converged(taa: true, sharpness: 0.5);
    final g0 = gradientEnergy(soft, w, h);
    final g1 = gradientEnergy(sharp, w, h);
    print('gradient energy: sharpness 0 = $g0, sharpness 0.5 = $g1');
    expect(g1, greaterThan(g0));
  });
}
