@JS()
library flutter_filament_js;

import 'dart:js_interop';
import 'package:dart_filament/dart_filament/entities/filament_entity.dart';
import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';

///
/// An extension type on [JSObject] that represents a 
/// Javascript shim implementation for the [AbstractFilamentViewer] interface.
/// 
extension type DartFilamentAPIJSShim(JSObject _) implements JSObject {

  @JS('wasm_test')
  external JSPromise wasm_test(String str);
  
  @JS('set_rendering')
  external JSPromise set_rendering(bool render);

  @JS('render')
  external JSPromise render();

  @JS('setFrameRate')
  external JSPromise setFrameRate(int framerate);

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
  external JSPromise removeLight(FilamentEntity light);

  @JS('clearLights')
  external JSPromise clearLights();

  @JS('loadGlb')
  external JSPromise<JSNumber> loadGlb(String path, int numInstances);

  @JS('createInstance')
  external JSPromise<JSNumber> createInstance(FilamentEntity entity);

  @JS('getInstanceCount')
  external JSPromise<JSNumber> getInstanceCount(FilamentEntity entity);

  @JS('getInstances')
  external JSPromise<JSArray<JSNumber>> getInstances(FilamentEntity entity);

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
      FilamentEntity entity, JSArray<JSNumber> weights);

  @JS('getMorphTargetNames')
  external JSPromise<JSArray<JSString>> getMorphTargetNames(
      FilamentEntity entity, FilamentEntity childEntity);

  @JS('getBoneNames')
  external JSPromise<JSArray<JSString>> getBoneNames(
      FilamentEntity entity, int skinIndex);

  @JS('getAnimationNames')
  external JSPromise<JSArray<JSString>> getAnimationNames(
      FilamentEntity entity);

  @JS('getAnimationDuration')
  external JSPromise<JSNumber> getAnimationDuration(
      FilamentEntity entity, int animationIndex);

  @JS('setMorphAnimationData')
  external JSPromise setMorphAnimationData(
      FilamentEntity entity,
      JSArray<JSArray<JSNumber>> animation,
      JSArray<JSString> morphTargets,
      JSArray<JSString>? targetMeshNames,
      double frameLengthInMs);

  @JS('resetBones')
  external JSPromise resetBones(FilamentEntity entity);

  @JS('addBoneAnimation')
  external JSPromise addBoneAnimation(
      FilamentEntity entity,
      JSArray<JSString> bones,
      JSArray<JSArray<JSArray<JSNumber>>> frameData,
      JSNumber frameLengthInMs,
      JSNumber spaceEnum,
      JSNumber skinIndex,
      JSNumber fadeInInSecs,
      JSNumber fadeOutInSecs,
      JSNumber maxDelta);

  @JS('removeEntity')
  external JSPromise removeEntity(FilamentEntity entity);

  @JS('clearEntities')
  external JSPromise clearEntities();

  @JS('zoomBegin')
  external JSPromise zoomBegin();

  @JS('zoomUpdate')
  external JSPromise zoomUpdate(double x, double y, double z);

  @JS('zoomEnd')
  external JSPromise zoomEnd();

  @JS('playAnimation')
  external JSPromise playAnimation(
    FilamentEntity entity,
    int index,
    bool loop,
    bool reverse,
    bool replaceActive,
    double crossfade,
  );

  @JS('playAnimationByName')
  external JSPromise playAnimationByName(
    FilamentEntity entity,
    String name,
    bool loop,
    bool reverse,
    bool replaceActive,
    double crossfade,
  );

  @JS('setAnimationFrame')
  external JSPromise setAnimationFrame(
      FilamentEntity entity, int index, int animationFrame);

  @JS('stopAnimation')
  external JSPromise stopAnimation(FilamentEntity entity, int animationIndex);

  @JS('stopAnimationByName')
  external JSPromise stopAnimationByName(FilamentEntity entity, String name);

  @JS('setCamera')
  external JSPromise setCamera(FilamentEntity entity, String? name);

  @JS('setMainCamera')
  external JSPromise setMainCamera();

  @JS('getMainCamera')
  external JSPromise<JSNumber> getMainCamera();

  @JS('setCameraFov')
  external JSPromise setCameraFov(double degrees, double width, double height);

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
  external JSPromise moveCameraToAsset(FilamentEntity entity);

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
  external JSPromise setMaterialColor(FilamentEntity entity, String meshName,
      int materialIndex, double r, double g, double b, double a);

  @JS('transformToUnitCube')
  external JSPromise transformToUnitCube(FilamentEntity entity);

  @JS('setPosition')
  external JSPromise setPosition(
      FilamentEntity entity, double x, double y, double z);

  @JS('setScale')
  external JSPromise setScale(FilamentEntity entity, double scale);

  @JS('setRotation')
  external JSPromise setRotation(
      FilamentEntity entity, double rads, double x, double y, double z);

  @JS('queuePositionUpdate')
  external JSPromise queuePositionUpdate(
      FilamentEntity entity, double x, double y, double z, bool relative);

  @JS('queueRotationUpdate')
  external JSPromise queueRotationUpdate(FilamentEntity entity, double rads,
      double x, double y, double z, bool relative);

  @JS('queueRotationUpdateQuat')
  external JSPromise queueRotationUpdateQuat(
      FilamentEntity entity, JSArray<JSNumber> quat, bool relative);

  @JS('setPostProcessing')
  external JSPromise setPostProcessing(bool enabled);

  @JS('setAntiAliasing')
  external JSPromise setAntiAliasing(bool msaa, bool fxaa, bool taa);

  @JS('setRotationQuat')
  external JSPromise setRotationQuat(
      FilamentEntity entity, JSArray<JSNumber> rotation);

  @JS('reveal')
  external JSPromise reveal(FilamentEntity entity, String? meshName);

  @JS('hide')
  external JSPromise hide(FilamentEntity entity, String? meshName);

  @JS('pick')
  external void pick(int x, int y);

  @JS('getNameForEntity')
  external String? getNameForEntity(FilamentEntity entity);

  @JS('setCameraManipulatorOptions')
  external JSPromise setCameraManipulatorOptions(
    int mode,
    double orbitSpeedX,
    double orbitSpeedY,
    double zoomSpeed,
  );

  @JS('getChildEntities')
  external JSPromise<JSArray<JSNumber>> getChildEntities(
      FilamentEntity parent, bool renderableOnly);

  @JS('getChildEntity')
  external JSPromise<JSNumber> getChildEntity(
      FilamentEntity parent, String childName);

  @JS('getChildEntityNames')
  external JSPromise<JSArray<JSString>> getChildEntityNames(
      FilamentEntity entity, bool renderableOnly);

  @JS('setRecording')
  external JSPromise setRecording(JSBoolean recording);

  @JS('setRecordingOutputDirectory')
  external JSPromise setRecordingOutputDirectory(String outputDirectory);

  @JS('addAnimationComponent')
  external JSPromise addAnimationComponent(FilamentEntity entity);

  @JS('removeAnimationComponent')
  external JSPromise removeAnimationComponent(FilamentEntity entity);

  @JS('addCollisionComponent')
  external JSPromise addCollisionComponent(FilamentEntity entity);

  @JS('removeCollisionComponent')
  external JSPromise removeCollisionComponent(FilamentEntity entity);

  @JS('createGeometry')
  external JSPromise<JSNumber> createGeometry(JSArray<JSNumber> vertices,
      JSArray<JSNumber> indices, String? materialPath, int primitiveType);

  @JS('setParent')
  external JSPromise setParent(FilamentEntity child, FilamentEntity parent);

  @JS('getParent')
  external JSPromise<JSNumber> getParent(FilamentEntity child);

  @JS('getParent')
  external JSPromise<JSNumber> getBone(
      FilamentEntity child, int boneIndex, int skinIndex);

  @JS('testCollisions')
  external JSPromise testCollisions(FilamentEntity entity);

  @JS('setPriority')
  external JSPromise setPriority(FilamentEntity entityId, int priority);

  @JS('getLocalTransform')
  external JSPromise<JSArray<JSNumber>> getLocalTransform(
      FilamentEntity entity);

  @JS('getWorldTransform')
  external JSPromise<JSArray<JSNumber>> getWorldTransform(
      FilamentEntity entity);

  @JS('updateBoneMatrices')
  external JSPromise updateBoneMatrices(FilamentEntity entity);

  @JS('setTransform')
  external JSPromise setTransform(
      FilamentEntity entity, JSArray<JSNumber> transform);

  @JS('setBoneTransform')
  external JSPromise setBoneTransform(
      FilamentEntity entity, int boneIndex, JSArray<JSNumber> transform, int skinIndex);
}

