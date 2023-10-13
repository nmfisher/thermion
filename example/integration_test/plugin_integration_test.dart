import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:polyvox_filament/widgets/filament_widget.dart';
import '../lib/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      as IntegrationTestWidgetsFlutterBinding;

  late String platformIdentifier;
  if (Platform.isIOS) {
    platformIdentifier = "ios";
  } else if (Platform.isAndroid) {
    platformIdentifier = "android";
  } else if (Platform.isMacOS) {
    platformIdentifier = "macos";
  } else if (Platform.isWindows) {
    platformIdentifier = "windows";
  } else if (Platform.isLinux) {
    platformIdentifier = "linux";
  } else {
    throw Exception("Unexpected platform");
  }

  int _counter = 0;

  Future _snapshot(WidgetTester tester, Device device, String label,
      [int seconds = 0]) async {
    for (int i = 0; i < seconds; i++) {
      await Future.delayed(Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    await Future.delayed(Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    var screenshotPath = '$platformIdentifier/${_counter}_$label';
    if (Platform.isIOS) {
      // this is currently hanging on Android
      // see https://github.com/flutter/flutter/issues/127306
      // it is also not yet implemented on Windows or MacOS
      await binding.convertFlutterSurfaceToImage();
      final bytes = await binding.takeScreenshot(screenshotPath);
    }
    _counter++;
  }

  late Device device;

  Future tap(WidgetTester tester, String label, [int seconds = 0]) async {
    var target = find.text(label).first;
    await tester.dragUntilVisible(
        target,
        find.byType(SingleChildScrollView),
        // widget you want to scroll
        const Offset(0, 500), // delta to move
        duration: Duration(milliseconds: 10));
    await tester.tap(target);
    await _snapshot(
        tester, device, label.replaceAll(RegExp("[ -:]"), ""), seconds);
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    bool timerDone = false;
    final timer = Timer(
        timeout, () => throw TimeoutException("Pump until has timed out"));
    while (timerDone != true) {
      await tester.pump();

      final found = tester.any(finder);
      if (found) {
        timerDone = true;
      }
    }
    timer.cancel();
  }

  testGoldens('test', (WidgetTester tester) async {
    app.main();
    await pumpUntilFound(tester, find.byType(app.ExampleWidget));
    device = Device(size: Size(800, 600), name: "desktop");
    await _snapshot(tester, device, "fresh");
    await tap(tester, "create viewer (default ubershader)", 4);

    await tap(tester, "load skybox");
    await tap(tester, "load IBL");
    await tap(tester, "Rendering: false");
    await tap(tester, "load shapes GLB");

    final Offset pointerLocation =
        tester.getCenter(find.byType(FilamentWidget));
    TestPointer testPointer = TestPointer(1, PointerDeviceKind.mouse);

    // scroll/zoom
    testPointer.hover(pointerLocation);
    await tester.sendEventToBinding(testPointer.scroll(const Offset(0.0, 1.0)));
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(testPointer.scroll(const Offset(0.0, 1.0)));
    await tester.pumpAndSettle();
    await _snapshot(tester, device, "zoomin");

    // rotate
    testPointer =
        TestPointer(1, PointerDeviceKind.mouse, null, kTertiaryButton);
    testPointer.hover(pointerLocation);
    await tester.sendEventToBinding(testPointer.down(pointerLocation));
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(
        testPointer.move(pointerLocation + Offset(10.0, 10.0)));
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(
        testPointer.move(pointerLocation + Offset(20.0, 20.0)));
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(testPointer.up());

    await _snapshot(tester, device, "rotate", 2);

    // pan
    testPointer = TestPointer(1, PointerDeviceKind.mouse, null, kPrimaryButton);
    testPointer.hover(pointerLocation);
    await tester.sendEventToBinding(testPointer.down(pointerLocation));
    await tester
        .sendEventToBinding(testPointer.move(pointerLocation + Offset(0, 1.0)));

    for (int i = 0; i < 60; i++) {
      await tester.sendEventToBinding(testPointer
          .move(pointerLocation + Offset(i.toDouble() * 2, i.toDouble() * 2)));
      await tester.pumpAndSettle();
    }
    await tester.sendEventToBinding(testPointer.up());
    await tester.pumpAndSettle();

    await _snapshot(tester, device, "pan");

    await tap(tester, "transform to unit cube");
    await tap(tester, "set shapes position to 1, 1, -1");
    await tap(tester, "Disable frustum culling");
    await tap(tester, "Set tone mapping to linear");
    await tap(tester, "Move camera to asset");
    await tap(tester, "move camera to 1, 1, -1");
    await tap(tester, 'set camera to first camera in shapes GLB');

    await tap(tester, 'resize');
  });
}
