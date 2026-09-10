import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/bindings/src/ffi.dart' as ffi;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

// Build native/test/rendering's upload_lifetime_fixture and set its path in
// THERMION_UPLOAD_LIFETIME_FIXTURE. No production-only test hooks are needed.
void main() {
  final fixturePath = Platform.environment['THERMION_UPLOAD_LIFETIME_FIXTURE'];
  group(
    'gltf input snapshot',
    () {
      late FFIFilamentApp app;
      late void Function() reset;
      late void Function() release;
      late Pointer<ffi.NativeFunction<ffi.Void Function()>> wait;

      setUpAll(() async {
        final fixture = DynamicLibrary.open(fixturePath!);
        reset = fixture.lookupFunction<ffi.Void Function(), void Function()>('resetTaskRelease');
        release = fixture.lookupFunction<ffi.Void Function(), void Function()>('allowTaskToFinish');
        wait = fixture.lookup('waitForTaskRelease');
        await FFIFilamentApp.create(
          config: FFIFilamentConfig(
            backend: Platform.isMacOS ? Backend.METAL : Backend.DEFAULT,
            loadResource: (uri) => File(uri).readAsBytes(),
          ),
        );
        app = FilamentApp.instance! as FFIFilamentApp;
      });
      tearDownAll(() => app.destroy());

      test('glTF source survives source overwrite before parsing', () async {
        final bytes = Uint8List.fromList(
          utf8.encode(
            '{"asset":{"version":"2.0"},"nodes":[{"name":"snapshot"}],'
            '"scenes":[{"nodes":[0]}],"scene":0}',
          ),
        );
        reset();
        ffi.RenderThread_addTask(wait);
        late Future<Pointer<TFilamentAsset>> pending;
        try {
          pending = withPointerCallback<TFilamentAsset>((cb) {
            GltfAssetLoader_loadRenderThread(app.engine, app.gltfAssetLoader, bytes.address, bytes.length, 1, cb);
          });
          bytes.fillRange(0, bytes.length, 0xa5);
        } finally {
          release();
        }
        final asset = await pending.timeout(const Duration(seconds: 5));
        expect(asset, isNot(nullptr));
        expect(FilamentAsset_getEntityCount(asset), 1);
        // Resource loading initializes Filament's animator before SceneAsset wraps it.
        final resourceLoader = await withPointerCallback<TGltfResourceLoader>(
          (cb) => GltfResourceLoader_createRenderThread(app.engine, cb),
        );
        expect(
          await withBoolCallback((cb) => GltfResourceLoader_loadResourcesRenderThread(resourceLoader, asset, cb)),
          isTrue,
        );
        await withVoidCallback((id, cb) => GltfResourceLoader_destroyRenderThread(app.engine, resourceLoader, id, cb));
        // A SceneAsset owns and destroys the underlying Filament asset.
        final sceneAsset = await withPointerCallback<TSceneAsset>((cb) {
          SceneAsset_createFromFilamentAssetRenderThread(
            app.engine,
            app.gltfAssetLoader,
            app.nameComponentManager,
            asset,
            0,
            cb,
          );
        });
        await withVoidCallback(
          (id, cb) => SceneAsset_destroyRenderThread(sceneAsset, id, cb),
        ).timeout(const Duration(seconds: 5));
      });
    },
    skip: fixturePath == null ? 'Set THERMION_UPLOAD_LIFETIME_FIXTURE to the native fixture library' : false,
  );
}
