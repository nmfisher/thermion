import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/scheduler.dart';
import 'package:logging/logging.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/bindings/src/thermion_dart_ffi.g.dart'
    show
        FrameScheduler_start,
        FrameScheduler_stop,
        FrameCallbackFunction,
        FrameScheduler_initDartApi,
        FrameScheduler_startWithPort,
        FrameScheduler_steadyClockUs;

/// Drives per-frame callbacks off the native FrameScheduler (CVDisplayLink /
/// DXGI / AChoreographer / timer) via one of three modes:
///
/// - **Direct callback** (release builds): native calls a Dart function
///   pointer via [ffi.NativeCallable.listener].
/// - **Port mode** (debug builds): native posts messages to a [ReceivePort].
///   Hot-restart safe — messages to dead ports are silently dropped.
/// - **Flutter-synced** (Linux): Flutter's persistent frame callback drives
///   the same Dart callback pipeline as the native display-link sources.
class FrameScheduler {
  FrameScheduler._();

  static final FrameScheduler _instance = FrameScheduler._();

  /// Returns the process-wide singleton.
  static FrameScheduler get instance => _instance;

  /// Called once per admitted frame in every mode.
  Future<void> Function()? _onFrameCallback;

  /// Bind the per-frame callback. Must be called before [start] or
  /// [startFlutterSynced].
  void setOnFrame(Future<void> Function() onFrame) {
    _onFrameCallback = onFrame;
  }

  static final _logger = Logger("FrameScheduler");

  // Dart_InitializeApiDL is per-process; keep as static.
  static bool _dartApiInitialized = false;

  bool _active = false;
  bool _paused = false;
  bool _rendering = false;

  /// True once [startFlutterSynced] has registered a persistent frame
  /// callback. In that mode the loop is driven by Flutter's frame clock
  /// and must be re-armed with [SchedulerBinding.scheduleFrame] on resume.
  bool _flutterSynced = false;
  bool _flutterFrameCallbackRegistered = false;

  ffi.NativeCallable<FrameCallbackFunction>? _frameCallable;
  ReceivePort? _framePort;

  int Function()? _flutterTargetFps;
  int _flutterAppliedFpsLimit = 0;
  int _nextFlutterFrameUs = 0;

  int _diagFrameCount = 0;
  int _diagDropCount = 0;
  int _diagJankCount = 0;
  double _diagMaxFrameMs = 0;
  double _diagSumFrameMs = 0;
  final _diagStopwatch = Stopwatch();
  int _diagTransitSum = 0;
  int _diagTransitCount = 0;
  int _diagTransitMax = 0;

  bool get isActive => _active;
  bool get isPaused => _paused;
  bool get isRendering => _rendering;

  // Monotonic count of frames admitted past both the framerate throttle and
  // in-flight guard. A scheduled frame is not necessarily rendered — the
  // render itself can still fail — so this counts accepted work rather than
  // completions. Never resets, unlike the rolling _diag* counters used for
  // the periodic log line.
  int _scheduledFrameCount = 0;

  /// Total number of frames scheduled (dispatched) since the scheduler was
  /// created. Monotonic; sample deltas to measure scheduled frames-per-second.
  int get scheduledFrameCount => _scheduledFrameCount;

  /// Start the native scheduler. Picks port mode in debug builds on
  /// macOS/iOS/Android/Windows and a direct native callback otherwise.
  ///
  /// Idempotent: a no-op if already active. Guards against a rapid
  /// pause→resume (or an in-flight [start]) double-registering the
  /// callback/port and double-starting the native scheduler.
  Future<void> start() async {
    if (_active) return;
    _active = true;

    final usePortMode =
        kDebugMode &&
        (Platform.isMacOS ||
            Platform.isIOS ||
            Platform.isAndroid ||
            Platform.isWindows);

    if (usePortMode) {
      await _initializePortMode();
    } else {
      _frameCallable = ffi.NativeCallable<FrameCallbackFunction>.listener(
        _onFrame,
      );
      FrameScheduler_start(_frameCallable!.nativeFunction, 60);
    }
  }

  /// Drive the normal frame callback pipeline from Flutter's frame clock.
  ///
  /// Linux uses this because it has no reliable native display-link source
  /// synchronized with Flutter's compositor. Rendering itself is still owned
  /// by the callback installed with [setOnFrame], just like every other mode.
  Future<void> startFlutterSynced({required int Function() targetFps}) async {
    if (_active) return;
    _active = true;
    _flutterSynced = true;
    _flutterTargetFps = targetFps;
    _flutterAppliedFpsLimit = 0;
    _nextFlutterFrameUs = 0;

    // Persistent callbacks cannot be unregistered. Register exactly once for
    // this isolate; stop/reset only deactivate it, and a later start reuses it.
    if (!_flutterFrameCallbackRegistered) {
      SchedulerBinding.instance.addPersistentFrameCallback(_onFlutterFrame);
      _flutterFrameCallbackRegistered = true;
    }
    SchedulerBinding.instance.scheduleFrame();

    _logger.info('Flutter-synced render loop started');
  }

  /// Stop the native scheduler and release the Dart-side callback/port.
  ///
  /// Safe to call when already stopped. Always calls the native stop —
  /// after hot restart the native scheduler may still be running with a
  /// dangling pointer from the previous isolate.
  void stop() {
    _active = false;
    _flutterSynced = false;
    _flutterTargetFps = null;
    _flutterAppliedFpsLimit = 0;
    _nextFlutterFrameUs = 0;

    // Always stop native state even when Dart has just hot-restarted and no
    // longer remembers that the previous isolate started a scheduler.
    FrameScheduler_stop();

    _frameCallable?.close();
    _frameCallable = null;

    _framePort?.close();
    _framePort = null;
  }

  /// Stops all scheduler state and forgets pointers owned by the old engine.
  void reset() {
    stop();
    _paused = false;
    _rendering = false;
    _onFrameCallback = null;
  }

  void pause() => _paused = true;

  /// Clear the pause flag. In Flutter-synced mode this must also re-arm the
  /// frame callback: [pause] stops [_onFlutterFrame] from scheduling the next
  /// frame, so without an explicit [SchedulerBinding.scheduleFrame] the loop
  /// would stay frozen after a background→foreground transition.
  void resume() {
    _paused = false;
    if (_active && _flutterSynced) {
      SchedulerBinding.instance.scheduleFrame();
    }
  }

  Future<void> _initializePortMode() async {
    if (!_dartApiInitialized) {
      FrameScheduler_initDartApi(ffi.NativeApi.initializeApiDLData);
      _dartApiInitialized = true;
    }

    _framePort = ReceivePort();
    _framePort!.listen((message) {
      if (message is List) {
        final frameTimeNanos = message[0] as int;
        final postTimeUs = message[1] as int;
        final recvTimeUs = FrameScheduler_steadyClockUs();
        final transitUs = recvTimeUs - postTimeUs;
        _diagTransitSum += transitUs;
        _diagTransitCount++;
        if (transitUs > _diagTransitMax) _diagTransitMax = transitUs;
        if (transitUs > 2000) {
          _logger.warning(
            '[PORT] transit=${(transitUs / 1000.0).toStringAsFixed(1)}ms',
          );
        }
        if (_diagTransitCount % 120 == 0) {
          final avgMs = _diagTransitSum / (_diagTransitCount * 1000.0);
          _logger.info(
            '[PORT] 120-frame transit avg=${(avgMs).toStringAsFixed(2)}ms '
            'max=${(_diagTransitMax / 1000.0).toStringAsFixed(1)}ms',
          );
          _diagTransitSum = 0;
          _diagTransitCount = 0;
          _diagTransitMax = 0;
        }
        _onFrame(frameTimeNanos);
      } else {
        _onFrame(message as int);
      }
    });

    final nativePort = _framePort!.sendPort.nativePort;
    FrameScheduler_startWithPort(nativePort, 60);

    _logger.info('Frame scheduler started in port mode (hot restart safe)');
  }

  void _onFrame(int frameTimeNanos) {
    // Framerate throttling for this path happens at the native source
    // (dispatchFrame skips dropped vsyncs before this is even called), so no
    // Dart-side gate here — only the callback in-flight guard below.
    final callback = _admitFrameCallback();
    if (callback != null) {
      _runFrameCallback(callback);
    }
  }

  /// Applies the common active, pause, callback, and in-flight gates before a
  /// frame is admitted in any scheduling mode.
  Future<void> Function()? _admitFrameCallback() {
    if (!_active || _paused) return null;
    if (_rendering) {
      // Keep only one callback/render in flight. Frames arriving while Dart
      // or the render thread is still busy are dropped rather than queued.
      _diagDropCount++;
      return null;
    }
    final callback = _onFrameCallback;
    if (callback == null) {
      throw StateError('FrameScheduler.setOnFrame must be called before start');
    }
    return callback;
  }

  /// Runs an admitted callback and records diagnostics.
  void _runFrameCallback(Future<void> Function() callback) {
    _rendering = true;
    _scheduledFrameCount++;
    _diagStopwatch
      ..reset()
      ..start();
    callback()
        .then((_) {
          _diagStopwatch.stop();
          _rendering = false;
          final frameMs = _diagStopwatch.elapsedMicroseconds / 1000.0;
          _diagFrameCount++;
          _diagSumFrameMs += frameMs;
          if (frameMs > _diagMaxFrameMs) _diagMaxFrameMs = frameMs;
          if (frameMs > 20.0) {
            _diagJankCount++;
            _logger.warning(
              '#$_diagFrameCount JANK renderFrame=${frameMs.toStringAsFixed(1)}ms',
            );
          }
          if (_diagFrameCount % 120 == 0) {
            final avgMs = _diagSumFrameMs / 120.0;
            _logger.info(
              '120-frame avg=${avgMs.toStringAsFixed(1)}ms '
              'max=${_diagMaxFrameMs.toStringAsFixed(1)}ms '
              'jank=$_diagJankCount drop=$_diagDropCount',
            );
            _diagJankCount = 0;
            _diagDropCount = 0;
            _diagMaxFrameMs = 0;
            _diagSumFrameMs = 0;
          }
        })
        .catchError((error) {
          _logger.warning('Frame render error: $error');
          _rendering = false;
        });
  }

  void _onFlutterFrame(Duration timeStamp) {
    if (!_active || !_flutterSynced || _paused) return;
    final callback = _admitFrameCallback();
    if (callback != null && _admitFlutterFrameAtTargetFps(timeStamp)) {
      _runFrameCallback(callback);
    }
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Applies the same absolute-deadline pacing used by the native frame
  /// sources. The deadline advances only when a frame can actually run, so a
  /// slow render does not consume future frame slots while it is in flight.
  bool _admitFlutterFrameAtTargetFps(Duration timeStamp) {
    final fps = _flutterTargetFps?.call() ?? 0;
    if (fps <= 0) {
      _flutterAppliedFpsLimit = 0;
      _nextFlutterFrameUs = 0;
      return true;
    }

    final frameTimeUs = timeStamp.inMicroseconds;
    final intervalUs = math.max(1, 1000000 ~/ fps);
    const toleranceUs = 1000;

    if (_flutterAppliedFpsLimit != fps || _nextFlutterFrameUs == 0) {
      _flutterAppliedFpsLimit = fps;
      _nextFlutterFrameUs = frameTimeUs;
    }

    if (_nextFlutterFrameUs > frameTimeUs &&
        _nextFlutterFrameUs - frameTimeUs > toleranceUs) {
      return false;
    }

    if (_nextFlutterFrameUs <= frameTimeUs) {
      final missedIntervals =
          (frameTimeUs - _nextFlutterFrameUs) ~/ intervalUs + 1;
      _nextFlutterFrameUs += missedIntervals * intervalUs;
    } else {
      _nextFlutterFrameUs += intervalUs;
    }
    return true;
  }
}
