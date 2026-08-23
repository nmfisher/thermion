// Integration test that verifies setTargetFramerate changes the rate at which
// render work is accepted — not just an internal interval value.
//
// It counts handlers dispatched past the FrameScheduler's native throttle and
// in-flight guard (via dispatchedFrameCount) over wall-clock windows before and
// after a setTargetFramerate call. The native
// scheduler (CVDisplayLink / CADisplayLink / AChoreographer / DXGI) drives
// the loop, so the numbers reflect work the device actually accepts.
//
// Run on a real target:
//
//   flutter test integration_test/framerate_test.dart -d macos
//   flutter test integration_test/framerate_test.dart -d linux
//   flutter test integration_test/framerate_test.dart -d <device-id>
//
// Requires the example assets (assets/cube.glb, default_env_*.ktx).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
// ignore: implementation_imports
import 'package:thermion_flutter/src/platform/src/frame_scheduler.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Frames-per-second accepted over a [window] of real wall-clock time,
  /// measured with a [Stopwatch] (system clock, unaffected by any test
  /// clock). Lets the native vsync-driven scheduler tick at its own cadence.
  Future<double> measureDispatchedFps(Duration window) async {
    final sw = Stopwatch()..start();
    final start = FrameScheduler.instance.dispatchedFrameCount;
    // Yield to the event loop in small increments so the native scheduler
    // callbacks are delivered while real time elapses.
    while (sw.elapsed < window) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final frames = FrameScheduler.instance.dispatchedFrameCount - start;
    final realSeconds = sw.elapsed.inMicroseconds / 1e6;
    return frames / realSeconds;
  }

  testWidgets('setTargetFramerate lowers dispatched frames-per-second',
      (tester) async {
    ThermionViewer? viewer;
    final sun = DirectLight.sun(direction: Vector3(0.7, -1, -0.8).normalized());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewerWidget(
            assetPath: 'assets/cube.glb',
            skyboxPath: 'assets/default_env_skybox.ktx',
            iblPath: 'assets/default_env_ibl.ktx',
            directLight: sun,
            transformToUnitCube: true,
            initialCameraPosition: Vector3(0, 0, 6),
            manipulatorType: ManipulatorType.ORBIT,
            onViewerAvailable: (v) async {
              viewer = v;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(viewer, isNotNull, reason: 'viewer should be available after init');
    expect(FrameScheduler.instance.isActive, isTrue);

    // onViewerAvailable can run before the debounced ThermionWidget texture
    // allocation has attached its Android swapchain. This test concerns frame
    // pacing rather than pre-attachment rendering state, so wait for the
    // surface instead of depending on that separate behavior.
    final attachmentDeadline = DateTime.now().add(const Duration(seconds: 5));
    var swapChains = await FilamentApp.instance!.getSwapChains();
    while (swapChains.isEmpty && DateTime.now().isBefore(attachmentDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      swapChains = await FilamentApp.instance!.getSwapChains();
    }
    expect(
      swapChains,
      isNotEmpty,
      reason: 'Android rendering surface should be attached before sampling',
    );

    // Ensure continuous rendering is on (a static scene may otherwise render
    // only on demand).
    await viewer!.setRendering(true);

    // Establish a known baseline even if another test or a hot restart left a
    // process-wide cap behind.
    FilamentApp.instance!.setTargetFramerate(60);

    // Let the loop settle, then measure the 60 FPS rate.
    await Future<void>.delayed(const Duration(seconds: 1));
    final defaultFps = await measureDispatchedFps(const Duration(seconds: 2));
    debugPrint(
      'Thermion dispatched FPS: default=${defaultFps.toStringAsFixed(1)}',
    );

    // Sanity: the loop is rendering continuously (not stalled). The absolute
    // rate is bounded by render() cost (debug builds) and the display refresh,
    // so only assert it's clearly alive.
    expect(defaultFps, greaterThanOrEqualTo(15),
        reason: 'loop should render continuously; got $defaultFps');

    // Cap well below the render-limited default and confirm the dispatched rate
    // drops to the cap. 5 FPS is unambiguously below any reasonable default.
    FilamentApp.instance!.setTargetFramerate(5);
    // Give the new interval a moment to take effect.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final lowFps = await measureDispatchedFps(const Duration(seconds: 2));
    debugPrint('Thermion dispatched FPS: limited=${lowFps.toStringAsFixed(1)}');

    expect(lowFps, lessThan(defaultFps / 2),
        reason: '5 FPS cap should schedule far fewer frames than the default '
            '(default=$defaultFps, low=$lowFps)');
    expect(lowFps, closeTo(5, 3),
        reason: '5 FPS cap should schedule ~5 FPS; got $lowFps');

    // Non-Linux platforms destroy and recreate their native scheduler across
    // lifecycle transitions. The process-wide cap must survive that restart.
    if (!Platform.isLinux) {
      FrameScheduler.instance.stop();
      await FrameScheduler.instance.start();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final afterRestartFps =
          await measureDispatchedFps(const Duration(seconds: 2));
      debugPrint(
        'Thermion dispatched FPS: after restart='
        '${afterRestartFps.toStringAsFixed(1)}',
      );
      expect(afterRestartFps, closeTo(5, 3),
          reason: '5 FPS cap should survive scheduler restart; '
              'got $afterRestartFps');
    }

    // Restore and confirm the rate climbs back near the default.
    FilamentApp.instance!.setTargetFramerate(60);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final restoredFps = await measureDispatchedFps(const Duration(seconds: 2));
    debugPrint(
      'Thermion dispatched FPS: restored=${restoredFps.toStringAsFixed(1)}',
    );
    expect(restoredFps, greaterThan(lowFps * 2),
        reason: 'restoring 60 FPS should raise the rate well above the 5 FPS '
            'cap (low=$lowFps, restored=$restoredFps)');
  }, skip: Platform.isWindows); // TODO: needs a Windows host to run
}
