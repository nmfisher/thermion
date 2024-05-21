import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_filament_platform_interface/flutter_filament_platform_interface.dart';
import 'package:flutter_filament_platform_interface/flutter_filament_texture.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'resize_observer.dart';

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
        
      if (mounted) {
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    if (_texture != null) {
      widget.plugin.destroyTexture(_texture!);
    }

    super.dispose();
  }

 
  bool _resizing = false;

  Future _resizeTexture(Size newSize) async {
    if (_resizing) {
      return;
    }
    await Future.delayed(Duration.zero);
    if (_resizing) {
      return;
    }
    _resizing = true;

    var dpr = MediaQuery.of(context).devicePixelRatio;

    _texture = await widget.plugin.resizeTexture(_texture!,
        (dpr * newSize.width).ceil(), (dpr * newSize.height).ceil(), 0, 0);
    print(
        "Resized texture, new flutter ID is ${_texture!.flutterTextureId} (hardware ID ${_texture!.hardwareTextureId})");
    setState(() {});
    _resizing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_texture == null) {
      return widget.initial ??
          Container(color: kIsWeb ? Colors.transparent : Colors.red);
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
