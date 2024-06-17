import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data' as td;
import 'dart:typed_data';
import 'package:web/web.dart';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:vector_math/vector_math_64.dart';

extension type _EmscriptenModule(JSObject _) implements JSObject {
  external JSAny? ccall(String name, String returnType,
      JSArray<JSString> argTypes, JSArray<JSAny?> args, JSAny? opts);

  external JSNumber _malloc(int numBytes);
  external void _free(JSNumber addr);
  external JSNumber stackAlloc(int numBytes);

  external JSAny getValue(JSNumber addr, String llvmType);
  external void setValue(JSNumber addr, JSNumber value, String llvmType);

  external JSString intArrayToString(JSAny ptr);
  external JSString UTF8ToString(JSAny ptr);
  external void stringToUTF8(
      JSString str, JSNumber ptr, JSNumber maxBytesToWrite);
  external void writeArrayToMemory(JSUint8Array data, JSNumber ptr);
  external JSAny get ALLOC_STACK;
  external JSAny get HEAPU32;
  external JSAny get HEAP32;
}

///
/// An [ThermionViewer] implementation that forwards calls to
/// the (Emscripten-generated) ThermionDart JS module.
///
class ThermionViewerFFIWasm implements ThermionViewer {
  late _EmscriptenModule _module;

  bool _initialized = false;
  bool _rendering = false;

  ThermionViewerFFIWasm() {
    _module = window.getProperty<_EmscriptenModule>("df".toJS);
  }

  JSBigInt? _viewer;
  JSBigInt? _sceneManager;

  @override
  Future initialize(int width, int height, {String? uberArchivePath}) async {
    final context = _module.ccall("thermion_dart_web_create_gl_context", "int",
        <JSString>[].toJS, <JSAny>[].toJS, null);
    final loader = _module.ccall(
        "thermion_dart_web_get_resource_loader_wrapper",
        "void*",
        <JSString>[].toJS,
        <JSAny>[].toJS,
        null);
    _viewer = _module.ccall(
        "create_filament_viewer",
        "void*",
        ["void*".toJS, "void*".toJS, "void*".toJS, "string".toJS].toJS,
        [context, loader, null, uberArchivePath?.toJS].toJS,
        null) as JSBigInt;
    print("Created viewer");
    await createSwapChain(width, height);
    _updateViewportAndCameraProjection(width, height, 1.0);
    _sceneManager = _module.ccall("get_scene_manager", "void*",
        ["void*".toJS].toJS, [_viewer!].toJS, null) as JSBigInt;
    _initialized = true;
  }

  Future createSwapChain(int width, int height) async {
    _module.ccall(
        "create_swap_chain",
        "void",
        ["void*".toJS, "void*".toJS, "uint32_t".toJS, "uint32_t".toJS].toJS,
        [_viewer!, null, width.toJS, height.toJS].toJS,
        null);
  }

  Future destroySwapChain() async {
    _module.ccall("destroy_swap_chain", "void", ["void*".toJS].toJS,
        [_viewer!].toJS, null);
  }

  @override
  void _updateViewportAndCameraProjection(
      int width, int height, double scaleFactor) {
    _module.ccall(
        "update_viewport_and_camera_projection",
        "void",
        ["void*".toJS, "uint32_t".toJS, "uint32_t".toJS, "float".toJS].toJS,
        [_viewer!, width.toJS, height.toJS, scaleFactor.toJS].toJS,
        null);
  }

  @override
  Future<bool> get initialized async {
    return _initialized;
  }

  @override
  Stream<FilamentPickResult> get pickResult {
    throw UnimplementedError();
  }

  @override
  bool get rendering => _rendering;

  @override
  Future dispose() async {
    _module.ccall("destroy_filament_viewer", "void", ["void*".toJS].toJS,
        [_viewer].toJS, null);
    _initialized = false;
    _viewer = null;
  }

  @override
  Future setBackgroundColor(double r, double g, double b, double alpha) async {
    _module.ccall(
        "set_background_color",
        "void",
        ["void*".toJS, "float".toJS, "float".toJS, "float".toJS, "float".toJS]
            .toJS,
        [_viewer!, r.toJS, g.toJS, b.toJS, alpha.toJS].toJS,
        null);
  }

  @override
  Future addAnimationComponent(ThermionEntity entity) async {
    _module.ccall(
        "add_animation_component",
        "bool",
        ["void*".toJS, "int32_t".toJS].toJS,
        [_sceneManager!, entity.toJS].toJS,
        null);
  }

  Matrix4 _matrixFromPtr(JSNumber matPtr) {
    final mat = Matrix4.zero();
    for (int i = 0; i < 16; i++) {
      mat[i] = (_module.getValue((matPtr.toDartInt + (i * 4)).toJS, "float")
              as JSNumber)
          .toDartDouble;
    }
    return mat;
  }

  @override
  Future<List<Matrix4>> getRestLocalTransforms(ThermionEntity entity,
      {int skinIndex = 0}) async {
    var boneCountJS = _module.ccall(
        "get_bone_count",
        "int",
        ["void*".toJS, "int".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS, skinIndex.toJS].toJS,
        null) as JSNumber;
    var boneCount = boneCountJS.toDartInt;
    var buf = _module._malloc(boneCount * 16 * 4) as JSNumber;
    _module.ccall(
        "get_rest_local_transforms",
        "void",
        ["void*".toJS, "int".toJS, "int".toJS, "float*".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS, skinIndex.toJS, buf, boneCount.toJS].toJS,
        null);
    var transforms = <Matrix4>[];
    for (int i = 0; i < boneCount; i++) {
      var matPtr = (buf.toDartInt + (i * 16 * 4)).toJS;
      transforms.add(_matrixFromPtr(matPtr));
    }
    _module._free(buf);
    return transforms;
  }

  @override
  Future<ThermionEntity> getBone(ThermionEntity parent, int boneIndex,
      {int skinIndex = 0}) async {
    final boneId = _module.ccall(
        "get_bone",
        "int",
        ["void*".toJS, "int32_t".toJS, "int32_t".toJS, "int32_t".toJS].toJS,
        [_sceneManager!, parent.toJS, skinIndex.toJS, boneIndex.toJS].toJS,
        null) as JSNumber;
    if (boneId.toDartInt == -1) {
      throw Exception("Failed to get bone");
    }
    return boneId.toDartInt;
  }

  Future<List<ThermionEntity>> getBones(ThermionEntity entity,
      {int skinIndex = 0}) async {
    final boneNames = await getBoneNames(entity);
    final bones = await Future.wait(List.generate(
        boneNames.length, (i) => getBone(entity, i, skinIndex: skinIndex)));
    return bones;
  }

  @override
  Future addBoneAnimation(ThermionEntity entity, BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeInInSecs = 0.0,
      double fadeOutInSecs = 0.0,
      double maxDelta = 1.0}) async {
    final boneNames = await getBoneNames(entity);
    final bones = await getBones(entity);

    var numBytes = animation.numFrames * 16 * 4;
    var floatPtr = _module._malloc(numBytes);

    var restLocalTransforms = await getRestLocalTransforms(entity);

    for (int i = 0; i < animation.bones.length; i++) {
      final boneName = animation.bones[i];
      final entityBoneIndex = boneNames.indexOf(boneName);

      var boneEntity = bones[entityBoneIndex];

      var baseTransform = restLocalTransforms[entityBoneIndex];

      var world = Matrix4.identity();

      // this odd use of ! is intentional, without it, the WASM optimizer gets in trouble
      var parentBoneEntity = (await getParent(boneEntity))!;
      while (true) {
        if (!bones.contains(parentBoneEntity!)) {
          break;
        }
        world = restLocalTransforms[bones.indexOf(parentBoneEntity!)] * world;
        parentBoneEntity = (await getParent(parentBoneEntity))!;
      }

      world = Matrix4.identity()..setRotation(world.getRotation());
      var worldInverse = Matrix4.identity()..copyInverse(world);

      for (int frameNum = 0; frameNum < animation.numFrames; frameNum++) {
        var rotation = animation.frameData[frameNum][i].rotation;
        var translation = animation.frameData[frameNum][i].translation;
        var frameTransform =
            Matrix4.compose(translation, rotation, Vector3.all(1.0));
        var newLocalTransform = frameTransform.clone();
        if (animation.space == Space.Bone) {
          newLocalTransform = baseTransform * frameTransform;
        } else if (animation.space == Space.ParentWorldRotation) {
          newLocalTransform =
              baseTransform * (worldInverse * frameTransform * world);
        }
        for (int j = 0; j < 16; j++) {
          var offset = ((frameNum * 16) + j) * 4;
          _module.setValue((floatPtr.toDartInt + offset).toJS,
              newLocalTransform.storage[j].toJS, "float");
        }
      }

      _module.ccall(
          "add_bone_animation",
          "void",
          [
            "void*".toJS,
            "int".toJS,
            "int".toJS,
            "int".toJS,
            "float*".toJS,
            "int".toJS,
            "float".toJS,
            "float".toJS,
            "float".toJS,
            "float".toJS
          ].toJS,
          [
            _sceneManager!,
            entity.toJS,
            skinIndex.toJS,
            entityBoneIndex.toJS,
            floatPtr,
            animation.numFrames.toJS,
            animation.frameLengthInMs.toJS,
            fadeOutInSecs.toJS,
            fadeInInSecs.toJS,
            maxDelta.toJS
          ].toJS,
          null);
    }
    _module._free(floatPtr);
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
      bool castShadows = true}) async {
    final entityId = _module.ccall(
        "add_light",
        "int",
        [
          "void*".toJS,
          "uint8_t".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "bool".toJS
        ].toJS,
        [
          _viewer,
          type.index.toJS,
          colour.toJS,
          intensity.toJS,
          posX.toJS,
          posY.toJS,
          posZ.toJS,
          dirX.toJS,
          dirY.toJS,
          dirZ.toJS,
          falloffRadius.toJS,
          spotLightConeInner.toJS,
          spotLightConeOuter.toJS,
          sunAngularRadius.toJS,
          sunHaloSize.toJS,
          sunHaloFallof.toJS,
          castShadows.toJS
        ].toJS,
        null) as JSNumber;
    if (entityId.toDartInt == -1) {
      throw Exception("Failed to add light");
    }
    return entityId.toDartInt;
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
  Future<List<String>> getBoneNames(ThermionEntity entity,
      {int skinIndex = 0}) async {
    var boneCountJS = _module.ccall(
        "get_bone_count",
        "int",
        ["void*".toJS, "int".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS, skinIndex.toJS].toJS,
        null) as JSNumber;
    var boneCount = boneCountJS.toDartInt;
    var buf = _module._malloc(boneCount * 4) as JSNumber;

    var empty = " ".toJS;
    var ptrs = <JSNumber>[];
    for (int i = 0; i < boneCount; i++) {
      var ptr = _module._malloc(256);
      _module.stringToUTF8(empty, ptr, 255.toJS);
      ptrs.add(ptr);
      _module.setValue((buf.toDartInt + (i * 4)).toJS, ptr, "i32");
    }
    _module.ccall(
        "get_bone_names",
        "void",
        ["void*".toJS, "int".toJS, "char**".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS, buf, skinIndex.toJS].toJS,
        null);
    var names = <String>[];
    for (int i = 0; i < boneCount; i++) {
      var name = _module.UTF8ToString(ptrs[i]).toDart;
      names.add(name);
    }

    return names;
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
      ThermionEntity parent, bool renderableOnly) async {
    var entityCountJS = _module.ccall(
        "get_entity_count",
        "int",
        ["void*".toJS, "int".toJS, "bool".toJS].toJS,
        [_sceneManager!, parent.toJS, renderableOnly.toJS].toJS,
        null) as JSNumber;
    var entityCount = entityCountJS.toDartInt;
    var entities = <ThermionEntity>[];
    var buf = _module._malloc(entityCount * 4) as JSNumber;

    _module.ccall(
        "get_entities",
        "void",
        ["void*".toJS, "int".toJS, "bool".toJS, "int*".toJS].toJS,
        [_sceneManager!, parent.toJS, renderableOnly.toJS, buf].toJS,
        null);
    for (int i = 0; i < entityCount; i++) {
      var entityId =
          _module.getValue((buf.toDartInt + (i * 4)).toJS, "i32") as JSNumber;
      entities.add(entityId.toDartInt);
    }
    _module._free(buf);
    return entities;
  }

  @override
  Future<ThermionEntity> getChildEntity(
      ThermionEntity parent, String childName) async {
    final entityId = _module.ccall(
        "find_child_entity_by_name",
        "int",
        ["void*".toJS, "int".toJS, "string".toJS].toJS,
        [_sceneManager!, parent.toJS, childName.toJS].toJS,
        null) as JSNumber;
    if (entityId.toDartInt == -1) {
      throw Exception("Failed to find child entity");
    }
    return entityId.toDartInt;
  }

  @override
  Future<List<String>> getChildEntityNames(ThermionEntity entity,
      {bool renderableOnly = true}) async {
    var entityCountJS = _module.ccall(
        "get_entity_count",
        "int",
        ["void*".toJS, "int".toJS, "bool".toJS].toJS,
        [_sceneManager!, entity.toJS, renderableOnly.toJS].toJS,
        null) as JSNumber;
    var entityCount = entityCountJS.toDartInt;
    var names = <String>[];
    for (int i = 0; i < entityCount; i++) {
      var namePtr = _module.ccall(
          "get_entity_name_at",
          "char*",
          ["void*".toJS, "int".toJS, "int".toJS, "bool".toJS].toJS,
          [_sceneManager!, entity.toJS, i.toJS, renderableOnly.toJS].toJS,
          null) as JSNumber;
      names.add(_module.UTF8ToString(namePtr).toDart);
    }
    return names;
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
  Future<ThermionEntity> getMainCamera() async {
    final entityId = _module.ccall(
            "get_main_camera", "int", ["void*".toJS].toJS, [_viewer].toJS, null)
        as JSNumber;
    if (entityId.toDartInt == -1) {
      throw Exception("Failed to get main camera");
    }
    return entityId.toDartInt;
  }

  @override
  Future<List<String>> getMorphTargetNames(
      ThermionEntity entity, ThermionEntity childEntity) async {
    var morphTargetCountJS = _module.ccall(
        "get_morph_target_name_count",
        "int",
        ["void*".toJS, "int32_t".toJS, "int32_t".toJS].toJS,
        [_sceneManager!, entity.toJS, childEntity.toJS].toJS,
        null) as JSNumber;
    var morphTargetCount = morphTargetCountJS.toDartInt;
    var names = <String>[];
    for (int i = 0; i < morphTargetCount; i++) {
      var buf = _module._malloc(256) as JSNumber;
      _module.ccall(
          "get_morph_target_name",
          "void",
          [
            "void*".toJS,
            "int32_t".toJS,
            "int32_t".toJS,
            "char*".toJS,
            "int32_t".toJS
          ].toJS,
          [_sceneManager!, entity.toJS, childEntity.toJS, buf, i.toJS].toJS,
          null);
      names.add(_module.UTF8ToString(buf).toDart);
      _module._free(buf);
    }
    return names;
  }

  @override
  String? getNameForEntity(ThermionEntity entity) {
    final namePtr = _module.ccall(
        "get_name_for_entity",
        "char*",
        ["void*".toJS, "int32_t".toJS].toJS,
        [_sceneManager!, entity.toJS].toJS,
        null) as JSNumber;
    if (namePtr.toDartInt == 0) {
      return null;
    }
    return _module.UTF8ToString(namePtr).toDart;
  }

  @override
  Future<ThermionEntity?> getParent(ThermionEntity child) async {
    final parentId = _module.ccall(
        "get_parent",
        "int",
        ["void*".toJS, "int32_t".toJS].toJS,
        [_sceneManager!, child.toJS].toJS,
        null) as JSNumber;
    if (parentId.toDartInt == -1) {
      return null;
    }
    return parentId.toDartInt;
  }

  @override
  Future<Matrix4> getWorldTransform(ThermionEntity entity) async {
    final matrixPtr = _module._malloc(16 * 4) as JSNumber;
    _module.ccall(
        "get_world_transform",
        "void",
        ["void*".toJS, "int32_t".toJS, "float*".toJS].toJS,
        [_sceneManager!, entity.toJS, matrixPtr].toJS,
        null);
    final matrix = _matrixFromPtr(matrixPtr);
    _module._free(matrixPtr);
    return matrix;
  }

  @override
  // TODO: implement gizmo
  AbstractGizmo? get gizmo => throw UnimplementedError();

  @override
  Future hide(ThermionEntity entity, String? meshName) async {
    if (meshName != null) {
      final result = _module.ccall(
          "hide_mesh",
          "int",
          ["void*".toJS, "int".toJS, "string".toJS].toJS,
          [_sceneManager!, entity.toJS, meshName.toJS].toJS,
          null) as JSNumber;
      if (result.toDartInt == -1) {
        throw Exception(
            "Failed to hide mesh ${meshName} on entity ${entity.toJS}");
      }
    } else {
      throw Exception(
          "Cannot hide mesh, meshName must be specified when invoking this method");
    }
  }

  Future<ThermionEntity> loadGlbFromBuffer(Uint8List data,
      {int numInstances = 1}) async {
    if (numInstances != 1) {
      throw Exception("TODO");
    }
    final ptr = _module._malloc(data.length);
    _module.writeArrayToMemory(data.toJS, ptr);

    final result = _module.ccall(
        "load_glb_from_buffer",
        "int",
        ["void*".toJS, "void*".toJS, "size_t".toJS].toJS,
        [_sceneManager!, ptr, data.lengthInBytes.toJS].toJS,
        null) as JSNumber;
    final entityId = result.toDartInt;
    _module._free(ptr);
    if (entityId == -1) {
      throw Exception("Failed to load GLB");
    }
    return entityId;
  }

  @override
  Future<ThermionEntity> loadGlb(String path, {int numInstances = 1}) async {
    final promise = _module.ccall(
        "load_glb",
        "int",
        ["void*".toJS, "string".toJS, "int".toJS].toJS,
        [_sceneManager!, path.toJS, numInstances.toJS].toJS,
        {"async": true}.jsify()) as JSPromise<JSNumber>;
    final entityId = (await promise.toDart).toDartInt;
    if (entityId == -1) {
      throw Exception("Failed to load GLB");
    }
    return entityId;
  }

  @override
  Future<ThermionEntity> loadGltf(String path, String relativeResourcePath,
      {bool force = false}) async {
    final promise = _module.ccall(
        "load_gltf",
        "int",
        ["void*".toJS, "string".toJS, "string".toJS, "bool".toJS].toJS,
        [_sceneManager!, path.toJS, relativeResourcePath.toJS, force.toJS].toJS,
        {"async": true}.jsify()) as JSPromise<JSNumber>;
    final entityId = (await promise.toDart).toDartInt;
    if (entityId == -1) {
      throw Exception("Failed to load GLTF");
    }
    return entityId;
  }

  @override
  Future loadIbl(String lightingPath, {double intensity = 30000}) async {
    var promise = _module.ccall(
        "load_ibl",
        "void",
        ["void*".toJS, "string".toJS, "float".toJS].toJS,
        [_viewer!, lightingPath.toJS, intensity.toJS].toJS,
        {"async": true}.jsify()) as JSPromise;
    await promise.toDart;
  }

  @override
  Future loadSkybox(String skyboxPath) async {
    var promise = _module.ccall(
        "load_skybox",
        "void",
        ["void*".toJS, "string".toJS].toJS,
        [_viewer!, skyboxPath.toJS].toJS,
        {"async": true}.jsify()) as JSPromise;
    await promise.toDart;
  }

  @override
  Future moveCameraToAsset(ThermionEntity entity) {
    // TODO: implement moveCameraToAsset
    throw UnimplementedError();
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
  Future playAnimation(ThermionEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    _module.ccall(
        "play_animation",
        "void",
        [
          "void*".toJS,
          "int32_t".toJS,
          "int32_t".toJS,
          "bool".toJS,
          "bool".toJS,
          "bool".toJS,
          "float".toJS
        ].toJS,
        [
          _sceneManager!,
          entity.toJS,
          index.toJS,
          loop.toJS,
          reverse.toJS,
          replaceActive.toJS,
          crossfade.toJS
        ].toJS,
        null);
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

  int _last = 0;

  @override
  Future render() async {
    _last = DateTime.now().millisecondsSinceEpoch * 1000000;
    _module.ccall(
        "render",
        "void",
        [
          "void*".toJS,
          "uint64_t".toJS,
          "void*".toJS,
          "void*".toJS,
          "void*".toJS
        ].toJS,
        [
          _viewer!,
          0.toJS,
          null, // pixelBuffer,
          null, // callback
          null // data
        ].toJS,
        null);
  }

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
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
    _module.ccall(
        "set_antialiasing",
        "void",
        ["void*".toJS, "bool".toJS, "bool".toJS, "bool".toJS].toJS,
        [_viewer!, msaa.toJS, fxaa.toJS, taa.toJS].toJS,
        null);
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
  Future setCameraFov(double degrees, double width, double height) {
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
  Future setCameraPosition(double x, double y, double z) async {
    _module.ccall(
        "set_camera_position",
        "void",
        ["void*".toJS, "float".toJS, "float".toJS, "float".toJS].toJS,
        [_viewer!, x.toJS, y.toJS, z.toJS].toJS,
        null);
  }

  @override
  Future setCameraRotation(Quaternion quaternion) async {
    _module.ccall(
        "set_camera_rotation",
        "void",
        ["void*".toJS, "float".toJS, "float".toJS, "float".toJS, "float".toJS]
            .toJS,
        [
          _viewer!,
          quaternion.w.toJS,
          quaternion.x.toJS,
          quaternion.y.toJS,
          quaternion.z.toJS
        ].toJS,
        null);
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

  // @override
  // Future setMorphAnimationData(
  //     ThermionEntity entity, MorphAnimationData animation,
  //     {List<String>? targetMeshNames}) async {
  //   final morphTargetNames = await getMorphTargetNames(entity, entity);

  //   // We need to create a JS array for the morph indices and morph data
  //   final numFrames = animation.numFrames;
  //   final numMorphTargets = morphTargetNames.length;
  //   final numBytes = numFrames * numMorphTargets * 4;
  //   final floatPtr = _module._malloc(numBytes);
  //   final morphIndicesPtr = _module._malloc(numFrames * 4);

  //   // Extract the morph data for the target morph targets
  //   final morphData = animation.extract(morphTargets: targetMeshNames);

  //   // Create a list of morph indices based on the target morph targets
  //   final morphIndices = targetMeshNames != null
  //       ? animation._getMorphTargetIndices(targetMeshNames)
  //       : List<int>.generate(morphTargetNames.length, (i) => i);
  //   final morphIndicesList = td.Int32List.fromList(morphIndices);

  //   // Set the morph data and indices into the JS arrays
  //   _module.writeArrayToMemory(morphData.buffer.asUint8List(morphData.offsetInBytes).toJS, floatPtr);
  //   _module.writeArrayToMemory(morphIndicesList.buffer.asUint8List(morphData.offsetInBytes).toJS, morphIndicesPtr);

  //   // Set the morph animation data
  //   _module.ccall(
  //       "set_morph_animation",
  //       "bool",
  //       [
  //         "void*".toJS,
  //         "int".toJS,
  //         "float*".toJS,
  //         "int*".toJS,
  //         "int".toJS,
  //         "int".toJS,
  //         "float".toJS
  //       ].toJS,
  //       [
  //         _sceneManager!,
  //         entity.toJS,
  //         floatPtr,
  //         morphIndicesPtr,
  //         numMorphTargets.toJS,
  //         numFrames.toJS,
  //         animation.frameLengthInMs.toJS
  //       ].toJS,
  //       null);

  //   // Free the memory allocated for the JS arrays
  //   _module._free(floatPtr);
  //   _module._free(morphIndicesPtr);
  // }

  @override
  Future setMorphAnimationData(
      ThermionEntity entity, MorphAnimationData animation,
      {List<String>? targetMeshNames, bool useNextEntity = false}) async {
    var meshNames = await getChildEntityNames(entity, renderableOnly: false);
    if (targetMeshNames != null) {
      for (final targetMeshName in targetMeshNames) {
        if (!meshNames.contains(targetMeshName)) {
          throw Exception(
              "Error: mesh ${targetMeshName} does not exist under the specified entity. Available meshes : ${meshNames}");
        }
      }
    }

    var meshEntities = await getChildEntities(entity, false);

    // Entities are not guaranteed to have the same morph targets (or share the same order),
    // either from each other, or from those specified in [animation].
    // We therefore set morph targets separately for each mesh.
    // For each mesh, allocate enough memory to hold FxM 32-bit floats
    // (where F is the number of Frames, and M is the number of morph targets in the mesh).
    // we call [extract] on [animation] to return frame data only for morph targets that present in both the mesh and the animation
    for (int i = 0; i < meshNames.length; i++) {
      var meshName = meshNames[i];
      var meshEntity = meshEntities[i];

      if (targetMeshNames?.contains(meshName) == false) {
        // print("Skipping $meshName, not contained in target");
        continue;
      }

      if (useNextEntity) meshEntity += 1;

      var meshMorphTargets = await getMorphTargetNames(entity, meshEntity);

      print("Got mesh morph targets ${meshMorphTargets}");

      var intersection = animation.morphTargets
          .toSet()
          .intersection(meshMorphTargets.toSet())
          .toList();

      if (intersection.isEmpty) {
        throw Exception(
            """No morph targets specified in animation are present on mesh $meshName. 
            If you weren't intending to animate every mesh, specify [targetMeshNames] when invoking this method.
            Animation morph targets: ${animation.morphTargets}\n
            Mesh morph targets ${meshMorphTargets}
            Child meshes: ${meshNames}""");
      }

      var indices =
          intersection.map((m) => meshMorphTargets.indexOf(m)).toList();

      var frameData = animation.extract(morphTargets: intersection);

      assert(frameData.length == animation.numFrames * intersection.length);

      // Allocate memory in WASM for the morph data
      var dataPtr = _module._malloc(frameData.length * 4) as JSNumber;

      // Create a Float32List to copy the morph data to
      var dataList = td.Float32List.fromList(frameData);

      // Copy the morph data to WASM
      _module.writeArrayToMemory(
          dataList.buffer.asUint8List(dataList.offsetInBytes).toJS, dataPtr);

      // Allocate memory in WASM for the morph indices
      var idxPtr = _module._malloc(indices.length * 4) as JSNumber;

      // Create an Int32List to copy the morph indices to
      var idxList = td.Int32List.fromList(indices);

      // Copy the morph indices to WASM
      _module.writeArrayToMemory(
          idxList.buffer.asUint8List(idxList.offsetInBytes).toJS, idxPtr);

      var result = _module.ccall(
          "set_morph_animation",
          "bool",
          [
            "void*".toJS,
            "int".toJS,
            "float*".toJS,
            "int*".toJS,
            "int".toJS,
            "int".toJS,
            "float".toJS
          ].toJS,
          [
            _sceneManager!,
            meshEntity.toJS,
            dataPtr,
            idxPtr,
            indices.length.toJS,
            animation.numFrames.toJS,
            animation.frameLengthInMs.toJS
          ].toJS,
          null) as JSBoolean;

      // Free the memory allocated in WASM
      _module._free(dataPtr);
      _module._free(idxPtr);

      if (!result.toDart) {
        throw Exception("Failed to set morph animation data for ${meshName}");
      }
    }
  }

  @override
  Future setMorphTargetWeights(ThermionEntity entity, List<double> weights) {
    // TODO: implement setMorphTargetWeights
    throw UnimplementedError();
  }

  @override
  Future setParent(ThermionEntity child, ThermionEntity parent) {
    // TODO: implement setParent
    throw UnimplementedError();
  }

  @override
  Future setPosition(
      ThermionEntity entity, double x, double y, double z) async {
    _module.ccall(
        "set_position",
        "void",
        ["void*".toJS, "int".toJS, "float".toJS, "float".toJS, "float".toJS]
            .toJS,
        [_sceneManager!, entity.toJS, x.toJS, y.toJS, z.toJS].toJS,
        null);
  }

  @override
  Future setPostProcessing(bool enabled) async {
    _module.ccall("set_post_processing", "void",
        ["void*".toJS, "bool".toJS].toJS, [_viewer!, enabled.toJS].toJS, null);
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
      ThermionEntity entity, double rads, double x, double y, double z) async {
    var quaternion = Quaternion.axisAngle(Vector3(x, y, z), rads);
    _module.ccall(
        "set_rotation",
        "void",
        [
          "void*".toJS,
          "int".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS
        ].toJS,
        [
          _sceneManager!,
          entity.toJS,
          quaternion.radians.toJS,
          quaternion.x.toJS,
          quaternion.y.toJS,
          quaternion.z.toJS,
          quaternion.w.toJS
        ].toJS,
        null);
  }

  @override
  Future setRotationQuat(ThermionEntity entity, Quaternion rotation) async {
    _module.ccall(
        "set_rotation",
        "void",
        [
          "void*".toJS,
          "int".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS
        ].toJS,
        [
          _sceneManager!,
          entity.toJS,
          rotation.radians.toJS,
          rotation.x.toJS,
          rotation.y.toJS,
          rotation.z.toJS,
          rotation.w.toJS
        ].toJS,
        null);
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
}
