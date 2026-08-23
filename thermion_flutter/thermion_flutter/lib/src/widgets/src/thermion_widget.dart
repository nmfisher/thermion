import 'dart:async';

import 'package:flutter/material.dart' hide View;

import '../../platform/src/platform_texture_descriptor.dart';
import 'thermion_widget_internal/surface_widget_builder.dart';

import 'package:thermion_flutter/thermion_flutter.dart';

class ThermionWidget extends StatefulWidget {
  // The viewer whose content will be rendered into this widget.
  final ThermionViewer viewer;

  const ThermionWidget({Key? key, required this.viewer}) : super(key: key);

  @override
  State<ThermionWidget> createState() => _ThermionWidgetState();
}

class _ThermionWidgetState extends State<ThermionWidget> {
  @override
  Widget build(BuildContext context) {
    return ThermionWidgetInternal(
      view: widget.viewer.view,
      surfaceWidgetBuilder: surfaceWidgetBuilder,
      onTexturePreparing: (descriptor) async {
        final view = widget.viewer.view;
        var camera = await view.getCamera();
        var near = await camera.getNear();
        var far = await camera.getCullingFar();
        var focalLength = await camera.getFocalLength();

        await camera.setLensProjection(
          near: near,
          far: far,
          focalLength: focalLength,
          aspect: descriptor.width.toDouble() / descriptor.height.toDouble(),
        );

        await view.setViewport(descriptor.width, descriptor.height);
      },
    );
  }
}

// Inserts [view] into the widget tree by allocating a hardware surface
// and binding to the [view]. The actual implementation
// (e.g. texture vs window, render target vs swapchain, etc) will differ by
// the actual platform; see [ThermionFlutterPluginImpl] for details.
class ThermionWidgetInternal extends StatefulWidget {
  final View view;
  final Widget Function(PlatformTextureDescriptor?, View) surfaceWidgetBuilder;
  final Future<void> Function(PlatformTextureDescriptor descriptor)?
  onTexturePreparing;

  const ThermionWidgetInternal({
    super.key,
    required this.view,
    required this.surfaceWidgetBuilder,
    this.onTexturePreparing,
  });

  @override
  State<ThermionWidgetInternal> createState() => _ThermionWidgetInternalState();
}

@visibleForTesting
Widget buildStagedTextureSurface({
  required Widget current,
  Widget? replacement,
}) {
  if (replacement == null) return current;
  return Stack(
    fit: StackFit.expand,
    // The replacement must be mounted so deferred Linux textures receive a
    // populate callback, but the last valid frame stays painted above it.
    children: [replacement, current],
  );
}

class _ThermionWidgetInternalState extends State<ThermionWidgetInternal> {
  static const _debounceDuration = Duration(milliseconds: 100);

  PlatformTextureDescriptor? _texture;
  PlatformTextureDescriptor? _pendingTexture;
  Timer? _debounceTimer;
  Future<void> _textureOperations = Future<void>.value();
  bool _disposing = false;

  // The current texture size (what's actually allocated)
  int _currentWidth = 0;
  int _currentHeight = 0;

  // The pending size (what we want to allocate after debounce)
  int? _pendingWidth;
  int? _pendingHeight;

  @override
  void dispose() {
    _disposing = true;
    _debounceTimer?.cancel();
    final view = widget.view;
    _enqueueTextureOperation(() async {
      // The plugin owns the complete dependency-ordered teardown: detach any
      // descriptor-managed surface, destroy Filament render targets, then
      // release the platform texture. Serializing this after allocation/resize
      // also guarantees the final descriptor is destroyed exactly once.
      await ThermionFlutterPlugin.instance.destroyTextureForView(view);
      _texture = null;
      _pendingTexture = null;
    }, 'disposing a Thermion widget texture');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var dpr = MediaQuery.of(context).devicePixelRatio;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        var width = (constraints.maxWidth * dpr).ceil();
        var height = (constraints.maxHeight * dpr).ceil();

        if (width == 0 || height == 0) {
          return const SizedBox.shrink();
        }

        // If size hasn't changed, keep using current texture
        if (width == _currentWidth && height == _currentHeight) {
          if (_texture == null) {
            // Initial case - no texture yet
            _scheduleTextureAllocation(width, height);
          }
          return _buildSurface();
        }

        // Size changed - schedule a debounced allocation
        _scheduleTextureAllocation(width, height);

        // Keep showing the old texture during debounce
        return _buildSurface();
      },
    );
  }

  Widget _buildSurface() {
    final pending = _pendingTexture;
    final current = _texture;
    if (pending == null || current == null) {
      return widget.surfaceWidgetBuilder(current ?? pending, widget.view);
    }
    return buildStagedTextureSurface(
      current: widget.surfaceWidgetBuilder(current, widget.view),
      replacement: widget.surfaceWidgetBuilder(pending, widget.view),
    );
  }

  void _scheduleTextureAllocation(int width, int height) {
    if (_disposing) return;

    _pendingWidth = width;
    _pendingHeight = height;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (!_disposing && _pendingWidth != null && _pendingHeight != null) {
        _allocateTexture(_pendingWidth!, _pendingHeight!);
      }
    });
  }

  void _allocateTexture(int width, int height) {
    _enqueueTextureOperation(
      () => _performTextureAllocation(width, height),
      'allocating a Thermion widget texture',
    );
  }

  Future<void> _performTextureAllocation(int width, int height) async {
    if (_disposing) return;

    PlatformTextureDescriptor? texture;

    final previousTexture = _texture;
    final plugin = ThermionFlutterPlugin.instance;
    final staged =
        previousTexture != null && plugin.supportsStagedTextureResize;

    if (previousTexture != null) {
      // Resize existing texture (on Windows this reuses the Flutter
      // texture ID to avoid a black frame flash).
      texture = await ThermionFlutterPlugin.instance.resizeTexture(
        previousTexture,
        widget.view,
        width,
        height,
      );
    } else {
      texture = await ThermionFlutterPlugin.instance.createTextureAndBindToView(
        widget.view,
        width,
        height,
      );
    }

    if (texture == null) return;

    if (staged && !identical(texture, previousTexture)) {
      if (_disposing || !mounted) return;
      setState(() => _pendingTexture = texture);

      // Linux can only create its GL texture from populate(), so ensure the
      // hidden replacement has entered the tree before awaiting native bind.
      await WidgetsBinding.instance.endOfFrame;
      if (_disposing || !mounted) return;

      try {
        await widget.onTexturePreparing?.call(texture);
        await plugin.prepareTextureForPresentation(texture);
      } catch (error, stackTrace) {
        await plugin.cancelStagedTextureResize(
          texture,
          previousTexture,
          widget.view,
        );
        if (!_disposing && mounted) {
          setState(() => _pendingTexture = null);
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (_disposing || !mounted) return;
    } else {
      await widget.onTexturePreparing?.call(texture);
    }

    if (_disposing || !mounted) {
      // Publish the result even if dispose() ran while the platform operation
      // was awaiting. The queued teardown operation owns releasing this final
      // descriptor and its per-view binding.
      _texture = texture;
      _pendingTexture = null;
      _currentWidth = width;
      _currentHeight = height;
      return;
    }

    setState(() {
      // Windows updates the descriptor in place. Staged desktop resize swaps
      // to an already-primed descriptor and retires the old one below.
      _texture = texture;
      _pendingTexture = null;
      _currentWidth = width;
      _currentHeight = height;
    });

    if (staged && !identical(previousTexture, texture)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _enqueueTextureOperation(
          () => plugin.retireTextureAfterResize(previousTexture),
          'retiring a resized Thermion widget texture',
        );
      });
    }
  }

  void _enqueueTextureOperation(
    Future<void> Function() operation,
    String context,
  ) {
    final previous = _textureOperations;
    _textureOperations = () async {
      await previous;
      try {
        await operation();
      } catch (exception, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'thermion_flutter',
            context: ErrorDescription('while $context'),
          ),
        );
      }
    }();
    unawaited(_textureOperations);
  }
}
