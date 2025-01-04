@JS()
library thermion_flutter_js;

import 'dart:js_interop';

import '../../shared_types/shared_types.dart';

///
/// An extension type on [JSObject] that represents a
/// Javascript shim implementation of the [ThermionViewer] interface.
///
extension type ThermionViewerJSShim(JSObject _) implements JSObject {
  @JS('initialized')
  external JSPromise<JSBoolean> get initialized;

  @JS('rendering')
  external bool get rendering;

  @JS('setRendering')
  external JSPromise setRendering(bool render);

  @JS('render')
  external JSPromise render();

  @JS('capture')
  external JSPromise<JSUint8Array> capture();

  @JS('setFrameRate')
  external JSPromise setFrameRate(int framerate);

  @JS('dispose')
  external JSPromise dispose();

  @JS('setBackgroundImage')
  external JSPromise setBackgroundImage(String path, bool fillHeight);

  @JS('setBackgroundImagePosition')
  external JSPromise setBackgroundImagePosition(double x, double y, bool clamp);

  @JS('clearBackgroundImage')
  external JSPromise clearBackgroundImage();

  @JS('setBackgroundColor')
  external JSPromise setBackgroundColor(
      double r, double g, double b, double alpha);

  @JS('loadSkybox')
  external JSPromise loadSkybox(String skyboxPath);

  @JS('removeSkybox')
  external JSPromise removeSkybox();

  @JS('loadIbl')
  external JSPromise loadIbl(String lightingPath, double intensity);

  @JS('rotateIbl')
  external JSPromise rotateIbl(JSArray<JSNumber> rotationMatrix);

  @JS('removeIbl')
  external JSPromise removeIbl();

  @JS('addLight')
  external JSPromise<JSNumber> addLight(
      int type,
      double colour,
      double intensity,
      double posX,
      double posY,
      double posZ,
      double dirX,
      double dirY,
      double dirZ,
      double falloffRadius,
      double spotLightConeInner,
      double spotLightConeOuter,
      double sunAngularRadius,
      double sunHaloSize,
      double sunHaloFallof,
      bool castShadows);

  @JS('removeLight')
  external JSPromise removeLight(ThermionEntity light);

  @JS('destroyLights')
  external JSPromise destroyLights();

  @JS('loadGlb')
  external JSPromise<JSNumber> loadGlb(String path, int numInstances);

  @JS('createInstance')
  external JSPromise<JSNumber> createInstance(ThermionEntity entity);

  @JS('getInstanceCount')
  external JSPromise<JSNumber> getInstanceCount(ThermionEntity entity);

  @JS('getInstances')
  external JSPromise<JSArray<JSNumber>> getInstances(ThermionEntity entity);

  @JS('loadGltf')
  external JSPromise<JSNumber> loadGltf(
      String path, String relativeResourcePath);

  @JS('panStart')
  external JSPromise panStart(double x, double y);

  @JS('panUpdate')
  external JSPromise panUpdate(double x, double y);

  @JS('panEnd')
  external JSPromise panEnd();

  @JS('rotateStart')
  external JSPromise rotateStart(double x, double y);

  @JS('rotateUpdate')
  external JSPromise rotateUpdate(double x, double y);

  @JS('rotateEnd')
  external JSPromise rotateEnd();

  @JS('setMorphTargetWeights')
  external JSPromise setMorphTargetWeights(
      ThermionEntity entity, JSArray<JSNumber> weights);

  @JS('getMorphTargetNames')
  external JSPromise<JSArray<JSString>> getMorphTargetNames(
      ThermionEntity entity, ThermionEntity childEntity);

  @JS('getBoneNames')
  external JSPromise<JSArray<JSString>> getBoneNames(
      ThermionEntity entity, int skinIndex);

  @JS('getAnimationNames')
  external JSPromise<JSArray<JSString>> getAnimationNames(
      ThermionEntity entity);

  @JS('getAnimationDuration')
  external JSPromise<JSNumber> getAnimationDuration(
      ThermionEntity entity, int animationIndex);

  @JS('clearMorphAnimationData')
  external void clearMorphAnimationData(ThermionEntity entity);

  @JS('setMorphAnimationData')
  external JSPromise setMorphAnimationData(
      ThermionEntity entity,
      JSArray<JSArray<JSNumber>> animation,
      JSArray<JSString> morphTargets,
      JSArray<JSString>? targetMeshNames,
      double frameLengthInMs);

  @JS('resetBones')
  external JSPromise resetBones(ThermionEntity entity);

  @JS('addBoneAnimation')
  external JSPromise addBoneAnimation(
      ThermionEntity entity,
      JSArray<JSString> bones,
      JSArray<JSArray<JSArray<JSNumber>>> frameData,
      JSNumber frameLengthInMs,
      JSNumber spaceEnum,
      JSNumber skinIndex,
      JSNumber fadeInInSecs,
      JSNumber fadeOutInSecs,
      JSNumber maxDelta);

  @JS('destroyAsset')
  external JSPromise destroyAsset(ThermionEntity entity);

  @JS('destroyAssets')
  external JSPromise destroyAssets();

  @JS('zoomBegin')
  external JSPromise zoomBegin();

  @JS('zoomUpdate')
  external JSPromise zoomUpdate(double x, double y, double z);

  @JS('zoomEnd')
  external JSPromise zoomEnd();

  @JS('playAnimation')
  external JSPromise playAnimation(
    ThermionEntity entity,
    int index,
    bool loop,
    bool reverse,
    bool replaceActive,
    double crossfade,
    double startOffset,
  );

  @JS('playAnimationByName')
  external JSPromise playAnimationByName(
    ThermionEntity entity,
    String name,
    bool loop,
    bool reverse,
    bool replaceActive,
    double crossfade,
  );

  @JS('setAnimationFrame')
  external JSPromise setAnimationFrame(
      ThermionEntity entity, int index, int animationFrame);

  @JS('stopAnimation')
  external JSPromise stopAnimation(ThermionEntity entity, int animationIndex);

  @JS('stopAnimationByName')
  external JSPromise stopAnimationByName(ThermionEntity entity, String name);

  @JS('setCamera')
  external JSPromise setCamera(ThermionEntity entity, String? name);

  @JS('setMainCamera')
  external JSPromise setMainCamera();

  @JS('getMainCamera')
  external JSPromise<JSNumber> getMainCamera();

  @JS('setCameraFov')
  external JSPromise setCameraFov(double degrees, bool horizontal);

  @JS('setToneMapping')
  external JSPromise setToneMapping(int mapper);

  @JS('setBloom')
  external JSPromise setBloom(double bloom);

  @JS('setCameraFocalLength')
  external JSPromise setCameraFocalLength(double focalLength);

  @JS('setCameraCulling')
  external JSPromise setCameraCulling(double near, double far);

  @JS('getCameraCullingNear')
  external JSPromise<JSNumber> getCameraCullingNear();

  @JS('getCameraCullingFar')
  external JSPromise<JSNumber> getCameraCullingFar();

  @JS('setCameraFocusDistance')
  external JSPromise setCameraFocusDistance(double focusDistance);

  @JS('getCameraPosition')
  external JSPromise<JSArray<JSNumber>> getCameraPosition();

  @JS('getCameraModelMatrix')
  external JSPromise<JSArray<JSNumber>> getCameraModelMatrix();

  @JS('getCameraViewMatrix')
  external JSPromise<JSArray<JSNumber>> getCameraViewMatrix();

  @JS('getCameraProjectionMatrix')
  external JSPromise<JSArray<JSNumber>> getCameraProjectionMatrix();

  @JS('getCameraCullingProjectionMatrix')
  external JSPromise<JSArray<JSNumber>> getCameraCullingProjectionMatrix();

  @JS('getCameraFrustum')
  external JSPromise<JSObject> getCameraFrustum();

  @JS('setCameraPosition')
  external JSPromise setCameraPosition(double x, double y, double z);

  @JS('getCameraRotation')
  external JSPromise<JSArray<JSNumber>> getCameraRotation();

  @JS('moveCameraToAsset')
  external JSPromise moveCameraToAsset(ThermionEntity entity);

  @JS('setViewFrustumCulling')
  external JSPromise setViewFrustumCulling(JSBoolean enabled);

  @JS('setCameraExposure')
  external JSPromise setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity);

  @JS('setCameraRotation')
  external JSPromise setCameraRotation(JSArray<JSNumber> quaternion);

  @JS('setCameraModelMatrix')
  external JSPromise setCameraModelMatrix(JSArray<JSNumber> matrix);

  @JS('setMaterialColor')
  external JSPromise setMaterialColor(ThermionEntity entity, String meshName,
      int materialIndex, double r, double g, double b, double a);

  @JS('transformToUnitCube')
  external JSPromise transformToUnitCube(ThermionEntity entity);

  @JS('setPosition')
  external JSPromise setPosition(
      ThermionEntity entity, double x, double y, double z);

  @JS('setScale')
  external JSPromise setScale(ThermionEntity entity, double scale);

  @JS('setRotation')
  external JSPromise setRotation(
      ThermionEntity entity, double rads, double x, double y, double z);

  @JS('queuePositionUpdate')
  external JSPromise queuePositionUpdate(
      ThermionEntity entity, double x, double y, double z, bool relative);

  @JS('queueRotationUpdate')
  external JSPromise queueRotationUpdate(ThermionEntity entity, double rads,
      double x, double y, double z, bool relative);

  @JS('queueRotationUpdateQuat')
  external JSPromise queueRotationUpdateQuat(
      ThermionEntity entity, JSArray<JSNumber> quat, bool relative);

  @JS('setPostProcessing')
  external JSPromise setPostProcessing(bool enabled);

  @JS('setAntiAliasing')
  external JSPromise setAntiAliasing(bool msaa, bool fxaa, bool taa);

  @JS('setRotationQuat')
  external JSPromise setRotationQuat(
      ThermionEntity entity, JSArray<JSNumber> rotation);

  @JS('reveal')
  external JSPromise reveal(ThermionEntity entity, String? meshName);

  @JS('hide')
  external JSPromise hide(ThermionEntity entity, String? meshName);

  @JS('pick')
  external void pick(int x, int y);

  @JS('getNameForEntity')
  external String? getNameForEntity(ThermionEntity entity);

  @JS('setCameraManipulatorOptions')
  external JSPromise setCameraManipulatorOptions(
    int mode,
    double orbitSpeedX,
    double orbitSpeedY,
    double zoomSpeed,
  );

  @JS('getChildEntities')
  external JSPromise<JSArray<JSNumber>> getChildEntities(
      ThermionEntity parent, bool renderableOnly);

  @JS('getChildEntity')
  external JSPromise<JSNumber> getChildEntity(
      ThermionEntity parent, String childName);

  @JS('getChildEntityNames')
  external JSPromise<JSArray<JSString>> getChildEntityNames(
      ThermionEntity entity, bool renderableOnly);

  @JS('setRecording')
  external JSPromise setRecording(JSBoolean recording);

  @JS('setRecordingOutputDirectory')
  external JSPromise setRecordingOutputDirectory(String outputDirectory);

  @JS('addAnimationComponent')
  external JSPromise addAnimationComponent(ThermionEntity entity);

  @JS('removeAnimationComponent')
  external JSPromise removeAnimationComponent(ThermionEntity entity);

  @JS('addCollisionComponent')
  external JSPromise addCollisionComponent(ThermionEntity entity);

  @JS('removeCollisionComponent')
  external JSPromise removeCollisionComponent(ThermionEntity entity);

  @JS('createGeometry')
  external JSPromise<JSNumber> createGeometry(JSArray<JSNumber> vertices,
      JSArray<JSNumber> indices, String? materialPath, int primitiveType);

  @JS('setParent')
  external JSPromise setParent(ThermionEntity child, ThermionEntity parent, bool preserveScaling);

  @JS('getParent')
  external JSPromise<JSNumber> getParent(ThermionEntity child);

  @JS('getParent')
  external JSPromise<JSNumber> getBone(
      ThermionEntity child, int boneIndex, int skinIndex);

  @JS('testCollisions')
  external JSPromise testCollisions(ThermionEntity entity);

  @JS('setPriority')
  external JSPromise setPriority(ThermionEntity entityId, int priority);

  @JS('getLocalTransform')
  external JSPromise<JSArray<JSNumber>> getLocalTransform(
      ThermionEntity entity);

  @JS('getWorldTransform')
  external JSPromise<JSArray<JSNumber>> getWorldTransform(
      ThermionEntity entity);

  @JS('updateBoneMatrices')
  external JSPromise updateBoneMatrices(ThermionEntity entity);

  @JS('setTransform')
  external JSPromise setTransform(
      ThermionEntity entity, JSArray<JSNumber> transform);

  @JS('setBoneTransform')
  external JSPromise setBoneTransform(ThermionEntity entity, int boneIndex,
      JSArray<JSNumber> transform, int skinIndex);

  @JS('setShadowsEnabled')
  external JSPromise setShadowsEnabled(bool enabled);

  @JS('setShadowType')
  external JSPromise setShadowType(int shadowType);

  @JS('setSoftShadowOptions')
  external JSPromise setSoftShadowOptions(
      double penumbraScale, double penumbraRatioScale);
}
