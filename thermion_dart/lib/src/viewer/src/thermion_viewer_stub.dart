import 'dart:typed_data';

import 'package:animation_tools_dart/src/bone_animation_data.dart';
import 'package:animation_tools_dart/src/morph_animation_data.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

class ThermionViewerStub extends ThermionViewer {
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
  Future<ThermionEntity> addDirectLight(DirectLight light) {
    // TODO: implement addDirectLight
    throw UnimplementedError();
  }

  @override
  // TODO: implement app
  FilamentApp get app => throw UnimplementedError();

  @override
  Future clearBackgroundImage() {
    // TODO: implement clearBackgroundImage
    throw UnimplementedError();
  }

  @override
  Future clearMorphAnimationData(ThermionEntity entity) {
    // TODO: implement clearMorphAnimationData
    throw UnimplementedError();
  }

  @override
  Future<Camera> createCamera() {
    // TODO: implement createCamera
    throw UnimplementedError();
  }

  @override
  Future<GizmoAsset> createGizmo(covariant View view, GizmoType type) {
    // TODO: implement createGizmo
    throw UnimplementedError();
  }

  @override
  Future destroyAsset(ThermionAsset asset) {
    // TODO: implement destroyAsset
    throw UnimplementedError();
  }

  @override
  Future destroyAssets() {
    // TODO: implement destroyAssets
    throw UnimplementedError();
  }

  @override
  Future destroyCamera(covariant Camera camera) {
    // TODO: implement destroyCamera
    throw UnimplementedError();
  }

  @override
  Future destroyLights() {
    // TODO: implement destroyLights
    throw UnimplementedError();
  }

  @override
  Future dispose() {
    // TODO: implement dispose
    throw UnimplementedError();
  }

  @override
  Future<Camera> getActiveCamera() {
    // TODO: implement getActiveCamera
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity?> getAncestor(ThermionEntity entity) {
    // TODO: implement getAncestor
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
  int getCameraCount() {
    // TODO: implement getCameraCount
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
  String? getNameForEntity(ThermionEntity entity) {
    // TODO: implement getNameForEntity
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity?> getParent(ThermionEntity entity) {
    // TODO: implement getParent
    throw UnimplementedError();
  }

  @override
  Future<Aabb3> getRenderableBoundingBox(ThermionEntity entity) {
    // TODO: implement getRenderableBoundingBox
    throw UnimplementedError();
  }

  @override
  Future<Aabb2> getViewportBoundingBox(ThermionEntity entity) {
    // TODO: implement getViewportBoundingBox
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getWorldTransform(ThermionEntity entity) {
    // TODO: implement getWorldTransform
    throw UnimplementedError();
  }

  @override
  Future<ThermionAsset> loadGlb(String path, {int numInstances = 1, bool keepData = false}) {
    // TODO: implement loadGlb
    throw UnimplementedError();
  }

  @override
  Future<ThermionAsset> loadGlbFromBuffer(Uint8List data, {int numInstances = 1, bool keepData = false, int priority = 4, int layer = 0, bool loadResourcesAsync = false}) {
    // TODO: implement loadGlbFromBuffer
    throw UnimplementedError();
  }

  @override
  Future<ThermionAsset> loadGltf(String path, String relativeResourcePath, {bool keepData = false}) {
    // TODO: implement loadGltf
    throw UnimplementedError();
  }

  @override
  Future loadIbl(String lightingPath, {double intensity = 30000}) {
    // TODO: implement loadIbl
    throw UnimplementedError();
  }

  @override
  Future loadSkybox(String skyboxPath) {
    // TODO: implement loadSkybox
    throw UnimplementedError();
  }

  @override
  // TODO: implement msPerFrame
  double get msPerFrame => throw UnimplementedError();

  @override
  void onDispose(Future Function() callback) {
    // TODO: implement onDispose
  }

  @override
  Future pick(int x, int y, void Function(PickResult p1) resultHandler) {
    // TODO: implement pick
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
  Future registerRequestFrameHook(Future Function() hook) {
    // TODO: implement registerRequestFrameHook
    throw UnimplementedError();
  }

  @override
  Future removeAnimationComponent(ThermionEntity entity) {
    // TODO: implement removeAnimationComponent
    throw UnimplementedError();
  }

  @override
  Future removeGridOverlay() {
    // TODO: implement removeGridOverlay
    throw UnimplementedError();
  }

  @override
  Future removeIbl() {
    // TODO: implement removeIbl
    throw UnimplementedError();
  }

  @override
  Future removeLight(ThermionEntity light) {
    // TODO: implement removeLight
    throw UnimplementedError();
  }

  @override
  Future removeSkybox() {
    // TODO: implement removeSkybox
    throw UnimplementedError();
  }

  @override
  Future render() {
    // TODO: implement render
    throw UnimplementedError();
  }

  @override
  // TODO: implement rendering
  bool get rendering => throw UnimplementedError();

  @override
  Future requestFrame() {
    // TODO: implement requestFrame
    throw UnimplementedError();
  }

  @override
  Future resetBones(ThermionAsset asset) {
    // TODO: implement resetBones
    throw UnimplementedError();
  }

  @override
  Future rotateIbl(Matrix3 rotation) {
    // TODO: implement rotateIbl
    throw UnimplementedError();
  }

  @override
  Future setActiveCamera(covariant Camera camera) {
    // TODO: implement setActiveCamera
    throw UnimplementedError();
  }

  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) {
    // TODO: implement setAntiAliasing
    throw UnimplementedError();
  }

  @override
  Future setBackgroundColor(double r, double g, double b, double alpha) {
    // TODO: implement setBackgroundColor
    throw UnimplementedError();
  }

  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) {
    // TODO: implement setBackgroundImage
    throw UnimplementedError();
  }

  @override
  Future setBackgroundImagePosition(double x, double y, {bool clamp = false}) {
    // TODO: implement setBackgroundImagePosition
    throw UnimplementedError();
  }

  @override
  Future setBloom(bool enabled, double strength) {
    // TODO: implement setBloom
    throw UnimplementedError();
  }

  @override
  Future setBoneTransform(ThermionEntity entity, int boneIndex, Matrix4 transform, {int skinIndex = 0}) {
    // TODO: implement setBoneTransform
    throw UnimplementedError();
  }

  @override
  Future setCamera(ThermionEntity entity, String? name) {
    // TODO: implement setCamera
    throw UnimplementedError();
  }

  @override
  Future setFrameRate(int framerate) {
    // TODO: implement setFrameRate
    throw UnimplementedError();
  }

  @override
  Future setGltfAnimationFrame(covariant ThermionAsset asset, int index, int animationFrame) {
    // TODO: implement setGltfAnimationFrame
    throw UnimplementedError();
  }

  @override
  Future setLightDirection(ThermionEntity lightEntity, Vector3 direction) {
    // TODO: implement setLightDirection
    throw UnimplementedError();
  }

  @override
  Future setLightPosition(ThermionEntity lightEntity, double x, double y, double z) {
    // TODO: implement setLightPosition
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
  Future setParent(ThermionEntity child, ThermionEntity? parent, {bool preserveScaling= false}) {
    // TODO: implement setParent
    throw UnimplementedError();
  }

  @override
  Future setPostProcessing(bool enabled) {
    // TODO: implement setPostProcessing
    throw UnimplementedError();
  }

  @override
  Future setPriority(ThermionEntity entityId, int priority) {
    // TODO: implement setPriority
    throw UnimplementedError();
  }

  @override
  Future setRendering(bool render) {
    // TODO: implement setRendering
    throw UnimplementedError();
  }

  @override
  Future setShadowType(ShadowType shadowType) {
    // TODO: implement setShadowType
    throw UnimplementedError();
  }

  @override
  Future setShadowsEnabled(bool enabled) {
    // TODO: implement setShadowsEnabled
    throw UnimplementedError();
  }

  @override
  Future setSoftShadowOptions(double penumbraScale, double penumbraRatioScale) {
    // TODO: implement setSoftShadowOptions
    throw UnimplementedError();
  }

  @override
  Future setToneMapping(ToneMapper mapper) {
    // TODO: implement setToneMapping
    throw UnimplementedError();
  }

  @override
  Future setTransform(ThermionEntity entity, Matrix4 transform) {
    // TODO: implement setTransform
    throw UnimplementedError();
  }

  @override
  Future setViewFrustumCulling(bool enabled) {
    // TODO: implement setViewFrustumCulling
    throw UnimplementedError();
  }

  @override
  Future showGridOverlay() {
    // TODO: implement showGridOverlay
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
  Future unregisterRequestFrameHook(Future Function() hook) {
    // TODO: implement unregisterRequestFrameHook
    throw UnimplementedError();
  }

  @override
  Future updateBoneMatrices(ThermionEntity entity) {
    // TODO: implement updateBoneMatrices
    throw UnimplementedError();
  }

  @override
  // TODO: implement view
  View get view => throw UnimplementedError();

}
