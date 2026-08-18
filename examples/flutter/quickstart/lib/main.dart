import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// Dev-only dependency, imported behind a --dart-define gate so this example can
// be driven from an AI harness via the Dart/Flutter MCP. See README.
// ignore: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';
import 'package:logging/logging.dart';
// 'Transform' is hidden: thermion_dart exports its own bone-animation Transform
// class, which would shadow the Flutter widget used throughout this file.
import 'package:thermion_flutter/thermion_flutter.dart' hide Transform;

void main() {
  if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
    enableFlutterDriverExtension();
  }
  runApp(const MyApp());
  Logger.root.onRecord.listen((record) {
    debugPrint(record.toString());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // No Material: a bare WidgetsApp provides Directionality + MediaQuery +
    // a default text style, and nothing else. All chrome below is hand-drawn.
    return WidgetsApp(
      color: _bg,
      debugShowCheckedModeBanner: false,
      builder: (_, __) => const MyHomePage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0A0F);
const _bg2 = Color(0xFF101019);
const _surface = Color(0xFF16161E);
const _surfaceTop = Color(0xFF1E1E2A);
const _border = Color(0xFF262633);
const _accent = Color(0xFF6EA8FF);
const _accent2 = Color(0xFF9D7BFF);
const _danger = Color(0xFFFF7B7B);
const _text = Color(0xFFECECF2);
const _textDim = Color(0xFF80808E);
const _textFaint = Color(0xFF50505C);

const _skyboxAsset = 'assets/default_env_skybox.ktx';

// ─────────────────────────────────────────────────────────────────────────────
// Type scale — no theme anywhere; every glyph is explicitly styled.
// ─────────────────────────────────────────────────────────────────────────────
const _mono = 'monospace';

/// Small-caps style for labels, badges and stat readouts.
const _microLabel = TextStyle(
  fontFamily: _mono,
  fontSize: 9.5,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.3,
);

/// The brand word, tinted with the accent gradient via ShaderMask.
const _brandTitle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.4,
);

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

/// Demonstrates mounting multiple [ViewerWidget]s simultaneously.
///
/// Each tile owns an independent [ThermionViewer]. Mounting and disposing
/// several at once exercises the serialised attach/detach path in
/// [FFIRenderManager] (see the `_syncViews` snapshot + `_opChain` logic),
/// which is what keeps concurrent viewer teardown from racing.
class _MyHomePageState extends State<MyHomePage> {
  int _nextTileId = 0;
  // Reassigned (not mutated in place) on every change so the GridView's
  // SliverChildListDelegate sees a new list and re-inflates its children.
  List<_ViewerTile> _tiles = [];
  int _framerate = 60;

  /// Batch size for the footer's add/remove control.
  int _batch = 1;

  /// Web runs one engine/canvas/worker per viewer; WebOptions.maxViewers
  /// (default 8) caps concurrent viewers there. Native has no such cap.
  final int _maxBatch = kIsWeb ? 8 : 64;

  late DirectLight _sun;

  @override
  void initState() {
    super.initState();
    _sun = DirectLight.sun(direction: Vector3(0.7, -1, -0.8).normalized());
  }

  /// Applies the batch: mounts `_batch` viewers at once when the grid is
  /// empty, otherwise removes the most recently added `_batch`.
  ///
  /// Adding the whole batch in a single `setState` mounts every tile in the
  /// same frame, so all `createViewer` chains run concurrently — the exact
  /// multi-viewer stress path the FFIRenderManager op-chain serialises.
  void _applyBatch() {
    final batch = _batch;
    setState(() {
      if (_tiles.isEmpty) {
        _tiles = [..._tiles, for (var i = 0; i < batch; i++) _newTile()];
      } else {
        final keep = math.max(0, _tiles.length - batch);
        _tiles = _tiles.take(keep).toList();
      }
    });
  }

  _ViewerTile _newTile() {
    final id = _nextTileId++;
    return _ViewerTile(
      key: ValueKey(id),
      index: _tiles.length + 1,
      directLight: _sun,
      onRemove: () {
        setState(() {
          _tiles = _tiles.where((tile) => tile.key != ValueKey(id)).toList();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bg, _bg2],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _Header(count: _tiles.length, multiViewer: true),
            const _Divider(),
            Expanded(
              child: _tiles.isEmpty
                  ? const _EmptyState()
                  : GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      children: _tiles,
                    ),
            ),
            _Footer(
              framerate: _framerate,
              viewerCount: _tiles.length,
              batch: _batch,
              maxBatch: _maxBatch,
              onBatchChanged: (v) => setState(() => _batch = v),
              onApplyBatch: _applyBatch,
              onFramerateChanged: (v) {
                setState(() => _framerate = v);
                // Applies to every engine (web runs one engine per viewer).
                ThermionFlutterPlugin.instance.setTargetFramerate(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chrome
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.count, required this.multiViewer});
  final int count;
  final bool multiViewer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          const _CubeGlyph(size: 22),
          const SizedBox(width: 12),
          // Brand word tinted with the accent gradient.
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_accent, _accent2],
            ).createShader(bounds),
            child: Text(
              'Thermion',
              style: _brandTitle.copyWith(color: const Color(0xFFFFFFFF)),
            ),
          ),
          const SizedBox(width: 10),
          _Badge(label: multiViewer ? 'MULTI-VIEWER' : 'SINGLE VIEWER'),
          const Spacer(),
          Text(
            '$count ${count == 1 ? 'VIEWER' : 'VIEWERS'}',
            style: _microLabel.copyWith(color: _textDim),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _accent.withValues(alpha: 0.30)),
      ),
      child: Text(label, style: _microLabel.copyWith(color: _accent)),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _border,
            _border.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatefulWidget {
  const _EmptyState();

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final phase = t * 2 * math.pi;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dashed "socket" slot with a slowly marching dash pattern;
              // the glyph bobs inside it.
              SizedBox(
                width: 250,
                height: 180,
                child: CustomPaint(
                  painter: _DashedFramePainter(progress: t),
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(0, math.sin(phase) * 5),
                      child: Opacity(
                        opacity: 0.30 + 0.12 * (0.5 + 0.5 * math.sin(phase + math.pi)),
                        child: const _CubeGlyph(size: 64),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              const Text('No viewers mounted',
                  style: TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  )),
              const SizedBox(height: 6),
              const Text(
                'Set a batch with the stepper, then hit “Add”.',
                style: TextStyle(color: _textDim, fontSize: 12.5),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rounded-rect frame with a slowly rotating dash pattern.
class _DashedFramePainter extends CustomPainter {
  _DashedFramePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 7.0;
    const gap = 6.0;
    final rect = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)));
    final paint = Paint()
      ..color = _textFaint.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Rotate the dash phase so the pattern visibly creeps along the frame.
    final phase = progress * (dash + gap);
    for (final metric in path.computeMetrics()) {
      var distance = -phase;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + dash, metric.length)),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFramePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.framerate,
    required this.viewerCount,
    required this.batch,
    required this.maxBatch,
    required this.onBatchChanged,
    required this.onApplyBatch,
    required this.onFramerateChanged,
  });

  final int framerate;
  final int viewerCount;
  final int batch;
  final int maxBatch;
  final ValueChanged<int> onBatchChanged;
  final VoidCallback onApplyBatch;
  final ValueChanged<int> onFramerateChanged;

  @override
  Widget build(BuildContext context) {
    // Empty grid → the button adds `batch` viewers; otherwise it removes
    // that many (clamped to what's actually mounted).
    final adding = viewerCount == 0;
    final removeCount = math.min(batch, viewerCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Row(
        children: [
          _Button(
            primary: true,
            danger: !adding,
            verticalPadding: 7,
            semanticLabel: adding
                ? 'Add $batch viewers'
                : 'Remove $removeCount viewers',
            onPressed: onApplyBatch,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reads as a sentence: "Add − 1 + viewers". The stepper
                // tunes the batch; taps on the rest apply it.
                Text(adding ? 'Add' : 'Remove'),
                const SizedBox(width: 10),
                _EmbeddedStepper(
                  value: batch,
                  min: 1,
                  max: maxBatch,
                  onChanged: onBatchChanged,
                ),
                const SizedBox(width: 10),
                const Text('viewers'),
              ],
            ),
          ),
          const Spacer(),
          // Drop the label on narrow windows rather than overflow the row.
          if (MediaQuery.sizeOf(context).width >= 540) ...[
            Text('TARGET FPS', style: _microLabel.copyWith(color: _textFaint)),
            const SizedBox(width: 10),
          ],
          _Segmented<int>(
            values: const [(15, '15'), (30, '30'), (60, '60')],
            selected: framerate,
            onChanged: onFramerateChanged,
          ),
        ],
      ),
    );
  }
}

/// − / value / + stepper embedded inside the batch button, so the batch size
/// and the add/remove action live in one control. The cells sit on a dark
/// surface chip so they read as a separate sub-control against the button's
/// gradient.
class _EmbeddedStepper extends StatelessWidget {
  const _EmbeddedStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            key: const ValueKey('batch-decrease'),
            glyph: '−',
            enabled: value > min,
            semanticLabel: 'Decrease batch size',
            onPressed: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 26,
            height: 26,
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  color: _text,
                  fontFamily: _mono,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _StepButton(
            key: const ValueKey('batch-increase'),
            glyph: '+',
            enabled: value < max,
            semanticLabel: 'Increase batch size',
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

/// One − / + cell of the embedded batch stepper. Disabled at the
/// [min]/[max] ends.
class _StepButton extends StatefulWidget {
  const _StepButton({
    super.key,
    required this.glyph,
    required this.enabled,
    required this.semanticLabel,
    required this.onPressed,
  });

  final String glyph;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          // Nested inside the batch button's own GestureDetector: the tap
          // recognizer on this (inner) cell wins the arena, so taps here
          // adjust the batch instead of triggering the apply action.
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: enabled && _hovered ? _surfaceTop : null,
            ),
            child: Center(
              child: Text(
                widget.glyph,
                style: TextStyle(
                  color: enabled ? (_pressed ? _accent : _text) : _textFaint,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// A single viewer cell. Owns its own ThermionViewer, rotation animation, and
// skybox state so sibling tiles never share mutable state.
// ─────────────────────────────────────────────────────────────────────────────
class _ViewerTile extends StatefulWidget {
  const _ViewerTile({
    super.key,
    required this.index,
    required this.directLight,
    required this.onRemove,
  });

  final int index;
  final DirectLight directLight;
  final VoidCallback onRemove;

  @override
  State<_ViewerTile> createState() => _ViewerTileState();
}

class _ViewerTileState extends State<_ViewerTile> {
  ThermionViewer? _viewer;
  Timer? _assetAnimationTimer;

  /// Skybox starts on (ViewerWidget loads [skyboxPath]); toggled by the button.
  bool _skyboxOn = true;
  bool _skyboxBusy = false;

  void _cancelCallbacks() {
    _assetAnimationTimer?.cancel();
    _assetAnimationTimer = null;
  }

  Future<void> _toggleSkybox() async {
    final viewer = _viewer;
    if (viewer == null || _skyboxBusy) return;
    setState(() => _skyboxBusy = true);
    try {
      if (_skyboxOn) {
        await viewer.removeSkybox();
        if (mounted) setState(() => _skyboxOn = false);
      } else {
        await viewer.loadSkybox(_skyboxAsset);
        if (mounted) setState(() => _skyboxOn = true);
      }
    } catch (error, stackTrace) {
      debugPrint('skybox toggle failed: $error\n$stackTrace');
    } finally {
      if (mounted) setState(() => _skyboxBusy = false);
    }
  }

  @override
  void dispose() {
    _cancelCallbacks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Slide-and-fade the tile in when it mounts.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
      ),
      child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x50000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_surfaceTop, _surface],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Positioned.fill(
                child: ViewerWidget(
                  assetPath: 'assets/cube.glb',
                  skyboxPath: _skyboxAsset,
                  iblPath: 'assets/default_env_ibl.ktx',
                  directLight: widget.directLight,
                  transformToUnitCube: true,
                  initialCameraPosition: Vector3(0, 0, 6),
                  manipulatorType: ManipulatorType.ORBIT,
                  onAssetLoaded: (viewer, asset) async {
                    _assetAnimationTimer?.cancel();
                    final startedAt = DateTime.now();
                    _assetAnimationTimer = Timer.periodic(
                      const Duration(milliseconds: 16),
                      (timer) async {
                        if (!mounted || !identical(_viewer, viewer)) {
                          timer.cancel();
                          return;
                        }
                        final now = DateTime.now();
                        final elapsed = (now.millisecondsSinceEpoch -
                                startedAt.millisecondsSinceEpoch) /
                            1000;
                        await asset.setTransform(Matrix4.rotationY(elapsed));
                      },
                    );
                  },
                  onViewerAvailable: (viewer) async {
                    if (!mounted) return;
                    setState(() => _viewer = viewer);
                  },
                  initial: const _Pulse(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: _surface),
                      child: Center(child: _CubeGlyph(size: 28)),
                    ),
                  ),
                ),
              ),
              // Top scrim so overlay controls stay legible on bright skyboxes.
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 72,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _OverlayLabel('#${widget.index}'),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OverlayButton(
                      label: _skyboxBusy ? '· · ·' : 'Skybox',
                      semanticLabel: 'Toggle skybox',
                      active: _skyboxOn,
                      onPressed: _viewer == null ? null : _toggleSkybox,
                    ),
                    const SizedBox(width: 6),
                    _OverlayButton(
                      label: '×',
                      semanticLabel: 'Remove viewer',
                      onPressed: widget.onRemove,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hand-drawn controls (no Material)
// ─────────────────────────────────────────────────────────────────────────────
class _Button extends StatefulWidget {
  const _Button({
    required this.onPressed,
    required this.child,
    this.primary = false,
    this.danger = false,
    this.semanticLabel,
    this.verticalPadding,
  });

  final VoidCallback onPressed;
  final Widget child;
  final bool primary;

  /// Swaps the primary gradient to the danger tint (used for remove mode).
  final bool danger;
  final String? semanticLabel;

  /// Overrides the default vertical padding (12 for primary buttons).
  final double? verticalPadding;

  @override
  State<_Button> createState() => _ButtonState();
}

class _ButtonState extends State<_Button> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final pressed = _pressed;
    final hovered = _hovered;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: Transform.translate(
            // 1px tactile "push" while held.
            offset: Offset(0, pressed ? 1 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              padding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical:
                    widget.verticalPadding ?? (widget.primary ? 12 : 10),
              ),
              decoration: BoxDecoration(
                gradient: widget.primary
                    ? LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: pressed
                            ? (widget.danger
                                ? const [
                                    Color(0xFFB84558),
                                    Color(0xFFC74F63),
                                  ]
                                : const [
                                    Color(0xFF5786D8),
                                    Color(0xFF7E64D8),
                                  ])
                            : [
                                Color.lerp(
                                    widget.danger
                                        ? const Color(0xFFD9536A)
                                        : _accent,
                                    const Color(0xFFFFFFFF),
                                    hovered ? 0.08 : 0)!,
                                Color.lerp(
                                    widget.danger ? _danger : _accent2,
                                    const Color(0xFFFFFFFF),
                                    hovered ? 0.08 : 0)!,
                              ],
                      )
                    : null,
                color: widget.primary
                    ? null
                    : (pressed ? _surfaceTop : (hovered ? _surfaceTop : _surface)),
                borderRadius: BorderRadius.circular(12),
                border: widget.primary
                    ? null
                    : Border.all(
                        color: hovered
                            ? _accent.withValues(alpha: 0.45)
                            : _border),
                boxShadow: widget.primary
                    ? [
                        BoxShadow(
                          color: (widget.danger ? _danger : _accent)
                              .withValues(
                                  alpha: pressed ? 0.18 : (hovered ? 0.5 : 0.34)),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: widget.primary ? const Color(0xFF0A0A0F) : _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.onChanged,
    this.itemWidth = 46,
  });

  final List<(T, String)> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = values.indexWhere((v) => v.$1 == selected);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Stack(
        children: [
          if (selectedIndex >= 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              left: selectedIndex * itemWidth,
              top: 0,
              bottom: 0,
              width: itemWidth,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: _accent.withValues(alpha: 0.45)),
                  ),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label) in values)
                _Segment(
                  width: itemWidth,
                  label: label,
                  selected: value == selected,
                  semanticLabel: 'Set target frame rate to $label',
                  onPressed: () => onChanged(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({
    required this.width,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.semanticLabel,
  });

  final double width;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.width,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: selected ? null : (_hovered ? _surfaceTop : null),
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: TextStyle(
                  color: selected
                      ? _accent
                      : (_hovered || _pressed ? _text : _textDim),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.3,
                  fontFamily: _mono,
                ),
                child: Text(widget.label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Translucent pill button for overlaying 3D content.
class _OverlayButton extends StatefulWidget {
  const _OverlayButton({
    required this.label,
    required this.onPressed,
    this.active = false,
    this.semanticLabel,
  });

  final String label;
  final bool active;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  State<_OverlayButton> createState() => _OverlayButtonState();
}

class _OverlayButtonState extends State<_OverlayButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final active = widget.active;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          // Whole pill (padding included) is the tap target, not just the
          // label glyph — opaque regardless of what the child paints.
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? _accent.withValues(
                      alpha: _pressed ? 0.20 : (_hovered ? 0.44 : 0.28))
                  : Color.lerp(
                      const Color(0x66000000),
                      const Color(0xFF000000),
                      _pressed ? 0.4 : (_hovered ? 0.25 : 0),
                    ),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: active
                    ? _accent.withValues(
                        alpha: _pressed ? 0.6 : (_hovered ? 1.0 : 0.85))
                    : Color.lerp(
                        const Color(0x33FFFFFF),
                        const Color(0xFFFFFFFF),
                        _pressed || _hovered ? 0.5 : 0,
                      )!,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: enabled ? _text : _textFaint,
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayLabel extends StatelessWidget {
  const _OverlayLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// Loops its child's opacity up and down — used for the "loading" glyph shown
/// while a viewer is still initialising.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.25, end: 0.55).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// A shaded isometric cube mark, drawn with CustomPaint. Used as the brand glyph
// and the empty-state illustration.
// ─────────────────────────────────────────────────────────────────────────────
class _CubeGlyph extends StatelessWidget {
  const _CubeGlyph({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CubePainter(size: size)),
    );
  }
}

class _CubePainter extends CustomPainter {
  _CubePainter({required this.size});
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final r = (math.min(canvasSize.width, canvasSize.height) / 2) * 0.92;
    final h = r * math.sqrt(3) / 2; // horizontal half-width

    final top = Offset(cx, cy - r);
    final topRight = Offset(cx + h, cy - r / 2);
    final botRight = Offset(cx + h, cy + r / 2);
    final bottom = Offset(cx, cy + r);
    final botLeft = Offset(cx - h, cy + r / 2);
    final topLeft = Offset(cx - h, cy - r / 2);
    final center = Offset(cx, cy);

    final stroke = Paint()
      ..color = _accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.045
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Three shaded faces (top brightest, right mid, left darkest).
    void face(List<Offset> pts, double alpha) {
      final p = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      p.close();
      canvas.drawPath(
        p,
        Paint()..color = _accent.withValues(alpha: alpha),
      );
    }

    face([top, topRight, center, topLeft], 0.55); // top
    face([topRight, botRight, bottom, center], 0.32); // right
    face([topLeft, center, bottom, botLeft], 0.18); // left

    // Outline.
    final outline = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(botRight.dx, botRight.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(botLeft.dx, botLeft.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..close();
    canvas.drawPath(outline, stroke);

    // Internal edges meeting at the center.
    canvas.drawLine(center, topRight, stroke);
    canvas.drawLine(center, bottom, stroke);
    canvas.drawLine(center, topLeft, stroke);
  }

  @override
  bool shouldRepaint(_CubePainter oldDelegate) => oldDelegate.size != size;
}
