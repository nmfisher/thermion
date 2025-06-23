import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter_web/thermion_flutter_web.dart';
import 'package:web/web.dart' as web;
import 'resize_observer.dart';

class ThermionWidgetWeb extends StatefulWidget {
  final ThermionFlutterWebOptions options;
  final ThermionViewer viewer;

  const ThermionWidgetWeb(
      {super.key,
      this.options = const ThermionFlutterWebOptions(),
      required this.viewer});

  @override
  State<StatefulWidget> createState() => _ThermionWidgetWebState();
}

class _ThermionWidgetWebState extends State<ThermionWidgetWeb> {
  void initState() {
    super.initState();
    _requestFrame();
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
    ThermionFlutterWebPlugin.instance
        .resizeCanvas(newSize.width, newSize.height);
    await widget.viewer.setViewport(width, height);
  }

  @override
  Widget build(BuildContext context) {
    return ResizeObserver(
        onResized: _resize,
        child: widget.options.importCanvasAsWidget
            ? _ImageCopyingWidget(viewer: widget.viewer)
            : SizedBox.expand(
                child: Container(color: const Color(0x00000000))));
  }
}

class _PlatformView extends StatefulWidget {
  final ThermionViewer viewer;

  const _PlatformView({super.key, required this.viewer});
  @override
  State<StatefulWidget> createState() => _PlatformViewState();
}

class _PlatformViewState extends State<_PlatformView> {
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
