import 'dart:async';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("integration");

  group("skybox", () {
    test('load skybox', () async {
      var viewer = await testHelper.createViewer();
      await viewer.loadSkybox(
          "file:///${testHelper.testDir}/assets/default_env_skybox.ktx");
      await testHelper.capture(viewer, "load_skybox");
      await viewer.removeSkybox();
      await testHelper.capture(viewer, "remove_skybox");
    });
  });
}
