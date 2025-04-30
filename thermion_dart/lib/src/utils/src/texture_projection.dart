import 'dart:io';
import 'dart:typed_data';

import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/thermion_dart.dart';

class TextureProjection {
  final SwapChain swapChain;
  final Material projectionMaterial;
  final MaterialInstance projectionMaterialInstance;
  final Material depthWriteMaterial;
  final MaterialInstance depthWriteMaterialInstance;
  final Texture texture;
  final View sourceView;
  final View depthView;
  final View projectionView;

  TextureProjection._(
      {required this.swapChain,
      required this.projectionMaterial,
      required this.projectionMaterialInstance,
      required this.depthWriteMaterial,
      required this.depthWriteMaterialInstance,
      required this.texture,
      required this.sourceView,
      required this.depthView,
      required this.projectionView}) {}

  static Future<TextureProjection> create(
      View sourceView, SwapChain swapChain) async {
    final viewport = await sourceView.getViewport();
    var depthWriteMat = await FilamentApp.instance!.createMaterial(
      File(
        "/Users/nickfisher/Documents/thermion/materials/linear_depth.filamat",
      ).readAsBytesSync(),
    );
    var depthWriteMi = await depthWriteMat.createInstance();

    final depthWriteView = await FilamentApp.instance!.createView() as FFIView;
    await depthWriteView.setFrustumCullingEnabled(false);
    await depthWriteView.setPostProcessing(false);
    await depthWriteView.setViewport(viewport.width, viewport.height);
    await depthWriteView.setBlendMode(BlendMode.transparent);

    final depthWriteColorTexture = await FilamentApp.instance!
        .createTexture(viewport.width, viewport.height,
            flags: {
              TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
              TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
              TextureUsage.TEXTURE_USAGE_BLIT_SRC
            },
            textureFormat: TextureFormat.R32F);
    await depthWriteView
        .setRenderTarget(await FilamentApp.instance!.createRenderTarget(
      viewport.width,
      viewport.height,
      color: depthWriteColorTexture,
    ) as FFIRenderTarget);

    final color = await (await sourceView.getRenderTarget())!.getColorTexture();
    final depth =
        await (await depthWriteView.getRenderTarget())!.getColorTexture();

    var captureMat = await FilamentApp.instance!.createMaterial(
      File(
        "/Users/nickfisher/Documents/thermion/materials/capture_uv.filamat",
      ).readAsBytesSync(),
    );
    var captureMi = await captureMat.createInstance();
    await captureMi.setParameterBool("flipUVs", true);
    await captureMi.setParameterTexture(
        "color", color, await FilamentApp.instance!.createTextureSampler());
    await captureMi.setParameterTexture(
        "depth", depth, await FilamentApp.instance!.createTextureSampler());
    await captureMi.setParameterBool("useDepth", true);

    final projectionView = await FilamentApp.instance!.createView() as FFIView;
    await projectionView.setFrustumCullingEnabled(false);
    await projectionView.setPostProcessing(false);
    await projectionView.setViewport(viewport.width, viewport.height);

    return TextureProjection._(
        sourceView: sourceView,
        swapChain: swapChain,
        depthView: depthWriteView,
        projectionView: projectionView,
        projectionMaterial: captureMat,
        projectionMaterialInstance: captureMi,
        depthWriteMaterial: depthWriteMat,
        depthWriteMaterialInstance: depthWriteMi,
        texture: depthWriteColorTexture);
  }

  Future destroy() async {
    await projectionMaterialInstance.destroy();
    await projectionMaterial.destroy();
    await FilamentApp.instance!.destroyView(depthView);
    await FilamentApp.instance!.destroyView(projectionView);
  }

  var _pixelBuffers = <View, Uint8List>{};
  Uint8List getColorBuffer() => _pixelBuffers[sourceView]!;
  Uint8List getDepthWritePixelBuffer() => _pixelBuffers[depthView]!;
  Uint8List getProjectedPixelBuffer() => _pixelBuffers[projectionView]!;

  Future project(ThermionAsset target) async {
    final originalMi = await target.getMaterialInstanceAt();

    await FilamentApp.instance!.register(swapChain, depthView);
    await FilamentApp.instance!.register(swapChain, projectionView);

    final camera = await sourceView.getCamera();
    await depthView.setCamera(camera);
    await projectionView.setCamera(camera);
    await (depthView as FFIView)
        .setScene(await sourceView.getScene() as FFIScene);
    await (projectionView as FFIView)
        .setScene(await sourceView.getScene() as FFIScene);

    await sourceView.setRenderOrder(0);
    await depthView.setRenderOrder(1);
    await projectionView.setRenderOrder(2);

    var pixelBuffers = await FilamentApp.instance!.capture(swapChain,
        beforeRender: (view) async {
      if (view == depthView) {
        await target.setMaterialInstanceAt(depthWriteMaterialInstance);
      } else if (view == projectionView) {
        await target.setMaterialInstanceAt(projectionMaterialInstance);
      }
    },
        pixelDataFormat: PixelDataFormat.RGBA,
        pixelDataType: PixelDataType.FLOAT);

    await target.setMaterialInstanceAt(originalMi);

    _pixelBuffers.clear();

    for (final (view, pixelBuffer) in pixelBuffers) {
      _pixelBuffers[view] = pixelBuffer;
    }

    await FilamentApp.instance!.unregister(swapChain, depthView);
    await FilamentApp.instance!.unregister(swapChain, projectionView);

    await target.setMaterialInstanceAt(originalMi);
  }
}
