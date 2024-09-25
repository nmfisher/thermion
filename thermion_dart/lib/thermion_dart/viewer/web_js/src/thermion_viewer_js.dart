import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart/entities/abstract_gizmo.dart';
import 'package:thermion_dart/thermion_dart/scene.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_dart/thermion_dart/viewer/events.dart';
import 'package:thermion_dart/thermion_dart/viewer/shared_types/camera.dart';

import 'package:vector_math/vector_math_64.dart';
import 'thermion_viewer_js_shim.dart';

///
/// An [ThermionViewer] implementation that forwards calls to
/// a corresponding Javascript shim implementation (see [ThermionViewerJSShim]).
///
class ThermionViewerJS implements ThermionViewer {
  final _logger = Logger("ThermionViewerJS");
  late final ThermionViewerJSShim _shim;

  ThermionViewerJS.fromGlobalProperty(String globalPropertyName) {
    this._shim = globalContext.getProperty(globalPropertyName.toJS)
        as ThermionViewerJSShim;
  }

  ThermionViewerJS(this._shim);

  @override
  Future<bool> get initialized async {
    var inited = _shim.initialized;
    final JSBoolean result = await inited.toDart;
    return result.toDart;
  }

  @override
  Stream<FilamentPickResult> get pickResult {
    throw UnimplementedError();
  }

  @override
  bool get rendering => _shim.rendering;

  @override
  Future<void> setRendering(bool render) async {
    await _shim.setRendering(render).toDart;
  }

  @override
  Future<void> render() async {
    await _shim.render().toDart;
  }

  @override
  Future<void> setFrameRate(int framerate) async {
    await _shim.setFrameRate(framerate).toDart;
  }

  @override
  Future<void> dispose() async {
    await _shim.dispose().toDart;
    for (final callback in _onDispose) {
      callback.call();
    }
  }

  @override
  Future<void> setBackgroundImage(String path,
      {bool fillHeight = false}) async {
    await _shim.setBackgroundImage(path, fillHeight).toDart;
  }

  @override
  Future<void> setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    await _shim.setBackgroundImagePosition(x, y, clamp).toDart;
  }

  @override
  Future<void> clearBackgroundImage() async {
    await _shim.clearBackgroundImage().toDart;
  }

  @override
  Future<void> setBackgroundColor(
      double r, double g, double b, double alpha) async {
    await _shim.setBackgroundColor(r, g, b, alpha).toDart;
  }

  @override
  Future<void> loadSkybox(String skyboxPath) async {
    await _shim.loadSkybox(skyboxPath).toDart;
  }

  @override
  Future<void> removeSkybox() async {
    await _shim.removeSkybox().toDart;
  }

  @override
  Future<void> loadIbl(String lightingPath, {double intensity = 30000}) async {
    await _shim.loadIbl(lightingPath, intensity).toDart;
  }

  @override
  Future<void> rotateIbl(Matrix3 rotation) async {
    await _shim
        .rotateIbl(rotation.storage.map((v) => v.toJS).toList().toJS)
        .toDart;
  }

  @override
  Future<void> removeIbl() async {
    await _shim.removeIbl().toDart;
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
      bool castShadows = true}) async {
    return (await _shim
            .addLight(
                type.index,
                colour,
                intensity,
                posX,
                posY,
                posZ,
                dirX,
                dirY,
                dirZ,
                falloffRadius,
                spotLightConeInner,
                spotLightConeOuter,
                sunAngularRadius,
                sunHaloSize,
                sunHaloFallof,
                castShadows)
            .toDart)
        .toDartInt;
  }

  @override
  Future<void> removeLight(ThermionEntity light) async {
    await _shim.removeLight(light).toDart;
  }

  @override
  Future<void> clearLights() async {
    await _shim.clearLights().toDart;
  }

  @override
  Future<ThermionEntity> loadGlb(String path, {int numInstances = 1, bool keepData=false}) async {
    var entity = (await _shim.loadGlb(path, numInstances).toDart).toDartInt;
    return entity;
  }

  @override
  Future<ThermionEntity> createInstance(ThermionEntity entity) async {
    return (await _shim.createInstance(entity).toDart).toDartInt;
  }

  @override
  Future<int> getInstanceCount(ThermionEntity entity) async {
    return (await _shim.getInstanceCount(entity).toDart).toDartInt;
  }

  @override
  Future<List<ThermionEntity>> getInstances(ThermionEntity entity) async {
    throw UnimplementedError();
    // final List<JSObject> jsInstances =
    //     await _shim.getInstances(entity).toDart;
    // return jsInstances
    //     .map((js) => ThermionEntity._fromJSObject(js))
    //     .toList()
    //     .toDart;
  }

  @override
  Future<ThermionEntity> loadGltf(String path, String relativeResourcePath,
      {bool keepData = false}) async {
    throw UnimplementedError();
    // final ThermionEntity jsEntity = await _shim
    //     .loadGltf(path, relativeResourcePath, force: force)
    //     .toDart;
    // return ThermionEntity._fromJSObject(jsEntity).toDart;
  }

  @override
  Future<void> panStart(double x, double y) async {
    await _shim.panStart(x, y).toDart;
  }

  @override
  Future<void> panUpdate(double x, double y) async {
    await _shim.panUpdate(x, y).toDart;
  }

  @override
  Future<void> panEnd() async {
    await _shim.panEnd().toDart;
  }

  @override
  Future<void> rotateStart(double x, double y) async {
    await _shim.rotateStart(x, y).toDart;
  }

  @override
  Future<void> rotateUpdate(double x, double y) async {
    await _shim.rotateUpdate(x, y).toDart;
  }

  @override
  Future<void> rotateEnd() async {
    await _shim.rotateEnd().toDart;
  }

  @override
  Future<void> setMorphTargetWeights(
      ThermionEntity entity, List<double> weights) async {
    var jsWeights = weights.map((x) => x.toJS).cast<JSNumber>().toList().toJS;
    var promise = _shim.setMorphTargetWeights(entity, jsWeights);
    await promise.toDart;
  }

  @override
  Future<List<String>> getMorphTargetNames(
      ThermionEntity entity, ThermionEntity childEntity) async {
    var result = await _shim.getMorphTargetNames(entity, childEntity).toDart;
    return result.toDart.map((r) => r.toDart).toList();
  }

  @override
  Future<List<String>> getAnimationNames(ThermionEntity entity) async {
    var names = (await (_shim.getAnimationNames(entity).toDart))
        .toDart
        .map((x) => x.toDart)
        .toList();
    return names;
  }

  @override
  Future<double> getAnimationDuration(
      ThermionEntity entity, int animationIndex) async {
    return (await _shim.getAnimationDuration(entity, animationIndex).toDart)
        .toDartDouble;
  }

  @override
  Future<void> clearMorphAnimationData(ThermionEntity entity) async {
    _shim.clearMorphAnimationData(entity);
  }

  @override
  Future<void> setMorphAnimationData(
      ThermionEntity entity, MorphAnimationData animation,
      {List<String>? targetMeshNames}) async {
    try {
      var animationDataJs = animation.data
          .map((x) => x.map((y) => y.toJS).toList().toJS)
          .toList()
          .toJS;
      var morphTargetsJs = animation.morphTargets
          .map((x) => x.toJS)
          .cast<JSString>()
          .toList()
          .toJS;
      var targetMeshNamesJS =
          targetMeshNames?.map((x) => x.toJS).cast<JSString>().toList().toJS;
      await _shim
          .setMorphAnimationData(entity, animationDataJs, morphTargetsJs,
              targetMeshNamesJS, animation.frameLengthInMs)
          .toDart;
    } catch (err, st) {
      _logger.severe(err);
      _logger.severe(st);
      rethrow;
    }
  }

  @override
  Future<void> resetBones(ThermionEntity entity) async {
    await _shim.resetBones(entity).toDart;
  }

  @override
  Future<void> addBoneAnimation(
      ThermionEntity entity, BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeInInSecs = 0.0,
      double fadeOutInSecs = 0.0,
      double maxDelta = 1.0}) async {
    var boneNames = animation.bones.map((n) => n.toJS).toList().toJS;
    var frameData = animation.frameData
        .map((frame) => frame
            .map((q) => [
                  q.translation[0].toJS,
                  q.translation[1].toJS,
                  q.translation[2].toJS,
                  q.rotation.x.toJS,
                  q.rotation.y.toJS,
                  q.rotation.z.toJS,
                  q.rotation.w.toJS,
                ].toJS)
            .toList()
            .toJS)
        .toList()
        .toJS;

    await _shim
        .addBoneAnimation(
            entity,
            boneNames,
            frameData,
            animation.frameLengthInMs.toJS,
            animation.space.index.toJS,
            skinIndex.toJS,
            fadeInInSecs.toJS,
            fadeOutInSecs.toJS,
            maxDelta.toJS)
        .toDart;
  }

  @override
  Future<void> removeEntity(ThermionEntity entity) async {
    await _shim.removeEntity(entity).toDart;
  }

  @override
  Future<void> clearEntities() async {
    await _shim.clearEntities().toDart;
  }

  @override
  Future<void> zoomBegin() async {
    await _shim.zoomBegin().toDart;
  }

  @override
  Future<void> zoomUpdate(double x, double y, double z) async {
    await _shim.zoomUpdate(x, y, z).toDart;
  }

  @override
  Future<void> zoomEnd() async {
    await _shim.zoomEnd().toDart;
  }

  @override
  Future<void> playAnimation(ThermionEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0}) async {
    await _shim
        .playAnimation(
            entity, index, loop, reverse, replaceActive, crossfade, startOffset)
        .toDart;
  }

  @override
  Future<void> playAnimationByName(ThermionEntity entity, String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    await _shim
        .playAnimationByName(
            entity, name, loop, reverse, replaceActive, crossfade)
        .toDart;
  }

  @override
  Future<void> setAnimationFrame(
      ThermionEntity entity, int index, int animationFrame) async {
    await _shim.setAnimationFrame(entity, index, animationFrame).toDart;
  }

  @override
  Future<void> stopAnimation(ThermionEntity entity, int animationIndex) async {
    await _shim.stopAnimation(entity, animationIndex).toDart;
  }

  @override
  Future<void> stopAnimationByName(ThermionEntity entity, String name) async {
    await _shim.stopAnimationByName(entity, name).toDart;
  }

  @override
  Future<void> setCamera(ThermionEntity entity, String? name) async {
    await _shim.setCamera(entity, name).toDart;
  }

  @override
  Future<void> setMainCamera() async {
    await _shim.setMainCamera().toDart;
  }

  @override
  Future<Camera> getMainCamera() async {
    throw UnimplementedError();
    // final ThermionEntity jsEntity = await _shim.getMainCamera().toDart;
    // return ThermionEntity._fromJSObject(jsEntity).toDart;
  }

  @override
  Future<void> setCameraFov(double degrees, {bool horizontal = true}) async {
    await _shim.setCameraFov(degrees, horizontal).toDart;
  }

  @override
  Future<void> setToneMapping(ToneMapper mapper) async {
    await _shim.setToneMapping(mapper.index).toDart;
  }

  @override
  Future<void> setBloom(double bloom) async {
    await _shim.setBloom(bloom).toDart;
  }

  @override
  Future<void> setCameraFocalLength(double focalLength) async {
    await _shim.setCameraFocalLength(focalLength).toDart;
  }

  @override
  Future<void> setCameraCulling(double near, double far) async {
    await _shim.setCameraCulling(near, far).toDart;
  }

  @override
  Future<double> getCameraCullingNear() async {
    return (await _shim.getCameraCullingNear().toDart).toDartDouble;
  }

  @override
  Future<double> getCameraCullingFar() async {
    return (await _shim.getCameraCullingFar().toDart).toDartDouble;
  }

  @override
  Future<void> setCameraFocusDistance(double focusDistance) async {
    await _shim.setCameraFocusDistance(focusDistance).toDart;
  }

  @override
  Future<Vector3> getCameraPosition() async {
    final jsPosition = (await _shim.getCameraPosition().toDart).toDart;
    return Vector3(jsPosition[0].toDartDouble, jsPosition[1].toDartDouble,
        jsPosition[2].toDartDouble);
  }

  @override
  Future<Matrix4> getCameraModelMatrix() async {
    throw UnimplementedError();
    // final JSMatrix4 jsMatrix = await _shim.getCameraModelMatrix().toDart;
    // return Matrix4.fromList(jsMatrix.storage).toDart;
  }

  @override
  Future<Matrix4> getCameraViewMatrix() async {
    throw UnimplementedError();
    // final JSMatrix4 jsMatrix = await _shim.getCameraViewMatrix().toDart;
    // return Matrix4.fromList(jsMatrix.storage).toDart;
  }

  @override
  Future<Matrix4> getCameraProjectionMatrix() async {
    throw UnimplementedError();
    // final JSMatrix4 jsMatrix =
    //     await _shim.getCameraProjectionMatrix().toDart;
    // return Matrix4.fromList(jsMatrix.storage).toDart;
  }

  @override
  Future<Matrix4> getCameraCullingProjectionMatrix() async {
    throw UnimplementedError();
    // final JSMatrix4 jsMatrix =
    //     await _shim.getCameraCullingProjectionMatrix().toDart;
    // return Matrix4.fromList(jsMatrix.storage).toDart;
  }

  @override
  Future<Frustum> getCameraFrustum() async {
    throw UnimplementedError();
    // final JSObject jsFrustum = await _shim.getCameraFrustum().toDart;
    // // Assuming Frustum is a class that can be constructed from the JSObject
    // return Frustum._fromJSObject(jsFrustum).toDart;
  }

  @override
  Future<void> setCameraPosition(double x, double y, double z) async {
    await _shim.setCameraPosition(x, y, z).toDart;
  }

  @override
  Future<Matrix3> getCameraRotation() async {
    throw UnimplementedError();
    // final JSMatrix3 jsRotation = await _shim.getCameraRotation().toDart;
    // return Matrix3.fromList(jsRotation.storage).toDart;
  }

  @override
  Future<void> moveCameraToAsset(ThermionEntity entity) async {
    await _shim.moveCameraToAsset(entity).toDart;
  }

  @override
  Future<void> setViewFrustumCulling(bool enabled) async {
    throw UnimplementedError();
    // await _shim.setViewFrustumCulling(enabled.toJSBoolean()).toDart;
  }

  @override
  Future<void> setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    await _shim.setCameraExposure(aperture, shutterSpeed, sensitivity).toDart;
  }

  @override
  Future<void> setCameraRotation(Quaternion quaternion) async {
    final values = <JSNumber>[
      quaternion.x.toJS,
      quaternion.y.toJS,
      quaternion.z.toJS,
      quaternion.w.toJS
    ];
    await _shim.setCameraRotation(values.toJS).toDart;
  }

  @override
  Future<void> setCameraModelMatrix(List<double> matrix) async {
    throw UnimplementedError();

    // await _shim.setCameraModelMatrix(matrix.toJSBox).toDart;
  }

  @override
  Future<void> setMaterialColor(ThermionEntity entity, String meshName,
      int materialIndex, double r, double g, double b, double a) async {
    await _shim
        .setMaterialColor(entity, meshName, materialIndex, r, g, b, a)
        .toDart;
  }

  @override
  Future<void> transformToUnitCube(ThermionEntity entity) async {
    await _shim.transformToUnitCube(entity).toDart;
  }

  @override
  Future<void> setPosition(
      ThermionEntity entity, double x, double y, double z) async {
    await _shim.setPosition(entity, x, y, z).toDart;
  }

  @override
  Future<void> setScale(ThermionEntity entity, double scale) async {
    await _shim.setScale(entity, scale).toDart;
  }

  @override
  Future<void> setRotation(
      ThermionEntity entity, double rads, double x, double y, double z) async {
    await _shim.setRotation(entity, rads, x, y, z).toDart;
  }

  @override
  Future<void> queuePositionUpdate(
      ThermionEntity entity, double x, double y, double z,
      {bool relative = false}) async {
    await _shim.queuePositionUpdate(entity, x, y, z, relative).toDart;
  }

  @override
  Future<void> queueRotationUpdate(
      ThermionEntity entity, double rads, double x, double y, double z,
      {bool relative = false}) async {
    await _shim.queueRotationUpdate(entity, rads, x, y, z, relative).toDart;
  }

  @override
  Future<void> queueRotationUpdateQuat(ThermionEntity entity, Quaternion quat,
      {bool relative = false}) async {
    throw UnimplementedError();

    // final JSQuaternion jsQuat = quat.toJSQuaternion().toDart;
    // await _shim
    //     .queueRotationUpdateQuat(entity, jsQuat, relative: relative)
    //     .toDart;
  }

  @override
  Future<void> setPostProcessing(bool enabled) async {
    await _shim.setPostProcessing(enabled).toDart;
  }

  @override
  Future<void> setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
    await _shim.setAntiAliasing(msaa, fxaa, taa).toDart;
  }

  @override
  Future<void> setRotationQuat(
      ThermionEntity entity, Quaternion rotation) async {
    throw UnimplementedError();
    // final JSQuaternion jsRotation = rotation.toJSQuaternion().toDart;
    // await _shim.setRotationQuat(entity, jsRotation).toDart;
  }

  @override
  Future<void> reveal(ThermionEntity entity, String? meshName) async {
    throw UnimplementedError();
    // await _shim.reveal(entity, meshName).toDart;
  }

  @override
  Future<void> hide(ThermionEntity entity, String? meshName) async {
    throw UnimplementedError();
    // await _shim.hide(entity, meshName).toDart;
  }

  @override
  void pick(int x, int y) {
    throw UnimplementedError();
    // _shim.pick(x, y).toDart;
  }

  @override
  String? getNameForEntity(ThermionEntity entity) {
    return _shim.getNameForEntity(entity);
  }

  @override
  Future<void> setCameraManipulatorOptions(
      {ManipulatorMode mode = ManipulatorMode.ORBIT,
      double orbitSpeedX = 0.01,
      double orbitSpeedY = 0.01,
      double zoomSpeed = 0.01}) async {
    await _shim
        .setCameraManipulatorOptions(
            mode.index, orbitSpeedX, orbitSpeedY, zoomSpeed)
        .toDart;
  }

  @override
  Future<List<ThermionEntity>> getChildEntities(
      ThermionEntity parent, bool renderableOnly) async {
    final children =
        await _shim.getChildEntities(parent, renderableOnly).toDart;
    return children.toDart
        .map((js) => js.toDartInt)
        .cast<ThermionEntity>()
        .toList();
  }

  @override
  Future<ThermionEntity> getChildEntity(
      ThermionEntity parent, String childName) async {
    return (await _shim.getChildEntity(parent, childName).toDart).toDartInt;
  }

  @override
  Future<List<String>> getChildEntityNames(ThermionEntity entity,
      {bool renderableOnly = true}) async {
    var names = await _shim.getChildEntityNames(entity, renderableOnly).toDart;
    return names.toDart.map((x) => x.toDart).toList();
  }

  @override
  Future<void> setRecording(bool recording) async {
    throw UnimplementedError();
    // await _shim.setRecording(recording.toJSBoolean()).toDart;
  }

  @override
  Future<void> setRecordingOutputDirectory(String outputDirectory) async {
    await _shim.setRecordingOutputDirectory(outputDirectory).toDart;
  }

  @override
  Future<void> addAnimationComponent(ThermionEntity entity) async {
    await _shim.addAnimationComponent(entity).toDart;
  }

  @override
  Future<void> addCollisionComponent(ThermionEntity entity,
      {void Function(int entityId1, int entityId2)? callback,
      bool affectsTransform = false}) async {
    throw UnimplementedError();
    // final JSFunction? jsCallback = callback != null
    //     ? allowInterop(
    //         (int entityId1, int entityId2) => callback(entityId1, entityId2))
    //     : null;
    // await _shim
    //     .addCollisionComponent(entity,
    //         callback: jsCallback,
    //         affectsTransform: affectsTransform.toJSBoolean())
    //     .toDart;
  }

  @override
  Future<void> removeCollisionComponent(ThermionEntity entity) async {
    await _shim.removeCollisionComponent(entity).toDart;
  }

  @override
  Future<ThermionEntity> createGeometry(
      Geometry geometry,
      {
        bool keepData=false, MaterialInstance? materialInstance,
      PrimitiveType primitiveType = PrimitiveType.TRIANGLES}) async {
    throw UnimplementedError();
    // final ThermionEntity jsEntity = await _shim
    //     .createGeometry(vertices, indices,
    //         materialPath: materialPath, primitiveType: primitiveType.index)
    //     .toDart;
    // return ThermionEntity._fromJSObject(jsEntity).toDart;
  }

  @override
  Future<void> setParent(ThermionEntity child, ThermionEntity parent,
      {bool preserveScaling = false}) async {
    await _shim.setParent(child, parent, preserveScaling).toDart;
  }

  @override
  Future<void> testCollisions(ThermionEntity entity) async {
    await _shim.testCollisions(entity).toDart;
  }

  @override
  Future<void> setPriority(ThermionEntity entityId, int priority) async {
    await _shim.setPriority(entityId, priority).toDart;
  }

  AbstractGizmo? get gizmo => null;

  @override
  Future<List<String>> getBoneNames(ThermionEntity entity,
      {int skinIndex = 0}) async {
    var result = await _shim.getBoneNames(entity, skinIndex).toDart;
    return result.toDart.map((n) => n.toDart).toList();
  }

  @override
  Future<ThermionEntity> getBone(ThermionEntity entity, int boneIndex,
      {int skinIndex = 0}) async {
    var result = await _shim.getBone(entity, boneIndex, skinIndex).toDart;
    return result.toDartInt;
  }

  @override
  Future<Matrix4> getInverseBindMatrix(ThermionEntity parent, int boneIndex,
      {int skinIndex = 0}) {
    // TODO: implement getInverseBindMatrix
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getLocalTransform(ThermionEntity entity) async {
    var result = await _shim.getLocalTransform(entity).toDart;
    return Matrix4.fromList(result.toDart.map((v) => v.toDartDouble).toList());
  }

  @override
  Future<ThermionEntity?> getParent(ThermionEntity child) async {
    var result = await _shim.getParent(child).toDart;
    return result.toDartInt;
  }

  @override
  Future<Matrix4> getWorldTransform(ThermionEntity entity) async {
    var result = await _shim.getLocalTransform(entity).toDart;
    return Matrix4.fromList(result.toDart.map((v) => v.toDartDouble).toList());
  }

  @override
  Future removeAnimationComponent(ThermionEntity entity) {
    return _shim.removeAnimationComponent(entity).toDart;
  }

  @override
  Future setBoneTransform(
      ThermionEntity entity, int boneIndex, Matrix4 transform,
      {int skinIndex = 0}) {
    return _shim
        .setBoneTransform(entity, boneIndex,
            transform.storage.map((v) => v.toJS).toList().toJS, skinIndex)
        .toDart;
  }

  @override
  Future setTransform(ThermionEntity entity, Matrix4 transform) {
    return _shim
        .setTransform(
            entity, transform.storage.map((v) => v.toJS).toList().toJS)
        .toDart;
  }

  @override
  Future updateBoneMatrices(ThermionEntity entity) {
    return _shim.updateBoneMatrices(entity).toDart;
  }

  final _onDispose = <Future Function()>[];

  ///
  ///
  ///
  void onDispose(Future Function() callback) {
    _onDispose.add(callback);
  }

  @override
  Future setShadowType(ShadowType shadowType) {
    return _shim.setShadowType(shadowType.index).toDart;
  }

  @override
  Future setShadowsEnabled(bool enabled) {
    return _shim.setShadowsEnabled(enabled).toDart;
  }

  @override
  Future setSoftShadowOptions(double penumbraScale, double penumbraRatioScale) {
    return _shim.setSoftShadowOptions(penumbraScale, penumbraRatioScale).toDart;
  }

  @override
  Future<Uint8List> capture() async {
    final captured = await _shim.capture().toDart;
    return captured.toDart;
  }

  @override
  late (double, double) viewportDimensions;

  @override
  Future<Aabb2> getBoundingBox(ThermionEntity entity) {
    // return _shim.getBoundingBox(entity);
    throw UnimplementedError();
  }

  @override
  Future<double> getCameraFov(bool horizontal) {
    // TODO: implement getCameraFov
    throw UnimplementedError();
  }

  @override
  Future queueRelativePositionUpdateWorldAxis(ThermionEntity entity,
      double viewportX, double viewportY, double x, double y, double z) {
    // TODO: implement queueRelativePositionUpdateWorldAxis
    throw UnimplementedError();
  }
  
  @override
  double pixelRatio = 0.0;
  
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
  Future setLayerEnabled(int layer, bool enabled) {
    // TODO: implement setLayerEnabled
    throw UnimplementedError();
  }
  
  @override
  // TODO: implement entitiesAdded
  Stream<ThermionEntity> get entitiesAdded => throw UnimplementedError();
  
  @override
  // TODO: implement entitiesRemoved
  Stream<ThermionEntity> get entitiesRemoved => throw UnimplementedError();
  
  @override
  Future<ThermionEntity?> getAncestor(ThermionEntity entity) {
    // TODO: implement getAncestor
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
  // TODO: implement lightsAdded
  Stream<ThermionEntity> get lightsAdded => throw UnimplementedError();
  
  @override
  // TODO: implement lightsRemoved
  Stream<ThermionEntity> get lightsRemoved => throw UnimplementedError();
  
  @override
  Future<ThermionEntity> loadGlbFromBuffer(Uint8List data, {int numInstances = 1, bool keepData = false, int layer=4, int priority =4 }) {
    // TODO: implement loadGlbFromBuffer
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
  Future setCameraModelMatrix4(Matrix4 matrix) {
    // TODO: implement setCameraModelMatrix4
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
  Future setStencilHighlight(ThermionEntity entity, {double r = 1.0, double g = 0.0, double b = 0.0}) {
    // TODO: implement setStencilHighlight
    throw UnimplementedError();
  }

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
  Future<ThermionEntity> getMainCameraEntity() {
    // TODO: implement getMainCameraEntity
    throw UnimplementedError();
  }

  @override
  Future<MaterialInstance?> getMaterialInstanceAt(ThermionEntity entity, int index) {
    // TODO: implement getMaterialInstanceAt
    throw UnimplementedError();
  }

  @override
  void requestFrame() {
    // TODO: implement requestFrame
  }

  @override
  // TODO: implement sceneUpdated
  Stream<SceneUpdateEvent> get sceneUpdated => throw UnimplementedError();

  @override
  Future setLayerVisibility(int layer, bool visible) {
    // TODO: implement setLayerVisibility
    throw UnimplementedError();
  }

  @override
  Future setMaterialPropertyInt(ThermionEntity entity, String propertyName, int materialIndex, int value) {
    // TODO: implement setMaterialPropertyInt
    throw UnimplementedError();
  }

  @override
  Future setVisibilityLayer(ThermionEntity entity, int layer) {
    // TODO: implement setVisibilityLayer
    throw UnimplementedError();
  }
  
  @override
  Future setCameraLensProjection({double near = kNear, double far = kFar, double? aspect, double focalLength = kFocalLength}) {
    // TODO: implement setCameraLensProjection
    throw UnimplementedError();
  }
}
