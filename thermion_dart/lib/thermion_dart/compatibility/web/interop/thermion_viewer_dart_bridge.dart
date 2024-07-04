@JS()
library thermion_flutter_js;

import 'dart:js_interop';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart/compatibility/web/interop/thermion_viewer_js_shim.dart';

import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'dart:js_interop_unsafe';

import 'package:vector_math/vector_math_64.dart';

///
/// A (Dart) class that wraps a (Dart) instance of [ThermionViewer],
/// but exported to JS by binding to a global property.
/// This is effectively an implementation of [ThermionViewerJSShim];
/// allowing users to interact with an instance of [ThermionViewer]
/// (presumably compiled to WASM) from any Javascript context (including
/// the browser console).
///
@JSExport()
class ThermionViewerJSDartBridge {
  final _logger = Logger("ThermionViewerJSDartBridge");
  final ThermionViewer viewer;

  ThermionViewerJSDartBridge(this.viewer);

  void bind({String globalPropertyName = "thermionViewer"}) {
    var wrapper = createJSInteropWrapper<ThermionViewerJSDartBridge>(this)
        as ThermionViewerJSShim;
    globalContext.setProperty(globalPropertyName.toJS, wrapper);
  }

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
  JSPromise loadIbl(String lightingPath, double intensity) {
    _logger.info("Loading IBL from $lightingPath with intensity $intensity");
    return viewer.loadIbl(lightingPath, intensity: intensity).toJS;
  }

  @JSExport()
  JSPromise rotateIbl(JSArray<JSNumber> rotation) {
    var matrix =
        Matrix3.fromList(rotation.toDart.map((v) => v.toDartDouble).toList());
    return viewer.rotateIbl(matrix).toJS;
  }

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
      double falloffRadius,
      double spotLightConeInner,
      double spotLightConeOuter,
      double sunAngularRadius,
      double sunHaloSize,
      double sunHaloFallof,
      bool castShadows) {
    return viewer
        .addLight(LightType.values[type], colour, intensity, posX, posY, posZ,
            dirX, dirY, dirZ,
            falloffRadius: falloffRadius,
            spotLightConeInner: spotLightConeInner,
            spotLightConeOuter: spotLightConeOuter,
            sunAngularRadius: sunAngularRadius,
            sunHaloSize: sunHaloSize,
            sunHaloFallof: sunHaloFallof,
            castShadows: castShadows)
        .then((entity) => entity.toJS)
        .toJS;
  }

  @JSExport()
  JSPromise removeLight(ThermionEntity light) => viewer.removeLight(light).toJS;

  @JSExport()
  JSPromise clearLights() => viewer.clearLights().toJS;

  @JSExport()
  JSPromise<JSNumber> loadGlb(String path, {int numInstances = 1}) {
    _logger.info("Loading GLB from path $path with numInstances $numInstances");
    return viewer
        .loadGlb(path, numInstances: numInstances)
        .then((entity) => entity.toJS)
        .catchError((err) {
      _logger.info("Error: $err");
    }).toJS;
  }

  @JSExport()
  JSPromise<JSNumber> createInstance(ThermionEntity entity) {
    return viewer.createInstance(entity).then((instance) => instance.toJS).toJS;
  }

  @JSExport()
  JSPromise<JSNumber> getInstanceCount(ThermionEntity entity) =>
      viewer.getInstanceCount(entity).then((v) => v.toJS).toJS;

  @JSExport()
  JSPromise<JSArray<JSNumber>> getInstances(ThermionEntity entity) {
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
      ThermionEntity entity, JSArray<JSNumber> weights) {
    var dartWeights = weights.toDart.map((w) => w.toDartDouble).toList();
    return viewer.setMorphTargetWeights(entity, dartWeights).toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSString>> getMorphTargetNames(
      ThermionEntity entity, ThermionEntity childEntity) {
    var morphTargetNames = viewer
        .getMorphTargetNames(entity, childEntity)
        .then((v) => v.map((s) => s.toJS).toList().toJS);
    return morphTargetNames.toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSString>> getBoneNames(
      ThermionEntity entity, int skinIndex) {
    return viewer
        .getBoneNames(entity, skinIndex: skinIndex)
        .then((v) => v.map((s) => s.toJS).toList().toJS)
        .toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSString>> getAnimationNames(ThermionEntity entity) =>
      viewer
          .getAnimationNames(entity)
          .then((v) => v.map((s) => s.toJS).toList().toJS)
          .toJS;

  @JSExport()
  JSPromise<JSNumber> getAnimationDuration(
          ThermionEntity entity, int animationIndex) =>
      viewer
          .getAnimationDuration(entity, animationIndex)
          .then((v) => v.toJS)
          .toJS;

  @JSExport()
  JSPromise setMorphAnimationData(
      ThermionEntity entity,
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
        _logger.severe("ERROR SETTING MORPH ANIMATION DATA : $err\n$st");
        return null;
      });
      return result.toJS;
    } catch (err, st) {
      _logger.severe(err);
      _logger.severe(st);
      rethrow;
    }
  }

  @JSExport()
  JSPromise resetBones(ThermionEntity entity) => viewer.resetBones(entity).toJS;

  @JSExport()
  JSPromise addBoneAnimation(
      ThermionEntity entity,
      JSArray<JSString> bones,
      JSArray<JSArray<JSArray<JSNumber>>> frameData,
      JSNumber frameLengthInMs,
      JSNumber spaceEnum,
      JSNumber skinIndex,
      JSNumber fadeInInSecs,
      JSNumber fadeOutInSecs,
      JSNumber maxDelta) {
    var frameDataDart = frameData.toDart
        .map((frame) => frame.toDart
            .map((v) {
              var values = v.toDart;
              var trans = v64.Vector3(values[0].toDartDouble,
                  values[1].toDartDouble, values[2].toDartDouble);
              var rot = v64.Quaternion(
                  values[3].toDartDouble,
                  values[4].toDartDouble,
                  values[5].toDartDouble,
                  values[6].toDartDouble);
              return (rotation: rot, translation: trans);
            })
            .cast<BoneAnimationFrame>()
            .toList())
        .toList();

    var data = BoneAnimationData(
        bones.toDart.map((n) => n.toDart).toList(), frameDataDart,
        frameLengthInMs: frameLengthInMs.toDartDouble,
        space: Space.values[spaceEnum.toDartInt]);

    return viewer
        .addBoneAnimation(entity, data,
            skinIndex: skinIndex.toDartInt,
            fadeInInSecs: fadeInInSecs.toDartDouble,
            fadeOutInSecs: fadeOutInSecs.toDartDouble)
        .toJS;
  }

  @JSExport()
  JSPromise removeEntity(ThermionEntity entity) =>
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
  JSPromise playAnimation(ThermionEntity entity, int index,
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
  JSPromise playAnimationByName(ThermionEntity entity, String name,
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
          ThermionEntity entity, int index, int animationFrame) =>
      viewer
          .setAnimationFrame(
            entity,
            index,
            animationFrame,
          )
          .toJS;

  @JSExport()
  JSPromise stopAnimation(ThermionEntity entity, int animationIndex) =>
      viewer.stopAnimation(entity, animationIndex).toJS;

  @JSExport()
  JSPromise stopAnimationByName(ThermionEntity entity, String name) =>
      viewer.stopAnimationByName(entity, name).toJS;

  @JSExport()
  JSPromise setCamera(ThermionEntity entity, String? name) =>
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
  JSPromise moveCameraToAsset(ThermionEntity entity) =>
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
  JSPromise setCameraRotation(JSArray<JSNumber> quaternion) {
    var dartVals = quaternion.toDart;
    return viewer
        .setCameraRotation(v64.Quaternion(
            dartVals[0].toDartDouble,
            dartVals[1].toDartDouble,
            dartVals[2].toDartDouble,
            dartVals[3].toDartDouble))
        .toJS;
  }

  @JSExport()
  JSPromise setCameraModelMatrix(JSArray<JSNumber> matrix) {
    throw UnimplementedError();
    // viewer.setCameraModelMatrix(matrix).toJS;
  }

  @JSExport()
  JSPromise setMaterialColor(ThermionEntity entity, String meshName,
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
  JSPromise transformToUnitCube(ThermionEntity entity) =>
      viewer.transformToUnitCube(entity).toJS;
  @JSExport()
  JSPromise setPosition(ThermionEntity entity, double x, double y, double z) =>
      viewer.setPosition(entity, x, y, z).toJS;
  @JSExport()
  JSPromise setScale(ThermionEntity entity, double scale) =>
      viewer.setScale(entity, scale).toJS;
  @JSExport()
  JSPromise setRotation(
          ThermionEntity entity, double rads, double x, double y, double z) =>
      viewer.setRotation(entity, rads, x, y, z).toJS;
  @JSExport()
  JSPromise queuePositionUpdate(
          ThermionEntity entity, double x, double y, double z, bool relative) =>
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
  JSPromise queueRotationUpdate(ThermionEntity entity, double rads, double x,
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
          ThermionEntity entity, JSArray<JSNumber> quat, JSBoolean relative) =>
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
          ThermionEntity entity, JSArray<JSNumber> rotation) =>
      throw UnimplementedError();

  @JSExport()
  JSPromise reveal(ThermionEntity entity, String? meshName) =>
      viewer.reveal(entity, meshName).toJS;

  @JSExport()
  JSPromise hide(ThermionEntity entity, String? meshName) =>
      viewer.hide(entity, meshName).toJS;

  @JSExport()
  void pick(int x, int y) => viewer.pick(x, y);

  @JSExport()
  String? getNameForEntity(ThermionEntity entity) =>
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
      ThermionEntity parent, bool renderableOnly) {
    return viewer
        .getChildEntities(
          parent,
          renderableOnly,
        )
        .then((entities) => entities.map((entity) => entity.toJS).toList().toJS)
        .onError((e, st) async {
      _logger.severe("Error : $e\n$st");
      return <JSNumber>[].toJS;
    }).toJS;
  }

  @JSExport()
  JSPromise<JSNumber> getChildEntity(ThermionEntity parent, String childName) {
    return viewer
        .getChildEntity(
          parent,
          childName,
        )
        .then((entity) => entity.toJS)
        .onError((e, st) async {
      _logger.severe("Error getChildEntity : $e\n$st");
      return 0.toJS;
    }).toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSString>> getChildEntityNames(
          ThermionEntity entity, bool renderableOnly) =>
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
  JSPromise addAnimationComponent(ThermionEntity entity) =>
      viewer.addAnimationComponent(entity).toJS;

  @JSExport()
  JSPromise removeAnimationComponent(ThermionEntity entity) =>
      viewer.removeAnimationComponent(entity).toJS;

  @JSExport()
  JSPromise getParent(ThermionEntity entity) =>
      viewer.removeAnimationComponent(entity).toJS;

  @JSExport()
  JSPromise getBone(ThermionEntity entity, int boneIndex, int skinIndex) =>
      viewer.getBone(entity, boneIndex, skinIndex: skinIndex).toJS;

  @JSExport()
  JSPromise<JSArray<JSNumber>> getLocalTransform(ThermionEntity entity) {
    return viewer
        .getLocalTransform(entity)
        .then((t) => t.storage.map((v) => v.toJS).toList().toJS)
        .toJS;
  }

  @JSExport()
  JSPromise<JSArray<JSNumber>> getWorldTransform(ThermionEntity entity) {
    return viewer
        .getWorldTransform(entity)
        .then((t) => t.storage.map((v) => v.toJS).toList().toJS)
        .toJS;
  }

  @JSExport()
  JSPromise setTransform(ThermionEntity entity, JSArray<JSNumber> transform) {
    return viewer
        .setTransform(
            entity,
            Matrix4.fromList(
                transform.toDart.map((v) => v.toDartDouble).toList()))
        .toJS;
  }

  @JSExport()
  JSPromise updateBoneMatrices(ThermionEntity entity) {
    return viewer.updateBoneMatrices(entity).toJS;
  }

  @JSExport()
  JSPromise setBoneTransform(ThermionEntity entity, int boneIndex,
      JSArray<JSNumber> transform, int skinIndex) {
    return viewer
        .setBoneTransform(
            entity,
            boneIndex,
            Matrix4.fromList(
                transform.toDart.map((v) => v.toDartDouble).toList()),
            skinIndex: skinIndex)
        .toJS;
  }

  @JSExport()
  JSPromise addCollisionComponent(ThermionEntity entity,
      {JSFunction? callback, bool affectsTransform = false}) {
    throw UnimplementedError();
  }

  @JSExport()
  JSPromise setShadowsEnabled(bool enabled) {
    return viewer.setShadowsEnabled(enabled).toJS;
  }

  @JSExport()
  JSPromise setShadowType(int shadowType) {
    return viewer.setShadowType(ShadowType.values[shadowType]).toJS;
  }

  @JSExport()
  JSPromise setSoftShadowOptions(
      double penumbraScale, double penumbraRatioScale) {
    return viewer.setSoftShadowOptions(penumbraScale, penumbraRatioScale).toJS;
  }
}
