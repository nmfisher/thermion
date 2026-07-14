import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("vertex_animation");
  await testHelper.setup();

  test('vertex animation - interpolate cube vertices over 10 frames', () async {
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((
      result,
    ) async {
      final asset = await result.viewer.createGeometry(GeometryUtils.cube());
      await result.viewer.addToScene(asset);

      // Capture the initial state (frame 0)
      await testHelper.capture(result.viewer.view, "vertex_anim_frame_00");

      // The standard cube vertices (24 verts x 3 components = 72 floats)
      final startVertices = Float32List.fromList([
        // Front face
        -1, -1, 1, 1, -1, 1, 1, 1, 1, -1, 1, 1,
        // Back face
        -1, -1, -1, 1, -1, -1, 1, 1, -1, -1, 1, -1,
        // Top face
        -1, 1, 1, 1, 1, 1, 1, 1, -1, -1, 1, -1,
        // Bottom
        -1, -1, -1, 1, -1, -1, 1, -1, 1, -1, -1, 1,
        // Right
        1, -1, 1, 1, -1, -1, 1, 1, -1, 1, 1, 1,
        // Left
        -1, -1, -1, -1, -1, 1, -1, 1, 1, -1, 1, -1,
      ]);

      // Target: deform the cube by pulling the top-right-front vertex (index 2)
      // outward to (2, 2, 2). Also deform shared copies of that vertex
      // (indices 9 and 19 in the top and right faces).
      final endVertices = Float32List.fromList(startVertices);
      // Front face vertex 2
      endVertices[6] = 2;
      endVertices[7] = 2;
      endVertices[8] = 2;
      // Top face vertex 9 (same corner)
      endVertices[27] = 2;
      endVertices[28] = 2;
      endVertices[29] = 2;
      // Right face vertex 19 (same corner)
      endVertices[57] = 2;
      endVertices[58] = 2;
      endVertices[59] = 2;

      final vb = asset.getVertexBuffer();
      expect(
        vb,
        isNotNull,
        reason: 'Geometry asset should expose a VertexBuffer',
      );

      // Animate over 10 frames by linearly interpolating between start and end
      const totalFrames = 10;
      for (var frame = 1; frame <= totalFrames; frame++) {
        final t = frame / totalFrames;
        final interpolated = Float32List(startVertices.length);
        for (var i = 0; i < interpolated.length; i++) {
          interpolated[i] =
              startVertices[i] + (endVertices[i] - startVertices[i]) * t;
        }

        await vb!.setBufferAt(0, interpolated);

        final frameStr = frame.toString().padLeft(2, '0');
        await testHelper.capture(
          result.viewer.view,
          "vertex_anim_frame_$frameStr",
        );
      }

      // Clean up
      await result.viewer.removeFromScene(asset);
      await result.viewer.destroyAsset(asset);
    });
  });
}
