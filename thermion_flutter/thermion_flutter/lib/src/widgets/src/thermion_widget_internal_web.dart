import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart' hide View;
import 'package:logging/logging.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide BlendMode;
import 'package:web/web.dart' as web;
import '../../platform/platform.dart';
import 'resize_observer.dart';

class ThermionWidgetInternal extends StatefulWidget {
  ///
  final ThermionViewer viewer;

  ///
  final Widget? initial;

  /// A callback that will be invoked whenever this widget (and the underlying texture is resized).
  final Future Function(Size size, View view, double pixelRatio)? onResize;

  /// When true, an FPS counter will be displayed at the top right of the widget
  final bool showFpsCounter;

  const ThermionWidgetInternal({
    super.key,
    required this.viewer,
    this.initial,
    this.onResize,
    this.showFpsCounter = false,
  });

  @override
  State<StatefulWidget> createState() => _ThermionWidgetWebState();
}

class _ThermionWidgetWebState extends State<ThermionWidgetInternal> {

  late final ThermionFlutterPluginImpl plugin;

  @override
  void initState() {
    super.initState();

    plugin = ThermionFlutterPlugin.instance as ThermionFlutterPluginImpl;
    if (!ThermionFlutterPlugin.instance.options.webOptions.importCanvasAsWidget) {
      _requestFrame();
    }
  }

  DateTime lastRender = DateTime.now();

  void _requestFrame() async {
    Pointer? stackPtr;
    WidgetsBinding.instance.scheduleFrameCallback((d) async {
      if (stackPtr != null) {
        stackRestore(stackPtr!);
        stackPtr = null;
      }

      var elapsed = DateTime.now().microsecondsSinceEpoch -
          lastRender.microsecondsSinceEpoch;

      lastRender = DateTime.now();
      if (widget.viewer.rendering) {
        await FilamentApp.instance!.requestFrame();
      }

      stackPtr = stackSave();
      _requestFrame();
    });
  }

  void _resize(Size oldSize, Size newSize) async {
    var width = newSize.width.toInt();
    var height = newSize.height.toInt();
    plugin.resizeCanvas(newSize.width, newSize.height);
    await widget.viewer.setViewport(width, height);
  }

  @override
  Widget build(BuildContext context) {
    print("WEB");

    return ResizeObserver(
        onResized: _resize,
        child: ThermionFlutterPlugin.instance.options.webOptions.importCanvasAsWidget
            ? _ImageCopyingWidget(viewer: widget.viewer)
            : SizedBox.expand(
                child: CustomPaint(painter: TransparencyPainter())));
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


class _PlatformView extends StatefulWidget {
  final ThermionViewer viewer;

  const _PlatformView({super.key, required this.viewer});
  @override
  State<StatefulWidget> createState() => _PlatformViewState();
}

class _PlatformViewState extends State<_PlatformView> {
  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(
      'imported-canvas',
      (int viewId, {Object? params}) {
        var canvas = web.document.getElementById("thermion_canvas");
        return canvas! as Object;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: 'imported-canvas',
      onPlatformViewCreated: (i) {},
      creationParams: <String, Object?>{
        'key': 'someValue',
      },
    );
  }
}

class _ImageCopyingWidget extends StatefulWidget {
  final ThermionViewer viewer;

  const _ImageCopyingWidget({super.key, required this.viewer});
  @override
  State<StatefulWidget> createState() {
    return _ImageCopyingWidgetState();
  }
}

class _ImageCopyingWidgetState extends State<_ImageCopyingWidget> {
  late final _logger = Logger(this.runtimeType.toString());
  late web.HTMLCanvasElement canvas;
  ui.Image? _img;
  double width = 0;
  double height = 0;

  @override
  void initState() {
    super.initState();
    canvas =
        web.document.getElementById("thermion_canvas") as web.HTMLCanvasElement;
    WidgetsBinding.instance.addPostFrameCallback((t) {
      _refresh(Duration.zero);
    });
  }

  void _refresh(Duration _) async {
    try {
      final rb = this.context.findRenderObject() as RenderBox?;

      if (rb == null) {
        setState(() {});
        return;
      }

      if (rb.size.isEmpty) {
        setState(() {});
        return;
      }

      // if (_resizing) {
      //   setState(() {});
      //   return;
      // }

      if (canvas.width != rb.size.width || canvas.height != rb.size.height) {
        // ThermionFlutterWebPlugin.instance
        //     .resizeCanvas(rb.size.width, rb.size.height);
        // await widget.viewer
        //     .setViewport(rb.size.width.ceil(), rb.size.height.ceil())
        //     .timeout(Duration(seconds: 1));
      }

      width = canvas.width * web.window.devicePixelRatio;
      height = canvas.height * web.window.devicePixelRatio;
      _img = await ui_web.createImageFromTextureSource(canvas,
          width: width.ceil(), height: height.ceil(), transferOwnership: true);

      _request++;
    } catch (err) {
      _logger.severe(err);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {});
      });
      WidgetsBinding.instance.scheduleFrameCallback(_refresh);
    }
  }

  int _request = 0;

  // bool _resizing = false;
  // Timer? _resizeTimer;

  // void _resize(Size oldSize, Size newSize) {
  //   _resizeTimer?.cancel();
  //   _resizing = true;
  //   _resizeTimer = Timer(Duration(milliseconds: 100), () {
  //     _resizing = false;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    if (_img == null) {
      return Container();
    }

    return RawImage(
      key: Key(_request.toString()),
      width: width,
      height: height,
      image: _img!,
      filterQuality: FilterQuality.high,
      isAntiAlias: false,
    );
  }
}
