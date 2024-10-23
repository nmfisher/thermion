import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("renderThread");

  group('camera', () {
    test('getCameraModelMatrix, getCameraPosition, rotation', () async {
      var viewer = await testHelper.createViewer();
      var matrix = await viewer.getCameraModelMatrix();
      expect(matrix.trace(), 4);

      await viewer.setCameraPosition(2.0, 2.0, 2.0);
      matrix = await viewer.getCameraModelMatrix();
      var position = matrix.getColumn(3).xyz;
      expect(position.x, 2.0);
      expect(position.y, 2.0);
      expect(position.z, 2.0);

      position = await viewer.getCameraPosition();
      expect(position.x, 2.0);
      expect(position.y, 2.0);
      expect(position.z, 2.0);
    });

    
  });
}
