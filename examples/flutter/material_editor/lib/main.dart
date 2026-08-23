import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
// thermion_dart exports classes whose names collide with Flutter widgets
// (Material, Transform, Texture...) as well as vector_math (Vector3, Matrix4).
// The unprefixed import wins for viewer plumbing; the `t` prefix is used for
// the colliding names.
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as t;

/// A live material editor for Thermion + Filament.
///
/// The top half renders a sphere. The bottom half is a text editor holding
/// Filament `.mat` source. On every edit (debounced) the source is compiled
/// to a `.filamat` package *inside the running engine*
/// (`FilamentApp.compileMaterial`), and the new package is hot-swapped onto
/// the sphere (`FilamentApp.reloadMaterialFromBytes`), which preserves the
/// material instance's parameter values. Compile errors are shown inline so
/// you can iterate without restarting the app.
///
/// Runtime compilation is linked into desktop engine builds only (linux,
/// macOS, Windows). On other platforms this example still runs, but the
/// sphere keeps the default material and the status bar explains why.
void main() {
  Logger.root.onRecord.listen((record) {
    debugPrint(record.toString());
  });
  runApp(const MaterialEditorApp());
}

class MaterialEditorApp extends StatelessWidget {
  const MaterialEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thermion material editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6EA8FF)),
        useMaterial3: true,
      ),
      home: const EditorPage(),
    );
  }
}

/// Values applied to the starter material's parameters. They survive every
/// hot-swap: [FilamentApp.reloadMaterialFromBytes] replays recorded instance
/// state onto the replacement instance.
const _starterTint = [0.62, 0.55, 0.92, 1.0];
const _starterRoughness = 0.35;
const _starterMetallic = 0.15;

/// Debounce window between the last keystroke and a recompile.
const _autoApplyDelay = Duration(milliseconds: 600);

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _editorScroll = ScrollController();

  ThermionViewer? _viewer;
  ThermionAsset? _asset;

  /// Completes when the starter source has been seeded into the editor.
  /// [_onViewerAvailable] waits on it so the first compile always sees the
  /// real starter source, not a still-empty text field.
  Future<void>? _starterLoaded;

  /// The material currently on the sphere; null until the first successful
  /// compile. Subsequent successful compiles replace it via
  /// [FilamentApp.reloadMaterialFromBytes].
  t.Material? _material;

  Timer? _debounce;
  Timer? _spin;
  bool _busy = false;
  bool _autoApply = true;
  String _status = 'loading…';
  String? _error;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _starterLoaded = _loadStarterSource();
  }

  Future<void> _loadStarterSource() async {
    // Seed the editor from the shipped starter .mat so it opens with
    // something that renders immediately (and is easy to break on purpose).
    try {
      _controller.text = await rootBundle.loadString('materials/starter.mat');
    } catch (_) {
      _controller.text = _fallbackStarter;
    }
  }

  /// Called by [ViewerWidget] once the viewer exists. Creates the sphere with
  /// the starter material applied, or — where runtime compilation is not
  /// linked — with the default material plus an explanatory status.
  Future<void> _onViewerAvailable(ThermionViewer viewer) async {
    _viewer = viewer;
    await _starterLoaded;
    // Runtime compilation is only linked into desktop engine builds. Check
    // up front so the message is accurate; the exception handlers below
    // still cover the case where the platform stub throws instead.
    final desktop = switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows =>
        true,
      _ => false,
    };
    if (!desktop) {
      await _createGeometryWithDefaultMaterial();
      if (mounted) {
        setState(() {
          _error = 'runtime material compilation requires a desktop build '
              '(linux, macOS or Windows)';
          _status = 'runtime compilation unavailable';
        });
      }
      return;
    }
    try {
      final app = FilamentApp.instance!;
      final bytes = await app.compileMaterial(_controller.text);
      final material = await app.createMaterial(bytes);
      final instance = await material.createInstance();
      await _applyStarterParams(instance);
      _material = material;
      _asset = await viewer.createGeometry(
        GeometryUtils.sphere(),
        materialInstances: [instance],
      );
      _startSpin();
      if (mounted) {
        setState(() {
          _ok = true;
          _status = 'compiled starter material (${bytes.length} bytes)';
        });
      }
    } on UnsupportedError catch (error) {
      // Web: the WASM engine does not link the material compiler.
      await _createGeometryWithDefaultMaterial();
      if (mounted) {
        setState(() {
          _error = error.message;
          _status = 'runtime compilation unavailable';
        });
      }
    } on MaterialCompileException catch (error) {
      // Android/iOS: the stub implementation reports through this exception.
      await _createGeometryWithDefaultMaterial();
      if (mounted) {
        setState(() {
          _error = error.message;
          _status = 'runtime compilation unavailable';
        });
      }
    } catch (error, stackTrace) {
      debugPrint('viewer setup failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _status = 'viewer setup failed');
      }
    }
  }

  Future<void> _createGeometryWithDefaultMaterial() async {
    // No material instance to pass: the geometry falls back to the default
    // ubershader so there is still something to look at.
    _asset = await _viewer!.createGeometry(GeometryUtils.sphere());
    _startSpin();
  }

  Future<void> _applyStarterParams(MaterialInstance instance) async {
    await instance.setParameterFloat4(
        'baseTint', _starterTint[0], _starterTint[1], _starterTint[2], _starterTint[3]);
    await instance.setParameterFloat('roughness', _starterRoughness);
    await instance.setParameterFloat('metallic', _starterMetallic);
  }

  void _startSpin() {
    _spin?.cancel();
    final started = DateTime.now();
    _spin = Timer.periodic(const Duration(milliseconds: 16), (timer) async {
      final asset = _asset;
      if (!mounted || asset == null) {
        timer.cancel();
        return;
      }
      final elapsed =
          DateTime.now().difference(started).inMilliseconds / 1000.0;
      await asset.setTransform(Matrix4.rotationY(elapsed * 0.5));
    });
  }

  void _onSourceChanged() {
    if (!_autoApply) return;
    _debounce?.cancel();
    _debounce = Timer(_autoApplyDelay, _compileAndApply);
  }

  /// The heart of the example: compile the edited source and hot-swap it.
  Future<void> _compileAndApply() async {
    final app = FilamentApp.instance;
    final material = _material;
    if (app == null || _busy) return;

    setState(() {
      _busy = true;
      _status = 'compiling…';
      _error = null;
    });
    try {
      final bytes = await app.compileMaterial(_controller.text);
      if (material == null) {
        // Reachable only if the initial compile failed (e.g. the shipped
        // starter was somehow invalid) and a manual edit fixed it: build the
        // material fresh and put it on the geometry.
        final created = await app.createMaterial(bytes);
        final instance = await created.createInstance();
        await _applyStarterParams(instance);
        final asset = _asset;
        if (asset == null) {
          _asset = await _viewer!.createGeometry(
            GeometryUtils.sphere(),
            materialInstances: [instance],
          );
        } else {
          await app.setMaterialInstanceAt(asset.entity, 0, instance);
        }
        _material = created;
      } else {
        // Swap the new package in. Instance parameters are replayed from the
        // recorded shadow state, so tint/roughness/metallic survive.
        _material = await app.reloadMaterialFromBytes(material, bytes);
      }
      if (mounted) {
        setState(() {
          _ok = true;
          _status = 'applied (${bytes.length} bytes)';
        });
      }
    } on MaterialCompileException catch (error) {
      // Parse/shader errors land here with the compiler's message.
      if (mounted) {
        setState(() {
          _ok = false;
          _status = 'compile failed';
          _error = error.message;
        });
      }
    } on UnsupportedError catch (error) {
      if (mounted) {
        setState(() {
          _ok = false;
          _status = 'runtime compilation unavailable';
          _error = error.message;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('compile failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _ok = false;
          _status = 'apply failed';
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resetToStarter() async {
    // Programmatic text changes do not fire onChanged, so apply explicitly —
    // after the (async) reload of the starter source completes.
    await _loadStarterSource();
    if (mounted) setState(() => _error = null);
    await _compileAndApply();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _spin?.cancel();
    _controller.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > constraints.maxHeight;
            final editor = _buildEditorPane(scheme);
            final viewport = _buildViewport(scheme);
            return wide
                ? Row(children: [
                    Expanded(flex: 5, child: viewport),
                    Expanded(flex: 4, child: editor),
                  ])
                : Column(children: [
                    Expanded(flex: 5, child: viewport),
                    Expanded(flex: 4, child: editor),
                  ]);
          },
        ),
      ),
    );
  }

  Widget _buildViewport(ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: ViewerWidget(
              background: scheme.surfaceContainerLowest,
              directLight:
                  DirectLight.sun(direction: Vector3(0.6, -1.0, -0.7).normalized()),
              initialCameraPosition: Vector3(0, 0, 3.2),
              manipulatorType: ManipulatorType.ORBIT,
              onViewerAvailable: _onViewerAvailable,
              initial: const Center(child: CircularProgressIndicator()),
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 12,
            child: _HintChip('drag to orbit · scroll to zoom'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPane(ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(scheme),
          const Divider(height: 1),
          Expanded(
            child: TextField(
              controller: _controller,
              scrollController: _editorScroll,
              onChanged: (_) => _onSourceChanged(),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
                hintText: 'material { … }',
              ),
            ),
          ),
          if (_error != null) ...[
            const Divider(height: 1),
            _ErrorPane(_error!),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Icon(
            _busy
                ? Icons.hourglass_top
                : _ok
                    ? Icons.check_circle
                    : Icons.error_outline,
            size: 16,
            color: _busy
                ? scheme.tertiary
                : _ok
                    ? Colors.green
                    : scheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Auto-apply while typing',
            isSelected: _autoApply,
            onPressed: () => setState(() => _autoApply = !_autoApply),
            icon: const Icon(Icons.autorenew),
            selectedIcon: const Icon(Icons.autorenew),
          ),
          IconButton(
            tooltip: 'Reset to starter material',
            onPressed: _resetToStarter,
            icon: const Icon(Icons.restart_alt),
          ),
          const SizedBox(width: 4),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _compileAndApply,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Apply'),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      color: scheme.errorContainer.withValues(alpha: 0.35),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: scheme.onErrorContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
      ),
    );
  }
}

/// Used only if the starter asset cannot be loaded; mirrors
/// materials/starter.mat.
const _fallbackStarter = '''
material {
    name : "Editor Starter",
    requires : [ position, uv0 ],
    parameters : [
        { type : float4, name : baseTint },
        { type : float, name : roughness },
        { type : float, name : metallic }
    ],
    shadingModel : lit,
    blending : opaque,
    culling : back,
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseTint;
        material.roughness = materialParams.roughness;
        material.metallic = materialParams.metallic;
    }
}
''';
