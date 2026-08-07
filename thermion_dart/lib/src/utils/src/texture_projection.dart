import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_camera.dart';
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

  TextureProjection._({
    required this.projectionMaterial,
    required this.projectionMaterialInstance,
    required this.depthWriteMaterial,
    required this.depthWriteMaterialInstance,
    required this.sourceView,
    required this.depthView,
    required this.projectionView,
    required this.depthWriteColorTexture,
    required this.sampler,
  }) {}

  static Future<TextureProjection> create(
    View sourceView,
    Uint8List depthWriteMaterial,
    Uint8List captureUvMaterial,
  ) async {
    throw Exception("TODO");
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
  Future<TextureProjectionResult> project(Texture texture, List<ThermionEntity> targets) async {
    final viewport = await sourceView.getViewport();

    final camera = (await sourceView.getCamera()) as FFICamera;
    final originalScene = await sourceView.getScene() as FFIScene;

    // since we will be creating a single (unlit) scene, we need
    // to replace the target asset's material with an unlit material
    // (otherwise nothing will be visible in the initial output colour buffer).
    final unlit = await FilamentApp.instance!.createUnlitMaterialInstance() as FFIMaterialInstance;
    await unlit.setParameterFloat4("baseColorFactor", 1.0, 1.0, 1.0, 1.0);

    final projectionScene = (await FilamentApp.instance!.createScene()) as FFIScene;

    final restoreMaterials = <ThermionEntity, List<MaterialInstance>>{};
    for (final target in targets) {
      await projectionScene.addEntity(target);
      restoreMaterials[target] = [];
      for (int i = 0; i < await FilamentApp.instance!.getPrimitiveCount(target); i++) {
        final mi = await FilamentApp.instance!.getMaterialInstanceAt(target, i);
        restoreMaterials[target]!.add(mi);
        await FilamentApp.instance!.setMaterialInstanceAt(target, i, unlit);
      }
    }

    await depthView.setCamera(camera);
    await depthView.setScene(projectionScene);
    await depthView.setViewport(viewport.width, viewport.height);

    await projectionView.setCamera(camera);
    await projectionView.setScene(projectionScene);
    await projectionView.setViewport(viewport.width, viewport.height);

    var sourceViewCapture = (await FilamentApp.instance!.capture(
      null,
      view: sourceView,
      captureRenderTarget: true,
    )).first.$2;

    for (final target in targets) {
      for (int i = 0; i < await FilamentApp.instance!.getPrimitiveCount(target); i++) {
        await FilamentApp.instance!.setMaterialInstanceAt(target, i, depthWriteMaterialInstance);
      }
    }

    var depthViewCapture = (await FilamentApp.instance!.capture(null, view: depthView)).first.$2;

    await projectionMaterialInstance.setParameterTexture("color", texture as FFITexture, sampler);

    for (final target in targets) {
      for (int i = 0; i < await FilamentApp.instance!.getPrimitiveCount(target); i++) {
        await FilamentApp.instance!.setMaterialInstanceAt(target, i, projectionMaterialInstance);
      }
    }

    final projectionViewCaptures = <Uint8List>[];

    var projectionViewCapture = (await FilamentApp.instance!.capture(null, view: projectionView)).first.$2;
    projectionViewCaptures.add(projectionViewCapture);

    for (final target in targets) {
      await projectionScene.removeEntity(target);
      for (int i = 0; i < await FilamentApp.instance!.getPrimitiveCount(target); i++) {
        await FilamentApp.instance!.setMaterialInstanceAt(target, i, restoreMaterials[target]![i]);
      }
    }

    await sourceView.setScene(originalScene);

    await FilamentApp.instance!.destroyScene(projectionScene);

    return TextureProjectionResult(sourceViewCapture, depthViewCapture, projectionViewCaptures);
  }
}

class TextureProjectionResult {
  final Uint8List? sourceView;
  final Uint8List depth;
  final List<Uint8List> projected;

  TextureProjectionResult(this.sourceView, this.depth, this.projected);
}
