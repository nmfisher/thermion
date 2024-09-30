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

  static final _views = <t.View>[];

  @override
  void dispose() {
    super.dispose();
    _views.remove(widget.view);
    _texture?.destroy();
  }

  @override
  void initState() {
    if (_views.contains(widget.view)) {
      throw Exception("View already embedded in a widget");
    }
    _views.add(widget.view);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await widget.viewer.initialized;

      var dpr = MediaQuery.of(context).devicePixelRatio;

      var size = ((context.findRenderObject()) as RenderBox).size;
      var width = (size.width * dpr).ceil();
      var height = (size.height * dpr).ceil();

      _texture = await ThermionFlutterPlatform.instance
          .createTexture(widget.view, width, height);

      await widget.view.updateViewport(_texture!.width, _texture!.height);
      var camera = await widget.view.getCamera();
      await camera.setLensProjection(
          aspect: _texture!.width / _texture!.height);

      if (mounted) {
        setState(() {});
      }

      _requestFrame();

      widget.viewer.onDispose(() async {
        var texture = _texture;
        if (mounted) {
          setState(() {});
        }
        await texture?.destroy();
        _views.clear();
      });
    });
    _callbackId = _numCallbacks;
    _numCallbacks++;
    super.initState();
  }

  bool _rendering = false;

  static int _numCallbacks = 0;
  static int _primaryCallback = 0;
  late int _callbackId;
  int lastRender = 0;

  void _requestFrame() {
    WidgetsBinding.instance.scheduleFrameCallback((d) async {
      if (widget.viewer.rendering && !_rendering) {
        _rendering = true;
        if (_callbackId == _primaryCallback && _texture != null) {
          await widget.viewer.requestFrame();
          lastRender = d.inMilliseconds;
        }
        await _texture?.markFrameAvailable();
        _rendering = false;
      }
      _requestFrame();
    });
  }

  final _resizing = <Future>[];

  Timer? _resizeTimer;

  Future _resize(Size oldSize, Size newSize) async {
    await Future.wait(_resizing);

    _resizeTimer?.cancel();

    _resizeTimer = Timer(const Duration(milliseconds: 100), () async {
      await Future.wait(_resizing);
      if (!mounted) {
        return;
      }

      if (newSize.width == _texture?.width &&
          newSize.height == _texture?.height) {
        return;
      }

      final completer = Completer();

      _resizing.add(completer.future);

      newSize *= MediaQuery.of(context).devicePixelRatio;

      var newWidth = newSize.width.ceil();
      var newHeight = newSize.height.ceil();

      await _texture?.resize(
        newWidth,
        newHeight,
        0,
        0,
      );


      await widget.view.updateViewport(_texture!.width, _texture!.height);
      var camera = await widget.view.getCamera();
      await camera.setLensProjection(
          aspect: _texture!.width.toDouble() / _texture!.height.toDouble());
      if (!mounted) {
        return;
      }
      setState(() {});
      completer.complete();
      _resizing.remove(completer.future);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_texture == null) {
      return widget.initial ?? Container(color: Colors.red);
    }

    return ResizeObserver(
        onResized: _resize,
        child: Stack(children: [
          Positioned.fill(
              child: Texture(
            key: ObjectKey("flutter_texture_${_texture!.flutterId}"),
            textureId: _texture!.flutterId,
            filterQuality: FilterQuality.none,
            freeze: false,
          ))
        ]));
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
