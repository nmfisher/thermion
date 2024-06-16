import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';

import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';
import 'package:dart_filament/dart_filament/entities/filament_entity.dart';
import 'package:dart_filament/dart_filament/scene.dart';
import 'package:vector_math/vector_math_64.dart';
import 'dart_filament_js_extension_type.dart';

class JsInteropFilamentViewer implements AbstractFilamentViewer {
  late final DartFilamentJSShim _jsObject;

  JsInteropFilamentViewer(String globalPropertyName) {
    this._jsObject = globalContext.getProperty(globalPropertyName.toJS)
        as DartFilamentJSShim;
  }

  @override
  Future<bool> get initialized async {
    var inited = _jsObject.initialized;
    final JSBoolean result = await inited.toDart;
    return result.toDart;
  }

  @override
  Stream<FilamentPickResult> get pickResult {
    throw UnimplementedError();
  }

  @override
  bool get rendering => _jsObject.rendering;

  @override
  Future<void> setRendering(bool render) async {
    await _jsObject.setRendering(render).toDart;
  }

  @override
  Future<void> render() async {
    await _jsObject.render().toDart;
  }

  @override
  Future<void> setFrameRate(int framerate) async {
    await _jsObject.setFrameRate(framerate).toDart;
  }

  @override
  Future<void> dispose() async {
    await _jsObject.dispose().toDart;
  }

  @override
  Future<void> setBackgroundImage(String path,
      {bool fillHeight = false}) async {
    await _jsObject.setBackgroundImage(path, fillHeight).toDart;
  }

  @override
  Future<void> setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    await _jsObject.setBackgroundImagePosition(x, y, clamp).toDart;
  }

  @override
  Future<void> clearBackgroundImage() async {
    await _jsObject.clearBackgroundImage().toDart;
  }

  @override
  Future<void> setBackgroundColor(
      double r, double g, double b, double alpha) async {
    await _jsObject.setBackgroundColor(r, g, b, alpha).toDart;
  }

  @override
  Future<void> loadSkybox(String skyboxPath) async {
    await _jsObject.loadSkybox(skyboxPath).toDart;
  }

  @override
  Future<void> removeSkybox() async {
    await _jsObject.removeSkybox().toDart;
  }

  @override
  Future<void> loadIbl(String lightingPath, {double intensity = 30000}) async {
    await _jsObject.loadIbl(lightingPath, intensity).toDart;
  }

  @override
  Future<void> rotateIbl(Matrix3 rotation) async {
    await _jsObject
        .rotateIbl(rotation.storage.map((v) => v.toJS).toList().toJS)
        .toDart;
  }

  @override
  Future<void> removeIbl() async {
    await _jsObject.removeIbl().toDart;
  }

  @override
  Future<FilamentEntity> addLight(
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
    return (await _jsObject
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
  Future<void> removeLight(FilamentEntity light) async {
    await _jsObject.removeLight(light).toDart;
  }

  @override
  Future<void> clearLights() async {
    await _jsObject.clearLights().toDart;
  }

  @override
  Future<FilamentEntity> loadGlb(String path, {int numInstances = 1}) async {
    var entity = (await _jsObject.loadGlb(path, numInstances).toDart).toDartInt;
    scene.registerEntity(entity);
    return entity;
  }

  @override
  Future<FilamentEntity> createInstance(FilamentEntity entity) async {
    return (await _jsObject.createInstance(entity).toDart).toDartInt;
  }

  @override
  Future<int> getInstanceCount(FilamentEntity entity) async {
    return (await _jsObject.getInstanceCount(entity).toDart).toDartInt;
  }

  @override
  Future<List<FilamentEntity>> getInstances(FilamentEntity entity) async {
    throw UnimplementedError();
    // final List<JSObject> jsInstances =
    //     await _jsObject.getInstances(entity).toDart;
    // return jsInstances
    //     .map((js) => FilamentEntity._fromJSObject(js))
    //     .toList()
    //     .toDart;
  }

  @override
  Future<FilamentEntity> loadGltf(String path, String relativeResourcePath,
      {bool force = false}) async {
    throw UnimplementedError();
    // final FilamentEntity jsEntity = await _jsObject
    //     .loadGltf(path, relativeResourcePath, force: force)
    //     .toDart;
    // return FilamentEntity._fromJSObject(jsEntity).toDart;
  }

  @override
  Future<void> panStart(double x, double y) async {
    await _jsObject.panStart(x, y).toDart;
  }

  @override
  Future<void> panUpdate(double x, double y) async {
    await _jsObject.panUpdate(x, y).toDart;
  }

  @override
  Future<void> panEnd() async {
    await _jsObject.panEnd().toDart;
  }

  @override
  Future<void> rotateStart(double x, double y) async {
    await _jsObject.rotateStart(x, y).toDart;
  }

  @override
  Future<void> rotateUpdate(double x, double y) async {
    await _jsObject.rotateUpdate(x, y).toDart;
  }

  @override
  Future<void> rotateEnd() async {
    await _jsObject.rotateEnd().toDart;
  }

  @override
  Future<void> setMorphTargetWeights(
      FilamentEntity entity, List<double> weights) async {
    var jsWeights = weights.map((x) => x.toJS).cast<JSNumber>().toList().toJS;
    var promise = _jsObject.setMorphTargetWeights(entity, jsWeights);
    await promise.toDart;
  }

  @override
  Future<List<String>> getMorphTargetNames(
      FilamentEntity entity, FilamentEntity childEntity) async {
    var result =
        await _jsObject.getMorphTargetNames(entity, childEntity).toDart;
    return result.toDart.map((r) => r.toDart).toList();
  }

  @override
  Future<List<String>> getAnimationNames(FilamentEntity entity) async {
    var names = (await (_jsObject.getAnimationNames(entity).toDart))
        .toDart
        .map((x) => x.toDart)
        .toList();
    return names;
  }

  @override
  Future<double> getAnimationDuration(
      FilamentEntity entity, int animationIndex) async {
    return (await _jsObject.getAnimationDuration(entity, animationIndex).toDart)
        .toDartDouble;
  }

  @override
  Future<void> setMorphAnimationData(
      FilamentEntity entity, MorphAnimationData animation,
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
      await _jsObject
          .setMorphAnimationData(entity, animationDataJs, morphTargetsJs,
              targetMeshNamesJS, animation.frameLengthInMs)
          .toDart;
    } catch (err, st) {
      print(err);
      print(st);
      rethrow;
    }
  }

  @override
  Future<void> resetBones(FilamentEntity entity) async {
    await _jsObject.resetBones(entity).toDart;
  }

  @override
  Future<void> addBoneAnimation(
      FilamentEntity entity, BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeInInSecs = 0.0,
      double fadeOutInSecs = 0.0,
      double maxDelta=1.0}) async {
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

    await _jsObject
        .addBoneAnimation(
            entity,
            boneNames,
            frameData,
            animation.frameLengthInMs.toJS,
            animation.space.index.toJS,
            skinIndex.toJS,
            fadeInInSecs.toJS,
            fadeOutInSecs.toJS,
            maxDelta)
        .toDart;
  }

  @override
  Future<void> removeEntity(FilamentEntity entity) async {
    await _jsObject.removeEntity(entity).toDart;
  }

  @override
  Future<void> clearEntities() async {
    await _jsObject.clearEntities().toDart;
  }

  @override
  Future<void> zoomBegin() async {
    await _jsObject.zoomBegin().toDart;
  }

  @override
  Future<void> zoomUpdate(double x, double y, double z) async {
    await _jsObject.zoomUpdate(x, y, z).toDart;
  }

  @override
  Future<void> zoomEnd() async {
    await _jsObject.zoomEnd().toDart;
  }

  @override
  Future<void> playAnimation(FilamentEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    await _jsObject
        .playAnimation(entity, index, loop, reverse, replaceActive, crossfade)
        .toDart;
  }

  @override
  Future<void> playAnimationByName(FilamentEntity entity, String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    await _jsObject
        .playAnimationByName(
            entity, name, loop, reverse, replaceActive, crossfade)
        .toDart;
  }

  @override
  Future<void> setAnimationFrame(
      FilamentEntity entity, int index, int animationFrame) async {
    await _jsObject.setAnimationFrame(entity, index, animationFrame).toDart;
  }

  @override
  Future<void> stopAnimation(FilamentEntity entity, int animationIndex) async {
    await _jsObject.stopAnimation(entity, animationIndex).toDart;
  }

  @override
  Future<void> stopAnimationByName(FilamentEntity entity, String name) async {
    await _jsObject.stopAnimationByName(entity, name).toDart;
  }

  @override
  Future<void> setCamera(FilamentEntity entity, String? name) async {
    await _jsObject.setCamera(entity, name).toDart;
  }

  @override
  Future<void> setMainCamera() async {
    await _jsObject.setMainCamera().toDart;
  }

  @override
  Future<FilamentEntity> getMainCamera() async {
    throw UnimplementedError();
    // final FilamentEntity jsEntity = await _jsObject.getMainCamera().toDart;
    // return FilamentEntity._fromJSObject(jsEntity).toDart;
  }

  @override
  Future<void> setCameraFov(double degrees, double width, double height) async {
    await _jsObject.setCameraFov(degrees, width, height).toDart;
  }

  @override
  Future<void> setToneMapping(ToneMapper mapper) async {
    await _jsObject.setToneMapping(mapper.index).toDart;
  }

  @override
  Future<void> setBloom(double bloom) async {
    await _jsObject.setBloom(bloom).toDart;
  }

  @override
  Future<void> setCameraFocalLength(double focalLength) async {
    await _jsObject.setCameraFocalLength(focalLength).toDart;
  }

  @override
  Future<void> setCameraCulling(double near, double far) async {
    await _jsObject.setCameraCulling(near, far).toDart;
  }

  @override
  Future<double> getCameraCullingNear() async {
    return (await _jsObject.getCameraCullingNear().toDart).toDartDouble;
  }

  @override
  Future<double> getCameraCullingFar() async {
    return (await _jsObject.getCameraCullingFar().toDart).toDartDouble;
  }

  @override
  Future<void> setCameraFocusDistance(double focusDistance) async {
    await _jsObject.setCameraFocusDistance(focusDistance).toDart;
  }

  @override
  Future<Vector3> getCameraPosition() async {
    final jsPosition = (await _jsObject.getCameraPosition().toDart).toDart;
    return Vector3(jsPosition[0].toDartDouble, jsPosition[1].toDartDouble,
        jsPosition[2].toDartDouble);
  }

  @override
  Future<Matrix4> getCameraModelMatrix() async {
    throw UnimplementedError();
    // final JSMatrix4 jsMatrix = await _jsObject.getCameraModelMatrix().toDart;
    // return Matrix4.fromList(jsMatrix.storage).toDart;
  }

  @override
  Future<Matrix4> getCameraViewMatrix() async {
    throw UnimplementedError();
    // final JSMatrix4 jsMatrix = await _jsObject.getCameraViewMatrix().toDart;
    // return Matrix4.fromList(jsMatrix.storage).toDart;
  }

  @override
  Future<Matrix4> getCameraProjectionMatrix() async {
    throw UnimplementedError();
    // final JSMatrix4 jsMatrix =
    //     await _jsObject.getCameraProjectionMatrix().toDart;
    // return Matrix4.fromList(jsMatrix.storage).toDart;
  }

  @override
  Future<Matrix4> getCameraCullingProjectionMatrix() async {
    throw UnimplementedError();
    // final JSMatrix4 jsMatrix =
    //     await _jsObject.getCameraCullingProjectionMatrix().toDart;
    // return Matrix4.fromList(jsMatrix.storage).toDart;
  }

  @override
  Future<Frustum> getCameraFrustum() async {
    throw UnimplementedError();
    // final JSObject jsFrustum = await _jsObject.getCameraFrustum().toDart;
    // // Assuming Frustum is a class that can be constructed from the JSObject
    // return Frustum._fromJSObject(jsFrustum).toDart;
  }

  @override
  Future<void> setCameraPosition(double x, double y, double z) async {
    await _jsObject.setCameraPosition(x, y, z).toDart;
  }

  @override
  Future<Matrix3> getCameraRotation() async {
    throw UnimplementedError();
    // final JSMatrix3 jsRotation = await _jsObject.getCameraRotation().toDart;
    // return Matrix3.fromList(jsRotation.storage).toDart;
  }

  @override
  Future<void> moveCameraToAsset(FilamentEntity entity) async {
    await _jsObject.moveCameraToAsset(entity).toDart;
  }

  @override
  Future<void> setViewFrustumCulling(bool enabled) async {
    throw UnimplementedError();
    // await _jsObject.setViewFrustumCulling(enabled.toJSBoolean()).toDart;
  }

  @override
  Future<void> setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    await _jsObject
        .setCameraExposure(aperture, shutterSpeed, sensitivity)
        .toDart;
  }

  @override
  Future<void> setCameraRotation(Quaternion quaternion) async {
    final values = <JSNumber>[
      quaternion.x.toJS,
      quaternion.y.toJS,
      quaternion.z.toJS,
      quaternion.w.toJS
    ];
    await _jsObject.setCameraRotation(values.toJS).toDart;
  }

  @override
  Future<void> setCameraModelMatrix(List<double> matrix) async {
    throw UnimplementedError();

    // await _jsObject.setCameraModelMatrix(matrix.toJSBox).toDart;
  }

  @override
  Future<void> setMaterialColor(FilamentEntity entity, String meshName,
      int materialIndex, double r, double g, double b, double a) async {
    await _jsObject
        .setMaterialColor(entity, meshName, materialIndex, r, g, b, a)
        .toDart;
  }

  @override
  Future<void> transformToUnitCube(FilamentEntity entity) async {
    await _jsObject.transformToUnitCube(entity).toDart;
  }

  @override
  Future<void> setPosition(
      FilamentEntity entity, double x, double y, double z) async {
    await _jsObject.setPosition(entity, x, y, z).toDart;
  }

  @override
  Future<void> setScale(FilamentEntity entity, double scale) async {
    await _jsObject.setScale(entity, scale).toDart;
  }

  @override
  Future<void> setRotation(
      FilamentEntity entity, double rads, double x, double y, double z) async {
    await _jsObject.setRotation(entity, rads, x, y, z).toDart;
  }

  @override
  Future<void> queuePositionUpdate(
      FilamentEntity entity, double x, double y, double z,
      {bool relative = false}) async {
    await _jsObject.queuePositionUpdate(entity, x, y, z, relative).toDart;
  }

  @override
  Future<void> queueRotationUpdate(
      FilamentEntity entity, double rads, double x, double y, double z,
      {bool relative = false}) async {
    await _jsObject.queueRotationUpdate(entity, rads, x, y, z, relative).toDart;
  }

  @override
  Future<void> queueRotationUpdateQuat(FilamentEntity entity, Quaternion quat,
      {bool relative = false}) async {
    throw UnimplementedError();

    // final JSQuaternion jsQuat = quat.toJSQuaternion().toDart;
    // await _jsObject
    //     .queueRotationUpdateQuat(entity, jsQuat, relative: relative)
    //     .toDart;
  }

  @override
  Future<void> setPostProcessing(bool enabled) async {
    await _jsObject.setPostProcessing(enabled).toDart;
  }

  @override
  Future<void> setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
    await _jsObject.setAntiAliasing(msaa, fxaa, taa).toDart;
  }

  @override
  Future<void> setRotationQuat(
      FilamentEntity entity, Quaternion rotation) async {
    throw UnimplementedError();
    // final JSQuaternion jsRotation = rotation.toJSQuaternion().toDart;
    // await _jsObject.setRotationQuat(entity, jsRotation).toDart;
  }

  @override
  Future<void> reveal(FilamentEntity entity, String? meshName) async {
    throw UnimplementedError();
    // await _jsObject.reveal(entity, meshName).toDart;
  }

  @override
  Future<void> hide(FilamentEntity entity, String? meshName) async {
    throw UnimplementedError();
    // await _jsObject.hide(entity, meshName).toDart;
  }

  @override
  void pick(int x, int y) {
    throw UnimplementedError();
    // _jsObject.pick(x, y).toDart;
  }

  @override
  String? getNameForEntity(FilamentEntity entity) {
    return _jsObject.getNameForEntity(entity);
  }

  @override
  Future<void> setCameraManipulatorOptions(
      {ManipulatorMode mode = ManipulatorMode.ORBIT,
      double orbitSpeedX = 0.01,
      double orbitSpeedY = 0.01,
      double zoomSpeed = 0.01}) async {
    await _jsObject
        .setCameraManipulatorOptions(
            mode.index, orbitSpeedX, orbitSpeedY, zoomSpeed)
        .toDart;
  }

  @override
  Future<List<FilamentEntity>> getChildEntities(
      FilamentEntity parent, bool renderableOnly) async {
    final children =
        await _jsObject.getChildEntities(parent, renderableOnly).toDart;
    return children.toDart
        .map((js) => js.toDartInt)
        .cast<FilamentEntity>()
        .toList();
  }

  @override
  Future<FilamentEntity> getChildEntity(
      FilamentEntity parent, String childName) async {
    return (await _jsObject.getChildEntity(parent, childName).toDart).toDartInt;
  }

  @override
  Future<List<String>> getChildEntityNames(FilamentEntity entity,
      {bool renderableOnly = true}) async {
    var names =
        await _jsObject.getChildEntityNames(entity, renderableOnly).toDart;
    return names.toDart.map((x) => x.toDart).toList();
  }

  @override
  Future<void> setRecording(bool recording) async {
    throw UnimplementedError();
    // await _jsObject.setRecording(recording.toJSBoolean()).toDart;
  }

  @override
  Future<void> setRecordingOutputDirectory(String outputDirectory) async {
    await _jsObject.setRecordingOutputDirectory(outputDirectory).toDart;
  }

  @override
  Future<void> addAnimationComponent(FilamentEntity entity) async {
    await _jsObject.addAnimationComponent(entity).toDart;
  }

  @override
  Future<void> addCollisionComponent(FilamentEntity entity,
      {void Function(int entityId1, int entityId2)? callback,
      bool affectsTransform = false}) async {
    throw UnimplementedError();
    // final JSFunction? jsCallback = callback != null
    //     ? allowInterop(
    //         (int entityId1, int entityId2) => callback(entityId1, entityId2))
    //     : null;
    // await _jsObject
    //     .addCollisionComponent(entity,
    //         callback: jsCallback,
    //         affectsTransform: affectsTransform.toJSBoolean())
    //     .toDart;
  }

  @override
  Future<void> removeCollisionComponent(FilamentEntity entity) async {
    await _jsObject.removeCollisionComponent(entity).toDart;
  }

  @override
  Future<FilamentEntity> createGeometry(
      List<double> vertices, List<int> indices,
      {String? materialPath,
      PrimitiveType primitiveType = PrimitiveType.TRIANGLES}) async {
    throw UnimplementedError();
    // final FilamentEntity jsEntity = await _jsObject
    //     .createGeometry(vertices, indices,
    //         materialPath: materialPath, primitiveType: primitiveType.index)
    //     .toDart;
    // return FilamentEntity._fromJSObject(jsEntity).toDart;
  }

  @override
  Future<void> setParent(FilamentEntity child, FilamentEntity parent) async {
    await _jsObject.setParent(child, parent).toDart;
  }

  @override
  Future<void> testCollisions(FilamentEntity entity) async {
    await _jsObject.testCollisions(entity).toDart;
  }

  @override
  Future<void> setPriority(FilamentEntity entityId, int priority) async {
    await _jsObject.setPriority(entityId, priority).toDart;
  }

  Scene? _scene;

  // @override
  Scene get scene {
    _scene ??= SceneImpl(this);
    return _scene!;
  }

  AbstractGizmo? get gizmo => null;

  @override
  Future<List<String>> getBoneNames(FilamentEntity entity,
      {int skinIndex = 0}) async {
    var result = await _jsObject.getBoneNames(entity, skinIndex).toDart;
    return result.toDart.map((n) => n.toDart).toList();
  }

  @override
  Future<FilamentEntity> getBone(FilamentEntity entity, int boneIndex,
      {int skinIndex = 0}) async {
    var result = await _jsObject.getBone(entity, boneIndex, skinIndex).toDart;
    return result.toDartInt;
  }

  @override
  Future<Matrix4> getInverseBindMatrix(FilamentEntity parent, int boneIndex,
      {int skinIndex = 0}) {
    // TODO: implement getInverseBindMatrix
    throw UnimplementedError();
  }

  @override
  Future<Matrix4> getLocalTransform(FilamentEntity entity) async {
    var result = await _jsObject.getLocalTransform(entity).toDart;
    return Matrix4.fromList(result.toDart.map((v) => v.toDartDouble).toList());
  }

  @override
  Future<FilamentEntity?> getParent(FilamentEntity child) async {
    var result = await _jsObject.getParent(child).toDart;
    return result.toDartInt;
  }

  @override
  Future<Matrix4> getWorldTransform(FilamentEntity entity) async {
    var result = await _jsObject.getLocalTransform(entity).toDart;
    return Matrix4.fromList(result.toDart.map((v) => v.toDartDouble).toList());
  }

  @override
  Future removeAnimationComponent(FilamentEntity entity) {
    return _jsObject.removeAnimationComponent(entity).toDart;
  }

  @override
  Future setBoneTransform(
      FilamentEntity entity, int boneIndex, Matrix4 transform,
      {int skinIndex = 0}) {
    return _jsObject
        .setBoneTransform(entity, boneIndex,
            transform.storage.map((v) => v.toJS).toList().toJS, skinIndex)
        .toDart;
  }

  @override
  Future setTransform(FilamentEntity entity, Matrix4 transform) {
    return _jsObject
        .setTransform(
            entity, transform.storage.map((v) => v.toJS).toList().toJS)
        .toDart;
  }

  @override
  Future updateBoneMatrices(FilamentEntity entity) {
    return _jsObject.updateBoneMatrices(entity).toDart;
  }
}
