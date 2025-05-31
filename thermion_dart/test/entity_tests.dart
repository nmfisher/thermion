@Timeout(const Duration(seconds: 600))
import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  var testHelper = TestHelper("entity_tests");
  await testHelper.setup();

  test('get entity names', () async {
    var asset = await FilamentApp.instance!.loadGltfFromBuffer(
        File("${testHelper.testDir}/assets/cube.glb").readAsBytesSync(),
        nullptr);

    expect(null, await FilamentApp.instance!.getNameForEntity(asset.entity));
    var children = await asset.getChildEntities();
    var child = children.first;

    expect("Cube", await FilamentApp.instance!.getNameForEntity(child));
    var childNames = await asset.getChildEntityNames();
    expect("Cube", childNames.first);
  });
}
