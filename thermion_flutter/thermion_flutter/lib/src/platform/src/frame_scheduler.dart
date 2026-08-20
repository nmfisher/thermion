import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
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
        FrameScheduler_setRenderThread,
        FrameScheduler_setRenderManager,
        FrameScheduler_setPostRenderCallback,
        FrameScheduler_requestRender,
        FrameScheduler_steadyClockUs,
        PostRenderCallback,
        TRenderManager;

/// Drives per-frame callbacks off the native FrameScheduler (CVDisplayLink /
/// DXGI / AChoreographer / timer) via one of three modes:
///
/// - **Direct callback** (release builds): native calls a Dart function
///   pointer via [ffi.NativeCallable.listener].
/// - **Port mode** (debug builds): native posts messages to a [ReceivePort].
///   Hot-restart safe — messages to dead ports are silently dropped.
/// - **Flutter-synced** (Linux native render loop): Flutter's persistent
///   frame callback drives a non-blocking native render request. The Dart
///   per-frame hook runs once per frame the native scheduler admits, so it
///   stays 1:1 with rendered frames.
class FrameScheduler {
  FrameScheduler._();

  static final FrameScheduler _instance = FrameScheduler._();

  /// Returns the process-wide singleton.
  static FrameScheduler get instance => _instance;

  /// Called once per admitted frame in every mode: per native-dispatched
  /// frame in direct/port mode, and per native-admitted render request in
  /// Flutter-synced mode.
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

  /// Performs the native render request for the Flutter-synced path and
  /// returns whether the frame was admitted by the native throttle and
  /// in-flight guard. Indirection exists so tests can stub admission
  /// without driving a real render; production always uses
  /// [FrameScheduler_requestRender].
  @visibleForTesting
  bool Function(int frameTimeNanos) requestRender =
      FrameScheduler_requestRender;

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

  /// Configure the native scheduler to run the render loop entirely in
  /// native code, synchronized to Flutter's frame clock via a persistent
  /// frame callback.
  ///
  /// The Dart per-frame callback ([setOnFrame]) runs once per frame the native
  /// scheduler admits — the same 1:1 callback-to-render coupling as the other
  /// modes.
  Future<void> startFlutterSynced({
    required ffi.Pointer<ffi.Void> renderThreadHandle,
    required ffi.Pointer<TRenderManager> renderManagerHandle,
    required PostRenderCallback postRenderCallback,
    required ffi.Pointer<ffi.Void> postRenderUserData,
  }) async {
    if (_active) return;
    _active = true;
    _flutterSynced = true;

    FrameScheduler_setRenderThread(renderThreadHandle);
    FrameScheduler_setRenderManager(renderManagerHandle);
    FrameScheduler_setPostRenderCallback(
      postRenderCallback,
      postRenderUserData,
    );

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
      _runFrameCallback(callback, countAsScheduled: true);
    }
  }

  /// Applies the common active, pause, callback, and in-flight gates before a
  /// frame is admitted in any scheduling mode.
  Future<void> Function()? _admitFrameCallback() {
    if (!_active || _paused) return null;
    if (_rendering) {
      // Do not admit a native Linux render without its corresponding Dart
      // callback. This keeps callbacks and renders 1:1 even when Dart work
      // takes longer than a Flutter frame.
      _diagDropCount++;
      return null;
    }
    final callback = _onFrameCallback;
    if (callback == null) {
      throw StateError('FrameScheduler.setOnFrame must be called before start');
    }
    return callback;
  }

  /// Runs an admitted callback and records diagnostics. Direct/port mode
  /// counts this admission here; Flutter-synced mode counts only after the
  /// native scheduler accepts its render request.
  void _runFrameCallback(
    Future<void> Function() callback, {
    required bool countAsScheduled,
  }) {
    _rendering = true;
    if (countAsScheduled) {
      _scheduledFrameCount++;
    }
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
    if (callback != null) {
      // Native code owns Linux pacing, throttling, render-thread admission,
      // and rendering. The Dart callback is admitted first so a slow callback
      // cannot produce native renders with no corresponding Dart update.
      final scheduled = requestRender(timeStamp.inMicroseconds * 1000);
      if (scheduled) {
        _scheduledFrameCount++;
        _runFrameCallback(callback, countAsScheduled: false);
      }
    }
    SchedulerBinding.instance.scheduleFrame();
  }
}
