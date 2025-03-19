import 'dart:typed_data';

import 'package:animation_tools_dart/src/bone_animation_data.dart';
import 'package:animation_tools_dart/src/morph_animation_data.dart';
import 'package:thermion_dart/src/filament/src/layers.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_asset.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_material.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_scene.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';

class BackgroundImage extends ThermionAsset {
  final ThermionAsset asset;
  ThermionEntity get entity => asset.entity;

  Texture? _backgroundImageTexture;
  FFIMaterial? _imageMaterial;
  FFITextureSampler? _imageSampler;

  final FFIScene scene;
  final FilamentApp app;

  BackgroundImage._(this.asset, this.scene, this.app,
      this._backgroundImageTexture, this._imageMaterial, this._imageSampler);

  Future destroy() async {
    Scene_removeEntity(scene.scene, entity);
    await _backgroundImageTexture!.dispose();
    await _imageSampler!.dispose();
  }

  static Future<BackgroundImage> create(
      FFIFilamentApp app, FFIScene scene, Uint8List imageData) async {
    final image = await app.decodeImage(imageData);
    var backgroundImageTexture = await app.createTexture(
        await image.getWidth(), await image.getHeight());
    var imageMaterial = FFIMaterial(Material_createImageMaterial(), app);
    var imageSampler = await app.createTextureSampler() as FFITextureSampler;

    var imageMaterialInstance =
        await imageMaterial!.createInstance() as FFIMaterialInstance;
    await imageMaterialInstance.setParameterTexture(
        "image",
        backgroundImageTexture as FFITexture,
        imageSampler as FFITextureSampler);
    var backgroundImage =
        await app.createGeometry(GeometryHelper.fullscreenQuad()) as FFIAsset;
    backgroundImage.setMaterialInstanceAt(imageMaterialInstance);
    await scene.add(backgroundImage);
    return BackgroundImage._(backgroundImage, scene, app,
        backgroundImageTexture, imageMaterial, imageSampler);
  }

  @override
  Future<ThermionAsset> createInstance(
      {covariant List<MaterialInstance>? materialInstances = null}) {
    throw UnimplementedError();
  }

  @override
  Future<List<ThermionEntity>> getChildEntities() async {
    return [];
  }

  @override
  Future<ThermionAsset> getInstance(int index) {
    throw UnimplementedError();
  }

  @override
  Future<int> getInstanceCount() async {
    return 0;
  }

  @override
  Future<List<ThermionAsset>> getInstances() async {
    return [];
  }

  @override
  Future removeStencilHighlight() {
    // TODO: implement removeStencilHighlight
    throw UnimplementedError();
  }

  @override
  Future setBoundingBoxVisibility(bool visible) {
    // TODO: implement setBoundingBoxVisibility
    throw UnimplementedError();
  }

  @override
  Future setCastShadows(bool castShadows) {
    // TODO: implement setCastShadows
    throw UnimplementedError();
  }

  @override
  Future setMaterialInstanceAt(covariant MaterialInstance instance) {
    // TODO: implement setMaterialInstanceAt
    throw UnimplementedError();
  }

  @override
  Future setReceiveShadows(bool castShadows) {
    // TODO: implement setReceiveShadows
    throw UnimplementedError();
  }

  @override
  Future setStencilHighlight(
      {double r = 1.0, double g = 0.0, double b = 0.0, int? entityIndex}) {
    // TODO: implement setStencilHighlight
    throw UnimplementedError();
  }

  @override
  Future setVisibilityLayer(ThermionEntity entity, VisibilityLayers layer) {
    // TODO: implement setVisibilityLayer
    throw UnimplementedError();
  }

  @override
  Future addAnimationComponent(ThermionEntity entity) {
    // TODO: implement addAnimationComponent
    throw UnimplementedError();
  }

  @override
  Future addBoneAnimation(ThermionAsset asset, BoneAnimationData animation, {int skinIndex = 0, double fadeInInSecs = 0.0, double fadeOutInSecs = 0.0, double maxDelta = 1.0}) {
    // TODO: implement addBoneAnimation
    throw UnimplementedError();
  }

  @override
  Future clearMorphAnimationData(ThermionEntity entity) {
    // TODO: implement clearMorphAnimationData
    throw UnimplementedError();
  }

  @override
  Future<double> getAnimationDuration(covariant ThermionAsset asset, int animationIndex) {
    // TODO: implement getAnimationDuration
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getAnimationNames(covariant ThermionAsset asset) {
    // TODO: implement getAnimationNames
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity> getBone(covariant ThermionAsset asset, int boneIndex, {int skinIndex = 0}) {
    // TODO: implement getBone
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getBoneNames(covariant ThermionAsset asset, {int skinIndex = 0}) {
    // TODO: implement getBoneNames
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getInverseBindMatrix(covariant ThermionAsset asset, int boneIndex, {int skinIndex = 0}) {
    // TODO: implement getInverseBindMatrix
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getLocalTransform(ThermionEntity entity) {
    // TODO: implement getLocalTransform
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getMorphTargetNames(covariant ThermionAsset asset, ThermionEntity childEntity) {
    // TODO: implement getMorphTargetNames
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getWorldTransform(ThermionEntity entity) {
    // TODO: implement getWorldTransform
    throw UnimplementedError();
  }

  @override
  Future playAnimation(ThermionAsset asset, int index, {bool loop = false, bool reverse = false, bool replaceActive = true, double crossfade = 0.0, double startOffset = 0.0}) {
    // TODO: implement playAnimation
    throw UnimplementedError();
  }

  @override
  Future playAnimationByName(covariant ThermionAsset asset, String name, {bool loop = false, bool reverse = false, bool replaceActive = true, double crossfade = 0.0}) {
    // TODO: implement playAnimationByName
    throw UnimplementedError();
  }

  @override
  Future removeAnimationComponent(ThermionEntity entity) {
    // TODO: implement removeAnimationComponent
    throw UnimplementedError();
  }

  @override
  Future resetBones(ThermionAsset asset) {
    // TODO: implement resetBones
    throw UnimplementedError();
  }

  @override
  Future setBoneTransform(ThermionEntity entity, int boneIndex, Matrix4 transform, {int skinIndex = 0}) {
    // TODO: implement setBoneTransform
    throw UnimplementedError();
  }

  @override
  Future setGltfAnimationFrame(covariant ThermionAsset asset, int index, int animationFrame) {
    // TODO: implement setGltfAnimationFrame
    throw UnimplementedError();
  }

  @override
  Future setMorphAnimationData(covariant ThermionAsset asset, MorphAnimationData animation, {List<String>? targetMeshNames}) {
    // TODO: implement setMorphAnimationData
    throw UnimplementedError();
  }

  @override
  Future setMorphTargetWeights(ThermionEntity entity, List<double> weights) {
    // TODO: implement setMorphTargetWeights
    throw UnimplementedError();
  }

  @override
  Future setTransform(ThermionEntity entity, Matrix4 transform) {
    // TODO: implement setTransform
    throw UnimplementedError();
  }

  @override
  Future stopAnimation(covariant ThermionAsset asset, int animationIndex) {
    // TODO: implement stopAnimation
    throw UnimplementedError();
  }

  @override
  Future stopAnimationByName(covariant ThermionAsset asset, String name) {
    // TODO: implement stopAnimationByName
    throw UnimplementedError();
  }

  @override
  Future updateBoneMatrices(ThermionEntity entity) {
    // TODO: implement updateBoneMatrices
    throw UnimplementedError();
  }
}
