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

  test('get entity bounding boxes', () async {
    var cube = await FilamentApp.instance!
        .createGeometry(GeometryHelper.cube(), nullptr);
    var bb = await FilamentApp.instance!.getBoundingBox(cube.entity);

    expect(bb.center.x, 0.0);
    expect(bb.center.y, 0.0);
    expect(bb.center.z, 0.0);
    
    expect(bb.max.x, 1);
    expect(bb.max.y, 1);
    expect(bb.max.z, 1);

    expect(bb.min.x, -1);
    expect(bb.min.y, -1);
    expect(bb.min.z, -1);
  });
}
