import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/grid_overlay.dart';
import 'helpers.dart';

Future<void> captureGrid(ThermionViewer viewer, String name) async {
  final helper = TestHelper('grid_depth_diagnostic');
  final camera = await viewer.getActiveCamera();
  await camera.lookAt(Vector3(0, 5, 5));
  await helper.capture(viewer.view, '${name}_visible');
  await camera.lookAt(Vector3(0, 5, 10));
  await helper.capture(viewer.view, '${name}_angle');
  for (var i = 0; i < 10; i++) {
    await camera.lookAt(Vector3(0, 1 + i * 10, 0.005));
    await helper.capture(viewer.view, '${name}_fade$i');
  }
}

void main() async {
  final helper = TestHelper('grid_depth_diagnostic');
  await helper.setup();
  test('grid depth and draw order', () async {
    await helper.withViewer((viewer) async {
      await viewer.setGridOverlayVisibility(true);
      final app = FilamentApp.instance! as FFIFilamentApp;
      final grid = await GridOverlay.create(app);
      await captureGrid(viewer, 'original');
      for (final depthWrite in [true, false]) {
        for (final reverse in [false, true]) {
          for (var i = 0; i < grid.entities.length; i++) {
            final entity = grid.entities[i];
            final material = await app.renderableManager.getMaterialInstanceAt(entity, 0);
            await material!.setDepthWriteEnabled(depthWrite);
            await app.renderableManager.setBlendOrderAt(entity, 0, reverse ? grid.entities.length - i : i);
          }
          await captureGrid(viewer, 'depth_${depthWrite}_reverse_$reverse');
        }
      }
    }, postProcessing: true);
  });
}
