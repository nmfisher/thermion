import 'dart:io';

import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_camera.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';

class TextureProjection {
  final Material projectionMaterial;
  final FFIMaterialInstance projectionMaterialInstance;
  final Material depthWriteMaterial;
  final FFIMaterialInstance depthWriteMaterialInstance;
  final FFIView sourceView;
  final FFIView depthView;
  final FFIView projectionView;
  final Texture depthWriteColorTexture;
  final FFITextureSampler sampler;

  TextureProjection._(
      {required this.projectionMaterial,
      required this.projectionMaterialInstance,
      required this.depthWriteMaterial,
      required this.depthWriteMaterialInstance,
      required this.sourceView,
      required this.depthView,
      required this.projectionView,
      required this.depthWriteColorTexture,
      required this.sampler}) {}

  static Future<TextureProjection> create(View sourceView) async {
    final viewport = await sourceView.getViewport();
    var depthWriteMat = await FilamentApp.instance!.createMaterial(
      File(
        "/Users/nickfisher/Documents/thermion/materials/linear_depth.filamat",
      ).readAsBytesSync(),
    );
    var depthWriteMi = await depthWriteMat.createInstance();

    final depthView = await FilamentApp.instance!.createView() as FFIView;
    await depthView.setRenderable(true);
    await depthView.setFrustumCullingEnabled(false);
    await depthView.setPostProcessing(false);
    await depthView.setViewport(viewport.width, viewport.height);

    final depthWriteColorTexture = await FilamentApp.instance!
        .createTexture(viewport.width, viewport.height,
            flags: {
              TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
              TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
              TextureUsage.TEXTURE_USAGE_BLIT_SRC
            },
            textureFormat: TextureFormat.R32F) as FFITexture;
    final depthWriteRenderTarget =
        await FilamentApp.instance!.createRenderTarget(
      viewport.width,
      viewport.height,
      color: depthWriteColorTexture,
    ) as FFIRenderTarget;
    await depthView.setRenderTarget(depthWriteRenderTarget);

    final captureMat = await FilamentApp.instance!.createMaterial(
      File(
        "/Users/nickfisher/Documents/thermion/materials/capture_uv.filamat",
      ).readAsBytesSync(),
    ) as FFIMaterial;
    var captureMi = await captureMat.createInstance() as FFIMaterialInstance;
    await captureMi.setParameterBool("flipUVs", true);

    final sampler =
        await FilamentApp.instance!.createTextureSampler() as FFITextureSampler;

    await captureMi.setParameterTexture(
        "depth", depthWriteColorTexture, sampler);
    await captureMi.setParameterBool("useDepth", true);

    final projectionView = await FilamentApp.instance!.createView() as FFIView;

    final projectionRenderTarget = await FilamentApp.instance!
        .createRenderTarget(viewport.width, viewport.height) as FFIRenderTarget;
    await projectionView.setFrustumCullingEnabled(false);
    await projectionView.setPostProcessing(false);
    await projectionView.setViewport(viewport.width, viewport.height);
    await projectionView.setRenderTarget(projectionRenderTarget);

    return TextureProjection._(
        sourceView: sourceView as FFIView,
        depthView: depthView,
        projectionView: projectionView,
        projectionMaterial: captureMat,
        projectionMaterialInstance: captureMi,
        depthWriteMaterial: depthWriteMat,
        depthWriteMaterialInstance: depthWriteMi as FFIMaterialInstance,
        depthWriteColorTexture: depthWriteColorTexture,
        sampler: sampler);
  }

  Future destroy() async {
    await projectionMaterialInstance.destroy();
    await projectionMaterial.destroy();
    await FilamentApp.instance!.destroyView(depthView);
    await FilamentApp.instance!.destroyView(projectionView);
  }

  /// Projects/unwraps [texture] onto [target] based on the current view/camera
  /// and the UV coordinates for [target].
  ///
  /// 1) Create a new scene only containing the target asset
  /// 2) Assign a material to the target asset that writes the depth of each
  ///    fragment to an output texture
  /// 3) Render this "depth view" to a render target
  /// 4) Assign a material to the target asset that:
  ///   a) transforms each vertex position to its UV coordinates
  ///   b) colors each fragment blue
  /// 5) Use the render target color buffer as the input to a
  /// 6) Render this "projection view" and capture the output
  Future<TextureProjectionResult> project(Texture texture, ThermionAsset target,
      {bool renderSourceView = true}) async {
    await FilamentApp.instance!.setClearOptions(0, 0, 0, 1,
        clearStencil: 0, discard: false, clear: true);

    final viewport = await sourceView.getViewport();

    final originalMi = await target.getMaterialInstanceAt();

    final camera = (await sourceView.getCamera()) as FFICamera;
    final originalScene = await sourceView.getScene() as FFIScene;

    final projectionScene =
        (await FilamentApp.instance!.createScene()) as FFIScene;
    await projectionScene.add(target as FFIAsset);

    await sourceView.setScene(projectionScene);

    await depthView.setCamera(camera);
    await depthView.setScene(projectionScene);
    await depthView.setViewport(viewport.width, viewport.height);

    await projectionView.setCamera(camera);
    await projectionView.setScene(projectionScene);

    var _pixelBuffers = <View, Uint8List>{};

    if (renderSourceView) {
      _pixelBuffers[sourceView] =
          (await FilamentApp.instance!.capture(null, view: sourceView))
              .first
              .$2;
    }

    await target.setMaterialInstanceAt(depthWriteMaterialInstance);
    _pixelBuffers[depthView] =
        (await FilamentApp.instance!.capture(null, view: depthView)).first.$2;

    await projectionMaterialInstance.setParameterTexture(
        "color", texture as FFITexture, sampler);
    await target.setMaterialInstanceAt(projectionMaterialInstance);

    _pixelBuffers[projectionView] =
        (await FilamentApp.instance!.capture(null, view: projectionView)).first.$2;


    await target.setMaterialInstanceAt(originalMi as FFIMaterialInstance);

    await sourceView.setScene(originalScene);
    return TextureProjectionResult(_pixelBuffers[sourceView],
        _pixelBuffers[depthView]!, _pixelBuffers[projectionView]!);
  }
}

class TextureProjectionResult {
  final Uint8List? sourceView;
  final Uint8List depth;
  final Uint8List projected;

  TextureProjectionResult(this.sourceView, this.depth, this.projected);
}
