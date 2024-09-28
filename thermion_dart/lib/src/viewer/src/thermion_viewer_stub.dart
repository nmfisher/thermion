import 'dart:math';
import 'dart:typed_data';

import 'package:thermion_dart/src/utils/gizmo.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/swap_chain.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/view.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';
import 'dart:async';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'events.dart';
import 'shared_types/camera.dart';

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
  Future hide(ThermionEntity entity, String? meshName) {
    // TODO: implement hide
    throw UnimplementedError();
  }

  @override
  // TODO: implement initialized
  Future<bool> get initialized => throw UnimplementedError();

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
  
  @override
  Future createIbl(double r, double g, double b, double intensity) {
    // TODO: implement createIbl
    throw UnimplementedError();
  }
  
  @override
  // TODO: implement gizmoPickResult
  Stream<FilamentPickResult> get gizmoPickResult => throw UnimplementedError();
  
  @override
  void pickGizmo(int x, int y) {
    // TODO: implement pickGizmo
  }
  
  @override
  Future setGizmoVisibility(bool visible) {
    // TODO: implement setGizmoVisibility
    throw UnimplementedError();
  }
  
  @override
  Future<ThermionEntity?> getAncestor(ThermionEntity entity) {
    // TODO: implement getAncestor
    throw UnimplementedError();
  }
  
  
  @override
  Future queuePositionUpdateFromViewportCoords(ThermionEntity entity, double x, double y) {
    // TODO: implement queuePositionUpdateFromViewportCoords
    throw UnimplementedError();
  }
  
  @override
  Future removeStencilHighlight(ThermionEntity entity) {
    // TODO: implement removeStencilHighlight
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
  Future setStencilHighlight(ThermionEntity entity, {double r = 1.0, double g = 0.0, double b = 0.0}) {
    // TODO: implement setStencilHighlight
    throw UnimplementedError();
  }
  
  @override
  Future<double> getCameraNear() {
    // TODO: implement getCameraNear
    throw UnimplementedError();
  }
  
  @override
  Future<Aabb2> getViewportBoundingBox(ThermionEntity entity) {
    // TODO: implement getViewportBoundingBox
    throw UnimplementedError();
  }
  
  
  @override
  Future setCameraModelMatrix4(Matrix4 matrix) {
    // TODO: implement setCameraModelMatrix4
    throw UnimplementedError();
  }
  
    
  @override
  Future<ThermionEntity> loadGlb(String path, {int numInstances = 1, bool keepData = false}) {
    // TODO: implement loadGlb
    throw UnimplementedError();
  }
  
  @override
  Future<ThermionEntity> loadGltf(String path, String relativeResourcePath, {bool keepData = false}) {
    // TODO: implement loadGltf
    throw UnimplementedError();
  }
  
  @override
  Future setMaterialPropertyFloat(ThermionEntity entity, String propertyName, int materialIndex, double value) {
    // TODO: implement setMaterialPropertyFloat
    throw UnimplementedError();
  }
  
  @override
  Future setMaterialPropertyFloat4(ThermionEntity entity, String propertyName, int materialIndex, double f1, double f2, double f3, double f4) {
    // TODO: implement setMaterialPropertyFloat4
    throw UnimplementedError();
  }
  
  @override
  // TODO: implement sceneUpdated
  Stream<SceneUpdateEvent> get sceneUpdated => throw UnimplementedError();
  
  @override
  Future<ThermionEntity> addDirectLight(DirectLight light) {
    // TODO: implement addDirectLight
    throw UnimplementedError();
  }
  
  @override
  Future applyTexture(covariant ThermionTexture texture, ThermionEntity entity, {int materialIndex = 0, String parameterName = "baseColorMap"}) {
    // TODO: implement applyTexture
    throw UnimplementedError();
  }
  
  @override
  Future<ThermionTexture> createTexture(Uint8List data) {
    // TODO: implement createTexture
    throw UnimplementedError();
  }
  
  @override
  Future<MaterialInstance> createUbershaderMaterialInstance({bool doubleSided = false, bool unlit = false, bool hasVertexColors = false, bool hasBaseColorTexture = false, bool hasNormalTexture = false, bool hasOcclusionTexture = false, bool hasEmissiveTexture = false, bool useSpecularGlossiness = false, AlphaMode alphaMode = AlphaMode.OPAQUE, bool enableDiagnostics = false, bool hasMetallicRoughnessTexture = false, int metallicRoughnessUV = 0, int baseColorUV = 0, bool hasClearCoatTexture = false, int clearCoatUV = 0, bool hasClearCoatRoughnessTexture = false, int clearCoatRoughnessUV = 0, bool hasClearCoatNormalTexture = false, int clearCoatNormalUV = 0, bool hasClearCoat = false, bool hasTransmission = false, bool hasTextureTransforms = false, int emissiveUV = 0, int aoUV = 0, int normalUV = 0, bool hasTransmissionTexture = false, int transmissionUV = 0, bool hasSheenColorTexture = false, int sheenColorUV = 0, bool hasSheenRoughnessTexture = false, int sheenRoughnessUV = 0, bool hasVolumeThicknessTexture = false, int volumeThicknessUV = 0, bool hasSheen = false, bool hasIOR = false, bool hasVolume = false}) {
    // TODO: implement createUbershaderMaterialInstance
    throw UnimplementedError();
  }
  
  @override
  Future<MaterialInstance> createUnlitMaterialInstance() {
    // TODO: implement createUnlitMaterialInstance
    throw UnimplementedError();
  }
  
  @override
  Future destroyMaterialInstance(covariant MaterialInstance materialInstance) {
    // TODO: implement destroyMaterialInstance
    throw UnimplementedError();
  }
  
  @override
  Future destroyTexture(covariant ThermionTexture texture) {
    // TODO: implement destroyTexture
    throw UnimplementedError();
  }
  
  @override
  Future createGeometry(Geometry geometry, {MaterialInstance? materialInstance, bool keepData = false}) {
    // TODO: implement createGeometry
    throw UnimplementedError();
  }
  
  @override
  Future<ThermionEntity> loadGlbFromBuffer(Uint8List data, {int numInstances = 1, bool keepData = false, int priority = 4, int layer = 0}) {
    // TODO: implement loadGlbFromBuffer
    throw UnimplementedError();
  }
  
  @override
  Future setMaterialPropertyInt(ThermionEntity entity, String propertyName, int materialIndex, int value) {
    // TODO: implement setMaterialPropertyInt
    throw UnimplementedError();
  }
  
  @override
  Future<MaterialInstance?> getMaterialInstanceAt(ThermionEntity entity, int index) {
    // TODO: implement getMaterialInstanceAt
    throw UnimplementedError();
  }
  
  @override
  Future setLayerVisibility(int layer, bool visible) {
    // TODO: implement setLayerVisibility
    throw UnimplementedError();
  }
  
  @override
  Future setMaterialDepthWrite(ThermionEntity entity, int materialIndex, bool enabled) {
    // TODO: implement setMaterialDepthWrite
    throw UnimplementedError();
  }
  
  @override
  Future setVisibilityLayer(ThermionEntity entity, int layer) {
    // TODO: implement setVisibilityLayer
    throw UnimplementedError();
  }
  
  @override
  Future requestFrame() {
    throw UnimplementedError();
  }
  
  @override
  Future setCameraLensProjection({double near = kNear, double far = kFar, double? aspect, double focalLength = kFocalLength}) {
    // TODO: implement setCameraLensProjection
    throw UnimplementedError();
  }
  
  @override
  Future<ThermionEntity> getMainCameraEntity() {
    // TODO: implement getMainCameraEntity
    throw UnimplementedError();
  }

  @override
  Future<Camera> getMainCamera() {
    // TODO: implement getMainCamera
    throw UnimplementedError();
  }
  
  @override
  Future<Camera> createCamera() {
    // TODO: implement createCamera
    throw UnimplementedError();
  }
  
  @override
  Future registerRenderHook(Future Function() hook) {
    // TODO: implement registerRenderHook
    throw UnimplementedError();
  }
  
  @override
  Future setActiveCamera(covariant Camera camera) {
    // TODO: implement setActiveCamera
    throw UnimplementedError();
  }
  
  @override
  Future registerRequestFrameHook(Future Function() hook) {
    // TODO: implement registerRequestFrameHook
    throw UnimplementedError();
  }
  
  @override
  Future unregisterRequestFrameHook(Future Function() hook) {
    // TODO: implement unregisterRequestFrameHook
    throw UnimplementedError();
  }
  
  @override
  Camera getCameraAt(int index) {
    // TODO: implement getCameraAt
    throw UnimplementedError();
  }
  
  @override
  int getCameraCount() {
    // TODO: implement getCameraCount
    throw UnimplementedError();
  }
  
  @override
  Future getActiveCamera() {
    // TODO: implement getActiveCamera
    throw UnimplementedError();
  }
  
  @override
  Future queueTransformUpdates(List<ThermionEntity> entities, List<Matrix4> transforms) {
    // TODO: implement queueTransformUpdates
    throw UnimplementedError();
  }

  @override
  Future<SwapChain> createSwapChain(int width, int height) {
    // TODO: implement createSwapChain
    throw UnimplementedError();
  }
  
  @override
  Future<RenderTarget> createRenderTarget(int width, int height, int textureHandle) {
    // TODO: implement createRenderTarget
    throw UnimplementedError();
  }
  
  @override
  Future setRenderTarget(covariant RenderTarget renderTarget) {
    // TODO: implement setRenderTarget
    throw UnimplementedError();
  }

  @override
  Future<View> createView() {
    // TODO: implement createView
    throw UnimplementedError();
  }

  @override
  Future<View> getViewAt(int index) {
    // TODO: implement getViewAt
    throw UnimplementedError();
  }

  @override
  Future render(covariant SwapChain swapChain) {
    // TODO: implement render
    throw UnimplementedError();
  }
  
  @override
  Future<Uint8List> capture(covariant SwapChain swapChain, {covariant View? view, covariant RenderTarget? renderTarget}) {
    // TODO: implement capture
    throw UnimplementedError();
  }

  @override
  Future<Gizmo> createGizmo(covariant View view) {
    // TODO: implement createGizmo
    throw UnimplementedError();
  }

  
}
