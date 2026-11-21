import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide View, Transform;
import 'package:thermion_examples_lib/examples_lib.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Thermion — Storm Observatory',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff0b111a),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff67d7c5),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      sliderTheme: const SliderThemeData(trackHeight: 2),
    ),
    home: const ShowcasePage(),
  );
}

class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key});
  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage>
    with WidgetsBindingObserver {
  final _watch = Stopwatch()..start();
  final _clock = ShowcaseClock();
  final _cadence = FrameSamples();
  final _updates = FrameSamples();
  final _recordCadence = FrameSamples(capacity: 10000);
  final _recordUpdates = FrameSamples(capacity: 10000);
  final _scaffold = GlobalKey<ScaffoldState>();
  ThermionViewer? _viewer;
  EffectsShowcase? _scene;
  Timer? _hudTimer;
  String? _error;
  bool _closing = false, _suspended = false, _tour = false, _busy = false;
  ShowcaseQuality _quality = ShowcaseQuality.balanced;
  ShowcaseShot _shot = ShowcaseShot.overview;
  double _wind = .75, _rain = .85;
  double? _previousFrame, _recordStart;
  Map<String, Object?>? _report;
  String _resolution = 'Preparing surface';
  String? _recordViewport, _recordStatus;
  bool _readingViewport = false;
  double _yaw = 0, _pitch = 0, _radius = 20, _gestureRadius = 20;
  Vector3 _focus = ShowcaseShot.overview.focus;
  bool _cameraDirty = false;
  late final Future Function() _frameHook = _onFrame;
  // Retain the same factory and widget state across HUD refreshes and resizes.
  late final _renderer = ThermionWidget.create(
    viewerFactory: _createViewer,
    initial: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 18),
          Text('Building the observatory…'),
        ],
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOrbit(ShowcaseShot.overview);
    _hudTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && !_closing) {
        setState(() {});
        unawaited(_readViewport());
      }
    });
  }

  Future<ThermionViewer> _createViewer() async {
    ThermionViewer? viewer;
    try {
      viewer = await ThermionFlutterPlugin.createViewer();
      await viewer.setRendering(false);
      final scene = await EffectsShowcase.create(
        viewer,
        assetsDir: 'assets',
        quality: _quality,
      );
      if (_closing) {
        await scene.dispose();
        return viewer;
      }
      _scene = scene;
      _viewer = viewer;
      viewer.app.setTargetFramerate(60);
      await viewer.app.registerRequestFrameHook(_frameHook);
      viewer.onDispose(() async {
        await viewer!.app.unregisterRequestFrameHook(_frameHook);
        await scene.dispose();
      });
      await viewer.setRendering(!_suspended);
      if (mounted) setState(() {});
      return viewer;
    } catch (error, stack) {
      if (mounted) setState(() => _error = '$error');
      debugPrint('$error\n$stack');
      if (viewer != null) await viewer.dispose();
      rethrow;
    }
  }

  Future<void> _readViewport() async {
    final viewer = _viewer;
    if (_readingViewport || viewer == null || _closing) return;
    _readingViewport = true;
    try {
      final viewport = await viewer.view.getViewport();
      _resolution = '${viewport.width} × ${viewport.height}';
      if (_recordStart != null && _recordViewport != _resolution) {
        _finishRecord('Recording cancelled because the render size changed.');
      }
    } finally {
      _readingViewport = false;
    }
  }

  Future<void> _onFrame() async {
    final scene = _scene;
    if (scene == null || _closing || _suspended) return;
    final now = _watch.elapsedMicroseconds / 1e6;
    final previous = _previousFrame;
    _previousFrame = now;
    final interval = previous == null ? null : (now - previous) * 1000;
    if (interval != null) _cadence.add(interval);
    final record = _recordStart;
    final phase = record == null ? null : now - record - 2;
    final updateWatch = Stopwatch()..start();
    if (phase != null) {
      await scene.setTour(math.max(0, phase) * 2);
      await scene.update(3.2 + math.max(0, phase) * 2);
    } else {
      final time = _clock.tick(now);
      if (_tour) {
        await scene.setTour(time - 3.2);
      } else if (_cameraDirty) {
        _cameraDirty = false;
        final ce = math.cos(_pitch);
        final eye =
            _focus +
            Vector3(
                  ce * math.sin(_yaw),
                  math.sin(_pitch),
                  ce * math.cos(_yaw),
                ) *
                _radius;
        if (!_closing) {
          await (await _viewer!.getActiveCamera()).lookAt(eye, focus: _focus);
        }
      }
      await scene.update(time);
    }
    final updateMs = updateWatch.elapsedMicroseconds / 1000;
    _updates.add(updateMs);
    if (phase != null &&
        phase >= 0 &&
        phase < 10 &&
        interval != null &&
        previous! >= record! + 2 &&
        record == _recordStart) {
      _recordCadence.add(interval);
      _recordUpdates.add(updateMs);
    }
    if (phase != null && phase >= 10 && record == _recordStart) {
      await _readViewport();
      if (record != _recordStart || _closing) return;
      _report = {
        'schema': 1,
        'scene': 'storm_observatory',
        'runner': 'flutter',
        'platform': defaultTargetPlatform.name,
        'build_mode': kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug',
        'metric': 'render_request_interval_ms',
        'target_fps': 60,
        'warmup_seconds': 2,
        'measurement_seconds': 10,
        'viewport': _recordViewport,
        'quality': _quality.toJson(),
        'effects': {
          for (final e in ShowcaseEffect.values) e.name: scene.enabled[e],
        },
        'wind': _wind,
        'rain': _rain,
        'cadence': _recordCadence.summary(),
        'effect_update_ms': _recordUpdates.summary(),
        'note':
            'Cadence includes scheduling and the frame cap; effect updates include FFI waits. Neither is GPU time.',
      };
      _finishRecord('Recording complete.');
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    if (_busy || _scene == null || _recordStart != null || _closing) return;
    setState(() => _busy = true);
    try {
      await action();
      _cadence.clear();
      _updates.clear();
      _previousFrame = null;
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setOrbit(ShowcaseShot shot) {
    _focus = shot.focus;
    final offset = shot.eye - _focus;
    _radius = offset.length;
    _yaw = math.atan2(offset.x, offset.z);
    _pitch = math.asin(offset.y / _radius);
  }

  Future<void> _startRecord() async {
    await _readViewport();
    if (!mounted || _closing || _suspended) return;
    _recordCadence.clear();
    _recordUpdates.clear();
    _report = null;
    _recordStatus = null;
    _recordViewport = _resolution;
    _recordStart = _watch.elapsedMicroseconds / 1e6;
    _previousFrame = null;
    setState(() {});
  }

  void _finishRecord(String status) {
    _recordStart = null;
    _recordStatus = status;
    _tour = false;
    _clock.reset();
    _setOrbit(_shot);
    _cameraDirty = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _suspended = state != AppLifecycleState.resumed;
    _clock.suspend();
    _previousFrame = null;
    if (_suspended && _recordStart != null) {
      _finishRecord('Recording cancelled while the app was inactive.');
    }
    final viewer = _viewer;
    if (viewer != null && !_closing) {
      unawaited(viewer.setRendering(!_suspended));
    }
  }

  @override
  void dispose() {
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    _hudTimer?.cancel();
    final viewer = _viewer;
    if (viewer != null) {
      unawaited(viewer.app.unregisterRequestFrameHook(_frameHook));
    }
    // Stop queued scene operations before the owned renderer tears down.
    unawaited(_scene?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Widget _viewport() {
    final media = MediaQuery.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent && _recordStart == null) {
              _tour = false;
              _radius = (_radius * math.exp(event.scrollDelta.dy * .001)).clamp(
                2.0,
                42.0,
              );
              _cameraDirty = true;
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) {
              _gestureRadius = _radius;
            },
            onScaleUpdate: (details) {
              if (_recordStart != null) return;
              _tour = false;
              _yaw -= details.focalPointDelta.dx * .005;
              _pitch = (_pitch + details.focalPointDelta.dy * .005).clamp(
                .04,
                1.4,
              );
              _radius = (_gestureRadius / details.scale).clamp(2.0, 42.0);
              _cameraDirty = true;
            },
            child: MediaQuery(
              data: media.copyWith(
                devicePixelRatio:
                    media.devicePixelRatio * _quality.resolutionScale,
              ),
              child: RepaintBoundary(child: _renderer),
            ),
          ),
        ),
        Positioned(
          left: 24,
          top: 22,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STORM OBSERVATORY',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 3,
                    color: Color(0xff87d6cb),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Weather. Light. Material.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_resolution  ·  ${_quality.label}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: 20,
          right: 20,
          child: IgnorePointer(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metric(
                  'RENDER CADENCE',
                  '${(_cadence.summary()['hz'] ?? 0).toStringAsFixed(1)} fps',
                ),
                _metric(
                  'P95 INTERVAL',
                  '${(_cadence.summary()['p95_ms'] ?? 0).toStringAsFixed(1)} ms',
                ),
                _metric(
                  'EFFECT UPDATE',
                  '${(_updates.summary()['mean_ms'] ?? 0).toStringAsFixed(2)} ms',
                ),
                if (_recordStart != null)
                  _metric(
                    'RECORDING',
                    '${(12 - (_watch.elapsedMicroseconds / 1e6 - _recordStart!)).clamp(0, 12).ceil()} s',
                  ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SelectableText(_error!),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xe60b111a),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 1.2,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18)),
      ],
    ),
  );

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.7,
        color: Colors.white54,
      ),
    ),
  );

  Widget _controls() {
    final ready = _scene != null && !_busy && _recordStart == null;
    return Container(
      color: const Color(0xff101a27),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Text(
              'Explore the scene',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text(
              'Drag to orbit. Scroll or pinch to move closer.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            _section('Camera'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final shot in ShowcaseShot.values)
                  ChoiceChip(
                    label: Text(shot.label),
                    selected: _shot == shot && !_tour,
                    onSelected: !ready
                        ? null
                        : (_) => _change(() async {
                            _shot = shot;
                            _tour = false;
                            _setOrbit(shot);
                            await _scene!.setShot(shot);
                          }),
                  ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Camera tour'),
              value: _tour,
              onChanged: !ready
                  ? null
                  : (v) => setState(() {
                      _tour = v;
                      if (!v) {
                        _setOrbit(_shot);
                        _cameraDirty = true;
                      }
                    }),
            ),
            _section('Quality'),
            SegmentedButton<ShowcaseQuality>(
              segments: [
                for (final q in ShowcaseQuality.values)
                  ButtonSegment(value: q, label: Text(q.label)),
              ],
              selected: {_quality},
              showSelectedIcon: false,
              onSelectionChanged: !ready
                  ? null
                  : (values) => _change(() async {
                      final q = values.single;
                      await _scene!.setQuality(q);
                      if (mounted) setState(() => _quality = q);
                    }),
            ),
            const SizedBox(height: 10),
            Text(
              '${(_quality.resolutionScale * 100).round()}% resolution · ${_quality.furShells} fur layers\n'
              '${_quality.auroraSamples} sky / ${_quality.stormSamples} storm samples',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.6,
              ),
            ),
            _section('Effects'),
            for (final effect in ShowcaseEffect.values)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(effect.label),
                value: _scene?.enabled[effect] ?? true,
                onChanged: !ready
                    ? null
                    : (v) => _change(() => _scene!.setEnabled(effect, v)),
              ),
            _section('Weather'),
            Text(
              'Wind  ${_wind.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
            Slider(
              value: _wind,
              min: 0,
              max: 1.5,
              onChanged: !ready ? null : (v) => setState(() => _wind = v),
              onChangeEnd: !ready
                  ? null
                  : (v) => _change(() => _scene!.setWind(v)),
            ),
            Text(
              'Rain  ${(_rain * 100).round()}%',
              style: const TextStyle(fontSize: 12),
            ),
            Slider(
              value: _rain,
              onChanged: !ready ? null : (v) => setState(() => _rain = v),
              onChangeEnd: !ready
                  ? null
                  : (v) => _change(() => _scene!.setRain(v)),
            ),
            OutlinedButton.icon(
              onPressed: !ready
                  ? null
                  : () => setState(() => _clock.paused = !_clock.paused),
              icon: Icon(_clock.paused ? Icons.play_arrow : Icons.pause),
              label: Text(_clock.paused ? 'Resume motion' : 'Pause motion'),
            ),
            _section('Performance'),
            FilledButton.icon(
              onPressed: ready ? _startRecord : null,
              icon: const Icon(Icons.speed),
              label: const Text('Record 10-second tour'),
            ),
            const SizedBox(height: 10),
            const Text(
              '2 seconds of warm-up, then a fixed camera route. Controls lock during recording.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.5,
              ),
            ),
            if (kDebugMode)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Debug build — use profile or release for timing.',
                  style: TextStyle(color: Color(0xffffcc80), fontSize: 11),
                ),
              ),
            if (_recordStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _recordStatus!,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            if (_report != null) ...[
              const SizedBox(height: 12),
              Text(
                '${(_recordCadence.summary()['hz'] ?? 0).toStringAsFixed(1)} fps · '
                'p95 ${(_recordCadence.summary()['p95_ms'] ?? 0).toStringAsFixed(1)} ms',
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: const JsonEncoder.withIndent('  ').convert(_report),
                    ),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Performance report copied'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy JSON report'),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Cadence includes scheduling and the 60 fps cap. Effect-update timings include native calls. These are not GPU timestamps.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      return Scaffold(
        key: _scaffold,
        appBar: AppBar(
          backgroundColor: const Color(0xff0b111a),
          titleSpacing: 24,
          title: const Text(
            'THERMION  /  EFFECTS LAB',
            style: TextStyle(fontSize: 13, letterSpacing: 2),
          ),
          actions: [
            if (!wide)
              IconButton(
                tooltip: 'Show controls',
                icon: const Icon(Icons.tune),
                onPressed: () => _scaffold.currentState?.openEndDrawer(),
              ),
            const SizedBox(width: 12),
          ],
        ),
        endDrawer: wide ? null : Drawer(width: 320, child: _controls()),
        body: Row(
          children: [
            Expanded(child: _viewport()),
            if (wide) SizedBox(width: 320, child: _controls()),
          ],
        ),
      );
    },
  );
}
