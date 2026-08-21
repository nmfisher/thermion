// Integration test for the Flutter app-lifecycle handling added in
// `feat/flutter-lifecycle` (WidgetsBindingObserver + FrameScheduler).
//
// Two layers are exercised:
//
// 1. A deterministic, OS-independent suite that drives FrameScheduler's
//    *public* API (stop/start/pause/resume) directly. This validates the
//    stop→start round-trip and the start() idempotency guard without any
//    interference from the host OS.
// 2. A lenient end-to-end check that synthesizes AppLifecycleState events
//    through the binding. On desktop targets the real window also emits
//    lifecycle events (e.g. `inactive` on focus loss), which race with the
//    synthesized ones — so we only assert the scheduler *recovers* to
//    active+unpaused, not the exact intermediate state.
//
// The strongest regression guarded against: the Flutter-synced (Linux) loop
// freezing permanently after background→foreground because `resume()` failed
// to re-arm the frame callback. That specific path only runs under
// `startFlutterSynced` (Linux), so `-d linux` is where it's truly exercised.
//
// Run on a real target:
//
//   flutter test integration_test/lifecycle_test.dart -d macos
//   flutter test integration_test/lifecycle_test.dart -d linux
//   flutter test integration_test/lifecycle_test.dart -d <device-id>
//
// Requires the example assets (assets/cube.glb, default_env_*.ktx).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
// ignore: implementation_imports
import 'package:thermion_flutter/src/platform/src/frame_scheduler.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntilCompleted(
    WidgetTester tester,
    Completer<void> completion, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (!completion.isCompleted && stopwatch.elapsed < timeout) {
      // Linux OpenGL initialization needs a frame containing the deferred
      // bootstrap Texture before Filament can import Flutter's EGL context.
      await tester.pump(const Duration(milliseconds: 16));
    }
    if (!completion.isCompleted) {
      throw TimeoutException('Future not completed', timeout);
    }
    await completion.future;
  }

  Future<void> pumpViewer(WidgetTester tester) async {
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
          ),
        ),
      ),
    );
    // Wait for the viewer + plugin to initialize (and the FrameScheduler to
    // start).
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Desktop test runners are not always able to foreground the app. The
    // plugin correctly suspends when initialization observes that hidden
    // state, so normalize the harness to resumed before tests that expect an
    // active scheduler. Walk through the synthesized intermediate states to
    // keep Flutter's lifecycle state machine consistent.
    final binding = WidgetsBinding.instance;
    switch (binding.lifecycleState) {
      case AppLifecycleState.paused:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        break;
      case AppLifecycleState.hidden:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        break;
      case AppLifecycleState.resumed:
      case null:
        break;
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  // ---- Layer 1: deterministic, direct FrameScheduler drive -----------------

  testWidgets('FrameScheduler stop/start round-trip is clean and idempotent',
      (tester) async {
    await pumpViewer(tester);
    expect(FrameScheduler.instance.isActive, isTrue,
        reason: 'scheduler should be active after initialize');

    // stop() must flip active off and tolerate being called while a frame is
    // in flight.
    FrameScheduler.instance.stop();
    expect(FrameScheduler.instance.isActive, isFalse);

    // start() must bring it back.
    await FrameScheduler.instance.start();
    expect(FrameScheduler.instance.isActive, isTrue);

    // A second start() must be a no-op (the idempotency guard) — not throw,
    // not double-register the native callback.
    await FrameScheduler.instance.start();
    expect(FrameScheduler.instance.isActive, isTrue);
  }, skip: Platform.isWindows); // TODO: needs a Windows host to run

  testWidgets('pause/resume toggles isPaused without tearing down the loop',
      (tester) async {
    await pumpViewer(tester);
    expect(FrameScheduler.instance.isActive, isTrue);

    FrameScheduler.instance.pause();
    expect(FrameScheduler.instance.isPaused, isTrue);
    expect(FrameScheduler.instance.isActive, isTrue,
        reason: 'pause keeps the scheduler active');

    FrameScheduler.instance.resume();
    expect(FrameScheduler.instance.isPaused, isFalse);
    expect(FrameScheduler.instance.isActive, isTrue);
  }, skip: Platform.isWindows); // TODO: needs a Windows host to run

  // ---- Layer 2: end-to-end via the binding (lenient) -----------------------

  testWidgets('lifecycle hidden/paused resumes the scheduler cleanly',
      (tester) async {
    // Exercise SurfaceProducer's callback-capable path on Android as well as
    // the default SurfaceTexture path covered by the tests above.
    if (Platform.isAndroid) {
      ThermionFlutterPlugin.instance.setOptions(
        const ThermionFlutterOptions(
          nativeOptions: NativeOptions(
            androidTextureSource: AndroidTextureSource.surfaceProducer,
          ),
        ),
      );
      addTearDown(() {
        ThermionFlutterPlugin.instance.setOptions(
          const ThermionFlutterOptions(),
        );
      });
    }

    await pumpViewer(tester);
    expect(FrameScheduler.instance.isActive, isTrue);

    void setLifecycle(AppLifecycleState state) =>
        WidgetsBinding.instance.handleAppLifecycleStateChanged(state);

    // Drive the FULL lifecycle sequence in both directions
    // (resumed→inactive→hidden→paused→hidden→inactive→resumed), not a bare
    // paused→resumed jump.
    //
    // Why: SchedulerBinding.handleAppLifecycleStateChanged flips
    // `framesEnabled` to false on paused/hidden/detached. While that flag is
    // false, scheduleFrame() is a no-op, so tester.pump() — which on the
    // integration-test (live) binding waits for a real engine frame to fire
    // handleDrawFrame — never completes. Pumping *during* the paused window
    // therefore deadlocks. By walking through every state and ending at
    // resumed (which restores framesEnabled and calls scheduleFrame), the
    // frame loop is re-armed before we pump, so the post-resume pumps can
    // drive frames and the test makes progress.
    //
    // (Flutter also ignores duplicate consecutive states, so the states must
    // be distinct — hence the full round-trip rather than repeated
    // paused→resumed.)
    //
    // All pumping happens AFTER resumed, while framesEnabled is true.
    for (var i = 0; i < 2; i++) {
      setLifecycle(AppLifecycleState.inactive);
      setLifecycle(AppLifecycleState.hidden);

      // Desktop platforms stop at hidden and never enter paused. Linux keeps
      // its persistent Flutter callback registered but prevents it re-arming.
      if (Platform.isLinux) {
        expect(FrameScheduler.instance.isActive, isTrue);
        expect(FrameScheduler.instance.isPaused, isTrue);
      } else {
        expect(FrameScheduler.instance.isActive, isFalse);
      }

      setLifecycle(AppLifecycleState.paused);
      setLifecycle(AppLifecycleState.hidden);
      setLifecycle(AppLifecycleState.inactive);
      setLifecycle(AppLifecycleState.resumed);
      for (var j = 0; j < 10; j++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    expect(FrameScheduler.instance.isActive, isTrue,
        reason: 'scheduler must recover to active after resume');
    expect(FrameScheduler.instance.isPaused, isFalse,
        reason: 'pause flag must be cleared after resume');

    // A lifecycle round-trip must not override an explicit caller pause.
    ThermionFlutterPlugin.instance.pauseFrameScheduler();
    setLifecycle(AppLifecycleState.inactive);
    setLifecycle(AppLifecycleState.hidden);
    setLifecycle(AppLifecycleState.inactive);
    setLifecycle(AppLifecycleState.resumed);
    for (var j = 0; j < 10; j++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(FrameScheduler.instance.isActive, isTrue);
    expect(FrameScheduler.instance.isPaused, isTrue,
        reason: 'foregrounding must preserve an explicit pause');

    ThermionFlutterPlugin.instance.resumeFrameScheduler();
    expect(FrameScheduler.instance.isPaused, isFalse);
  }, skip: Platform.isWindows); // TODO: needs a Windows host to run

  testWidgets('repeated full viewer creation and removal tears down resources',
      (tester) async {
    for (var iteration = 0; iteration < 3; iteration++) {
      final available = Completer<void>();
      final disposalStarted = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewerWidget(
              assetPath: 'assets/cube.glb',
              skyboxPath: 'assets/default_env_skybox.ktx',
              iblPath: 'assets/default_env_ibl.ktx',
              directLight: DirectLight.sun(
                direction: Vector3(0.7, -1, -0.8).normalized(),
              ),
              onViewerAvailable: (viewer) async {
                viewer.onDispose(() async {
                  if (!disposalStarted.isCompleted) {
                    disposalStarted.complete();
                  }
                });
                if (!available.isCompleted) {
                  available.complete();
                }
              },
            ),
          ),
        ),
      );

      await pumpUntilCompleted(tester, available);
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpUntilCompleted(tester, disposalStarted);

      // Viewer disposal continues with scene/view/camera destruction after
      // onDispose callbacks. Give that render-thread work time to drain before
      // creating the next viewer.
      await tester.pump(const Duration(milliseconds: 500));
    }
  }, skip: Platform.isWindows); // TODO: needs a Windows host to run
}
