@JS()
library flutter_filament_js;

import 'dart:js_interop';
import 'dart:math';

import 'package:animation_tools_dart/src/morph_animation_data.dart';
import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';
import 'package:dart_filament/dart_filament/entities/filament_entity.dart';
import 'package:dart_filament/dart_filament/compatibility/web/interop/dart_filament_js_extension_type.dart';
import 'dart:js_interop_unsafe';

@JSExport()
class DartFilamentJSExportViewer {
  final AbstractFilamentViewer viewer;

  static void initializeBindings(AbstractFilamentViewer viewer) {
    var shim = DartFilamentJSExportViewer(viewer);
    var wrapper = createJSInteropWrapper<DartFilamentJSExportViewer>(shim)
        as DartFilamentJSShim;
    globalContext.setProperty("filamentViewer".toJS, wrapper);
  }

  DartFilamentJSExportViewer(this.viewer);

  JSPromise<JSBoolean> get initialized {
    return viewer.initialized.then((v) => v.toJS).toJS;
  }

  @JSExport()
  JSBoolean get rendering => viewer.rendering.toJS;

  @JSExport()
  JSPromise setRendering(bool render) {
    return viewer.setRendering(render).toJS;
  }

  @JSExport()
  JSPromise render() => viewer.render().toJS;

  @JSExport()
  JSPromise setFrameRate(int framerate) => viewer.setFrameRate(framerate).toJS;

  @JSExport()
  JSPromise dispose() => viewer.dispose().toJS;

  @JSExport()
  JSPromise setBackgroundImage(String path, {bool fillHeight = false}) =>
      viewer.setBackgroundImage(path, fillHeight: fillHeight).toJS;

  @JSExport()
  JSPromise setBackgroundImagePosition(double x, double y,
          {bool clamp = false}) =>
      viewer.setBackgroundImagePosition(x, y, clamp: clamp).toJS;

  @JSExport()
  JSPromise clearBackgroundImage() => viewer.clearBackgroundImage().toJS;

  @JSExport()
  JSPromise setBackgroundColor(double r, double g, double b, double alpha) =>
      viewer.setBackgroundColor(r, g, b, alpha).toJS;

  @JSExport()
  JSPromise loadSkybox(String skyboxPath) => viewer.loadSkybox(skyboxPath).toJS;

  @JSExport()
  JSPromise removeSkybox() => viewer.removeSkybox().toJS;

  @JSExport()
  JSPromise loadIbl(String lightingPath, {double intensity = 30000}) =>
      viewer.loadIbl(lightingPath, intensity: intensity).toJS;

  @JSExport()
  JSPromise rotateIbl(JSArray<JSNumber> rotation) => throw UnimplementedError();
  // viewer.rotateIbl(rotation.toDartMatrix3()).toJS;

  @JSExport()
  JSPromise removeIbl() => viewer.removeIbl().toJS;

  @JSExport()
  JSPromise<JSNumber> addLight(
      int type,
      double colour,
      double intensity,
      double posX,
      double posY,
      double posZ,
      double dirX,
      double dirY,
      double dirZ,
      bool castShadows) {
    return viewer
        .addLight(type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ,
            castShadows)
        .then((entity) => entity.toJS)
        .toJS;
  }

  @JSExport()
  JSPromise removeLight(FilamentEntity light) => viewer.removeLight(light).toJS;

  @JSExport()
  JSPromise clearLights() => viewer.clearLights().toJS;

  @JSExport()
  JSPromise<JSNumber> loadGlb(String path, {int numInstances = 1}) {
    return viewer
        .loadGlb(path, numInstances: numInstances)
        .then((entity) => entity.toJS)
        .toJS;
  }

  @JSExport()
  JSPromise<JSNumber> createInstance(FilamentEntity entity) {
    return viewer.createInstance(entity).then((instance) => instance.toJS).toJS;
  }

  @JSExport()
  JSPromise<JSNumber> getInstanceCount(FilamentEntity entity) =>
      viewer.getInstanceCount(entity).then((v) => v.toJS).toJS;

  @JSExport()
  JSPromise<JSArray<JSNumber>> getInstances(FilamentEntity entity) {
    return viewer
        .getInstances(entity)
        .then((instances) =>
            instances.map((instance) => instance.toJS).toList().toJS)
        .toJS;
  }

  @JSExport()
  JSPromise<JSNumber> loadGltf(String path, String relativeResourcePath,
      {bool force = false}) {
    return viewer
        .loadGltf(path, relativeResourcePath, force: force)
        .then((entity) => entity.toJS)
        .toJS;
  }

  @JSExport()
  JSPromise panStart(double x, double y) => viewer.panStart(x, y).toJS;

  @JSExport()
  JSPromise panUpdate(double x, double y) => viewer.panUpdate(x, y).toJS;

  @JSExport()
  JSPromise panEnd() => viewer.panEnd().toJS;

  @JSExport()
  JSPromise rotateStart(double x, double y) => viewer.rotateStart(x, y).toJS;

  @JSExport()
  JSPromise rotateUpdate(double x, double y) => viewer.rotateUpdate(x, y).toJS;

  @JSExport()
  JSPromise rotateEnd() => viewer.rotateEnd().toJS;

  @JSExport()
  JSPromise setMorphTargetWeights(
      FilamentEntity entity, JSArray<JSNumber> weights) {
    var dartWeights = weights.toDart.map((w) => w.toDartDouble).toList();
    return viewer.setMorphTargetWeights(entity, dartWeights).toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSString>> getMorphTargetNames(
      FilamentEntity entity, FilamentEntity childEntity) {
    var morphTargetNames = viewer
        .getMorphTargetNames(entity, childEntity)
        .then((v) => v.map((s) => s.toJS).toList().toJS);
    return morphTargetNames.toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSString>> getAnimationNames(FilamentEntity entity) =>
      viewer
          .getAnimationNames(entity)
          .then((v) => v.map((s) => s.toJS).toList().toJS)
          .toJS;

  @JSExport()
  JSPromise<JSNumber> getAnimationDuration(
          FilamentEntity entity, int animationIndex) =>
      viewer
          .getAnimationDuration(entity, animationIndex)
          .then((v) => v.toJS)
          .toJS;

  @JSExport()
  JSPromise setMorphAnimationData(
      FilamentEntity entity,
      JSArray<JSArray<JSNumber>> animation,
      JSArray<JSString> morphTargets,
      JSArray<JSString>? targetMeshNames,
      double frameLengthInMs) {
    try {
      var morphTargetsDart = morphTargets.toDart.map((m) => m.toDart).toList();
      var animationDataDart = animation.toDart
          .map((x) => x.toDart.map((y) => y.toDartDouble).toList())
          .toList();
      
      var morphAnimationData = MorphAnimationData(
          animationDataDart, morphTargetsDart,
          frameLengthInMs: frameLengthInMs);
      var targetMeshNamesDart =
          targetMeshNames?.toDart.map((x) => x.toDart).toList();
      if (animationDataDart.first.length != morphTargetsDart.length) {
        throw Exception(
            "Length mismatch between morph targets and animation data");
      }
      var result = viewer
          .setMorphAnimationData(
        entity,
        morphAnimationData,
        targetMeshNames: targetMeshNamesDart,
      )
          .onError((err, st) {
        print("ERROR SETTING MORPH ANIMATION DATA : $err\n$st");
        return null;
      });
      return result.toJS;
    } catch (err, st) {
      print(err);
      print(st);
      rethrow;
    }
  }

  @JSExport()
  JSPromise resetBones(FilamentEntity entity) => viewer.resetBones(entity).toJS;

  @JSExport()
  JSPromise addBoneAnimation(FilamentEntity entity, JSObject animation) {
    throw UnimplementedError();
  }
  // viewer
  //     .addBoneAnimation(
  //       entity,
  //       BoneAnimationData._fromJSObject(animation),
  //     )
  //     .toJS;

  @JSExport()
  JSPromise removeEntity(FilamentEntity entity) =>
      viewer.removeEntity(entity).toJS;

  @JSExport()
  JSPromise clearEntities() {
    return viewer.clearEntities().toJS;
  }

  @JSExport()
  JSPromise zoomBegin() => viewer.zoomBegin().toJS;

  @JSExport()
  JSPromise zoomUpdate(double x, double y, double z) =>
      viewer.zoomUpdate(x, y, z).toJS;

  @JSExport()
  JSPromise zoomEnd() => viewer.zoomEnd().toJS;

  @JSExport()
  JSPromise playAnimation(FilamentEntity entity, int index,
          {bool loop = false,
          bool reverse = false,
          bool replaceActive = true,
          double crossfade = 0.0}) =>
      viewer
          .playAnimation(
            entity,
            index,
            loop: loop,
            reverse: reverse,
            replaceActive: replaceActive,
            crossfade: crossfade,
          )
          .toJS;

  @JSExport()
  JSPromise playAnimationByName(FilamentEntity entity, String name,
          {bool loop = false,
          bool reverse = false,
          bool replaceActive = true,
          double crossfade = 0.0}) =>
      viewer
          .playAnimationByName(
            entity,
            name,
            loop: loop,
            reverse: reverse,
            replaceActive: replaceActive,
            crossfade: crossfade,
          )
          .toJS;

  @JSExport()
  JSPromise setAnimationFrame(
          FilamentEntity entity, int index, int animationFrame) =>
      viewer
          .setAnimationFrame(
            entity,
            index,
            animationFrame,
          )
          .toJS;

  @JSExport()
  JSPromise stopAnimation(FilamentEntity entity, int animationIndex) =>
      viewer.stopAnimation(entity, animationIndex).toJS;

  @JSExport()
  JSPromise stopAnimationByName(FilamentEntity entity, String name) =>
      viewer.stopAnimationByName(entity, name).toJS;

  @JSExport()
  JSPromise setCamera(FilamentEntity entity, String? name) =>
      viewer.setCamera(entity, name).toJS;

  @JSExport()
  JSPromise setMainCamera() => viewer.setMainCamera().toJS;

  @JSExport()
  JSPromise<JSNumber> getMainCamera() {
    return viewer.getMainCamera().then((camera) => camera.toJS).toJS;
  }

  @JSExport()
  JSPromise setCameraFov(double degrees, double width, double height) =>
      viewer.setCameraFov(degrees, width, height).toJS;

  @JSExport()
  JSPromise setToneMapping(int mapper) =>
      viewer.setToneMapping(ToneMapper.values[mapper]).toJS;

  @JSExport()
  JSPromise setBloom(double bloom) => viewer.setBloom(bloom).toJS;

  @JSExport()
  JSPromise setCameraFocalLength(double focalLength) =>
      viewer.setCameraFocalLength(focalLength).toJS;

  @JSExport()
  JSPromise setCameraCulling(double near, double far) =>
      viewer.setCameraCulling(near, far).toJS;

  @JSExport()
  JSPromise<JSNumber> getCameraCullingNear() =>
      viewer.getCameraCullingNear().then((v) => v.toJS).toJS;

  @JSExport()
  JSPromise<JSNumber> getCameraCullingFar() =>
      viewer.getCameraCullingFar().then((v) => v.toJS).toJS;

  @JSExport()
  JSPromise setCameraFocusDistance(double focusDistance) =>
      viewer.setCameraFocusDistance(focusDistance).toJS;

  @JSExport()
  JSPromise<JSArray<JSNumber>> getCameraPosition() {
    throw UnimplementedError();
    // return viewer.getCameraPosition().then((position) => position.toJS).toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSNumber>> getCameraModelMatrix() {
    throw UnimplementedError();
    // return viewer.getCameraModelMatrix().then((matrix) => matrix.toJSArray<JSNumber>()).toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSNumber>> getCameraViewMatrix() {
    throw UnimplementedError();
    // return viewer.getCameraViewMatrix().then((matrix) => matrix.toJSArray<JSNumber>()).toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSNumber>> getCameraProjectionMatrix() {
    throw UnimplementedError();
    // return viewer.getCameraProjectionMatrix().then((matrix) => matrix.toJSArray<JSNumber>()).toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSNumber>> getCameraCullingProjectionMatrix() {
    throw UnimplementedError();
    // return viewer.getCameraCullingProjectionMatrix().then((matrix) => matrix.toJSArray<JSNumber>()).toJS;
  }

  @JSExport()
  JSPromise<JSNumber> getCameraFrustum() {
    throw UnimplementedError();
    // return viewer.getCameraFrustum().then((frustum) => frustum.toJS).toJS;
  }

  @JSExport()
  JSPromise setCameraPosition(double x, double y, double z) =>
      viewer.setCameraPosition(x, y, z).toJS;
  @JSExport()
  JSPromise<JSArray<JSNumber>> getCameraRotation() {
    return viewer
        .getCameraRotation()
        .then((rotation) => rotation.storage.map((v) => v.toJS).toList().toJS)
        .toJS;
  }

  @JSExport()
  JSPromise moveCameraToAsset(FilamentEntity entity) =>
      throw UnimplementedError();
// viewer.moveCameraToAsset(entity)).toJS;
  @JSExport()
  JSPromise setViewFrustumCulling(JSBoolean enabled) =>
      throw UnimplementedError();
// viewer.setViewFrustumCulling(enabled).toJS;
  @JSExport()
  JSPromise setCameraExposure(
          double aperture, double shutterSpeed, double sensitivity) =>
      viewer.setCameraExposure(aperture, shutterSpeed, sensitivity).toJS;
  @JSExport()
  JSPromise setCameraRotation(JSArray<JSNumber> quaternion) =>
      throw UnimplementedError();
// viewer.setCameraRotation(quaternion.toDartQuaternion()).toJS;
  @JSExport()
  JSPromise setCameraModelMatrix(JSArray<JSNumber> matrix) {
    throw UnimplementedError();
    // viewer.setCameraModelMatrix(matrix).toJS;
  }

  @JSExport()
  JSPromise setMaterialColor(FilamentEntity entity, String meshName,
          int materialIndex, double r, double g, double b, double a) =>
      throw UnimplementedError();
// viewer.setMaterialColor(
// entity),
// meshName,
// materialIndex,
// r,
// g,
// b,
// a,
// ).toJS;
  @JSExport()
  JSPromise transformToUnitCube(FilamentEntity entity) =>
      viewer.transformToUnitCube(entity).toJS;
  @JSExport()
  JSPromise setPosition(FilamentEntity entity, double x, double y, double z) =>
      viewer.setPosition(entity, x, y, z).toJS;
  @JSExport()
  JSPromise setScale(FilamentEntity entity, double scale) =>
      viewer.setScale(entity, scale).toJS;
  @JSExport()
  JSPromise setRotation(
          FilamentEntity entity, double rads, double x, double y, double z) =>
      viewer.setRotation(entity, rads, x, y, z).toJS;
  @JSExport()
  JSPromise queuePositionUpdate(
          FilamentEntity entity, double x, double y, double z, bool relative) =>
      viewer
          .queuePositionUpdate(
            entity,
            x,
            y,
            z,
            relative: relative,
          )
          .toJS;
  @JSExport()
  JSPromise queueRotationUpdate(FilamentEntity entity, double rads, double x,
          double y, double z, bool relative) =>
      viewer
          .queueRotationUpdate(
            entity,
            rads,
            x,
            y,
            z,
            relative: relative,
          )
          .toJS;
  @JSExport()
  JSPromise queueRotationUpdateQuat(
          FilamentEntity entity, JSArray<JSNumber> quat, JSBoolean relative) =>
      throw UnimplementedError();
// viewer.queueRotationUpdateQuat(
// entity,
// quat.toDartQuaternion(),
// relative: relative,
// ).toJS;

  @JSExport()
  JSPromise setPostProcessing(bool enabled) =>
      viewer.setPostProcessing(enabled).toJS;
  @JSExport()
  JSPromise setAntiAliasing(bool msaa, bool fxaa, bool taa) =>
      viewer.setAntiAliasing(msaa, fxaa, taa).toJS;
  @JSExport()
  JSPromise setRotationQuat(
          FilamentEntity entity, JSArray<JSNumber> rotation) =>
      throw UnimplementedError();
// viewer.setRotationQuat(
// entity,
// rotation.toDartQuaternion(),
// ).toJS;
  @JSExport()
  JSPromise reveal(FilamentEntity entity, String? meshName) =>
      viewer.reveal(entity, meshName).toJS;
  @JSExport()
  JSPromise hide(FilamentEntity entity, String? meshName) =>
      viewer.hide(entity, meshName).toJS;
  @JSExport()
  void pick(int x, int y) => viewer.pick(x, y);
  @JSExport()
  String? getNameForEntity(FilamentEntity entity) =>
      viewer.getNameForEntity(entity);
  @JSExport()
  JSPromise setCameraManipulatorOptions({
    int mode = 0,
    double orbitSpeedX = 0.01,
    double orbitSpeedY = 0.01,
    double zoomSpeed = 0.01,
  }) =>
      viewer
          .setCameraManipulatorOptions(
            mode: ManipulatorMode.values[mode],
            orbitSpeedX: orbitSpeedX,
            orbitSpeedY: orbitSpeedY,
            zoomSpeed: zoomSpeed,
          )
          .toJS;
  @JSExport()
  JSPromise<JSArray<JSNumber>> getChildEntities(
      FilamentEntity parent, bool renderableOnly) {
    return viewer
        .getChildEntities(
          parent,
          renderableOnly,
        )
        .then((entities) => entities.map((entity) => entity.toJS).toList().toJS)
        .onError((e, st) async {
      print("Error : $e\n$st");
      return <JSNumber>[].toJS;
    }).toJS;
  }

  @JSExport()
  JSPromise<JSNumber> getChildEntity(FilamentEntity parent, String childName) {
    return viewer
        .getChildEntity(
          parent,
          childName,
        )
        .then((entity) => entity.toJS)
        .onError((e, st) async {
      print("Error getChildEntity : $e\n$st");
      return 0.toJS;
    }).toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSString>> getChildEntityNames(
          FilamentEntity entity, bool renderableOnly) =>
      viewer
          .getChildEntityNames(
            entity,
            renderableOnly: renderableOnly,
          )
          .then((v) => v.map((s) => s.toJS).toList().toJS)
          .toJS;
  @JSExport()
  JSPromise setRecording(bool recording) => viewer.setRecording(recording).toJS;
  @JSExport()
  JSPromise setRecordingOutputDirectory(String outputDirectory) =>
      viewer.setRecordingOutputDirectory(outputDirectory).toJS;
  @JSExport()
  JSPromise addAnimationComponent(FilamentEntity entity) =>
      viewer.addAnimationComponent(entity).toJS;

  @JSExport()
  JSPromise addCollisionComponent(FilamentEntity entity,
      {JSFunction? callback, bool affectsTransform = false}) {
    throw UnimplementedError();
// final Function? dartCallback = callback != null
// ? allowInterop((int entityId1, int entityId2) => callback.apply([entityId1, entityId2]))
// : null;
// return viewer.addCollisionComponent(
// entity),
// callback: dartCallback,
// affectsTransform: affectsTransform,
// ).toJs
  }
}
