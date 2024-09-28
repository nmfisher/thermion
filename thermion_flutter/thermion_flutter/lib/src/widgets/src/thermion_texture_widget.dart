import 'dart:async';
import 'package:flutter/material.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/view.dart' as t;
import 'package:thermion_flutter/src/widgets/src/resize_observer.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

class ThermionTextureWidget extends StatefulWidget {
  final ThermionViewer viewer;

  final t.View view;

  final Widget? initial;

  const ThermionTextureWidget(
      {super.key, required this.viewer, required this.view, this.initial});

  @override
  State<StatefulWidget> createState() {
    return _ThermionTextureWidgetState();
  }
}

class _ThermionTextureWidgetState extends State<ThermionTextureWidget> {
  ThermionFlutterTexture? _texture;
  RenderTarget? _renderTarget;

  @override
  void dispose() {
    super.dispose();
    _texture?.destroy();
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await widget.viewer.initialized;

      var dpr = MediaQuery.of(context).devicePixelRatio;

      var size = ((context.findRenderObject()) as RenderBox).size;
      var width = (size.width * dpr).ceil();
      var height = (size.height * dpr).ceil();

      _texture =
          await ThermionFlutterPlatform.instance.createTexture(width, height);

      _renderTarget = await widget.viewer.createRenderTarget(
          _texture!.width, _texture!.height, _texture!.hardwareId);

      await widget.view.setRenderTarget(_renderTarget!);

      await widget.view.updateViewport(width, height);
      var camera = await widget.view.getCamera();
      await camera.setLensProjection(aspect: width / height);

      if (mounted) {
        setState(() {});
      }

      _requestFrame();

      widget.viewer.onDispose(() async {
        var texture = _texture;
        if (mounted) {
          setState(() {});
        }
        if (texture != null) {
          _renderTarget = await widget.viewer.createRenderTarget(
              texture.width, texture.height, texture.flutterId);
          await widget.view.setRenderTarget(null);
          await _renderTarget!.destroy();
          texture.destroy();
        }
      });
    });
    super.initState();
  }

  bool _rendering = false;

  void _requestFrame() {
    WidgetsBinding.instance.scheduleFrameCallback((d) async {
      if (!_rendering) {
        _rendering = true;
        await widget.viewer.requestFrame();
        await _texture?.markFrameAvailable();
        _rendering = false;
      }
      _requestFrame();
    });
  }

  bool _resizing = false;
  Timer? _resizeTimer;

  Future _resize(Size newSize) async {
    
    _resizeTimer?.cancel();

    _resizeTimer = Timer(const Duration(milliseconds: 10), () async {
      if (_resizing || !mounted) {
        return;
      }
      _resizeTimer!.cancel();
      _resizing = true;

      if (!mounted) {
        return;
      }

      newSize *= MediaQuery.of(context).devicePixelRatio;

      var newWidth = newSize.width.ceil();
      var newHeight = newSize.height.ceil();

      await _texture?.resize(
        newWidth,
        newHeight,
        0,
        0,
      );

      await widget.view.updateViewport(newWidth, newHeight);
      var camera = await widget.view.getCamera();
      await camera.setLensProjection(aspect: newWidth / newHeight);

      setState(() {});
      _resizing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_texture == null) {
      return widget.initial ?? Container(color: Colors.red);
    }

    return Stack(children: [
      Positioned.fill(
          child: ResizeObserver(
              onResized: _resize,
              child: Stack(children: [
                Positioned.fill(
                    child: Texture(
                  key: ObjectKey("flutter_texture_${_texture!.flutterId}"),
                  textureId: _texture!.flutterId,
                  filterQuality: FilterQuality.none,
                  freeze: false,
                ))
              ]))),
      Align(
        alignment: Alignment.bottomLeft,
        child: ElevatedButton(
            onPressed: () async {
              var img =
                  await widget.viewer.capture(renderTarget: _renderTarget!);
              print(img);
            },
            child: Text("CAPTURE")),
      )
    ]);
  }
}



// class _ThermionWidgetState extends State<ThermionWidget> {
  
//   ThermionFlutterTexture? _texture;

//   @override
//   void initState() {
//     WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
//       await widget.viewer.initialized;
//       widget.viewer.onDispose(() async {
//         _rendering = false;

//         if (_texture != null) {
//           var texture = _texture;
//           _texture = null;
//           if (mounted) {
//             setState(() {});
//           }
//           await ThermionFlutterPlugin.destroyTexture(texture!);
//         }
//       });
//       var dpr = MediaQuery.of(context).devicePixelRatio;

//       var size = ((context.findRenderObject()) as RenderBox).size;
//       _texture = await ThermionFlutterPlugin.createTexture(
//           size.width, size.height, 0, 0, dpr);

//       if (mounted) {
//         setState(() {});
//       }

//       _requestFrame();
//     });
//     super.initState();
//   }

//   bool _rendering = false;

//   void _requestFrame() {
//     WidgetsBinding.instance.scheduleFrameCallback((d) async {
//       if (!_rendering) {
//         _rendering = true;
//         await widget.viewer.requestFrame();
//         _rendering = false;
//       }
//       _requestFrame();
//     });
//   }

//   bool _resizing = false;
//   Timer? _resizeTimer;

//   Future _resizeTexture(Size newSize) async {
//     _resizeTimer?.cancel();
//     _resizeTimer = Timer(const Duration(milliseconds: 500), () async {
//       if (_resizing || !mounted) {
//         return;
//       }
//       _resizeTimer!.cancel();
//       _resizing = true;

//       if (!mounted) {
//         return;
//       }

//       var dpr = MediaQuery.of(context).devicePixelRatio;

//       _texture.resize(newSize.width.ceil(), newSize.height.ceil(), 0, 0, dpr);
//       setState(() {});
//       _resizing = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_texture == null || _resizing) {
//       return widget.initial ??
//           Container(
//               color:
//                   kIsWeb ? const Color.fromARGB(0, 170, 129, 129) : Colors.red);
//     }

//     var textureWidget = Texture(
//       key: ObjectKey("texture_${_texture!.flutterId}"),
//       textureId: _texture!.flutterId!,
//       filterQuality: FilterQuality.none,
//       freeze: false,
//     );

//     return ResizeObserver(
//         onResized: _resizeTexture,
//         child: Stack(children: [
//           Positioned.fill(
//               child: Platform.isLinux || Platform.isWindows
//                   ? Transform(
//                       alignment: Alignment.center,
//                       transform: Matrix4.rotationX(
//                           pi), // TODO - this rotation is due to OpenGL texture coordinate working in a different space from Flutter, can we move this to the C++ side somewhere?
//                       child: textureWidget)
//                   : textureWidget)
//         ]));
//   }
// }
