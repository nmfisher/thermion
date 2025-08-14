import 'package:thermion_dart/src/filament/src/interface/ktx1_bundle.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:animation_tools_dart/src/bone_animation_data.dart';
import 'package:animation_tools_dart/src/morph_animation_data.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFITexturedQuad extends TexturedQuad {
  final ThermionAsset asset;

  ThermionEntity get entity => asset.entity;

  Texture? texture;

  FFITextureSampler? sampler;

  final MaterialInstance mi;

  int? width;
  int? height;

  FFITexturedQuad(
      {required this.asset, this.texture, this.sampler, required this.mi});

  T getHandle<T>() {
    return asset.getHandle() as T;
  }

  ///
  ///
  ///
  Future destroy() async {
    await texture?.dispose();
    await sampler?.dispose();
    await mi.destroy();
  }

  ///
  ///
  ///
  Future setBackgroundColor(double r, double g, double b, double a) async {
    await mi.setParameterFloat4("backgroundColor", r, g, b, a);
  }

  ///
  ///
  ///
  Future hideImage() async {
    await mi.setParameterInt("showImage", 0);
  }

  ///
  ///
  ///
  Future setCubemapFace(int index) async {
    if (index < 0 || index > 5) {
      throw Exception("Incorrect cubemap face index");
    }
    await mi.setParameterInt("cubeMapFace", index);
  }

  ///
  ///
  ///
  Future setImageFromKtxBundle(Ktx1Bundle bundle) async {
    final texture = await bundle.createTexture();

    if (bundle.isCubemap()) {
      sampler ??= await FilamentApp.instance!.createTextureSampler()
          as FFITextureSampler;
      this.texture = texture;
      await mi.setParameterTexture(
          "cubeMap", texture as FFITexture, sampler as FFITextureSampler);
      await setBackgroundColor(1, 1, 1, 0);
      await mi.setParameterInt("showImage", 1);
      await mi.setParameterInt("isCubeMap", 1);
      await setCubemapFace(0);
      width = await texture.getWidth();
      height = await texture.getHeight();
    } else {
      await setImageFromTexture(texture);
    }
  }

  ///
  ///
  ///
  Future setImage(Uint8List imageData) async {
    final image = await FilamentApp.instance!.decodeImage(imageData);
    final channels = await image.getChannels();
    final textureFormat = channels == 4
        ? TextureFormat.RGBA32F
        : channels == 3
            ? TextureFormat.RGB32F
            : throw UnimplementedError("Currently only 3 or 4 channels are supported");
    final pixelFormat = channels == 4
        ? PixelDataFormat.RGBA
        : channels == 3
            ? PixelDataFormat.RGB
            : throw UnimplementedError();

    final texture = await FilamentApp.instance!.createTexture(
        await image.getWidth(), await image.getHeight(),
        textureFormat: textureFormat);
    await texture.setLinearImage(image, pixelFormat, PixelDataType.FLOAT);
    await setImageFromTexture(texture);
  }

  ///
  ///
  ///
  Future setImageFromTexture(Texture texture) async {
    this.texture = texture;
    sampler ??=
        await FilamentApp.instance!.createTextureSampler() as FFITextureSampler;
    await mi.setParameterInt("isCubeMap", 0);
    await mi.setParameterTexture(
        "image", texture as FFITexture, sampler as FFITextureSampler);
    await setBackgroundColor(1, 1, 1, 0);
    await mi.setParameterInt("showImage", 1);
    width = await texture.getWidth();
    height = await texture.getHeight();
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
  Future removeAnimationComponent() {
    throw UnimplementedError();
  }

  @override
  Future resetBones() {
    throw UnimplementedError();
  }

  @override
  Future setBoneTransform(
      ThermionEntity entity, int boneIndex, Matrix4 transform,
      {int skinIndex = 0}) {
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

  Future<v64.Aabb3> getBoundingBox() {
    throw UnimplementedError();
  }

  @override
  Future setDepth(double depth) async {
    await mi.setDepthWriteEnabled(true);
    await mi.setParameterFloat("depth", depth);
  }
}
