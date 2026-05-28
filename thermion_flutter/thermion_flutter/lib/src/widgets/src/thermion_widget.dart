import 'dart:async';

import 'package:flutter/material.dart' hide View;
import '../../platform/src/platform_texture_descriptor.dart';
import 'thermion_widget_internal/surface_widget_builder.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

class ThermionWidget extends StatefulWidget {
  // The viewer whose content will be rendered into this widget.
  final ThermionViewer viewer;

  const ThermionWidget({
    Key? key,
    required this.viewer,
  }) : super(key: key);

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
            aspect: descriptor.width.toDouble() / descriptor.height.toDouble());

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

  // The current texture size (what's actually allocated)
  int _currentWidth = 0;
  int _currentHeight = 0;

  // The pending size (what we want to allocate after debounce)
  int? _pendingWidth;
  int? _pendingHeight;

  @override
  void dispose() {
    super.dispose();
    _debounceTimer?.cancel();
    var texture = _texture;
    _texture = null;
    // Tear down per-view plugin bindings (Android: SwapChain bound to
    // this view) BEFORE releasing the underlying texture. The
    // SurfaceTexture release frees the swap chain's native window, so
    // if the swap chain is still attached to the RenderManager when
    // that happens Filament's next render fires `eglSwapBuffers` on a
    // null buffer and the emulator/EGL stack logs `EGL_BAD_SURFACE`
    // until the widget unmount finishes propagating. Sequencing the
    // two awaits inside an unawaited closure keeps `dispose()` synchronous
    // for the framework while still ordering the calls.
    final view = widget.view;
    () async {
      await ThermionFlutterPlugin.instance.releaseTextureBindingForView(view);
      await texture?.destroy();
    }();
  }

  @override
  Widget build(BuildContext context) {
    var dpr = MediaQuery.of(context).devicePixelRatio;

    return LayoutBuilder(builder: (ctx, constraints) {
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
    });
  }

  void _scheduleTextureAllocation(int width, int height) {
    _pendingWidth = width;
    _pendingHeight = height;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (_pendingWidth != null && _pendingHeight != null) {
        _allocateTexture(_pendingWidth!, _pendingHeight!);
      }
    });
  }

  void _allocateTexture(int width, int height) async {
    PlatformTextureDescriptor? texture;

    if (_texture != null) {
      // Resize existing texture (on Windows this reuses the Flutter
      // texture ID to avoid a black frame flash).
      texture = await ThermionFlutterPlugin.instance
          .resizeTexture(_texture!, widget.view, width, height);
    } else {
      texture = await ThermionFlutterPlugin.instance
          .createTextureAndBindToView(widget.view, width, height);
    }

    widget.onTextureUpdated?.call(texture);

    if (!mounted) {
      texture?.destroy();
      return;
    }

    if (texture == null) return;

    setState(() {
      // On Windows resize, texture is the same object (same flutterTextureId),
      // so old?.destroy() is skipped to avoid destroying the live texture.
      final old = _texture;
      _texture = texture;
      _currentWidth = width;
      _currentHeight = height;
      if (old != null && old != texture) {
        old.destroy();
      }
    });
  }
}
