import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart/input/src/input_handler.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_dart/thermion_dart/input/src/implementations/fixed_orbit_camera_rotation_delegate.dart';
import 'package:vector_math/vector_math_64.dart';

// Generate mocks
@GenerateMocks([ThermionViewer])
import 'input_handlers.mocks.dart';

void main() {
  group('FixedOrbitRotateInputHandlerDelegate Tests', () {
    late MockThermionViewer mockViewer;
    late FixedOrbitRotateInputHandlerDelegate delegate;
    late ThermionEntity mockEntity;

    setUp(() {
      mockViewer = MockThermionViewer();
      mockEntity = 0;

      // Setup mock methods
      when(mockViewer.getMainCameraEntity()).thenAnswer((_) async => mockEntity);
      when(mockViewer.getCameraViewMatrix()).thenAnswer((_) async => Matrix4.identity());
      when(mockViewer.getCameraModelMatrix()).thenAnswer((_) async => Matrix4.translationValues(0, 0, 5));
      when(mockViewer.getCameraProjectionMatrix()).thenAnswer((_) async => Matrix4.identity());
      mockViewer.viewportDimensions = (800, 600);
      mockViewer.pixelRatio = 1.0;

      delegate = FixedOrbitRotateInputHandlerDelegate(
        mockViewer,
        entity: mockEntity,
        minimumDistance: 1.0,
      );
    });

    test('queue and execute rotation', () async {
      await delegate.queue(InputAction.ROTATE, Vector3(0.1, 0.1, 0));
      await delegate.execute();

      verify(mockViewer.setTransform(any, captureThat(
        predicate<Matrix4>((matrix) {
          var translation = matrix.getTranslation();
          var rotation = matrix.getRotation();

          // Check if the camera has rotated
          expect(rotation, isNot(equals(Matrix3.identity())));

          // Check if the distance from origin is maintained
          expect(translation.length, closeTo(5.0, 0.01));

          return true;
        })
      ))).called(1);
    });

    test('queue and execute zoom', () async {
      await delegate.queue(InputAction.PICK, Vector3(0, 0, 0.1));
      await delegate.execute();

      verify(mockViewer.setTransform(any, captureThat(
        predicate<Matrix4>((matrix) {
          var translation = matrix.getTranslation();

          // Check if the camera has moved closer
          expect(translation.length, lessThan(5.0));

          return true;
        })
      ))).called(1);
    });

    test('respects minimum distance', () async {
      when(mockViewer.getCameraModelMatrix()).thenAnswer((_) async => Matrix4.translationValues(0, 0, 1.5));
      await delegate.queue(InputAction.PICK, Vector3(0, 0, -1));
      await delegate.execute();

      verify(mockViewer.setTransform(any, captureThat(
        predicate<Matrix4>((matrix) {
          var translation = matrix.getTranslation();

          // Check if the camera distance is not less than the minimum distance
          expect(translation.length, greaterThanOrEqualTo(1.0));

          return true;
        })
      ))).called(1);
    });

    test('ignores translation in fixed orbit mode', () async {
      await delegate.queue(InputAction.TRANSLATE, Vector3(1, 1, 1));
      await delegate.execute();

      verifyNever(mockViewer.setTransform(any, any));
    });

    test('combined rotation and zoom', () async {
      await delegate.queue(InputAction.ROTATE, Vector3(0.1, 0.1, 0));
      await delegate.queue(InputAction.PICK, Vector3(0, 0, 0.1));
      await delegate.execute();

      verify(mockViewer.setTransform(any, captureThat(
        predicate<Matrix4>((matrix) {
          var translation = matrix.getTranslation();
          var rotation = matrix.getRotation();

          // Check if the camera has rotated
          expect(rotation, isNot(equals(Matrix3.identity())));

          // Check if the camera has moved closer
          expect(translation.length, lessThan(5.0));

          return true;
        })
      ))).called(1);
    });
  });
}