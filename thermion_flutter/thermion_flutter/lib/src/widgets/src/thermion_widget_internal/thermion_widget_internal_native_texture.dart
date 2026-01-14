import 'dart:async';
import 'package:flutter/material.dart' hide View;
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture;

// Inserts [view] into the widget tree by allocating a hardware surface 
// and binding to the [view]. The actual implementation 
// (e.g. texture vs window, render target vs swapchain, etc) will differ by 
// the actual platform; see [ThermionFlutterPluginImpl] for details.
class ThermionWidgetInternal extends StatefulWidget {
  
  final View view;

  ThermionWidgetInternal({super.key, required this.view});

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
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var dpr = MediaQuery.of(context).devicePixelRatio;

    return LayoutBuilder(builder: (ctx, constraints) {
      var width = (constraints.maxWidth * dpr).ceil();
      var height = (constraints.maxHeight * dpr).ceil();

      if (width == 0 || height == 0) {
        return SizedBox.shrink();
      }

      // If size hasn't changed, keep using current texture
      if (width == _currentWidth && height == _currentHeight) {
        if (_texture == null) {
          // Initial case - no texture yet
          _scheduleTextureAllocation(width, height);
        }
        return _buildTexture(_texture);
      }

      // Size changed - schedule a debounced allocation
      _scheduleTextureAllocation(width, height);

      // Keep showing the old texture during debounce
      return _buildTexture(_texture);
    });
  }

  Widget _buildTexture(PlatformTextureDescriptor? texture) {
    if (texture == null) {
      return SizedBox.shrink();
    }
    return Texture(
      key: ObjectKey("flutter_texture_${texture.flutterTextureId}"),
      textureId: texture.flutterTextureId,
      filterQuality: FilterQuality.none,
      freeze: false,
    );
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
    final texture = await ThermionFlutterPlugin.instance
        .createTextureAndBindToView(widget.view, width, height);

    if (!mounted) {
      texture?.destroy();
      return;
    }

    if (texture == null) return;

    setState(() {
      final old = _texture;
      _texture = texture;
      _currentWidth = width;
      _currentHeight = height;
      old?.destroy();
    });
  }
}
