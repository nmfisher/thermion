import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:thermion_flutter/filament/widgets/filament_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

  Future _snapshot(WidgetTester tester, String label, [int seconds = 0]) async {
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    for (int i = 0; i < seconds; i++) {
      await Future.delayed(Duration(seconds: 1));
      await tester.pumpAndSettle(Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle(Duration(milliseconds: 16));
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

  Future tap(WidgetTester tester, String label, [int seconds = 0]) async {
    var target = find.text(label, skipOffstage: false);

    if (!target.hasFound) {
      print("Couldn't find target, waiting 100ms");
      await tester.pump(const Duration(milliseconds: 100));
      target = find.text(label);
    }

    await tester.tap(target.first);
    await _snapshot(tester, label.replaceAll(RegExp("[ -:]"), ""), seconds);
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

  testWidgets('test', (WidgetTester tester) async {
    app.main();
    await pumpUntilFound(tester, find.byType(app.ExampleWidget));

    await tester.pumpAndSettle();

    await _snapshot(tester, "fresh");

    await tap(tester, "Controller / Viewer");
    await tap(tester, "Create ThermionFlutterPlugin (default ubershader)");
    await tap(tester, "Controller / Viewer");
    await tap(tester, "Create ThermionViewerFFI",
        4); // on older devices this may take a while, so let's insert a length delay

    await tap(tester, "Scene");
    await tap(tester, "Rendering");
    await tap(tester, "Set continuous rendering to true");

    await tap(tester, "Scene");
    await tap(tester, "Assets");
    await tap(tester, "Shapes");
    await tap(tester, "Load GLB");

    await tester.pump();

    await tap(tester, "Scene");
    await tap(tester, "Assets");
    await tap(tester, "Load skybox", 1);

    await tap(tester, "Scene");
    await tap(tester, "Assets");
    await tap(tester, "Load IBL", 1);

    final Offset pointerLocation =
        tester.getCenter(find.byType(ThermionWidget));
    TestPointer testPointer = TestPointer(1, PointerDeviceKind.mouse);

    // scroll/zoom
    testPointer.hover(pointerLocation);
    await tester.sendEventToBinding(testPointer.scroll(const Offset(0.0, 1.0)));
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(testPointer.scroll(const Offset(0.0, 1.0)));
    await tester.pumpAndSettle();
    await _snapshot(tester, "zoomin");

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

    await _snapshot(tester, "rotate", 2);

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

    await _snapshot(tester, "pan");

    await tap(tester, "Scene");
    await tap(tester, "Assets");
    await tap(tester, "Shapes");
    await tap(tester, "Transform to unit cube");

    await tap(tester, "Scene");
    await tap(tester, "Assets");
    await tap(tester, "Shapes");
    await tap(tester, "Set position to 1, 1, -1");

    await tap(tester, "Scene");
    await tap(tester, "Camera");
    await tap(tester, "Disable frustum culling");

    await tap(tester, "Scene");
    await tap(tester, "Rendering");
    await tap(tester, "Set tone mapping to linear");

    await tap(tester, "Scene");
    await tap(tester, "Camera");
    await tap(tester, 'Set to first camera in last added asset');

    await tap(tester, "Move to last added asset");
    await tap(tester, "Move to 1, 1, -1");

    await tap(tester, 'Toggle viewport size', 1);
    await tap(tester, 'Toggle viewport size', 1);
    await tap(tester, 'Toggle viewport size', 1);
  });
}
