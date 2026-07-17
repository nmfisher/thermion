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
      onTextureUpdated: (descriptor) async {
        if (descriptor == null) {
          return;
        }
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
  final void Function(PlatformTextureDescriptor? descriptor)? onTextureUpdated;
  final Widget Function(PlatformTextureDescriptor?) surfaceWidgetBuilder;

  const ThermionWidgetInternal({
    super.key,
    required this.view,
    required this.surfaceWidgetBuilder,
    this.onTextureUpdated,
  });

  @override
  State<ThermionWidgetInternal> createState() => _ThermionWidgetInternalState();
}

class _ThermionWidgetInternalState extends State<ThermionWidgetInternal> {
  static const _debounceDuration = Duration(milliseconds: 100);

  PlatformTextureDescriptor? _texture;
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
      // Tear down per-view plugin bindings (Android: SwapChain bound to
      // this view) BEFORE releasing the underlying texture. Releasing the
      // SurfaceProducer texture entry invalidates the swap chain's native
      // window, so if the swap chain is still attached to the RenderManager,
      // Filament's next render can call eglSwapBuffers on an invalid surface
      // and log EGL_BAD_SURFACE until widget teardown finishes propagating.
      //
      // Queueing this teardown after any in-flight allocation or resize also
      // ensures that it releases the final binding and destroys the final
      // descriptor exactly once.
      await ThermionFlutterPlugin.instance.releaseTextureBindingForView(view);
      final texture = _texture;
      _texture = null;
      await texture?.destroy();
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
          return widget.surfaceWidgetBuilder(_texture);
        }

        // Size changed - schedule a debounced allocation
        _scheduleTextureAllocation(width, height);

        // Keep showing the old texture during debounce
        return widget.surfaceWidgetBuilder(_texture);
      },
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

    if (_texture != null) {
      // Resize existing texture (on Windows this reuses the Flutter
      // texture ID to avoid a black frame flash).
      texture = await ThermionFlutterPlugin.instance.resizeTexture(
        _texture!,
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

    if (_disposing || !mounted) {
      // Publish the result even if dispose() ran while the platform operation
      // was awaiting. The queued teardown operation owns releasing this final
      // descriptor and its per-view binding.
      _texture = texture;
      _currentWidth = width;
      _currentHeight = height;
      return;
    }

    setState(() {
      // resizeTexture owns disposal of the superseded descriptor. On Windows
      // it returns the existing descriptor after updating it in place.
      _texture = texture;
      _currentWidth = width;
      _currentHeight = height;
    });

    widget.onTextureUpdated?.call(texture);
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
