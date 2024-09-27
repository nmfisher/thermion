import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("view");

  group('view tests', () {
    test('create view', () async {
      var viewer = await testHelper.createViewer();
      final renderTarget = await viewer.createRenderTarget(
          200, 400, await testHelper.createTexture(200, 400));
      final view = await viewer.createView();
      
      await view.updateViewport(200, 400);
      await view.setRenderTarget(renderTarget);
      await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
      await testHelper.capture(viewer, "create_view_with_render_target", renderTarget: renderTarget);
      await viewer.dispose();
    });
  });
}
