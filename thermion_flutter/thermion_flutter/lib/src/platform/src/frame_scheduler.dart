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
        FrameScheduler_startWithCallback,
        FrameScheduler_stop,
        FrameTickCallbackFunction,
        FrameScheduler_initDartApi,
        FrameScheduler_startWithPort,
        FrameScheduler_steadyClockUs;

/// Dispatches a frame handler from platform timing ticks via one of three
/// modes:
///
/// - **Direct tick** (release builds): native calls a Dart function
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

  /// Work dispatched once for each accepted timing tick.
  Future<void> Function()? _frameHandler;

  /// Bind the work dispatched for each accepted tick. Must be called before
  /// [start] or [startFlutterSynced].
  void setFrameHandler(Future<void> Function() handler) {
    _frameHandler = handler;
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
  bool _flutterTickCallbackRegistered = false;

  ffi.NativeCallable<FrameTickCallbackFunction>? _tickCallable;
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

  // Monotonic count of handlers dispatched past both the framerate throttle
  // and in-flight guard. A dispatched handler is not necessarily a completed
  // render, so this counts started work rather than completions. Never resets,
  // unlike the rolling _diag* counters used for the periodic log line.
  int _dispatchedFrameCount = 0;

  /// Total number of frame handlers dispatched since the scheduler was
  /// created. Monotonic; sample deltas to measure dispatched frames per second.
  int get dispatchedFrameCount => _dispatchedFrameCount;

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
      _tickCallable = ffi.NativeCallable<FrameTickCallbackFunction>.listener(
        _handleNativeFrameTick,
      );
      FrameScheduler_startWithCallback(_tickCallable!.nativeFunction, 60);
    }
  }

  /// Drive the normal frame callback pipeline from Flutter's frame clock.
  ///
  /// Linux uses this because it has no reliable native display-link source
  /// synchronized with Flutter's compositor. Rendering itself is still owned
  /// by the handler installed with [setFrameHandler], just like every other
  /// mode.
  Future<void> startFlutterSynced({required int Function() targetFps}) async {
    if (_active) return;
    _active = true;
    _flutterSynced = true;
    _flutterTargetFps = targetFps;
    _flutterAppliedFpsLimit = 0;
    _nextFlutterFrameUs = 0;

    // Persistent callbacks cannot be unregistered. Register exactly once for
    // this isolate; stop/reset only deactivate it, and a later start reuses it.
    if (!_flutterTickCallbackRegistered) {
      SchedulerBinding.instance.addPersistentFrameCallback(
        _handleFlutterFrameTick,
      );
      _flutterTickCallbackRegistered = true;
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

    _tickCallable?.close();
    _tickCallable = null;

    _framePort?.close();
    _framePort = null;
  }

  /// Stops all scheduler state and forgets pointers owned by the old engine.
  void reset() {
    stop();
    _paused = false;
    _rendering = false;
    _frameHandler = null;
  }

  void pause() => _paused = true;

  /// Clear the pause flag. In Flutter-synced mode this must also re-arm the
  /// frame callback: [pause] stops [_handleFlutterFrameTick] from scheduling
  /// the next frame, so without an explicit [SchedulerBinding.scheduleFrame]
  /// the loop would stay frozen after a background→foreground transition.
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
        _handleNativeFrameTick(frameTimeNanos);
      } else {
        _handleNativeFrameTick(message as int);
      }
    });

    final nativePort = _framePort!.sendPort.nativePort;
    FrameScheduler_startWithPort(nativePort, 60);

    _logger.info('Frame scheduler started in port mode (hot restart safe)');
  }

  void _handleNativeFrameTick(int frameTimeNanos) {
    // Framerate throttling for this path happens at the native source
    // (handleSourceTick skips rejected ticks before this is even called), so no
    // Dart-side gate here — only the handler in-flight guard below.
    _tryDispatchFrame();
  }

  /// Applies the common active, pause, handler, and in-flight gates, then
  /// dispatches one frame handler. An optional source-specific gate can reject
  /// the tick before work starts (Linux uses it for target-FPS pacing).
  bool _tryDispatchFrame({bool Function()? sourceGate}) {
    if (!_active || _paused) return false;
    if (_rendering) {
      // Keep only one handler/render in flight. Ticks arriving while Dart
      // or the render thread is still busy are dropped rather than queued.
      _diagDropCount++;
      return false;
    }
    final handler = _frameHandler;
    if (handler == null) {
      throw StateError(
        'FrameScheduler.setFrameHandler must be called before start',
      );
    }
    if (sourceGate != null && !sourceGate()) return false;

    _runFrameHandler(handler);
    return true;
  }

  /// Runs a dispatched frame handler and records diagnostics.
  void _runFrameHandler(Future<void> Function() handler) {
    _rendering = true;
    _dispatchedFrameCount++;
    _diagStopwatch
      ..reset()
      ..start();
    handler()
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

  void _handleFlutterFrameTick(Duration timeStamp) {
    if (!_active || !_flutterSynced || _paused) return;
    _tryDispatchFrame(
      sourceGate: () => _admitFlutterTickAtTargetFps(timeStamp),
    );
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Applies the same absolute-deadline pacing used by the native frame
  /// sources. The deadline advances only when a frame can actually run, so a
  /// slow render does not consume future frame slots while it is in flight.
  bool _admitFlutterTickAtTargetFps(Duration timeStamp) {
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
