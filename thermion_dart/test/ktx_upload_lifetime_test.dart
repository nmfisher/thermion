import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/bindings/src/ffi.dart' as ffi;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_ktx1_bundle.dart';

// Owns no additional engine. Only the skybox builder is replaced, to fail after
// the real native texture creation/upload has started.
class FailingSkyboxApp extends FFIFilamentApp {
  FailingSkyboxApp(FFIFilamentApp app)
    : super(
        app.engine,
        app.gltfAssetLoader,
        app.renderer,
        app.transformManager.getNativeHandle(),
        app.ubershaderMaterialProvider,
        app.renderManager.getNativeHandle(),
        app.renderThreadHandle,
        app.nameComponentManager,
        app.loadResource,
        app.lightManager.getNativeHandle(),
        app.renderableManager.getNativeHandle(),
        app.animationManager.getNativeHandle(),
      );

  @override
  Future<Skybox> buildSkybox({Texture? texture, bool showSun = false, double? intensity, int priority = 7}) async {
    expect(texture, isNotNull);
    throw StateError('skybox setup failed after texture creation');
  }
}

void main() {
  final fixturePath = Platform.environment['THERMION_UPLOAD_LIFETIME_FIXTURE'];
  group('KTX upload lifetime', () {
    late FFIFilamentApp app;
    late Uint8List bytes;
    late DynamicLibrary fixture;
    setUpAll(() async {
      fixture = DynamicLibrary.open(fixturePath!);
      bytes = await File('../examples/assets/default_env_skybox.ktx').readAsBytes();
      await FFIFilamentApp.create(
        config: FFIFilamentConfig(
          backend: Platform.isMacOS ? Backend.METAL : Backend.DEFAULT,
          loadResource: (uri) async {
            if (uri == 'missing') throw StateError('resource load failed');
            return bytes;
          },
        ),
      );
      app = FilamentApp.instance! as FFIFilamentApp;
    });
    tearDownAll(() async {
      await app.destroy();
    });

    test('caller waits for buffer release before destroying the bundle', () async {
      final reset = fixture.lookupFunction<ffi.Void Function(), void Function()>('resetTaskRelease');
      final release = fixture.lookupFunction<ffi.Void Function(), void Function()>('allowTaskToFinish');
      final blocked = fixture.lookup<ffi.NativeFunction<ffi.Void Function()>>('waitForTaskRelease');
      final bundle = await FFIKtx1Bundle.create(app, bytes);
      reset();
      ffi.RenderThread_addTask(blocked);
      late Future<Texture> textureCreated;
      var released = false;
      final uploadReleased =
          withVoidCallback((id, callback) {
            textureCreated = bundle.createTexture(
              onTextureUploadComplete: callback,
              textureUploadCompleteRequestId: id,
            );
          }).then((_) {
            released = true;
          });
      try {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(released, isFalse);
        expect(bundle.isCubemap(), isTrue); // Caller still owns the data.
      } finally {
        release();
      }
      final texture = await textureCreated.timeout(const Duration(seconds: 5));
      await app.flush();
      await uploadReleased.timeout(const Duration(seconds: 5));
      await bundle.destroy();
      await bundle.destroy();
      expect(bundle.isCubemap, throwsStateError);
      expect(await texture.getWidth(), greaterThan(0)); // Texture is independent.
      await texture.destroy();
    });

    test('skybox failure after texture creation reaches the public Future', () async {
      final viewer = ThermionViewerFFI(app: FailingSkyboxApp(app));
      await viewer.initialized;
      try {
        await expectLater(
          viewer.loadSkybox('valid').timeout(const Duration(seconds: 5)),
          throwsA(isA<StateError>().having((e) => e.message, 'message', 'skybox setup failed after texture creation')),
        );
        await app.flush();
        expect(await viewer.getSkybox(), isNull);
      } finally {
        await viewer.dispose();
      }
    });

    for (final asset in ['default_env_ibl.ktx', 'background.ktx']) {
      test('$asset releases upload data before caller cleanup', () async {
        final data = await File('../examples/assets/$asset').readAsBytes();
        final bundle = await FFIKtx1Bundle.create(app, data);
        late Future<Texture> textureCreated;
        final uploadReleased = withVoidCallback((id, callback) {
          textureCreated = bundle.createTexture(onTextureUploadComplete: callback, textureUploadCompleteRequestId: id);
        });
        final texture = await textureCreated.timeout(const Duration(seconds: 5));
        try {
          await app.flush();
          await uploadReleased.timeout(const Duration(seconds: 5));
          await bundle.destroy();
          expect(await texture.getWidth(), greaterThan(0));
        } finally {
          await texture.destroy();
        }
      });
    }

    test('IBL resource failure reaches the public Future and permits another operation', () async {
      final viewer = ThermionViewerFFI(app: app);
      await viewer.initialized;
      try {
        await expectLater(
          viewer.loadIbl('missing').timeout(const Duration(seconds: 5)),
          throwsA(isA<StateError>().having((e) => e.message, 'message', 'resource load failed')),
        );
        await viewer.setBackgroundColor(0, 0, 0, 1).timeout(const Duration(seconds: 5));
      } finally {
        await viewer.dispose();
      }
    });
  }, skip: fixturePath == null ? 'Set THERMION_UPLOAD_LIFETIME_FIXTURE; see native/test/rendering/README.md' : false);
}
