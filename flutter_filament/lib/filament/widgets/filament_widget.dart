import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_filament/filament/flutter_filament_plugin.dart';
import 'package:flutter_filament/filament/flutter_filament_texture.dart';
import 'dart:async';
import 'package:flutter_filament/filament/widgets/resize_observer.dart';
import 'package:flutter_filament/flutter_filament.dart';

class FilamentWidget extends StatefulWidget {
  final FlutterFilamentPlugin plugin;

  ///
  /// The content to render before the texture widget is available.
  /// The default is a solid red Container, intentionally chosen to make it clear that there will be at least one frame where the Texture widget is not being rendered.
  ///
  final Widget? initial;

  const FilamentWidget({Key? key, this.initial, required this.plugin})
      : super(key: key);

  @override
  _FilamentWidgetState createState() => _FilamentWidgetState();
}

class _FilamentWidgetState extends State<FilamentWidget> {
  FlutterFilamentTexture? _texture;

  late final AppLifecycleListener _appLifecycleListener;

  Rect get _rect {
    final renderBox = (context.findRenderObject()) as RenderBox;
    final size = renderBox.size;
    final translation = renderBox.getTransformTo(null).getTranslation();
    return Rect.fromLTWH(translation.x, translation.y, size.width, size.height);
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      var dpr = MediaQuery.of(context).devicePixelRatio;
      var size = ((context.findRenderObject()) as RenderBox).size;
      var width = (dpr * size.width).ceil();
      var height = (dpr * size.height).ceil();
      _texture = await widget.plugin.createTexture(width, height, 0, 0);
      _appLifecycleListener = AppLifecycleListener(
        onStateChange: _handleStateChange,
      );
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    if (_texture != null) {
      widget.plugin.destroyTexture(_texture!);
    }

    _appLifecycleListener.dispose();
    super.dispose();
  }

  bool _wasRenderingOnInactive = false;

  void _handleStateChange(AppLifecycleState state) async {
    await widget.plugin.initialized;
    switch (state) {
      case AppLifecycleState.detached:
        print("Detached");
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = widget.plugin.rendering;
        }
        await widget.plugin.setRendering(false);
        break;
      case AppLifecycleState.hidden:
        print("Hidden");
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = widget.plugin.rendering;
        }
        await widget.plugin.setRendering(false);
        break;
      case AppLifecycleState.inactive:
        print("Inactive");
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = widget.plugin.rendering;
        }
        // on Windows in particular, restoring a window after minimizing stalls the renderer (and the whole application) for a considerable length of time.
        // disabling rendering on minimize seems to fix the issue (so I wonder if there's some kind of command buffer that's filling up while the window is minimized).
        await widget.plugin.setRendering(false);
        break;
      case AppLifecycleState.paused:
        print("Paused");
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = widget.plugin.rendering;
        }
        await widget.plugin.setRendering(false);
        break;
      case AppLifecycleState.resumed:
        print("Resumed");
        await widget.plugin.setRendering(_wasRenderingOnInactive);
        break;
    }
  }

  Future _resizeTexture(Size newSize) async {
    var dpr = MediaQuery.of(context).devicePixelRatio;

    _texture = await widget.plugin.resizeTexture(
        _texture!, (dpr * newSize.width).ceil(), (dpr * newSize.height).ceil(), 0, 0);
    print(
        "Resized texture, new flutter ID is ${_texture!.flutterTextureId} (hardware ID ${_texture!.hardwareTextureId})");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_texture == null) {
      return widget.initial ?? Container(color: Colors.red);
    }

    var textureWidget = Texture(
      key: ObjectKey("texture_${_texture!.flutterTextureId}"),
      textureId: _texture!.flutterTextureId,
      filterQuality: FilterQuality.none,
      freeze: false,
    );

    return ResizeObserver(
        onResized: _resizeTexture,
        child: Stack(children: [
          Positioned.fill(
              child: Platform.isLinux || Platform.isWindows
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationX(
                          pi), // TODO - this rotation is due to OpenGL texture coordinate working in a different space from Flutter, can we move this to the C++ side somewhere?
                      child: textureWidget)
                  : textureWidget)
        ]));
  }
}
