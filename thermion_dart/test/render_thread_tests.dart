import 'dart:async';
import 'dart:ffi';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("render_thread");

  await testHelper.setup();

  test("request frame on render thread", () async {
    await testHelper.withViewer((viewer) async {
      await viewer.render();
      await Future.delayed(Duration(seconds: 1));
      await viewer.setRendering(true);
      await Future.delayed(Duration(seconds: 1));
      await FilamentApp.instance!.requestFrame();
      await testHelper.capture(viewer.view, "render_thread_2");
    }, addSkybox: true);
  });
}
