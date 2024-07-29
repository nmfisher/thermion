import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data' as td;
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart/scene.dart';
import 'package:web/web.dart';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:vector_math/vector_math_64.dart';

export 'thermion_viewer_dart_bridge.dart';

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

typedef ThermionViewerImpl = ThermionViewerWasm;

///
/// A [ThermionViewer] implementation that forwards calls to the
/// (Emscripten-generated) ThermionDart JS module.
///
class ThermionViewerWasm implements ThermionViewer {
  final _logger = Logger("ThermionViewerWasm");

  late _EmscriptenModule _module;

  bool _initialized = false;
  bool _rendering = false;

  ///
  /// Construct an instance of this class by explicitly passing the
  /// module instance via the [module] property, or by specifying [moduleName],
  /// being the name of the window property where the module has already been
  /// loaded.
  ///
  /// Pass [assetPathPrefix] if you need to prepend a path to all asset paths
  /// (e.g. on Flutter where the asset directory /foo is actually shipped under
  /// the directory /assets/foo, you would construct this as:
  ///
  /// final viewer = ThermionViewerWasm(assetPathPrefix:"/assets/")
  ///
  ThermionViewerWasm(
      {JSObject? module,
      String moduleName = "thermion_dart",
      String? assetPathPrefix}) {
    _module = module as _EmscriptenModule? ??
        window.getProperty<_EmscriptenModule>(moduleName.toJS);
    if (assetPathPrefix != null) {
      _setAssetPathPrefix(assetPathPrefix);
    }
  }

  void _setAssetPathPrefix(String assetPathPrefix) {
    _module.ccall(
        "thermion_dart_web_set_asset_path_prefix",
        "void",
        <JSString>["string".toJS].toJS,
        <JSAny>[assetPathPrefix.toJS].toJS,
        null);
  }

  JSNumber? _viewer;
  JSNumber? _sceneManager;

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
        null) as JSNumber;
    await createSwapChain(width, height);
    _updateViewportAndCameraProjection(width, height, 1.0);
    _sceneManager = _module.ccall("get_scene_manager", "void*",
        ["void*".toJS].toJS, [_viewer!].toJS, null) as JSNumber;
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
    if (_viewer == null) {
      // we've already cleaned everything up, ignore the call to dispose
      return;
    }
    await setRendering(false);
    await clearEntities();
    await clearLights();
    _destroyViewer();

    _sceneManager = null;
    _viewer = null;

    for (final callback in _onDispose) {
      await callback.call();
    }
    _onDispose.clear();
  }

  void _destroyViewer() {
    _module.ccall("destroy_filament_viewer", "void", ["void*".toJS].toJS,
        [_viewer].toJS, null);
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
        ["void*".toJS, "string".toJS, "string".toJS].toJS,
        [_sceneManager!, path.toJS, relativeResourcePath.toJS].toJS,
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
  Future playAnimation(ThermionEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0}) async {
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
          "float".toJS,
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
  Scene get scene => throw UnimplementedError();

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
  Future clearMorphAnimationData(
      ThermionEntity entity) async {
    var meshEntities = await getChildEntities(entity, false);
    for(final childEntity in meshEntities) {
          _module.ccall(
            "clear_morph_animation",
            "void",
            [
              "void*".toJS,
              "int".toJS,
            ].toJS,
            [
              _sceneManager!,
              childEntity.toJS,
            ].toJS,
            null);
    }

  }

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
        // _logger.info("Skipping $meshName, not contained in target");
        continue;
      }

      if (useNextEntity) meshEntity += 1;

      var meshMorphTargets = await getMorphTargetNames(entity, meshEntity);

      _logger.info("Got mesh morph targets ${meshMorphTargets}");

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
      bool result = false;
      try {
        var jsResult = _module.ccall(
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
            null);
        _logger.info("Got jsResult $jsResult");
        result = (jsResult as JSNumber).toDartInt == 1;
      } catch (err, st) {
        _logger.severe(err);
        _logger.severe(st);
      }

      // Free the memory allocated in WASM
      _module._free(dataPtr);
      _module._free(idxPtr);

      if (!result) {
        throw Exception("Failed to set morph animation data for ${meshName}");
      }
    }
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

  final _onDispose = <Future Function()>[];

  ///
  ///
  ///
  void onDispose(Future Function() callback) {
    _onDispose.add(callback);
  }

  @override
  Future clearBackgroundImage() async {
    _module.ccall("clear_background_image", "void", ["void*".toJS].toJS,
        [_viewer!].toJS, null);
  }

  @override
  Future clearEntities() async {
    _module.ccall(
        "clear_entities", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
  }

  @override
  Future clearLights() async {
    _module.ccall(
        "clear_lights", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
  }

  @override
  Future createGeometry(List<double> vertices, List<int> indices,
      {String? materialPath,
      PrimitiveType primitiveType = PrimitiveType.TRIANGLES}) async {
    final verticesData = td.Float32List.fromList(vertices);
    final indicesData = Uint16List.fromList(indices);
    final verticesPtr = _module._malloc(verticesData.lengthInBytes);
    final indicesPtr = _module._malloc(indicesData.lengthInBytes);
    _module.writeArrayToMemory(
        verticesData.buffer.asUint8List().toJS, verticesPtr);
    _module.writeArrayToMemory(
        indicesData.buffer.asUint8List().toJS, indicesPtr);

    final entityId = _module.ccall(
        "create_geometry",
        "int",
        [
          "void*".toJS,
          "float*".toJS,
          "int".toJS,
          "uint16_t*".toJS,
          "int".toJS,
          "int".toJS,
          "string".toJS
        ].toJS,
        [
          _viewer!,
          verticesPtr,
          vertices.length.toJS,
          indicesPtr,
          indices.length.toJS,
          primitiveType.index.toJS,
          materialPath?.toJS ?? "".toJS,
        ].toJS,
        null) as JSNumber;

    _module._free(verticesPtr);
    _module._free(indicesPtr);

    if (entityId.toDartInt == -1) {
      throw Exception("Failed to create geometry");
    }
    return entityId.toDartInt;
  }

  @override
  Future<ThermionEntity> createInstance(ThermionEntity entity) async {
    final result = _module.ccall(
        "create_instance",
        "int",
        ["void*".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS].toJS,
        null) as JSNumber;
    if (result.toDartInt == -1) {
      throw Exception("Failed to create instance of entity ${entity}");
    }
    return result.toDartInt;
  }

  @override
  Future<double> getAnimationDuration(
      ThermionEntity entity, int animationIndex) async {
    final result = _module.ccall(
        "get_animation_duration",
        "float",
        ["void*".toJS, "int".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS, animationIndex.toJS].toJS,
        null) as JSNumber;
    return result.toDartDouble;
  }

  @override
  Future<int> getAnimationCount(ThermionEntity entity) async {
    final animationCount = _module.ccall(
        "get_animation_count",
        "int",
        ["void*".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS].toJS,
        null) as JSNumber;
    return animationCount.toDartInt;
  }

  @override
  Future<List<String>> getAnimationNames(ThermionEntity entity) async {
    final animationCount = await getAnimationCount(entity);
    final names = <String>[];
    for (int i = 0; i < animationCount; i++) {
      final namePtr = _module._malloc(256) as JSNumber;
      _module.ccall(
          "get_animation_name",
          "void",
          ["void*".toJS, "int".toJS, "char*".toJS, "int".toJS].toJS,
          [_sceneManager!, entity.toJS, namePtr, i.toJS].toJS,
          null);
      names.add(_module.UTF8ToString(namePtr).toDart);
      _module._free(namePtr);
    }
    return names;
  }

  @override
  Future<double> getCameraCullingFar() async {
    final result = _module.ccall("get_camera_culling_far", "double",
        ["void*".toJS].toJS, [_viewer!].toJS, null) as JSNumber;
    return result.toDartDouble;
  }

  @override
  Future<double> getCameraCullingNear() async {
    final result = _module.ccall("get_camera_culling_near", "double",
        ["void*".toJS].toJS, [_viewer!].toJS, null) as JSNumber;
    return result.toDartDouble;
  }

  @override
  Future<Matrix4> getCameraCullingProjectionMatrix() async {
    final ptr = _module._malloc(16 * 8) as JSNumber;
    _module.ccall("get_camera_culling_projection_matrix", "void",
        ["void*".toJS, "double*".toJS].toJS, [_viewer!, ptr].toJS, null);
    final matrix = Matrix4.zero();
    for (int i = 0; i < 16; i++) {
      matrix[i] = (_module.getValue((ptr.toDartInt + (i * 8)).toJS, "double")
              as JSNumber)
          .toDartDouble;
    }
    _module._free(ptr);
    return matrix;
  }

  @override
  Future<Frustum> getCameraFrustum() async {
    final ptr = _module._malloc(24 * 8) as JSNumber;
    _module.ccall("get_camera_frustum", "void",
        ["void*".toJS, "double*".toJS].toJS, [_viewer!, ptr].toJS, null);
    final planes = List.generate(6, (i) {
      final offset = i * 4;
      return Plane()
        ..setFromComponents(
            (_module.getValue((ptr.toDartInt + (offset * 8)).toJS, "double")
                    as JSNumber)
                .toDartDouble,
            (_module.getValue(
                        (ptr.toDartInt + ((offset + 1) * 8)).toJS, "double")
                    as JSNumber)
                .toDartDouble,
            (_module.getValue(
                        (ptr.toDartInt + ((offset + 2) * 8)).toJS, "double")
                    as JSNumber)
                .toDartDouble,
            (_module.getValue(
                        (ptr.toDartInt + ((offset + 3) * 8)).toJS, "double")
                    as JSNumber)
                .toDartDouble);
    });
    _module._free(ptr);
    throw UnimplementedError();
    // return Frustum()..plane0 = planes[0]..plane1 =planes[1]..plane2 =planes[2]..plane3 =planes[3], planes[4], planes[5]);
  }

  @override
  Future<Matrix4> getCameraModelMatrix() async {
    final ptr = _module._malloc(16 * 8) as JSNumber;
    _module.ccall("get_camera_model_matrix", "void",
        ["void*".toJS, "double*".toJS].toJS, [_viewer!, ptr].toJS, null);
    final matrix = _matrixFromPtr(ptr);
    _module._free(ptr);
    return matrix;
  }

  @override
  Future<Vector3> getCameraPosition() async {
    final ptr = _module._malloc(3 * 8) as JSNumber;
    _module.ccall("get_camera_position", "void",
        ["void*".toJS, "void*".toJS].toJS, [_viewer!, ptr].toJS, null);
    final pos = Vector3(
        (_module.getValue(ptr.toDartInt.toJS, "double") as JSNumber)
            .toDartDouble,
        (_module.getValue((ptr.toDartInt + 8).toJS, "double") as JSNumber)
            .toDartDouble,
        (_module.getValue((ptr.toDartInt + 16).toJS, "double") as JSNumber)
            .toDartDouble);
    _module._free(ptr);
    return pos;
  }

  @override
  Future<Matrix4> getCameraProjectionMatrix() async {
    final ptr = _module._malloc(16 * 8) as JSNumber;
    _module.ccall("get_camera_projection_matrix", "void",
        ["void*".toJS, "double*".toJS].toJS, [_viewer!, ptr].toJS, null);
    final matrix = _matrixFromPtr(ptr);
    _module._free(ptr);
    return matrix;
  }

  @override
  Future<Matrix3> getCameraRotation() async {
    final model = await getCameraModelMatrix();
    final rotation = model.getRotation();
    return rotation;
  }

  @override
  Future<Matrix4> getCameraViewMatrix() async {
    final ptr = _module._malloc(16 * 8) as JSNumber;
    _module.ccall("get_camera_view_matrix", "void",
        ["void*".toJS, "double*".toJS].toJS, [_viewer!, ptr].toJS, null);
    final matrix = Matrix4.zero();
    for (int i = 0; i < 16; i++) {
      matrix[i] = (_module.getValue((ptr.toDartInt + (i * 8)).toJS, "double")
              as JSNumber)
          .toDartDouble;
    }
    _module._free(ptr);
    return matrix;
  }

  @override
  Future<int> getInstanceCount(ThermionEntity entity) async {
    final result = _module.ccall(
        "get_instance_count",
        "int",
        ["void*".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS].toJS,
        null) as JSNumber;
    return result.toDartInt;
  }

  @override
  Future<List<ThermionEntity>> getInstances(ThermionEntity entity) async {
    final instanceCount = await getInstanceCount(entity);
    final buf = _module._malloc(instanceCount * 4) as JSNumber;
    _module.ccall(
        "get_instances",
        "void",
        ["void*".toJS, "int".toJS, "int*".toJS].toJS,
        [_sceneManager!, entity.toJS, buf].toJS,
        null);
    final instances = <ThermionEntity>[];
    for (int i = 0; i < instanceCount; i++) {
      final instanceId =
          _module.getValue((buf.toDartInt + (i * 4)).toJS, "i32") as JSNumber;
      instances.add(instanceId.toDartInt);
    }
    _module._free(buf);
    return instances;
  }

  @override
  Future<Matrix4> getInverseBindMatrix(ThermionEntity parent, int boneIndex,
      {int skinIndex = 0}) async {
    final ptr = _module._malloc(16 * 4) as JSNumber;
    _module.ccall(
        "get_inverse_bind_matrix",
        "void",
        ["void*".toJS, "int".toJS, "int".toJS, "int".toJS, "float*".toJS].toJS,
        [_sceneManager!, parent.toJS, skinIndex.toJS, boneIndex.toJS, ptr].toJS,
        null);
    final matrix = _matrixFromPtr(ptr);
    _module._free(ptr);
    return matrix;
  }

  @override
  Future<Matrix4> getLocalTransform(ThermionEntity entity) async {
    final ptr = _module._malloc(16 * 4) as JSNumber;
    _module.ccall(
        "get_local_transform",
        "void",
        ["void*".toJS, "int".toJS, "float*".toJS].toJS,
        [_sceneManager!, entity.toJS, ptr].toJS,
        null);
    final matrix = _matrixFromPtr(ptr);
    _module._free(ptr);
    return matrix;
  }

  @override
  Future moveCameraToAsset(ThermionEntity entity) async {
    _module.ccall("move_camera_to_asset", "void",
        ["void*".toJS, "int".toJS].toJS, [_viewer!, entity.toJS].toJS, null);
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
    throw UnimplementedError();
    // _module.ccall("filament_pick", "void",
    //     ["void*".toJS, "int".toJS, "int".toJS, "void*".toJS].toJS, [
    //   _viewer!,
    //   x.toJS,
    //   y.toJS,
    //   (entityId, x, y) {}.toJS
    // ]);
  }

  @override
  Future playAnimationByName(ThermionEntity entity, String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    final animationNames = await getAnimationNames(entity);
    final index = animationNames.indexOf(name);
    if (index == -1) {
      throw Exception("Animation ${name} not found.");
    }
    return playAnimation(entity, index,
        loop: loop,
        reverse: reverse,
        replaceActive: replaceActive,
        crossfade: crossfade);
  }

  @override
  Future queuePositionUpdate(
      ThermionEntity entity, double x, double y, double z,
      {bool relative = false}) async {
    _module.ccall(
        "queue_position_update",
        "void",
        [
          "void*".toJS,
          "int".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "bool".toJS
        ].toJS,
        [_sceneManager!, entity.toJS, x.toJS, y.toJS, z.toJS, relative.toJS]
            .toJS,
        null);
  }

  @override
  Future queueRotationUpdate(
      ThermionEntity entity, double rads, double x, double y, double z,
      {bool relative = false}) async {
    _module.ccall(
        "queue_rotation_update",
        "void",
        [
          "void*".toJS,
          "int".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "bool".toJS
        ].toJS,
        [
          _sceneManager!,
          entity.toJS,
          rads.toJS,
          x.toJS,
          y.toJS,
          z.toJS,
          relative.toJS
        ].toJS,
        null);
  }

  @override
  Future queueRotationUpdateQuat(ThermionEntity entity, Quaternion quat,
      {bool relative = false}) async {
    _module.ccall(
        "queue_rotation_update",
        "void",
        [
          "void*".toJS,
          "int".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "bool".toJS
        ].toJS,
        [
          _sceneManager!,
          entity.toJS,
          quat.radians.toJS,
          quat.x.toJS,
          quat.y.toJS,
          quat.z.toJS,
          relative.toJS
        ].toJS,
        null);
  }

  @override
  Future removeAnimationComponent(ThermionEntity entity) async {
    _module.ccall(
        "remove_animation_component",
        "void",
        ["void*".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS].toJS,
        null);
  }

  @override
  Future removeCollisionComponent(ThermionEntity entity) async {
    _module.ccall(
        "remove_collision_component",
        "void",
        ["void*".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS].toJS,
        null);
  }

  @override
  Future removeEntity(ThermionEntity entity) async {
    _module.ccall("remove_entity", "void", ["void*".toJS, "int".toJS].toJS,
        [_viewer!, entity.toJS].toJS, null);
  }

  @override
  Future removeIbl() async {
    _module.ccall(
        "remove_ibl", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
  }

  @override
  Future removeLight(ThermionEntity light) async {
    _module.ccall("remove_light", "void", ["void*".toJS, "int".toJS].toJS,
        [_viewer!, light.toJS].toJS, null);
  }

  @override
  Future removeSkybox() async {
    _module.ccall(
        "remove_skybox", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
  }

  @override
  Future resetBones(ThermionEntity entity) async {
    _module.ccall("reset_to_rest_pose", "void", ["void*".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS].toJS, null);
  }

  @override
  Future reveal(ThermionEntity entity, String? meshName) async {
    if (meshName != null) {
      final result = _module.ccall(
          "reveal_mesh",
          "int",
          ["void*".toJS, "int".toJS, "string".toJS].toJS,
          [_sceneManager!, entity.toJS, meshName.toJS].toJS,
          null) as JSNumber;
      if (result.toDartInt == -1) {
        throw Exception(
            "Failed to reveal mesh ${meshName} on entity ${entity.toJS}");
      }
    } else {
      throw Exception(
          "Cannot reveal mesh, meshName must be specified when invoking this method");
    }
  }

  @override
  Future rotateEnd() {
    // TODO: implement rotateEnd
    throw UnimplementedError();
  }

  @override
  Future rotateIbl(Matrix3 rotation) async {
    final ptr = _module._malloc(9 * 4) as JSNumber;
    for (int i = 0; i < 9; i++) {
      _module.setValue(
          (ptr.toDartInt + (i * 4)).toJS, rotation.storage[i].toJS, "float");
    }
    _module.ccall("rotate_ibl", "void", ["void*".toJS, "float*".toJS].toJS,
        [_viewer!, ptr].toJS, null);
    _module._free(ptr);
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
      ThermionEntity entity, int index, int animationFrame) async {
    _module.ccall(
        "set_animation_frame",
        "void",
        ["void*".toJS, "int".toJS, "int".toJS, "int".toJS].toJS,
        [
          _sceneManager!,
          entity.toJS,
          index.toJS,
          animationFrame.toJS,
        ].toJS,
        null);
  }

  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) async {
    _module.ccall(
        "set_background_image",
        "void",
        ["void*".toJS, "string".toJS, "bool".toJS].toJS,
        [_viewer!, path.toJS, fillHeight.toJS].toJS,
        null);
  }

  @override
  Future setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    _module.ccall(
        "set_background_image_position",
        "void",
        ["void*".toJS, "float".toJS, "float".toJS, "bool".toJS].toJS,
        [_viewer!, x.toJS, y.toJS, clamp.toJS].toJS,
        null);
  }

  @override
  Future setBloom(double bloom) async {
    _module.ccall("set_bloom", "void", ["void*".toJS, "float".toJS].toJS,
        [_viewer!, bloom.toJS].toJS, null);
  }

  @override
  Future setBoneTransform(
      ThermionEntity entity, int boneIndex, Matrix4 transform,
      {int skinIndex = 0}) async {
    final ptr = _module._malloc(16 * 4) as JSNumber;
    for (int i = 0; i < 16; i++) {
      _module.setValue(
          (ptr.toDartInt + (i * 4)).toJS, transform.storage[i].toJS, "float");
    }
    final result = _module.ccall(
        "set_bone_transform",
        "bool",
        ["void*".toJS, "int".toJS, "int".toJS, "int".toJS, "float*".toJS].toJS,
        [_sceneManager!, entity.toJS, skinIndex.toJS, boneIndex.toJS, ptr].toJS,
        null) as JSBoolean;
    _module._free(ptr);
    if (!result.toDart) {
      throw Exception("Failed to set bone transform");
    }
  }

  @override
  Future setCamera(ThermionEntity entity, String? name) async {
    final result = _module.ccall(
        "set_camera",
        "bool",
        ["void*".toJS, "int".toJS, "string".toJS].toJS,
        [_viewer!, entity.toJS, (name ?? "").toJS].toJS,
        null) as JSBoolean;
    if (!result.toDart) {
      throw Exception("Failed to set camera to entity ${entity}");
    }
  }

  @override
  Future setCameraCulling(double near, double far) async {
    _module.ccall(
        "set_camera_culling",
        "void",
        ["void*".toJS, "double".toJS, "double".toJS].toJS,
        [_viewer!, near.toJS, far.toJS].toJS,
        null);
  }

  @override
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    _module.ccall(
        "set_camera_exposure",
        "void",
        ["void*".toJS, "float".toJS, "float".toJS, "float".toJS].toJS,
        [
          _viewer!,
          aperture.toJS,
          shutterSpeed.toJS,
          sensitivity.toJS,
        ].toJS,
        null);
  }

  @override
  Future setCameraFocalLength(double focalLength) async {
    _module.ccall(
        "set_camera_focal_length",
        "void",
        ["void*".toJS, "float".toJS].toJS,
        [_viewer!, focalLength.toJS].toJS,
        null);
  }

  @override
  Future setCameraFocusDistance(double focusDistance) async {
    _module.ccall(
        "set_camera_focus_distance",
        "void",
        ["void*".toJS, "float".toJS].toJS,
        [_viewer!, focusDistance.toJS].toJS,
        null);
  }

  @override
  Future setCameraFov(double degrees, double width, double height) async {
    _module.ccall(
        "set_camera_fov",
        "void",
        ["void*".toJS, "float".toJS, "float".toJS].toJS,
        [_viewer!, degrees.toJS, (width / height).toJS].toJS,
        null);
  }

  @override
  Future setCameraManipulatorOptions(
      {ManipulatorMode mode = ManipulatorMode.ORBIT,
      double orbitSpeedX = 0.01,
      double orbitSpeedY = 0.01,
      double zoomSpeed = 0.01}) async {
    _module.ccall(
        "set_camera_manipulator_options",
        "void",
        ["void*".toJS, "int".toJS, "double".toJS, "double".toJS, "double".toJS]
            .toJS,
        [
          _viewer!,
          mode.index.toJS,
          orbitSpeedX.toJS,
          orbitSpeedY.toJS,
          zoomSpeed.toJS
        ].toJS,
        null);
  }

  @override
  Future setCameraModelMatrix(List<double> matrix) async {
    assert(matrix.length == 16, "Matrix must have 16 elements");
    final ptr = _module._malloc(16 * 8) as JSNumber;
    for (int i = 0; i < 16; i++) {
      _module.setValue(
          (ptr.toDartInt + (i * 8)).toJS, matrix[i].toJS, "double");
    }
    _module.ccall("set_camera_model_matrix", "void",
        ["void*".toJS, "float*".toJS].toJS, [_viewer!, ptr].toJS, null);
    _module._free(ptr);
  }

  @override
  Future setFrameRate(int framerate) async {
    _module.ccall(
        "set_frame_interval",
        "void",
        ["void*".toJS, "float".toJS].toJS,
        [_viewer!, (1 / framerate).toJS].toJS,
        null);
  }

  @override
  Future setMainCamera() async {
    _module.ccall(
        "set_main_camera", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
  }

  @override
  Future setMaterialColor(ThermionEntity entity, String meshName,
      int materialIndex, double r, double g, double b, double a) async {
    final result = _module.ccall(
        "set_material_color",
        "bool",
        [
          "void*".toJS,
          "int".toJS,
          "string".toJS,
          "int".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS,
          "float".toJS
        ].toJS,
        [
          _sceneManager!,
          entity.toJS,
          meshName.toJS,
          materialIndex.toJS,
          r.toJS,
          g.toJS,
          b.toJS,
          a.toJS
        ].toJS,
        null) as JSBoolean;
    if (!result.toDart) {
      throw Exception("Failed to set material color");
    }
  }

  @override
  Future setMorphTargetWeights(
      ThermionEntity entity, List<double> weights) async {
    final numWeights = weights.length;
    final ptr = _module._malloc(numWeights * 4);
    for (int i = 0; i < numWeights; i++) {
      _module.setValue(
          (ptr.toDartInt + (i * 4)).toJS, weights[i].toJS, "float");
    }
    final result = _module.ccall(
        "set_morph_target_weights",
        "bool",
        ["void*".toJS, "int".toJS, "float*".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS, ptr, numWeights.toJS].toJS,
        null) as JSBoolean;
    _module._free(ptr);
    if (!result.toDart) {
      throw Exception("Failed to set morph target weights");
    }
  }

  @override
  Future setParent(ThermionEntity child, ThermionEntity parent) async {
    _module.ccall(
        "set_parent",
        "void",
        ["void*".toJS, "int".toJS, "int".toJS].toJS,
        [_sceneManager!, child.toJS, parent.toJS].toJS,
        null);
  }

  @override
  Future setPriority(ThermionEntity entityId, int priority) {
    // TODO: implement setPriority
    throw UnimplementedError();
  }

  @override
  Future setRecording(bool recording) async {
    _module.ccall("set_recording", "void", ["void*".toJS, "bool".toJS].toJS,
        [_viewer!, recording.toJS].toJS, null);
  }

  @override
  Future setRecordingOutputDirectory(String outputDirectory) async {
    _module.ccall(
        "set_recording_output_directory",
        "void",
        ["void*".toJS, "string".toJS].toJS,
        [_viewer!, outputDirectory.toJS].toJS,
        null);
  }

  Timer? _renderLoop;

  @override
  Future setRendering(bool render) async {
    if (render && !_rendering) {
      _rendering = true;
      _renderLoop = Timer.periodic(Duration(microseconds: 16667), (_) {
        this.render();
      });
    } else if (!render && _rendering) {
      _rendering = false;
      _renderLoop?.cancel();
      _renderLoop = null;
    }
  }

  @override
  Future setScale(ThermionEntity entity, double scale) async {
    _module.ccall(
        "set_scale",
        "void",
        ["void*".toJS, "int".toJS, "float".toJS].toJS,
        [_sceneManager!, entity.toJS, scale.toJS].toJS,
        null);
  }

  @override
  Future setToneMapping(ToneMapper mapper) async {
    _module.ccall("set_tone_mapping", "void", ["void*".toJS, "int".toJS].toJS,
        [_viewer!, mapper.index.toJS].toJS, null);
  }

  @override
  Future setTransform(ThermionEntity entity, Matrix4 transform) async {
    final ptr = _module._malloc(16 * 4) as JSNumber;
    for (int i = 0; i < 16; i++) {
      _module.setValue(
          (ptr.toDartInt + (i * 4)).toJS, transform.storage[i].toJS, "float");
    }
    final result = _module.ccall(
        "set_transform",
        "bool",
        ["void*".toJS, "int".toJS, "float*".toJS].toJS,
        [_sceneManager!, entity.toJS, ptr].toJS,
        null) as JSBoolean;
    _module._free(ptr);
    if (!result.toDart) {
      throw Exception("Failed to set transform");
    }
  }

  @override
  Future setViewFrustumCulling(bool enabled) async {
    _module.ccall("set_view_frustum_culling", "void",
        ["void*".toJS, "bool".toJS].toJS, [_viewer!, enabled.toJS].toJS, null);
  }

  @override
  Future stopAnimation(ThermionEntity entity, int animationIndex) async {
    _module.ccall(
        "stop_animation",
        "void",
        ["void*".toJS, "int".toJS, "int".toJS].toJS,
        [_sceneManager!, entity.toJS, animationIndex.toJS].toJS,
        null);
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
  Future setShadowType(ShadowType shadowType) async {
    _module.ccall("set_shadow_type", "void", ["void*".toJS, "int".toJS].toJS,
        [_viewer!, shadowType.index.toJS].toJS, null);
  }

  @override
  Future setShadowsEnabled(bool enabled) async {
    _module.ccall("set_shadows_enabled", "void",
        ["void*".toJS, "bool".toJS].toJS, [_viewer!, enabled.toJS].toJS, null);
  }

  @override
  Future setSoftShadowOptions(
      double penumbraScale, double penumbraRatioScale) async {
    _module.ccall(
        "set_soft_shadow_options",
        "void",
        ["void*".toJS, "float".toJS, "float".toJS].toJS,
        [_viewer!, penumbraScale.toJS, penumbraRatioScale.toJS].toJS,
        null);
  }
}
