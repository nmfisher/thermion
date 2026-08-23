import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

import 'frame_scheduler.dart';

enum _RenderingPauseReason { explicit, lifecycle, textureMutation }

/// Coordinates Flutter lifecycle events with Thermion's frame scheduler.
///
/// Texture ownership remains outside this class. Callers provide the
/// registry-derived surface availability check and the work that should run
/// after each rendered frame.
class NativeRenderingLifecycleController with WidgetsBindingObserver {
  NativeRenderingLifecycleController({
    required bool Function() hasUnavailableSurfaces,
    required Future<void> Function() onFrameRendered,
  }) : _hasUnavailableSurfaces = hasUnavailableSurfaces,
       _onFrameRendered = onFrameRendered;

  static final _logger = Logger('NativeRenderingLifecycleController');

  final bool Function() _hasUnavailableSurfaces;
  final Future<void> Function() _onFrameRendered;
  final _pauseReasons = <_RenderingPauseReason>{};

  bool get _shouldPauseRendering =>
      _pauseReasons.isNotEmpty || _hasUnavailableSurfaces();

  /// Stops callbacks left by a previous initialization and removes this
  /// observer before the engine is initialized again.
  void prepareForInitialization() {
    FrameScheduler.instance.reset();
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Starts the appropriate frame scheduling mode for the current platform.
  Future<void> start() async {
    FrameScheduler.instance.setOnFrame(_renderFrame);

    // Android must keep render admission on the Dart callback/port path.
    // SurfaceProducer consumes ImageReader frames from Android's main looper;
    // a producer loop decoupled from Flutter can fill that pipeline and block
    // acquireLatestImage() on the main thread for seconds.
    if (Platform.isLinux) {
      await _startFlutterSynced();
    } else {
      await FrameScheduler.instance.start();
    }

    WidgetsBinding.instance.addObserver(this);
    _syncLifecycleState();
    if (_shouldPauseRendering) {
      FrameScheduler.instance.pause();
    }
  }

  void stop() {
    FrameScheduler.instance.stop();
    WidgetsBinding.instance.removeObserver(this);
  }

  void pauseExplicitly() {
    _pauseReasons.add(_RenderingPauseReason.explicit);
    FrameScheduler.instance.pause();
  }

  void resumeExplicitly() {
    _pauseReasons.remove(_RenderingPauseReason.explicit);
    resumeRenderingIfReady();
  }

  /// Pauses rendering for registry-owned surface availability callbacks.
  ///
  /// Surface availability is intentionally not copied into [_pauseReasons]:
  /// multiple descriptors can be unavailable independently, so the registry
  /// remains the source of truth.
  void pauseRendering() {
    FrameScheduler.instance.pause();
  }

  void resumeRenderingIfReady() {
    if (!_shouldPauseRendering) {
      FrameScheduler.instance.resume();
    }
  }

  /// Drains the current frame and Filament render thread before [operation].
  ///
  /// The texture mutation reason composes with explicit and lifecycle pauses,
  /// so completing the operation never resumes rendering prematurely.
  Future<T> duringTextureMutation<T>(Future<T> Function() operation) async {
    _pauseReasons.add(_RenderingPauseReason.textureMutation);
    FrameScheduler.instance.pause();
    try {
      while (FrameScheduler.instance.isRendering) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final app = FilamentApp.instance;
      if (app is FFIFilamentApp) {
        await app.drainRequestFrameHooks();
      }
      await app?.flush();
      return await operation();
    } finally {
      _pauseReasons.remove(_RenderingPauseReason.textureMutation);
      resumeRenderingIfReady();
    }
  }

  Future<void> _startFlutterSynced() async {
    final app = FilamentApp.instance as FFIFilamentApp;
    await FrameScheduler.instance.startFlutterSynced(
      targetFps: () => app.targetFramerate,
    );
  }

  Future<void> _renderFrame() async {
    final app = FilamentApp.instance;
    if (app == null) return;

    await app.render();
    await _onFrameRendered();
  }

  bool _suspendForLifecycle() {
    if (!_pauseReasons.add(_RenderingPauseReason.lifecycle)) return false;

    if (Platform.isLinux) {
      // Linux registers one persistent Flutter frame callback. Keep it
      // registered, but stop it from re-arming while the app is hidden.
      FrameScheduler.instance.pause();
    } else {
      FrameScheduler.instance.stop();
    }
    return true;
  }

  Future<void> _resumeFromLifecycle() async {
    if (!_pauseReasons.remove(_RenderingPauseReason.lifecycle)) return;
    if (FilamentApp.instance == null) return;

    if (Platform.isLinux) {
      resumeRenderingIfReady();
    } else {
      await FrameScheduler.instance.start();
      if (_shouldPauseRendering) {
        FrameScheduler.instance.pause();
      } else {
        FrameScheduler.instance.resume();
      }
    }
    _logger.info('App foregrounded, frame scheduler resumed');
  }

  void _syncLifecycleState() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null) {
      didChangeAppLifecycleState(state);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_suspendForLifecycle()) {
          _logger.info('App hidden, frame scheduler suspended');
        }
        break;
      case AppLifecycleState.resumed:
        unawaited(
          _resumeFromLifecycle().catchError((Object error) {
            _logger.severe('Failed to resume frame scheduler: $error');
          }),
        );
        break;
      case AppLifecycleState.inactive:
        // The app can remain visible while inactive (split screen, system UI,
        // or an unfocused desktop window), so rendering remains enabled.
        break;
    }
  }
}
