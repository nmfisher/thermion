import 'dart:js_util';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart';
import 'package:flutter/widgets.dart';
import 'dart:html' as html;

class ThermionWidgetWeb extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => ThermionWidgetWebState();
}

class ThermionWidgetWebState extends State<ThermionWidgetWeb> {
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
    if (_img == null) {
      return Container(color: Colors.transparent);
    }
    return RawImage(image: _img!);
  }
}
