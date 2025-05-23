import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:animation_tools_dart/src/bone_animation_data.dart';
import 'package:animation_tools_dart/src/morph_animation_data.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';

class BackgroundImage extends ThermionAsset {
  final ThermionAsset asset;

  ThermionEntity get entity => asset.entity;

  Texture? texture;

  FFITextureSampler? sampler;

  final MaterialInstance mi;

  final FFIScene scene;

  BackgroundImage._(
      this.asset, this.scene, this.texture, this.sampler, this.mi);

  ///
  ///
  ///
  Future destroy() async {
    Scene_removeEntity(scene.scene, entity);

    await texture?.dispose();
    await sampler?.dispose();
    await mi.destroy();
  }

  ///
  ///
  ///
  static Future<BackgroundImage> create(
      ThermionViewer viewer, FFIScene scene) async {
    var imageMaterialInstance =
        await FilamentApp.instance!.createImageMaterialInstance();

    var backgroundImage =
        await viewer.createGeometry(GeometryHelper.fullscreenQuad());
    await imageMaterialInstance.setParameterInt("showImage", 0);
    var transform = Matrix4.identity();
    
    await imageMaterialInstance.setParameterMat4(
        "transform", transform);

    await backgroundImage.setMaterialInstanceAt(imageMaterialInstance);
    await scene.add(backgroundImage as FFIAsset);
    return BackgroundImage._(
        backgroundImage, scene, null, null, imageMaterialInstance);
  }

  ///
  ///
  ///
  Future setBackgroundColor(double r, double g, double b, double a) async {
    await mi.setParameterFloat4("backgroundColor", r, g, b, a);
  }

  Future hideImage() async {
    await mi.setParameterInt("showImage", 0);
  }

  ///
  ///
  ///
  Future setImage(Uint8List imageData) async {
    final image = await FilamentApp.instance!.decodeImage(imageData);

    texture ??= await FilamentApp.instance!.createTexture(
        await image.getWidth(), await image.getHeight(),
        textureFormat: TextureFormat.RGBA32F);
    await texture!
        .setLinearImage(image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
    sampler ??=
        await FilamentApp.instance!.createTextureSampler() as FFITextureSampler;

    await mi.setParameterTexture(
        "image", texture as FFITexture, sampler as FFITextureSampler);
    await setBackgroundColor(1, 1, 1, 0);
    await mi.setParameterInt("showImage", 1);
  }

  ///
  ///
  ///
  @override
  Future<ThermionAsset> createInstance(
      {covariant List<MaterialInstance>? materialInstances = null}) {
    throw UnimplementedError();
  }

  ///
  ///
  ///
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
  Future setCastShadows(bool castShadows) {
    // TODO: implement setCastShadows
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
  Future addAnimationComponent() {
    // TODO: implement addAnimationComponent
    throw UnimplementedError();
  }

  @override
  Future addBoneAnimation(BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeInInSecs = 0.0,
      double fadeOutInSecs = 0.0,
      double maxDelta = 1.0}) {
    // TODO: implement addBoneAnimation
    throw UnimplementedError();
  }

  @override
  Future clearMorphAnimationData(ThermionEntity entity) {
    // TODO: implement clearMorphAnimationData
    throw UnimplementedError();
  }

  @override
  Future<double> getAnimationDuration(int animationIndex) {
    // TODO: implement getAnimationDuration
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getAnimationNames() {
    // TODO: implement getAnimationNames
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity> getBone(int boneIndex, {int skinIndex = 0}) {
    // TODO: implement getBone
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getBoneNames({int skinIndex = 0}) {
    // TODO: implement getBoneNames
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity?> getChildEntity(String childName) {
    // TODO: implement getChildEntity
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getInverseBindMatrix(int boneIndex, {int skinIndex = 0}) {
    // TODO: implement getInverseBindMatrix
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getLocalTransform({ThermionEntity? entity}) {
    // TODO: implement getLocalTransform
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getMorphTargetNames({ThermionEntity? entity}) {
    // TODO: implement getMorphTargetNames
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getWorldTransform({ThermionEntity? entity}) {
    // TODO: implement getWorldTransform
    throw UnimplementedError();
  }

  @override
  Future playAnimation(int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0}) {
    // TODO: implement playAnimation
    throw UnimplementedError();
  }

  @override
  Future playAnimationByName(String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) {
    // TODO: implement playAnimationByName
    throw UnimplementedError();
  }

  @override
  Future removeAnimationComponent() {
    // TODO: implement removeAnimationComponent
    throw UnimplementedError();
  }

  @override
  Future resetBones() {
    // TODO: implement resetBones
    throw UnimplementedError();
  }

  @override
  Future setBoneTransform(
      ThermionEntity entity, int boneIndex, Matrix4 transform,
      {int skinIndex = 0}) {
    // TODO: implement setBoneTransform
    throw UnimplementedError();
  }

  @override
  Future setGltfAnimationFrame(int index, int animationFrame) {
    // TODO: implement setGltfAnimationFrame
    throw UnimplementedError();
  }

  @override
  Future setMorphAnimationData(MorphAnimationData animation,
      {List<String>? targetMeshNames}) {
    // TODO: implement setMorphAnimationData
    throw UnimplementedError();
  }

  @override
  Future setMorphTargetWeights(ThermionEntity entity, List<double> weights) {
    // TODO: implement setMorphTargetWeights
    throw UnimplementedError();
  }

  @override
  Future setTransform(Matrix4 transform, {ThermionEntity? entity}) {
    // TODO: implement setTransform
    throw UnimplementedError();
  }

  @override
  Future stopAnimation(int animationIndex) {
    // TODO: implement stopAnimation
    throw UnimplementedError();
  }

  @override
  Future stopAnimationByName(String name) {
    // TODO: implement stopAnimationByName
    throw UnimplementedError();
  }

  @override
  Future updateBoneMatrices(ThermionEntity entity) {
    // TODO: implement updateBoneMatrices
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getChildEntityNames() async {
    return [];
  }

  @override
  Future<bool> isCastShadowsEnabled({ThermionEntity? entity}) async {
    return false;
  }

  @override
  Future<bool> isReceiveShadowsEnabled({ThermionEntity? entity}) async {
    return false;
  }

  @override
  Future transformToUnitCube() {
    // TODO: implement transformToUnitCube
    throw UnimplementedError();
  }

  @override
  Future<MaterialInstance> getMaterialInstanceAt(
      {ThermionEntity? entity, int index = 0}) {
    throw UnimplementedError();
  }

  ThermionAsset? get boundingBoxAsset => throw UnimplementedError();

  @override
  Future<ThermionAsset> createBoundingBoxAsset() {
    throw UnimplementedError();
  }

  Future<v64.Aabb3> getBoundingBox() {
    throw UnimplementedError();
  }
  
  
}
