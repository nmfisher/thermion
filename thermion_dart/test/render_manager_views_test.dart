@Timeout(const Duration(seconds: 120))
import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

class _StubView implements View<Pointer<TView>> {
  _StubView(int address) : _handle = Pointer<TView>.fromAddress(address);

  final Pointer<TView> _handle;

  @override
  Pointer<TView> getNativeHandle() => _handle;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Uint8List> _readRenderTargetRgba8(
  FFIFilamentApp app,
  SwapChain swapChain,
  RenderTarget renderTarget,
  int width,
  int height,
) async {
  // Ensure the preceding RenderManager.render() frame has completed before
  // opening a readback frame on the same headless swapchain.
  await withVoidCallback((id, cb) => Engine_flushAndWaitJobThread(app.jobThreadHandle, app.engine, id, cb));

  var began = false;
  for (int attempt = 0; attempt < 5; attempt++) {
    began = await withBoolCallback(
      (cb) => Renderer_beginFrameJobThread(
        app.jobThreadHandle,
        app.renderer,
        swapChain.getNativeHandle(),
        (attempt + 1).toBigInt,
        cb,
      ),
    );
    if (began) break;
  }
  expect(began, isTrue, reason: 'Renderer.beginFrame failed before readPixels');

  final numBytes = width * height * 4;
  final pixels = allocate<Uint8>(numBytes);
  try {
    await withVoidCallback(
      (requestId, cb) => Renderer_readPixelsJobThread(
        app.jobThreadHandle,
        app.renderer,
        width,
        height,
        0,
        0,
        renderTarget.getNativeHandle(),
        PixelDataFormat.RGBA.value,
        PixelDataType.UBYTE.value,
        pixels.cast(),
        numBytes,
        requestId,
        cb,
      ),
    );
    await withVoidCallback(
      (requestId, cb) => Renderer_endFrameJobThread(app.jobThreadHandle, app.renderer, requestId, cb),
    );
    await withVoidCallback((id, cb) => Engine_flushAndWaitJobThread(app.jobThreadHandle, app.engine, id, cb));
    return Uint8List.fromList(pixels.cast<Uint8>().asTypedList(numBytes));
  } finally {
    free(pixels);
  }
}

(int r, int g, int b, int a) _sampleCenter(Uint8List rgba, int width, int height) {
  final x = width ~/ 2;
  final y = height ~/ 2;
  final offset = (y * width + x) * 4;
  return (rgba[offset], rgba[offset + 1], rgba[offset + 2], rgba[offset + 3]);
}

void main() {
  final testHelper = TestHelper('render_manager_views');

  setUpAll(() async {
    await testHelper.setup();
  });

  tearDownAll(() async {
    await FilamentApp.instance?.destroy();
  });

  test('renders 10 views attached to a single swapchain via RenderManager.render()', () async {
    const viewCount = 10;
    const tileSize = 50;

    final app = FilamentApp.instance! as FFIFilamentApp;
    final swapChain = await app.createHeadlessSwapChain(tileSize, tileSize);

    final camera = await app.createCamera();
    await camera.setLensProjection(near: 0.1, far: 100.0, aspect: 1.0, focalLength: 28.0);
    await camera.lookAt(Vector3(0, 0, 2.0));

    final views = <View>[];
    final scenes = <FFIScene>[];
    final assets = <FFIAsset>[];
    final materials = <MaterialInstance>[];
    final colorTextures = <Texture>[];
    final depthTextures = <Texture>[];
    final renderTargets = <RenderTarget>[];

    try {
      await app.setClearOptions(0, 0, 0, 0, clear: false, clearStencil: 0, discard: false);

      for (int i = 0; i < viewCount; i++) {
        final colorTexture = await app.createTexture(
          tileSize,
          tileSize,
          textureFormat: TextureFormat.RGBA8,
          flags: {
            TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
            TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
            TextureUsage.TEXTURE_USAGE_BLIT_SRC,
            TextureUsage.TEXTURE_USAGE_UPLOADABLE,
          },
        );
        await colorTexture.setImage(
          0,
          Uint8List(tileSize * tileSize * 4),
          tileSize,
          tileSize,
          PixelDataFormat.RGBA,
          PixelDataType.UBYTE,
        );
        final renderTarget = await app.createRenderTarget(tileSize, tileSize, color: colorTexture);
        final depthTexture = await renderTarget.getDepthTexture();

        final view = await app.createView();
        final scene = await app.createScene() as FFIScene;
        final material = await app.createUnlitMaterialInstance();
        final r = (i + 1) / viewCount;
        final g = (viewCount - i) / viewCount;
        final b = i.isEven ? 0.8 : 0.2;
        await material.setParameterFloat4('baseColorFactor', r, g, b, 1.0);

        final cube =
            await app.createGeometry(
                  GeometryUtils.cube(flipUvs: true),
                  materialInstances: [material],
                  addToScene: false,
                )
                as FFIAsset;
        await scene.add(cube);
        await view.setScene(scene);
        await view.setCamera(camera);
        await view.setRenderTarget(renderTarget);
        await view.setPostProcessing(false);
        await view.setFrustumCullingEnabled(false);
        await view.setViewport(tileSize, tileSize);

        await app.renderManager.attach(view, swapChain, renderOrder: i);

        views.add(view);
        scenes.add(scene);
        assets.add(cube);
        materials.add(material);
        colorTextures.add(colorTexture);
        depthTextures.add(depthTexture);
        renderTargets.add(renderTarget);
      }

      // Views 0..9 should all render in one RenderManager.render() pass
      // (previously views 8 and 9 were silently dropped by numViewAttachments = 8).
      await app.renderManager.render();

      final viewColors = <(int r, int g, int b, int a)>[];
      for (int i = 0; i < viewCount; i++) {
        expect(views[i].getVisibleRenderableCount(), 1, reason: 'View $i was not rendered by RenderManager');
        final rgba = await _readRenderTargetRgba8(app, swapChain, renderTargets[i], tileSize, tileSize);
        final pixel = _sampleCenter(rgba, tileSize, tileSize);
        viewColors.add(pixel);
        expect(pixel.$4, 255, reason: 'View $i alpha was not written');
        expect(pixel.$1 > 0 || pixel.$2 > 0 || pixel.$3 > 0, isTrue, reason: 'View $i stayed black: $pixel');
      }

      expect(viewColors.toSet(), hasLength(viewCount));
      expect(viewColors.last.$1, greaterThan(viewColors.first.$1));
      expect(viewColors.first.$2, greaterThan(viewColors.last.$2));

      // Verify setAttachments atomically updates the swapchain to only views 8 & 9.
      for (int i = 0; i < viewCount; i++) {
        await colorTextures[i].setImage(
          0,
          Uint8List(tileSize * tileSize * 4),
          tileSize,
          tileSize,
          PixelDataFormat.RGBA,
          PixelDataType.UBYTE,
        );
      }
      await app.renderManager.setAttachments(swapChain, [(view: views[8], order: 0), (view: views[9], order: 1)]);
      await app.renderManager.render();

      for (int i = 0; i < 8; i++) {
        final rgba = await _readRenderTargetRgba8(app, swapChain, renderTargets[i], tileSize, tileSize);
        expect(_sampleCenter(rgba, tileSize, tileSize), (0, 0, 0, 0), reason: 'Detached view $i should not render');
      }
      for (int i = 8; i < viewCount; i++) {
        final rgba = await _readRenderTargetRgba8(app, swapChain, renderTargets[i], tileSize, tileSize);
        expect(_sampleCenter(rgba, tileSize, tileSize), viewColors[i], reason: 'Retained view $i should render');
      }

      // Verify updateAttachments attaches/detaches without disturbing sibling views.
      await app.renderManager.updateAttachments(swapChain, attach: [(view: views[0], order: 0)], detach: [views[8]]);
      expect(app.renderManager.getAttachedViews(swapChain).toList(), [views[0], views[9]]);

      // Verify >255 renderable views throws RangeError and rolls back attachment state.
      final tooMany = List.generate(256, (i) => (view: _StubView(i + 1), order: i));
      await expectLater(app.renderManager.setAttachments(swapChain, tooMany), throwsRangeError);
      expect(app.renderManager.getAttachedViews(swapChain).toList(), [views[0], views[9]]);
    } finally {
      await app.renderManager.detachAll(swapChain);
      for (int i = 0; i < views.length; i++) {
        await scenes[i].remove(assets[i]);
        await app.destroyAsset(assets[i]);
        await materials[i].destroy();
        await app.destroyView(views[i]);
        await app.destroyScene(scenes[i]);
        await renderTargets[i].destroy();
        await depthTextures[i].destroy();
        await colorTextures[i].destroy();
      }
      await camera.destroy();
      await app.destroySwapChain(swapChain);
    }
  });
}
