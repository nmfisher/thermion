import 'dart:math';
import 'dart:typed_data';

import 'package:thermion_dart/thermion_dart/entities/abstract_gizmo.dart';
import 'package:thermion_dart/thermion_dart/scene.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:vector_math/vector_math_64.dart';
import 'dart:async';
import 'package:animation_tools_dart/animation_tools_dart.dart';

typedef ThermionViewerImpl = ThermionViewerStub;

class ThermionViewerStub extends ThermionViewer {
  @override
  Future addAnimationComponent(ThermionEntity entity) {
    // TODO: implement addAnimationComponent
    throw UnimplementedError();
  }

  @override
  Future addBoneAnimation(ThermionEntity entity, BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeInInSecs = 0.0,
      double fadeOutInSecs = 0.0,
      double maxDelta = 1.0}) {
    // TODO: implement addBoneAnimation
    throw UnimplementedError();
  }

  @override
  Future addCollisionComponent(ThermionEntity entity,
      {void Function(int entityId1, int entityId2)? callback,
      bool affectsTransform = false}) {
    // TODO: implement addCollisionComponent
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity> addLight(
      LightType type,
      double colour,
      double intensity,
      double posX,
      double posY,
      double posZ,
      double dirX,
      double dirY,
      double dirZ,
      {double falloffRadius = 1.0,
      double spotLightConeInner = pi / 8,
      double spotLightConeOuter = pi / 4,
      double sunAngularRadius = 0.545,
      double sunHaloSize = 10.0,
      double sunHaloFallof = 80.0,
      bool castShadows = true}) {
    // TODO: implement addLight
    throw UnimplementedError();
  }

  @override
  Future clearBackgroundImage() {
    // TODO: implement clearBackgroundImage
    throw UnimplementedError();
  }

  @override
  Future clearEntities() {
    // TODO: implement clearEntities
    throw UnimplementedError();
  }

  @override
  Future clearLights() {
    // TODO: implement clearLights
    throw UnimplementedError();
  }

  @override
  Future createGeometry(List<double> vertices, List<int> indices,
      {String? materialPath,
      PrimitiveType primitiveType = PrimitiveType.TRIANGLES}) {
    // TODO: implement createGeometry
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity> createInstance(ThermionEntity entity) {
    // TODO: implement createInstance
    throw UnimplementedError();
  }

  @override
  Future dispose() {
    // TODO: implement dispose
    throw UnimplementedError();
  }

  @override
  Future<double> getAnimationDuration(
      ThermionEntity entity, int animationIndex) {
    // TODO: implement getAnimationDuration
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getAnimationNames(ThermionEntity entity) {
    // TODO: implement getAnimationNames
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity> getBone(ThermionEntity parent, int boneIndex,
      {int skinIndex = 0}) {
    // TODO: implement getBone
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getBoneNames(ThermionEntity entity,
      {int skinIndex = 0}) {
    // TODO: implement getBoneNames
    throw UnimplementedError();
  }

  @override
  Future<double> getCameraCullingFar() {
    // TODO: implement getCameraCullingFar
    throw UnimplementedError();
  }

  @override
  Future<double> getCameraCullingNear() {
    // TODO: implement getCameraCullingNear
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getCameraCullingProjectionMatrix() {
    // TODO: implement getCameraCullingProjectionMatrix
    throw UnimplementedError();
  }

  @override
  Future<Frustum> getCameraFrustum() {
    // TODO: implement getCameraFrustum
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getCameraModelMatrix() {
    // TODO: implement getCameraModelMatrix
    throw UnimplementedError();
  }

  @override
  Future<Vector3> getCameraPosition() {
    // TODO: implement getCameraPosition
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getCameraProjectionMatrix() {
    // TODO: implement getCameraProjectionMatrix
    throw UnimplementedError();
  }

  @override
  Future<Matrix3> getCameraRotation() {
    // TODO: implement getCameraRotation
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getCameraViewMatrix() {
    // TODO: implement getCameraViewMatrix
    throw UnimplementedError();
  }

  @override
  Future<List<ThermionEntity>> getChildEntities(
      ThermionEntity parent, bool renderableOnly) {
    // TODO: implement getChildEntities
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity> getChildEntity(
      ThermionEntity parent, String childName) {
    // TODO: implement getChildEntity
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getChildEntityNames(ThermionEntity entity,
      {bool renderableOnly = true}) {
    // TODO: implement getChildEntityNames
    throw UnimplementedError();
  }

  @override
  Future<int> getInstanceCount(ThermionEntity entity) {
    // TODO: implement getInstanceCount
    throw UnimplementedError();
  }

  @override
  Future<List<ThermionEntity>> getInstances(ThermionEntity entity) {
    // TODO: implement getInstances
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getInverseBindMatrix(ThermionEntity parent, int boneIndex,
      {int skinIndex = 0}) {
    // TODO: implement getInverseBindMatrix
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getLocalTransform(ThermionEntity entity) {
    // TODO: implement getLocalTransform
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity> getMainCamera() {
    // TODO: implement getMainCamera
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getMorphTargetNames(
      ThermionEntity entity, ThermionEntity childEntity) {
    // TODO: implement getMorphTargetNames
    throw UnimplementedError();
  }

  @override
  String? getNameForEntity(ThermionEntity entity) {
    // TODO: implement getNameForEntity
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity?> getParent(ThermionEntity child) {
    // TODO: implement getParent
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getWorldTransform(ThermionEntity entity) {
    // TODO: implement getWorldTransform
    throw UnimplementedError();
  }

  @override
  // TODO: implement gizmo
  AbstractGizmo? get gizmo => throw UnimplementedError();

  @override
  Future hide(ThermionEntity entity, String? meshName) {
    // TODO: implement hide
    throw UnimplementedError();
  }

  @override
  // TODO: implement initialized
  Future<bool> get initialized => throw UnimplementedError();

  @override
  Future<ThermionEntity> loadGlb(String path, {int numInstances = 1}) {
    // TODO: implement loadGlb
    throw UnimplementedError();
  }

  @override
  Future<ThermionEntity> loadGltf(String path, String relativeResourcePath,
      {bool force = false}) {
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
  Future moveCameraToAsset(ThermionEntity entity) {
    // TODO: implement moveCameraToAsset
    throw UnimplementedError();
  }

  @override
  void onDispose(Future Function() callback) {
    // TODO: implement onDispose
  }

  @override
  Future panEnd() {
    // TODO: implement panEnd
    throw UnimplementedError();
  }

  @override
  Future panStart(double x, double y) {
    // TODO: implement panStart
    throw UnimplementedError();
  }

  @override
  Future panUpdate(double x, double y) {
    // TODO: implement panUpdate
    throw UnimplementedError();
  }

  @override
  void pick(int x, int y) {
    // TODO: implement pick
  }

  @override
  // TODO: implement pickResult
  Stream<FilamentPickResult> get pickResult => throw UnimplementedError();

  @override
  Future playAnimation(ThermionEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset=0.0}) {
    // TODO: implement playAnimation
    throw UnimplementedError();
  }

  @override
  Future playAnimationByName(ThermionEntity entity, String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) {
    // TODO: implement playAnimationByName
    throw UnimplementedError();
  }

  @override
  Future queuePositionUpdate(
      ThermionEntity entity, double x, double y, double z,
      {bool relative = false}) {
    // TODO: implement queuePositionUpdate
    throw UnimplementedError();
  }

  @override
  Future queueRotationUpdate(
      ThermionEntity entity, double rads, double x, double y, double z,
      {bool relative = false}) {
    // TODO: implement queueRotationUpdate
    throw UnimplementedError();
  }

  @override
  Future queueRotationUpdateQuat(ThermionEntity entity, Quaternion quat,
      {bool relative = false}) {
    // TODO: implement queueRotationUpdateQuat
    throw UnimplementedError();
  }

  @override
  Future removeAnimationComponent(ThermionEntity entity) {
    // TODO: implement removeAnimationComponent
    throw UnimplementedError();
  }

  @override
  Future removeCollisionComponent(ThermionEntity entity) {
    // TODO: implement removeCollisionComponent
    throw UnimplementedError();
  }

  @override
  Future removeEntity(ThermionEntity entity) {
    // TODO: implement removeEntity
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
  Future resetBones(ThermionEntity entity) {
    // TODO: implement resetBones
    throw UnimplementedError();
  }

  @override
  Future reveal(ThermionEntity entity, String? meshName) {
    // TODO: implement reveal
    throw UnimplementedError();
  }

  @override
  Future rotateEnd() {
    // TODO: implement rotateEnd
    throw UnimplementedError();
  }

  @override
  Future rotateIbl(Matrix3 rotation) {
    // TODO: implement rotateIbl
    throw UnimplementedError();
  }

  @override
  Future rotateStart(double x, double y) {
    // TODO: implement rotateStart
    throw UnimplementedError();
  }

  @override
  Future rotateUpdate(double x, double y) {
    // TODO: implement rotateUpdate
    throw UnimplementedError();
  }

  @override
  // TODO: implement scene
  Scene get scene => throw UnimplementedError();

  @override
  Future setAnimationFrame(
      ThermionEntity entity, int index, int animationFrame) {
    // TODO: implement setAnimationFrame
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
  Future setBloom(double bloom) {
    // TODO: implement setBloom
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
  Future setCamera(ThermionEntity entity, String? name) {
    // TODO: implement setCamera
    throw UnimplementedError();
  }

  @override
  Future setCameraCulling(double near, double far) {
    // TODO: implement setCameraCulling
    throw UnimplementedError();
  }

  @override
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) {
    // TODO: implement setCameraExposure
    throw UnimplementedError();
  }

  @override
  Future setCameraFocalLength(double focalLength) {
    // TODO: implement setCameraFocalLength
    throw UnimplementedError();
  }

  @override
  Future setCameraFocusDistance(double focusDistance) {
    // TODO: implement setCameraFocusDistance
    throw UnimplementedError();
  }

  @override
  Future setCameraFov(double degrees, {bool horizontal=true}) {
    // TODO: implement setCameraFov
    throw UnimplementedError();
  }

  @override
  Future setCameraManipulatorOptions(
      {ManipulatorMode mode = ManipulatorMode.ORBIT,
      double orbitSpeedX = 0.01,
      double orbitSpeedY = 0.01,
      double zoomSpeed = 0.01}) {
    // TODO: implement setCameraManipulatorOptions
    throw UnimplementedError();
  }

  @override
  Future setCameraModelMatrix(List<double> matrix) {
    // TODO: implement setCameraModelMatrix
    throw UnimplementedError();
  }

  @override
  Future setCameraPosition(double x, double y, double z) {
    // TODO: implement setCameraPosition
    throw UnimplementedError();
  }

  @override
  Future setCameraRotation(Quaternion quaternion) {
    // TODO: implement setCameraRotation
    throw UnimplementedError();
  }

  @override
  Future setFrameRate(int framerate) {
    // TODO: implement setFrameRate
    throw UnimplementedError();
  }

  @override
  Future setMainCamera() {
    // TODO: implement setMainCamera
    throw UnimplementedError();
  }

  @override
  Future setMaterialColor(ThermionEntity entity, String meshName,
      int materialIndex, double r, double g, double b, double a) {
    // TODO: implement setMaterialColor
    throw UnimplementedError();
  }

  @override
  Future clearMorphAnimationData(ThermionEntity entity) {
    throw UnimplementedError();
  }

  @override
  Future setMorphAnimationData(
      ThermionEntity entity, MorphAnimationData animation,
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
  Future setParent(ThermionEntity child, ThermionEntity parent, { bool preserveScaling = false}) {
    // TODO: implement setParent
    throw UnimplementedError();
  }

  @override
  Future setPosition(ThermionEntity entity, double x, double y, double z) {
    // TODO: implement setPosition
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
  Future setRecording(bool recording) {
    // TODO: implement setRecording
    throw UnimplementedError();
  }

  @override
  Future setRecordingOutputDirectory(String outputDirectory) {
    // TODO: implement setRecordingOutputDirectory
    throw UnimplementedError();
  }

  @override
  Future setRendering(bool render) {
    // TODO: implement setRendering
    throw UnimplementedError();
  }

  @override
  Future setRotation(
      ThermionEntity entity, double rads, double x, double y, double z) {
    // TODO: implement setRotation
    throw UnimplementedError();
  }

  @override
  Future setRotationQuat(ThermionEntity entity, Quaternion rotation) {
    // TODO: implement setRotationQuat
    throw UnimplementedError();
  }

  @override
  Future setScale(ThermionEntity entity, double scale) {
    // TODO: implement setScale
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
  Future stopAnimation(ThermionEntity entity, int animationIndex) {
    // TODO: implement stopAnimation
    throw UnimplementedError();
  }

  @override
  Future stopAnimationByName(ThermionEntity entity, String name) {
    // TODO: implement stopAnimationByName
    throw UnimplementedError();
  }

  @override
  Future testCollisions(ThermionEntity entity) {
    // TODO: implement testCollisions
    throw UnimplementedError();
  }

  @override
  Future transformToUnitCube(ThermionEntity entity) {
    // TODO: implement transformToUnitCube
    throw UnimplementedError();
  }

  @override
  Future updateBoneMatrices(ThermionEntity entity) {
    // TODO: implement updateBoneMatrices
    throw UnimplementedError();
  }

  @override
  Future zoomBegin() {
    // TODO: implement zoomBegin
    throw UnimplementedError();
  }

  @override
  Future zoomEnd() {
    // TODO: implement zoomEnd
    throw UnimplementedError();
  }

  @override
  Future zoomUpdate(double x, double y, double z) {
    // TODO: implement zoomUpdate
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
  Future<Uint8List> capture() {
    // TODO: implement capture
    throw UnimplementedError();
  }
  
  @override
  Future<Aabb2> getBoundingBox(ThermionEntity entity) {
    // TODO: implement getBoundingBox
    throw UnimplementedError();
  }
  
  @override
  Future<double> getCameraFov(bool horizontal) {
    // TODO: implement getCameraFov
    throw UnimplementedError();
  }
  
  @override
  Future queueRelativePositionUpdateWorldAxis(ThermionEntity entity, double viewportX, double viewportY, double x, double y, double z) {
    // TODO: implement queueRelativePositionUpdateWorldAxis
    throw UnimplementedError();
  }
  
  @override
  Future setLayerEnabled(int layer, bool enabled) {
    // TODO: implement setLayerEnabled
    throw UnimplementedError();
  }
}
