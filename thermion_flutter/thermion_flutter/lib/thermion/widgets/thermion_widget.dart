import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion/widgets/thermion_widget_web.dart';
import 'dart:async';

import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'resize_observer.dart';

class ThermionWidget extends StatefulWidget {
  final ThermionViewer viewer;

  ///
  /// The content to render before the texture widget is available.
  /// The default is a solid red Container, intentionally chosen to make it clear that there will be at least one frame where the Texture widget is not being rendered.
  ///
  final Widget? initial;

  const ThermionWidget({Key? key, this.initial, required this.viewer})
      : super(key: key);

  @override
  _ThermionWidgetState createState() => _ThermionWidgetState();
}

class _ThermionWidgetState extends State<ThermionWidget> {
  ThermionFlutterTexture? _texture;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await widget.viewer.initialized;
      widget.viewer.onDispose(() async {
        if (_texture != null) {
          var texture = _texture;
          _texture = null;
          if (mounted) {
            setState(() {});
          }
          await ThermionFlutterPlugin.destroyTexture(texture!);
        }
      });
      var dpr = MediaQuery.of(context).devicePixelRatio;
      
      var size = ((context.findRenderObject()) as RenderBox).size;
      _texture = await ThermionFlutterPlugin.createTexture(
          size.width, size.height, 0, 0, dpr);

      if (mounted) {
        setState(() {});
      }
    });
    super.initState();
  }

  bool _resizing = false;
  Timer? _resizeTimer;

  Future _resizeTexture(Size newSize) async {
    _resizeTimer?.cancel();
    _resizeTimer = Timer(Duration(milliseconds: 500), () async {
      if (_resizing || !mounted) {
        return;
      }
      _resizeTimer!.cancel();
      _resizing = true;
      var oldTexture = _texture;
      _texture = null;
      if (!mounted) {
        return;
      }

      var dpr = MediaQuery.of(context).devicePixelRatio;

      _texture = await ThermionFlutterPlugin.resizeTexture(oldTexture!,
          (dpr * newSize.width).ceil(), (dpr * newSize.height).ceil(), 0, 0);
      setState(() {});
      _resizing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (_texture == null || _resizing) {
        return widget.initial ?? Container(color: Colors.red);
      }
      return ResizeObserver(
          onResized: _resizeTexture, child: ThermionWidgetWeb());
    }

    if (_texture?.usesBackingWindow == true) {
      return ResizeObserver(
          onResized: _resizeTexture,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: TransparencyPainter()))
          ]));
    }

    if (_texture == null || _resizing) {
      return widget.initial ??
          Container(
              color:
                  kIsWeb ? const Color.fromARGB(0, 170, 129, 129) : Colors.red);
    }

    var textureWidget = Texture(
      key: ObjectKey("texture_${_texture!.flutterTextureId}"),
      textureId: _texture!.flutterTextureId!,
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

class TransparencyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..blendMode = BlendMode.clear
        ..color = const Color(0x00000000),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
