import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("picking");
  group("picking", () {
    test('pick cube', () async {
      await testHelper.withViewer((viewer) async {
        final cube = await viewer
            .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
        await viewer.setCameraPosition(0, 0, 10);
        final view = await viewer.getViewAt(0);
        final viewport = await view.getViewport();

        final completer = Completer<PickResult>();
        
        await viewer.pick(viewport.width ~/ 2, viewport.height ~/ 2, (result) {
          completer.complete(result);
        });

        for (int i = 0; i < 10; i++) {
          await testHelper.capture(viewer, "pick_cube0");
          if (completer.isCompleted) {
            break;
          }
        }

        expect(completer.isCompleted, true);
        var result = await completer.future;
        expect(result.entity, cube.entity);
      });
    });
  });
}
