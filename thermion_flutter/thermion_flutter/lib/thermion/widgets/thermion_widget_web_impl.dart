import 'dart:js_util';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import 'package:thermion_flutter_web/thermion_flutter_web_options.dart';
import 'package:web/web.dart';
import 'package:flutter/widgets.dart';

class ThermionWidgetWeb extends StatelessWidget {
  final ThermionFlutterWebOptions options;

  const ThermionWidgetWeb({super.key, required this.options});

  @override
  Widget build(BuildContext context) {
    if (options.importCanvasAsWidget) {
      return _ImageCopyingWidget();
    }
    return Container(color: const Color(0x00000000));
  }
}

class _ImageCopyingWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _ImageCopyingWidgetState();
  }
}

class _ImageCopyingWidgetState extends State<_ImageCopyingWidget> {
  ui.Image? _img;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      capture();
    });
  }

  Future capture() async {
    try {
      final ImageBitmap newSource = await promiseToFuture<ImageBitmap>(
          window.createImageBitmap(
              document.getElementById("canvas") as HTMLCanvasElement));
      _img = await ui_web.createImageFromImageBitmap(newSource);
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        capture();
      });
    } catch (err) {
      print(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawImage(image: _img!);
  }
}
