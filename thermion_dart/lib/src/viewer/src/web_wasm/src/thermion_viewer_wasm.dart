// import 'dart:async';
// import 'dart:js_interop';
// import 'dart:js_interop_unsafe';
// import 'dart:math';
// import 'dart:typed_data' as td;
// import 'dart:typed_data';
// import 'package:logging/logging.dart';
// import 'package:web/web.dart';
// import 'package:animation_tools_dart/animation_tools_dart.dart';

// import 'package:vector_math/vector_math_64.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../../shared_types/internal/gizmo.dart';
// import '../../shared_types/internal/gizmo.dart';
// import '../../../viewer.dart';
// import '../../events.dart';
// import '../../shared_types/camera.dart';
// import 'camera.dart';
// import 'material_instance.dart';

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

  external JSNumber addFunction(JSFunction f, String signature);
  external void removeFunction(JSNumber f);
  external JSAny get ALLOC_STACK;
  external JSAny get HEAPU32;
  external JSAny get HEAP32;
}

// typedef ThermionViewerImpl = ThermionViewerWasm;

// ///
// /// A [ThermionViewer] implementation that forwards calls to the
// /// (Emscripten-generated) ThermionDart JS module.
// ///
// class ThermionViewerWasm implements ThermionViewer {
//   final _logger = Logger("ThermionViewerWasm");

//   _EmscriptenModule? _module;

//   bool _initialized = false;
//   bool _rendering = false;

//   String? assetPathPrefix;

//   late (double, double) viewportDimensions;

//   late double pixelRatio;

//   ///
//   /// Construct an instance of this class by explicitly passing the
//   /// module instance via the [module] property, or by specifying [moduleName],
//   /// being the name of the window property where the module has already been
//   /// loaded.
//   ///
//   /// Pass [assetPathPrefix] if you need to prepend a path to all asset paths
//   /// (e.g. on Flutter where the asset directory /foo is actually shipped under
//   /// the directory /assets/foo, you would construct this as:
//   ///
//   /// final viewer = ThermionViewerWasm(assetPathPrefix:"/assets/")
//   ///
//   ThermionViewerWasm({JSObject? module, this.assetPathPrefix}) {
//     if (module != null) {
//       _module = module as _EmscriptenModule;
//     }
//   }
//   void _setAssetPathPrefix(String assetPathPrefix) {
//     _module!.ccall(
//         "thermion_dart_web_set_asset_path_prefix",
//         "void",
//         <JSString>["string".toJS].toJS,
//         <JSAny>[assetPathPrefix.toJS].toJS,
//         null);
//   }

//   JSNumber? _viewer;
//   JSNumber? _sceneManager;
//   int _width = 0;
//   int _height = 0;

//   Future initialize(double width, double height, double pixelRatio,
//       {String? uberArchivePath}) async {
//     if (!_initialized) {
//       await _initializeModule();
//       _initialized = true;
//       if (assetPathPrefix != null) {
//         _setAssetPathPrefix(assetPathPrefix!);
//       }
//     }
//     this.pixelRatio = pixelRatio;

//     final context = _module!.ccall("thermion_dart_web_create_gl_context", "int",
//         <JSString>[].toJS, <JSAny>[].toJS, null);
//     final loader = _module!.ccall(
//         "thermion_dart_web_get_resource_loader_wrapper",
//         "void*",
//         <JSString>[].toJS,
//         <JSAny>[].toJS,
//         null);
//     _viewer = _module!.ccall(
//         "create_filament_viewer",
//         "void*",
//         ["void*".toJS, "void*".toJS, "void*".toJS, "string".toJS].toJS,
//         [context!, loader, null, uberArchivePath?.toJS].toJS,
//         null) as JSNumber;
//     await createSwapChain(width.ceil(), height.ceil());
//     setViewportAndCameraProjection(width.ceil(), height.ceil(), 1.0);
//     _sceneManager = _module!.ccall("get_scene_manager", "void*",
//         ["void*".toJS].toJS, [_viewer!].toJS, null) as JSNumber;

//     _pickCallbackPtr = _module!.addFunction(_onPickCallback.toJS, "viii");
//     _pickGizmoCallbackPtr =
//         _module!.addFunction(_onPickGizmoCallback.toJS, "viii");

//     var gizmoOut = _module!._malloc(4 * 4);

//     _module!.ccall("get_gizmo", "void", ["void*".toJS, "void*".toJS].toJS,
//         [_sceneManager!, gizmoOut].toJS, null);

//     var x = _module!.getValue(gizmoOut, "i32") as JSNumber;
//     var y = _module!.getValue((gizmoOut.toDartInt + 4).toJS, "i32") as JSNumber;
//     var z = _module!.getValue((gizmoOut.toDartInt + 8).toJS, "i32") as JSNumber;
//     var center =
//         _module!.getValue((gizmoOut.toDartInt + 12).toJS, "i32") as JSNumber;
//     _gizmo =
//         Gizmo(x.toDartInt, y.toDartInt, z.toDartInt, center.toDartInt, this);
//     _module!._free(gizmoOut);
//     _initialized = true;
//   }

//   Future<void> _initializeModule() async {
//     var moduleScript = document.createElement("script") as HTMLScriptElement;

//     globalContext["exports"] = JSObject();
//     var module = JSObject();
//     globalContext["module"] = module;
//     var content = await http.get(Uri.parse("thermion_dart.js"));
//     moduleScript.innerHTML = content.body.toJS;
//     document.head!.appendChild(moduleScript);
//     var instantiate = module.getProperty("exports".toJS) as JSFunction;
//     var moduleInstance =
//         instantiate.callAsFunction() as JSPromise<_EmscriptenModule>;
//     _module = await moduleInstance.toDart;
//   }

//   Future createSwapChain(int width, int height) async {
//     _module!.ccall(
//         "create_swap_chain",
//         "void",
//         ["void*".toJS, "void*".toJS, "uint32_t".toJS, "uint32_t".toJS].toJS,
//         [_viewer!, null, width.toJS, height.toJS].toJS,
//         null);
//   }

//   Future destroySwapChain() async {
//     if (_viewer == null) {
//       return;
//     }
//     _module!.ccall("destroy_swap_chain", "void", ["void*".toJS].toJS,
//         [_viewer!].toJS, null);
//   }

//   void setViewportAndCameraProjection(
//       int width, int height, double scaleFactor) {
//     if (width == 0 || height == 0) {
//       throw Exception("Width/height must be greater than zero");
//     }
//     _width = (width * pixelRatio).ceil();
//     _height = (height * pixelRatio).ceil();
//     viewportDimensions = (_width.toDouble(), _height.toDouble());
//     _module!.ccall(
//         "update_viewport_and_camera_projection",
//         "void",
//         ["void*".toJS, "uint32_t".toJS, "uint32_t".toJS, "float".toJS].toJS,
//         [_viewer!, _width.toJS, _height.toJS, scaleFactor.toJS].toJS,
//         null);
//   }

//   @override
//   Future<bool> get initialized async {
//     return _initialized;
//   }

//   ///
//   ///
//   ///
//   final _pickResultController =
//       StreamController<FilamentPickResult>.broadcast();

//   @override
//   Stream<FilamentPickResult> get pickResult {
//     return _pickResultController.stream;
//   }

//   @override
//   Stream<FilamentPickResult> get gizmoPickResult =>
//       _gizmoPickResultController.stream;
//   final _gizmoPickResultController =
//       StreamController<FilamentPickResult>.broadcast();

//   @override
//   bool get rendering => _rendering;

//   @override
//   Future dispose() async {
//     if (_viewer == null) {
//       // we've already cleaned everything up, ignore the call to dispose
//       return;
//     }
//     await setRendering(false);
//     await destroyAssets();
//     await destroyLights();
//     _destroyViewer();

//     _sceneManager = null;
//     _viewer = null;

//     for (final callback in _onDispose) {
//       await callback.call();
//     }
//     _onDispose.clear();
//     _module!.removeFunction(_pickCallbackPtr);
//     _module!.removeFunction(_pickGizmoCallbackPtr);
//   }

//   void _destroyViewer() {
//     _module!.ccall("Viewer_destroy", "void", ["void*".toJS].toJS,
//         [_viewer].toJS, null);
//   }

//   @override
//   Future setBackgroundColor(double r, double g, double b, double alpha) async {
//     _module!.ccall(
//         "set_background_color",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS, "float".toJS, "float".toJS]
//             .toJS,
//         [_viewer!, r.toJS, g.toJS, b.toJS, alpha.toJS].toJS,
//         null);
//   }

//   @override
//   Future addAnimationComponent(ThermionEntity entity) async {
//     _module!.ccall(
//         "add_animation_component",
//         "bool",
//         ["void*".toJS, "int32_t".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null);
//   }

//   Matrix4 _matrixFromPtr(JSNumber matPtr) {
//     final mat = Matrix4.zero();
//     for (int i = 0; i < 16; i++) {
//       mat[i] = (_module!.getValue((matPtr.toDartInt + (i * 4)).toJS, "float")
//               as JSNumber)
//           .toDartDouble;
//     }
//     return mat;
//   }

//   @override
//   Future<List<Matrix4>> getRestLocalTransforms(ThermionEntity entity,
//       {int skinIndex = 0}) async {
//     var boneCountJS = _module!.ccall(
//         "get_bone_count",
//         "int",
//         ["void*".toJS, "int".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS, skinIndex.toJS].toJS,
//         null) as JSNumber;
//     var boneCount = boneCountJS.toDartInt;
//     var buf = _module!._malloc(boneCount * 16 * 4);
//     _module!.ccall(
//         "get_rest_local_transforms",
//         "void",
//         ["void*".toJS, "int".toJS, "int".toJS, "float*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS, skinIndex.toJS, buf, boneCount.toJS].toJS,
//         null);
//     var transforms = <Matrix4>[];
//     for (int i = 0; i < boneCount; i++) {
//       var matPtr = (buf.toDartInt + (i * 16 * 4)).toJS;
//       transforms.add(_matrixFromPtr(matPtr));
//     }
//     _module!._free(buf);
//     return transforms;
//   }

//   @override
//   Future<ThermionEntity> getBone(ThermionEntity parent, int boneIndex,
//       {int skinIndex = 0}) async {
//     final boneId = _module!.ccall(
//         "get_bone",
//         "int",
//         ["void*".toJS, "int32_t".toJS, "int32_t".toJS, "int32_t".toJS].toJS,
//         [_sceneManager!, parent.toJS, skinIndex.toJS, boneIndex.toJS].toJS,
//         null) as JSNumber;
//     if (boneId.toDartInt == -1) {
//       throw Exception("Failed to get bone");
//     }
//     return boneId.toDartInt;
//   }

//   Future<List<ThermionEntity>> getBones(ThermionEntity entity,
//       {int skinIndex = 0}) async {
//     final boneNames = await getBoneNames(entity);
//     final bones = await Future.wait(List.generate(
//         boneNames.length, (i) => getBone(entity, i, skinIndex: skinIndex)));
//     return bones;
//   }

//   @override
//   Future addBoneAnimation(ThermionEntity entity, BoneAnimationData animation,
//       {int skinIndex = 0,
//       double fadeInInSecs = 0.0,
//       double fadeOutInSecs = 0.0,
//       double maxDelta = 1.0}) async {
//     final boneNames = await getBoneNames(entity);
//     final bones = await getBones(entity);

//     var numBytes = animation.numFrames * 16 * 4;
//     var floatPtr = _module!._malloc(numBytes);

//     var restLocalTransforms = await getRestLocalTransforms(entity);

//     for (int i = 0; i < animation.bones.length; i++) {
//       final boneName = animation.bones[i];
//       final entityBoneIndex = boneNames.indexOf(boneName);

//       var boneEntity = bones[entityBoneIndex];

//       var baseTransform = restLocalTransforms[entityBoneIndex];

//       var world = Matrix4.identity();

//       // this odd use of ! is intentional, without it, the WASM optimizer gets in trouble
//       var parentBoneEntity = (await getParent(boneEntity))!;
//       while (true) {
//         if (!bones.contains(parentBoneEntity!)) {
//           break;
//         }
//         world = restLocalTransforms[bones.indexOf(parentBoneEntity!)] * world;
//         parentBoneEntity = (await getParent(parentBoneEntity))!;
//       }

//       world = Matrix4.identity()..setRotation(world.getRotation());
//       var worldInverse = Matrix4.identity()..copyInverse(world);

//       for (int frameNum = 0; frameNum < animation.numFrames; frameNum++) {
//         var rotation = animation.frameData[frameNum][i].rotation;
//         var translation = animation.frameData[frameNum][i].translation;
//         var frameTransform =
//             Matrix4.compose(translation, rotation, Vector3.all(1.0));
//         var newLocalTransform = frameTransform.clone();
//         if (animation.space == Space.Bone) {
//           newLocalTransform = baseTransform * frameTransform;
//         } else if (animation.space == Space.ParentWorldRotation) {
//           newLocalTransform =
//               baseTransform * (worldInverse * frameTransform * world);
//         }
//         for (int j = 0; j < 16; j++) {
//           var offset = ((frameNum * 16) + j) * 4;
//           _module!.setValue((floatPtr.toDartInt + offset).toJS,
//               newLocalTransform.storage[j].toJS, "float");
//         }
//       }

//       _module!.ccall(
//           "add_bone_animation",
//           "void",
//           [
//             "void*".toJS,
//             "int".toJS,
//             "int".toJS,
//             "int".toJS,
//             "float*".toJS,
//             "int".toJS,
//             "float".toJS,
//             "float".toJS,
//             "float".toJS,
//             "float".toJS
//           ].toJS,
//           [
//             _sceneManager!,
//             entity.toJS,
//             skinIndex.toJS,
//             entityBoneIndex.toJS,
//             floatPtr,
//             animation.numFrames.toJS,
//             animation.frameLengthInMs.toJS,
//             fadeOutInSecs.toJS,
//             fadeInInSecs.toJS,
//             maxDelta.toJS
//           ].toJS,
//           null);
//     }
//     _module!._free(floatPtr);
//   }

//   @override
//   Future addCollisionComponent(ThermionEntity entity,
//       {void Function(int entityId1, int entityId2)? callback,
//       bool affectsTransform = false}) {
//     // TODO: implement addCollisionComponent
//     throw UnimplementedError();
//   }

//   @override
//   Future<ThermionEntity> addLight(
//       LightType type,
//       double colour,
//       double intensity,
//       double posX,
//       double posY,
//       double posZ,
//       double dirX,
//       double dirY,
//       double dirZ,
//       {double falloffRadius = 1.0,
//       double spotLightConeInner = pi / 8,
//       double spotLightConeOuter = pi / 4,
//       double sunAngularRadius = 0.545,
//       double sunHaloSize = 10.0,
//       double sunHaloFallof = 80.0,
//       bool castShadows = true}) async {
//     final entityId = _module!.ccall(
//         "add_light",
//         "int",
//         [
//           "void*".toJS,
//           "uint8_t".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "bool".toJS
//         ].toJS,
//         [
//           _viewer,
//           type.index.toJS,
//           colour.toJS,
//           intensity.toJS,
//           posX.toJS,
//           posY.toJS,
//           posZ.toJS,
//           dirX.toJS,
//           dirY.toJS,
//           dirZ.toJS,
//           falloffRadius.toJS,
//           spotLightConeInner.toJS,
//           spotLightConeOuter.toJS,
//           sunAngularRadius.toJS,
//           sunHaloSize.toJS,
//           sunHaloFallof.toJS,
//           castShadows.toJS
//         ].toJS,
//         null) as JSNumber;
//     if (entityId.toDartInt == -1) {
//       throw Exception("Failed to add light");
//     }
//     return entityId.toDartInt;
//   }

//   @override
//   Future<List<String>> getBoneNames(ThermionEntity entity,
//       {int skinIndex = 0}) async {
//     var boneCountJS = _module!.ccall(
//         "get_bone_count",
//         "int",
//         ["void*".toJS, "int".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS, skinIndex.toJS].toJS,
//         null) as JSNumber;
//     var boneCount = boneCountJS.toDartInt;
//     var buf = _module!._malloc(boneCount * 4);

//     var empty = " ".toJS;
//     var ptrs = <JSNumber>[];
//     for (int i = 0; i < boneCount; i++) {
//       var ptr = _module!._malloc(256);
//       _module!.stringToUTF8(empty, ptr, 255.toJS);
//       ptrs.add(ptr);
//       _module!.setValue((buf.toDartInt + (i * 4)).toJS, ptr, "i32");
//     }
//     _module!.ccall(
//         "get_bone_names",
//         "void",
//         ["void*".toJS, "int".toJS, "char**".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS, buf, skinIndex.toJS].toJS,
//         null);
//     var names = <String>[];
//     for (int i = 0; i < boneCount; i++) {
//       var name = _module!.UTF8ToString(ptrs[i]).toDart;
//       names.add(name);
//     }

//     return names;
//   }

//   @override
//   Future<List<ThermionEntity>> getChildEntities(
//       ThermionEntity parent, bool renderableOnly) async {
//     var entityCountJS = _module!.ccall(
//         "get_entity_count",
//         "int",
//         ["void*".toJS, "int".toJS, "bool".toJS].toJS,
//         [_sceneManager!, parent.toJS, renderableOnly.toJS].toJS,
//         null) as JSNumber;
//     var entityCount = entityCountJS.toDartInt;
//     var entities = <ThermionEntity>[];
//     var buf = _module!._malloc(entityCount * 4);

//     _module!.ccall(
//         "get_entities",
//         "void",
//         ["void*".toJS, "int".toJS, "bool".toJS, "int*".toJS].toJS,
//         [_sceneManager!, parent.toJS, renderableOnly.toJS, buf].toJS,
//         null);
//     for (int i = 0; i < entityCount; i++) {
//       var entityId =
//           _module!.getValue((buf.toDartInt + (i * 4)).toJS, "i32") as JSNumber;
//       entities.add(entityId.toDartInt);
//     }
//     _module!._free(buf);
//     return entities;
//   }

//   @override
//   Future<ThermionEntity> getChildEntity(
//       ThermionEntity parent, String childName) async {
//     final entityId = _module!.ccall(
//         "find_child_entity_by_name",
//         "int",
//         ["void*".toJS, "int".toJS, "string".toJS].toJS,
//         [_sceneManager!, parent.toJS, childName.toJS].toJS,
//         null) as JSNumber;
//     if (entityId.toDartInt == -1) {
//       throw Exception("Failed to find child entity");
//     }
//     return entityId.toDartInt;
//   }

//   @override
//   Future<List<String>> getChildEntityNames(ThermionEntity entity,
//       {bool renderableOnly = true}) async {
//     var entityCountJS = _module!.ccall(
//         "get_entity_count",
//         "int",
//         ["void*".toJS, "int".toJS, "bool".toJS].toJS,
//         [_sceneManager!, entity.toJS, renderableOnly.toJS].toJS,
//         null) as JSNumber;
//     var entityCount = entityCountJS.toDartInt;
//     var names = <String>[];
//     for (int i = 0; i < entityCount; i++) {
//       var namePtr = _module!.ccall(
//           "get_entity_name_at",
//           "char*",
//           ["void*".toJS, "int".toJS, "int".toJS, "bool".toJS].toJS,
//           [_sceneManager!, entity.toJS, i.toJS, renderableOnly.toJS].toJS,
//           null) as JSNumber;
//       names.add(_module!.UTF8ToString(namePtr).toDart);
//     }
//     return names;
//   }

//   @override
//   Future<Camera> getMainCamera() async {
//     var mainCameraEntity = await getMainCameraEntity();
//     return ThermionWasmCamera(mainCameraEntity);
//   }

//   @override
//   Future<List<String>> getMorphTargetNames(
//       ThermionEntity entity, ThermionEntity childEntity) async {
//     var morphTargetCountJS = _module!.ccall(
//         "get_morph_target_name_count",
//         "int",
//         ["void*".toJS, "int32_t".toJS, "int32_t".toJS].toJS,
//         [_sceneManager!, entity.toJS, childEntity.toJS].toJS,
//         null) as JSNumber;
//     var morphTargetCount = morphTargetCountJS.toDartInt;
//     var names = <String>[];
//     for (int i = 0; i < morphTargetCount; i++) {
//       var buf = _module!._malloc(256);
//       _module!.ccall(
//           "get_morph_target_name",
//           "void",
//           [
//             "void*".toJS,
//             "int32_t".toJS,
//             "int32_t".toJS,
//             "char*".toJS,
//             "int32_t".toJS
//           ].toJS,
//           [_sceneManager!, entity.toJS, childEntity.toJS, buf, i.toJS].toJS,
//           null);
//       names.add(_module!.UTF8ToString(buf).toDart);
//       _module!._free(buf);
//     }
//     return names;
//   }

//   @override
//   String? getNameForEntity(ThermionEntity entity) {
//     final namePtr = _module!.ccall(
//         "get_name_for_entity",
//         "char*",
//         ["void*".toJS, "int32_t".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null) as JSNumber;
//     if (namePtr.toDartInt == 0) {
//       return null;
//     }
//     return _module!.UTF8ToString(namePtr).toDart;
//   }

//   @override
//   Future<ThermionEntity?> getParent(ThermionEntity child) async {
//     final parentId = _module!.ccall(
//         "get_parent",
//         "int",
//         ["void*".toJS, "int32_t".toJS].toJS,
//         [_sceneManager!, child.toJS].toJS,
//         null) as JSNumber;
//     if (parentId.toDartInt == -1) {
//       return null;
//     }
//     return parentId.toDartInt;
//   }

//   @override
//   Future<Matrix4> getWorldTransform(ThermionEntity entity) async {
//     final matrixPtr = _module!._malloc(16 * 4);
//     _module!.ccall(
//         "get_world_transform",
//         "void",
//         ["void*".toJS, "int32_t".toJS, "float*".toJS].toJS,
//         [_sceneManager!, entity.toJS, matrixPtr].toJS,
//         null);
//     final matrix = _matrixFromPtr(matrixPtr);
//     _module!._free(matrixPtr);
//     return matrix;
//   }

//   @override
//   AbstractGizmo? get gizmo => _gizmo;
//   Gizmo? _gizmo;

//   @override
//   Future hide(ThermionEntity entity, String? meshName) async {
//     if (meshName != null) {
//       final result = _module!.ccall(
//           "hide_mesh",
//           "int",
//           ["void*".toJS, "int".toJS, "string".toJS].toJS,
//           [_sceneManager!, entity.toJS, meshName.toJS].toJS,
//           null) as JSNumber;
//       if (result.toDartInt == -1) {
//         throw Exception(
//             "Failed to hide mesh ${meshName} on entity ${entity.toJS}");
//       }
//     } else {
//       throw Exception(
//           "Cannot hide mesh, meshName must be specified when invoking this method");
//     }
//   }

//   Future<ThermionEntity> loadGlbFromBuffer(Uint8List data,
//       {int numInstances = 1, bool keepData= false, int layer=0, int priority=4}) async {
//     if (numInstances != 1) {
//       throw Exception("TODO");
//     }
//     final ptr = _module!._malloc(data.length);
//     _module!.writeArrayToMemory(data.toJS, ptr);

//     final result = _module!.ccall(
//         "load_glb_from_buffer",
//         "int",
//         ["void*".toJS, "void*".toJS, "size_t".toJS].toJS,
//         [_sceneManager!, ptr, data.lengthInBytes.toJS].toJS,
//         null) as JSNumber;
//     final entityId = result.toDartInt;
//     _module!._free(ptr);
//     if (entityId == -1) {
//       throw Exception("Failed to load GLB");
//     }
//     return entityId;
//   }

//   @override
//   Future<ThermionEntity> loadGlb(String path,
//       {int numInstances = 1, bool keepData = false}) async {
//     final promise = _module!.ccall(
//         "load_glb",
//         "int",
//         ["void*".toJS, "string".toJS, "int".toJS].toJS,
//         [_sceneManager!, path.toJS, numInstances.toJS].toJS,
//         {"async": true}.jsify()) as JSPromise<JSNumber>;
//     final entityId = (await promise.toDart).toDartInt;
//     if (entityId == -1) {
//       throw Exception("Failed to load GLB");
//     }
//     return entityId;
//   }

//   @override
//   Future<ThermionEntity> loadGltf(String path, String relativeResourcePath,
//       {bool keepData = false}) async {
//     final promise = _module!.ccall(
//         "load_gltf",
//         "int",
//         ["void*".toJS, "string".toJS, "string".toJS].toJS,
//         [_sceneManager!, path.toJS, relativeResourcePath.toJS].toJS,
//         {"async": true}.jsify()) as JSPromise<JSNumber>;
//     final entityId = (await promise.toDart).toDartInt;
//     if (entityId == -1) {
//       throw Exception("Failed to load GLTF");
//     }
//     return entityId;
//   }

//   @override
//   Future loadIbl(String lightingPath, {double intensity = 30000}) async {
//     var promise = _module!.ccall(
//         "load_ibl",
//         "void",
//         ["void*".toJS, "string".toJS, "float".toJS].toJS,
//         [_viewer!, lightingPath.toJS, intensity.toJS].toJS,
//         {"async": true}.jsify()) as JSPromise;
//     await promise.toDart;
//   }

//   @override
//   Future loadSkybox(String skyboxPath) async {
//     var promise = _module!.ccall(
//         "load_skybox",
//         "void",
//         ["void*".toJS, "string".toJS].toJS,
//         [_viewer!, skyboxPath.toJS].toJS,
//         {"async": true}.jsify()) as JSPromise;
//     await promise.toDart;
//   }

//   @override
//   Future playAnimation(ThermionEntity entity, int index,
//       {bool loop = false,
//       bool reverse = false,
//       bool replaceActive = true,
//       double crossfade = 0.0,
//       double startOffset = 0.0}) async {
//     _module!.ccall(
//         "play_animation",
//         "void",
//         [
//           "void*".toJS,
//           "int32_t".toJS,
//           "int32_t".toJS,
//           "bool".toJS,
//           "bool".toJS,
//           "bool".toJS,
//           "float".toJS,
//           "float".toJS
//         ].toJS,
//         [
//           _sceneManager!,
//           entity.toJS,
//           index.toJS,
//           loop.toJS,
//           reverse.toJS,
//           replaceActive.toJS,
//           crossfade.toJS
//         ].toJS,
//         null);
//   }

//   int _last = 0;

//   @override
//   Future render() async {
//     _last = DateTime.now().millisecondsSinceEpoch * 1000000;
//     _module!.ccall(
//         "render",
//         "void",
//         [
//           "void*".toJS,
//           "uint64_t".toJS,
//           "void*".toJS,
//           "void*".toJS,
//           "void*".toJS
//         ].toJS,
//         [
//           _viewer!,
//           0.toJS,
//           null, // pixelBuffer,
//           null, // callback
//           null // data
//         ].toJS,
//         null);
//   }

//   Future<Uint8List> capture() async {
//     bool wasRendering = rendering;
//     await setRendering(false);
//     final pixelBuffer = _module!._malloc(_width * _height * 4);
//     final completer = Completer();
//     final callback = () {
//       completer.complete();
//     };
//     final callbackPtr = _module!.addFunction(callback.toJS, "v");

//     _module!.ccall(
//         "capture",
//         "void",
//         ["void*".toJS, "uint8_t*".toJS, "void*".toJS].toJS,
//         [_viewer!, pixelBuffer, callbackPtr].toJS,
//         null);

//     int iter = 0;
//     while (true) {
//       await Future.delayed(Duration(milliseconds: 5));
//       await render();
//       if (completer.isCompleted) {
//         break;
//       }
//       iter++;
//       if (iter > 1000) {
//         _module!._free(pixelBuffer);
//         throw Exception("Failed to complete capture");
//       }
//     }

//     // Create a Uint8ClampedList to store the pixel data
//     var data = Uint8List(_width * _height * 4);
//     for (int i = 0; i < data.length; i++) {
//       data[i] = (_module!.getValue(((pixelBuffer.toDartInt) + i).toJS, "i8")
//               as JSNumber)
//           .toDartInt;
//     }
//     _module!._free(pixelBuffer);
//     await setRendering(wasRendering);
//     print("Captured to ${data.length} pixel buffer");
//     _module!.removeFunction(callbackPtr);

//     return data;
//   }

//   @override
//   Future setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
//     _module!.ccall(
//         "set_antialiasing",
//         "void",
//         ["void*".toJS, "bool".toJS, "bool".toJS, "bool".toJS].toJS,
//         [_viewer!, msaa.toJS, fxaa.toJS, taa.toJS].toJS,
//         null);
//   }

//   @override
//   Future setCameraPosition(double x, double y, double z) async {
//     _module!.ccall(
//         "set_camera_position",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS, "float".toJS].toJS,
//         [_viewer!, x.toJS, y.toJS, z.toJS].toJS,
//         null);
//   }

//   @override
//   Future setCameraRotation(Quaternion quaternion) async {
//     _module!.ccall(
//         "set_camera_rotation",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS, "float".toJS, "float".toJS]
//             .toJS,
//         [
//           _viewer!,
//           quaternion.w.toJS,
//           quaternion.x.toJS,
//           quaternion.y.toJS,
//           quaternion.z.toJS
//         ].toJS,
//         null);
//   }

//   @override
//   Future clearMorphAnimationData(ThermionEntity entity) async {
//     var meshEntities = await getChildEntities(entity, false);
//     for (final childEntity in meshEntities) {
//       _module!.ccall(
//           "clear_morph_animation",
//           "void",
//           [
//             "void*".toJS,
//             "int".toJS,
//           ].toJS,
//           [
//             _sceneManager!,
//             childEntity.toJS,
//           ].toJS,
//           null);
//     }
//   }

//   @override
//   Future setMorphAnimationData(
//       ThermionEntity entity, MorphAnimationData animation,
//       {List<String>? targetMeshNames, bool useNextEntity = false}) async {
//     var meshNames = await getChildEntityNames(entity, renderableOnly: false);
//     if (targetMeshNames != null) {
//       for (final targetMeshName in targetMeshNames) {
//         if (!meshNames.contains(targetMeshName)) {
//           throw Exception(
//               "Error: mesh ${targetMeshName} does not exist under the specified entity. Available meshes : ${meshNames}");
//         }
//       }
//     }

//     var meshEntities = await getChildEntities(entity, false);

//     // Entities are not guaranteed to have the same morph targets (or share the same order),
//     // either from each other, or from those specified in [animation].
//     // We therefore set morph targets separately for each mesh.
//     // For each mesh, allocate enough memory to hold FxM 32-bit floats
//     // (where F is the number of Frames, and M is the number of morph targets in the mesh).
//     // we call [extract] on [animation] to return frame data only for morph targets that present in both the mesh and the animation
//     for (int i = 0; i < meshNames.length; i++) {
//       var meshName = meshNames[i];
//       var meshEntity = meshEntities[i];

//       if (targetMeshNames?.contains(meshName) == false) {
//         // _logger.info("Skipping $meshName, not contained in target");
//         continue;
//       }

//       if (useNextEntity) meshEntity += 1;

//       var meshMorphTargets = await getMorphTargetNames(entity, meshEntity);

//       _logger.info("Got mesh morph targets ${meshMorphTargets}");

//       var intersection = animation.morphTargets
//           .toSet()
//           .intersection(meshMorphTargets.toSet())
//           .toList();

//       if (intersection.isEmpty) {
//         throw Exception(
//             """No morph targets specified in animation are present on mesh $meshName. 
//             If you weren't intending to animate every mesh, specify [targetMeshNames] when invoking this method.
//             Animation morph targets: ${animation.morphTargets}\n
//             Mesh morph targets ${meshMorphTargets}
//             Child meshes: ${meshNames}""");
//       }

//       var indices =
//           intersection.map((m) => meshMorphTargets.indexOf(m)).toList();

//       var frameData = animation.extract(morphTargets: intersection);

//       assert(frameData.length == animation.numFrames * intersection.length);

//       // Allocate memory in WASM for the morph data
//       var dataPtr = _module!._malloc(frameData.length * 4);

//       // Create a Float32List to copy the morph data to
//       var dataList = td.Float32List.fromList(frameData);

//       // Copy the morph data to WASM
//       _module!.writeArrayToMemory(
//           dataList.buffer.asUint8List(dataList.offsetInBytes).toJS, dataPtr);

//       // Allocate memory in WASM for the morph indices
//       var idxPtr = _module!._malloc(indices.length * 4);

//       // Create an Int32List to copy the morph indices to
//       var idxList = td.Int32List.fromList(indices);

//       // Copy the morph indices to WASM
//       _module!.writeArrayToMemory(
//           idxList.buffer.asUint8List(idxList.offsetInBytes).toJS, idxPtr);
//       bool result = false;
//       try {
//         var jsResult = _module!.ccall(
//             "set_morph_animation",
//             "bool",
//             [
//               "void*".toJS,
//               "int".toJS,
//               "float*".toJS,
//               "int*".toJS,
//               "int".toJS,
//               "int".toJS,
//               "float".toJS
//             ].toJS,
//             [
//               _sceneManager!,
//               meshEntity.toJS,
//               dataPtr,
//               idxPtr,
//               indices.length.toJS,
//               animation.numFrames.toJS,
//               animation.frameLengthInMs.toJS
//             ].toJS,
//             null);
//         _logger.info("Got jsResult $jsResult");
//         result = (jsResult as JSNumber).toDartInt == 1;
//       } catch (err, st) {
//         _logger.severe(err);
//         _logger.severe(st);
//       }

//       // Free the memory allocated in WASM
//       _module!._free(dataPtr);
//       _module!._free(idxPtr);

//       if (!result) {
//         throw Exception("Failed to set morph animation data for ${meshName}");
//       }
//     }
//   }

//   @override
//   Future setPosition(
//       ThermionEntity entity, double x, double y, double z) async {
//     _module!.ccall(
//         "set_position",
//         "void",
//         ["void*".toJS, "int".toJS, "float".toJS, "float".toJS, "float".toJS]
//             .toJS,
//         [_sceneManager!, entity.toJS, x.toJS, y.toJS, z.toJS].toJS,
//         null);
//   }

//   @override
//   Future setPostProcessing(bool enabled) async {
//     _module!.ccall("set_post_processing", "void",
//         ["void*".toJS, "bool".toJS].toJS, [_viewer!, enabled.toJS].toJS, null);
//   }

//   @override
//   Future setRotation(
//       ThermionEntity entity, double rads, double x, double y, double z) async {
//     var quaternion = Quaternion.axisAngle(Vector3(x, y, z), rads);
//     _module!.ccall(
//         "set_rotation",
//         "void",
//         [
//           "void*".toJS,
//           "int".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS
//         ].toJS,
//         [
//           _sceneManager!,
//           entity.toJS,
//           quaternion.radians.toJS,
//           quaternion.x.toJS,
//           quaternion.y.toJS,
//           quaternion.z.toJS,
//           quaternion.w.toJS
//         ].toJS,
//         null);
//   }

//   @override
//   Future setRotationQuat(ThermionEntity entity, Quaternion rotation) async {
//     _module!.ccall(
//         "set_rotation",
//         "void",
//         [
//           "void*".toJS,
//           "int".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS
//         ].toJS,
//         [
//           _sceneManager!,
//           entity.toJS,
//           rotation.radians.toJS,
//           rotation.x.toJS,
//           rotation.y.toJS,
//           rotation.z.toJS,
//           rotation.w.toJS
//         ].toJS,
//         null);
//   }

//   final _onDispose = <Future Function()>[];

//   ///
//   ///
//   ///
//   void onDispose(Future Function() callback) {
//     _onDispose.add(callback);
//   }

//   @override
//   Future clearBackgroundImage() async {
//     _module!.ccall("clear_background_image", "void", ["void*".toJS].toJS,
//         [_viewer!].toJS, null);
//   }

//   @override
//   Future destroyAssets() async {
//     _module!.ccall(
//         "clear_entities", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
//   }

//   @override
//   Future destroyLights() async {
//     _module!.ccall(
//         "clear_lights", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
//   }

//   @override
//   Future createGeometry(Geometry geometry,
//       {MaterialInstance? materialInstance,
//       bool keepData = false,
//       PrimitiveType primitiveType = PrimitiveType.TRIANGLES}) async {
//     final verticesData = td.Float32List.fromList(geometry.vertices);
//     final indicesData = Uint16List.fromList(geometry.indices);
//     final verticesPtr = _module!._malloc(verticesData.lengthInBytes);
//     final indicesPtr = _module!._malloc(indicesData.lengthInBytes);
//     _module!.writeArrayToMemory(
//         verticesData.buffer.asUint8List().toJS, verticesPtr);
//     _module!
//         .writeArrayToMemory(indicesData.buffer.asUint8List().toJS, indicesPtr);

//     final entityId = _module!.ccall(
//         "create_geometry",
//         "int",
//         [
//           "void*".toJS,
//           "float*".toJS,
//           "int".toJS,
//           "uint16_t*".toJS,
//           "int".toJS,
//           "int".toJS,
//           "string".toJS
//         ].toJS,
//         [
//           _viewer!,
//           verticesPtr,
//           verticesData.length.toJS,
//           indicesPtr,
//           indicesData.length.toJS,
//           primitiveType.index.toJS,
//           (materialInstance as ThermionWasmMaterialInstance?)?.pointer.toJS ?? "".toJS,
//         ].toJS,
//         null) as JSNumber;

//     _module!._free(verticesPtr);
//     _module!._free(indicesPtr);

//     if (entityId.toDartInt == -1) {
//       throw Exception("Failed to create geometry");
//     }
//     return entityId.toDartInt;
//   }

//   @override
//   Future<ThermionEntity> createInstance(ThermionEntity entity) async {
//     final result = _module!.ccall(
//         "create_instance",
//         "int",
//         ["void*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null) as JSNumber;
//     if (result.toDartInt == -1) {
//       throw Exception("Failed to create instance of entity ${entity}");
//     }
//     return result.toDartInt;
//   }

//   @override
//   Future<double> getAnimationDuration(
//       ThermionEntity entity, int animationIndex) async {
//     final result = _module!.ccall(
//         "get_animation_duration",
//         "float",
//         ["void*".toJS, "int".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS, animationIndex.toJS].toJS,
//         null) as JSNumber;
//     return result.toDartDouble;
//   }

//   @override
//   Future<int> getAnimationCount(ThermionEntity entity) async {
//     final animationCount = _module!.ccall(
//         "get_animation_count",
//         "int",
//         ["void*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null) as JSNumber;
//     return animationCount.toDartInt;
//   }

//   @override
//   Future<List<String>> getAnimationNames(ThermionEntity entity) async {
//     final animationCount = await getAnimationCount(entity);
//     final names = <String>[];
//     for (int i = 0; i < animationCount; i++) {
//       final namePtr = _module!._malloc(256);
//       _module!.ccall(
//           "get_animation_name",
//           "void",
//           ["void*".toJS, "int".toJS, "char*".toJS, "int".toJS].toJS,
//           [_sceneManager!, entity.toJS, namePtr, i.toJS].toJS,
//           null);
//       names.add(_module!.UTF8ToString(namePtr).toDart);
//       _module!._free(namePtr);
//     }
//     return names;
//   }

//   @override
//   Future<double> getCameraCullingFar() async {
//     final result = _module!.ccall("Camera_getCullingFar", "double",
//         ["void*".toJS].toJS, [_viewer!].toJS, null) as JSNumber;
//     return result.toDartDouble;
//   }

//   @override
//   Future<double> getCameraCullingNear() async {
//     final result = _module!.ccall("get_camera_culling_near", "double",
//         ["void*".toJS].toJS, [_viewer!].toJS, null) as JSNumber;
//     return result.toDartDouble;
//   }

//   @override
//   Future<Matrix4> getCameraCullingProjectionMatrix() async {
//     final ptr = _module!._malloc(16 * 8);
//     _module!.ccall("Camera_getCullingProjectionMatrix", "void",
//         ["void*".toJS, "double*".toJS].toJS, [_viewer!, ptr].toJS, null);
//     final matrix = Matrix4.zero();
//     for (int i = 0; i < 16; i++) {
//       matrix[i] = (_module!.getValue((ptr.toDartInt + (i * 8)).toJS, "double")
//               as JSNumber)
//           .toDartDouble;
//     }
//     _module!._free(ptr);
//     return matrix;
//   }

//   @override
//   Future<Frustum> getCameraFrustum() async {
//     final ptr = _module!._malloc(24 * 8);
//     _module!.ccall("get_camera_frustum", "void",
//         ["void*".toJS, "double*".toJS].toJS, [_viewer!, ptr].toJS, null);
//     final planes = List.generate(6, (i) {
//       final offset = i * 4;
//       return Plane()
//         ..setFromComponents(
//             (_module!.getValue((ptr.toDartInt + (offset * 8)).toJS, "double")
//                     as JSNumber)
//                 .toDartDouble,
//             (_module!.getValue(
//                         (ptr.toDartInt + ((offset + 1) * 8)).toJS, "double")
//                     as JSNumber)
//                 .toDartDouble,
//             (_module!.getValue(
//                         (ptr.toDartInt + ((offset + 2) * 8)).toJS, "double")
//                     as JSNumber)
//                 .toDartDouble,
//             (_module!.getValue(
//                         (ptr.toDartInt + ((offset + 3) * 8)).toJS, "double")
//                     as JSNumber)
//                 .toDartDouble);
//     });
//     _module!._free(ptr);
//     throw UnimplementedError();
//     // return Frustum()..plane0 = planes[0]..plane1 =planes[1]..plane2 =planes[2]..plane3 =planes[3], planes[4], planes[5]);
//   }

//   @override
//   Future<Matrix4> getCameraModelMatrix() async {
//     final ptr = _module!.ccall("Camera_getModelMatrix", "void*",
//         ["void*".toJS].toJS, [_viewer!].toJS, null) as JSNumber;
//     final matrix = _matrixFromPtr(ptr);
//     _module!.ccall(
//         "thermion_flutter_free", "void", ["void*".toJS].toJS, [ptr].toJS, null);

//     return matrix;
//   }

//   @override
//   Future<Vector3> getCameraPosition() async {
//     final ptr = _module!._malloc(3 * 8);
//     _module!.ccall("get_camera_position", "void",
//         ["void*".toJS, "void*".toJS].toJS, [_viewer!, ptr].toJS, null);
//     final pos = Vector3(
//         (_module!.getValue(ptr.toDartInt.toJS, "double") as JSNumber)
//             .toDartDouble,
//         (_module!.getValue((ptr.toDartInt + 8).toJS, "double") as JSNumber)
//             .toDartDouble,
//         (_module!.getValue((ptr.toDartInt + 16).toJS, "double") as JSNumber)
//             .toDartDouble);
//     _module!._free(ptr);
//     return pos;
//   }

//   @override
//   Future<Matrix4> getCameraProjectionMatrix() async {
//     final ptr = _module!._malloc(16 * 8);
//     _module!.ccall("Camera_getProjectionMatrix", "void",
//         ["void*".toJS, "double*".toJS].toJS, [_viewer!, ptr].toJS, null);
//     final matrix = _matrixFromPtr(ptr);
//     _module!._free(ptr);
//     return matrix;
//   }

//   @override
//   Future<Matrix3> getCameraRotation() async {
//     final model = await getCameraModelMatrix();
//     final rotation = model.getRotation();
//     return rotation;
//   }

//   @override
//   Future<Matrix4> getCameraViewMatrix() async {
//     final ptr = _module!._malloc(16 * 8);
//     _module!.ccall("Camera_getViewMatrix", "void",
//         ["void*".toJS, "double*".toJS].toJS, [_viewer!, ptr].toJS, null);
//     final matrix = Matrix4.zero();
//     for (int i = 0; i < 16; i++) {
//       matrix[i] = (_module!.getValue((ptr.toDartInt + (i * 8)).toJS, "double")
//               as JSNumber)
//           .toDartDouble;
//     }
//     _module!._free(ptr);
//     return matrix;
//   }

//   @override
//   Future<int> getInstanceCount(ThermionEntity entity) async {
//     final result = _module!.ccall(
//         "get_instance_count",
//         "int",
//         ["void*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null) as JSNumber;
//     return result.toDartInt;
//   }

//   @override
//   Future<List<ThermionEntity>> getInstances(ThermionEntity entity) async {
//     final instanceCount = await getInstanceCount(entity);
//     final buf = _module!._malloc(instanceCount * 4);
//     _module!.ccall(
//         "get_instances",
//         "void",
//         ["void*".toJS, "int".toJS, "int*".toJS].toJS,
//         [_sceneManager!, entity.toJS, buf].toJS,
//         null);
//     final instances = <ThermionEntity>[];
//     for (int i = 0; i < instanceCount; i++) {
//       final instanceId =
//           _module!.getValue((buf.toDartInt + (i * 4)).toJS, "i32") as JSNumber;
//       instances.add(instanceId.toDartInt);
//     }
//     _module!._free(buf);
//     return instances;
//   }

//   @override
//   Future<Matrix4> getInverseBindMatrix(ThermionEntity parent, int boneIndex,
//       {int skinIndex = 0}) async {
//     final ptr = _module!._malloc(16 * 4);
//     _module!.ccall(
//         "get_inverse_bind_matrix",
//         "void",
//         ["void*".toJS, "int".toJS, "int".toJS, "int".toJS, "float*".toJS].toJS,
//         [_sceneManager!, parent.toJS, skinIndex.toJS, boneIndex.toJS, ptr].toJS,
//         null);
//     final matrix = _matrixFromPtr(ptr);
//     _module!._free(ptr);
//     return matrix;
//   }

//   @override
//   Future<Matrix4> getLocalTransform(ThermionEntity entity) async {
//     final ptr = _module!._malloc(16 * 4);
//     _module!.ccall(
//         "get_local_transform",
//         "void",
//         ["void*".toJS, "int".toJS, "float*".toJS].toJS,
//         [_sceneManager!, entity.toJS, ptr].toJS,
//         null);
//     final matrix = _matrixFromPtr(ptr);
//     _module!._free(ptr);
//     return matrix;
//   }

//   @override
//   Future moveCameraToAsset(ThermionEntity entity) async {
//     _module!.ccall("move_camera_to_asset", "void",
//         ["void*".toJS, "int".toJS].toJS, [_viewer!, entity.toJS].toJS, null);
//   }

//   @override
//   Future panEnd() async {
//     _module!
//         .ccall("grab_end", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
//   }

//   @override
//   Future panStart(double x, double y) async {
//     _module!.ccall(
//         "grab_begin",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS, "bool".toJS].toJS,
//         [_viewer!, x.toJS, y.toJS, true.toJS].toJS,
//         null);
//   }

//   @override
//   Future panUpdate(double x, double y) async {
//     _module!.ccall(
//         "grab_update",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS].toJS,
//         [_viewer!, x.toJS, y.toJS].toJS,
//         null);
//   }

//   late JSNumber _pickCallbackPtr;

//   void _onPickCallback(ThermionEntity entity, int x, int y) {
//     _pickResultController
//         .add((entity: entity, x: x.toDouble(), y: y.toDouble()));
//   }

//   @override
//   void pick(int x, int y) async {
//     x = (x * pixelRatio).ceil();
//     y = (viewportDimensions.$2 - (y * pixelRatio)).ceil();
//     _module!.ccall(
//         "filament_pick",
//         "void",
//         ["void*".toJS, "int".toJS, "int".toJS, "void*".toJS].toJS,
//         [_viewer!, x.toJS, y.toJS, _pickCallbackPtr].toJS,
//         null);
//   }

//   @override
//   Future playAnimationByName(ThermionEntity entity, String name,
//       {bool loop = false,
//       bool reverse = false,
//       bool replaceActive = true,
//       double crossfade = 0.0}) async {
//     final animationNames = await getAnimationNames(entity);
//     final index = animationNames.indexOf(name);
//     if (index == -1) {
//       throw Exception("Animation ${name} not found.");
//     }
//     return playAnimation(entity, index,
//         loop: loop,
//         reverse: reverse,
//         replaceActive: replaceActive,
//         crossfade: crossfade);
//   }

//   @override
//   Future queuePositionUpdate(
//       ThermionEntity entity, double x, double y, double z,
//       {bool relative = false}) async {
//     _module!.ccall(
//         "queue_position_update",
//         "void",
//         [
//           "void*".toJS,
//           "int".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "bool".toJS
//         ].toJS,
//         [_sceneManager!, entity.toJS, x.toJS, y.toJS, z.toJS, relative.toJS]
//             .toJS,
//         null);
//   }

//   @override
//   Future queueRotationUpdate(
//       ThermionEntity entity, double rads, double x, double y, double z,
//       {bool relative = false}) async {
//     _module!.ccall(
//         "queue_rotation_update",
//         "void",
//         [
//           "void*".toJS,
//           "int".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "bool".toJS
//         ].toJS,
//         [
//           _sceneManager!,
//           entity.toJS,
//           rads.toJS,
//           x.toJS,
//           y.toJS,
//           z.toJS,
//           relative.toJS
//         ].toJS,
//         null);
//   }

//   @override
//   Future queueRotationUpdateQuat(ThermionEntity entity, Quaternion quat,
//       {bool relative = false}) async {
//     _module!.ccall(
//         "queue_rotation_update",
//         "void",
//         [
//           "void*".toJS,
//           "int".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "bool".toJS
//         ].toJS,
//         [
//           _sceneManager!,
//           entity.toJS,
//           quat.radians.toJS,
//           quat.x.toJS,
//           quat.y.toJS,
//           quat.z.toJS,
//           relative.toJS
//         ].toJS,
//         null);
//   }

//   @override
//   Future removeAnimationComponent(ThermionEntity entity) async {
//     _module!.ccall(
//         "remove_animation_component",
//         "void",
//         ["void*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null);
//   }

//   @override
//   Future removeCollisionComponent(ThermionEntity entity) async {
//     _module!.ccall(
//         "remove_collision_component",
//         "void",
//         ["void*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null);
//   }

//   @override
//   Future destroyAsset(ThermionEntity entity) async {
//     _module!.ccall("remove_entity", "void", ["void*".toJS, "int".toJS].toJS,
//         [_viewer!, entity.toJS].toJS, null);
//   }

//   @override
//   Future removeIbl() async {
//     _module!.ccall(
//         "remove_ibl", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
//   }

//   @override
//   Future removeLight(ThermionEntity light) async {
//     _module!.ccall("remove_light", "void", ["void*".toJS, "int".toJS].toJS,
//         [_viewer!, light.toJS].toJS, null);
//   }

//   @override
//   Future removeSkybox() async {
//     _module!.ccall(
//         "remove_skybox", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
//   }

//   @override
//   Future resetBones(ThermionEntity entity) async {
//     _module!.ccall(
//         "reset_to_rest_pose",
//         "void",
//         ["void*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null);
//   }

//   @override
//   Future reveal(ThermionEntity entity, String? meshName) async {
//     final result = _module!.ccall(
//         "reveal_mesh",
//         "int",
//         ["void*".toJS, "int".toJS, "string".toJS].toJS,
//         [_sceneManager!, entity.toJS, meshName?.toJS].toJS,
//         null) as JSNumber;
//     if (result.toDartInt == -1) {
//       throw Exception(
//           "Failed to reveal mesh ${meshName} on entity ${entity.toJS}");
//     }
//   }

//   @override
//   Future rotateIbl(Matrix3 rotation) async {
//     final ptr = _module!._malloc(9 * 4);
//     for (int i = 0; i < 9; i++) {
//       _module!.setValue(
//           (ptr.toDartInt + (i * 4)).toJS, rotation.storage[i].toJS, "float");
//     }
//     _module!.ccall("rotate_ibl", "void", ["void*".toJS, "float*".toJS].toJS,
//         [_viewer!, ptr].toJS, null);
//     _module!._free(ptr);
//   }

//   @override
//   Future rotateStart(double x, double y) async {
//     _module!.ccall(
//         "grab_begin",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS, "bool".toJS].toJS,
//         [_viewer!, x.toJS, y.toJS, false.toJS].toJS,
//         null);
//   }

//   @override
//   Future rotateUpdate(double x, double y) async {
//     _module!.ccall(
//         "grab_update",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS].toJS,
//         [_viewer!, x.toJS, y.toJS].toJS,
//         null);
//   }

//   @override
//   Future rotateEnd() async {
//     _module!
//         .ccall("grab_end", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
//   }

//   @override
//   Future setAnimationFrame(
//       ThermionEntity entity, int index, int animationFrame) async {
//     _module!.ccall(
//         "set_animation_frame",
//         "void",
//         ["void*".toJS, "int".toJS, "int".toJS, "int".toJS].toJS,
//         [
//           _sceneManager!,
//           entity.toJS,
//           index.toJS,
//           animationFrame.toJS,
//         ].toJS,
//         null);
//   }

//   @override
//   Future setBackgroundImage(String path, {bool fillHeight = false}) async {
//     _module!.ccall(
//         "set_background_image",
//         "void",
//         ["void*".toJS, "string".toJS, "bool".toJS].toJS,
//         [_viewer!, path.toJS, fillHeight.toJS].toJS,
//         null);
//   }

//   @override
//   Future setBackgroundImagePosition(double x, double y,
//       {bool clamp = false}) async {
//     _module!.ccall(
//         "set_background_image_position",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS, "bool".toJS].toJS,
//         [_viewer!, x.toJS, y.toJS, clamp.toJS].toJS,
//         null);
//   }

//   @override
//   Future setBloom(double bloom) async {
//     _module!.ccall("set_bloom", "void", ["void*".toJS, "float".toJS].toJS,
//         [_viewer!, bloom.toJS].toJS, null);
//   }

//   @override
//   Future setBoneTransform(
//       ThermionEntity entity, int boneIndex, Matrix4 transform,
//       {int skinIndex = 0}) async {
//     final ptr = _module!._malloc(16 * 4);
//     for (int i = 0; i < 16; i++) {
//       _module!.setValue(
//           (ptr.toDartInt + (i * 4)).toJS, transform.storage[i].toJS, "float");
//     }
//     final result = _module!.ccall(
//         "set_bone_transform",
//         "bool",
//         ["void*".toJS, "int".toJS, "int".toJS, "int".toJS, "float*".toJS].toJS,
//         [_sceneManager!, entity.toJS, skinIndex.toJS, boneIndex.toJS, ptr].toJS,
//         null) as JSBoolean;
//     _module!._free(ptr);
//     if (!result.toDart) {
//       throw Exception("Failed to set bone transform");
//     }
//   }

//   @override
//   Future setCamera(ThermionEntity entity, String? name) async {
//     final result = _module!.ccall(
//         "set_camera",
//         "bool",
//         ["void*".toJS, "int".toJS, "string".toJS].toJS,
//         [_viewer!, entity.toJS, (name ?? "").toJS].toJS,
//         null) as JSBoolean;
//     if (!result.toDart) {
//       throw Exception("Failed to set camera to entity ${entity}");
//     }
//   }

//   @override
//   Future setCameraCulling(double near, double far) async {
//     _module!.ccall(
//         "set_camera_culling",
//         "void",
//         ["void*".toJS, "double".toJS, "double".toJS].toJS,
//         [_viewer!, near.toJS, far.toJS].toJS,
//         null);
//   }

//   @override
//   Future setCameraExposure(
//       double aperture, double shutterSpeed, double sensitivity) async {
//     _module!.ccall(
//         "Camera_setExposure",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS, "float".toJS].toJS,
//         [
//           _viewer!,
//           aperture.toJS,
//           shutterSpeed.toJS,
//           sensitivity.toJS,
//         ].toJS,
//         null);
//   }

//   @override
//   Future setCameraFocalLength(double focalLength) async {
//     _module!.ccall(
//         "set_camera_focal_length",
//         "void",
//         ["void*".toJS, "float".toJS].toJS,
//         [_viewer!, focalLength.toJS].toJS,
//         null);
//   }

//   @override
//   Future setCameraFocusDistance(double focusDistance) async {
//     _module!.ccall(
//         "Camera_setFocusDistance",
//         "void",
//         ["void*".toJS, "float".toJS].toJS,
//         [_viewer!, focusDistance.toJS].toJS,
//         null);
//   }

//   @override
//   Future setCameraFov(double degrees, {bool horizontal = true}) async {
//     _module!.ccall(
//         "set_camera_fov",
//         "void",
//         ["void*".toJS, "float".toJS, "bool".toJS].toJS,
//         [_viewer!, degrees.toJS, horizontal.toJS].toJS,
//         null);
//   }


//   @override
//   Future setCameraModelMatrix(List<double> matrix) async {
//     assert(matrix.length == 16, "Matrix must have 16 elements");
//     final ptr = _module!._malloc(16 * 8);
//     for (int i = 0; i < 16; i++) {
//       _module!
//           .setValue((ptr.toDartInt + (i * 8)).toJS, matrix[i].toJS, "double");
//     }
//     _module!.ccall("Camera_setModelMatrix", "void",
//         ["void*".toJS, "float*".toJS].toJS, [_viewer!, ptr].toJS, null);
//     _module!._free(ptr);
//   }

//   @override
//   Future setFrameRate(int framerate) async {
//     _module!.ccall(
//         "set_frame_interval",
//         "void",
//         ["void*".toJS, "float".toJS].toJS,
//         [_viewer!, (1 / framerate).toJS].toJS,
//         null);
//   }

//   @override
//   Future setMainCamera() async {
//     _module!.ccall(
//         "set_main_camera", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
//   }

//   @override
//   Future setMaterialColor(ThermionEntity entity, String meshName,
//       int materialIndex, double r, double g, double b, double a) async {
//     final result = _module!.ccall(
//         "set_material_color",
//         "bool",
//         [
//           "void*".toJS,
//           "int".toJS,
//           "string".toJS,
//           "int".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS
//         ].toJS,
//         [
//           _sceneManager!,
//           entity.toJS,
//           meshName.toJS,
//           materialIndex.toJS,
//           r.toJS,
//           g.toJS,
//           b.toJS,
//           a.toJS
//         ].toJS,
//         null) as JSBoolean;
//     if (!result.toDart) {
//       throw Exception("Failed to set material color");
//     }
//   }

//   @override
//   Future setMorphTargetWeights(
//       ThermionEntity entity, List<double> weights) async {
//     final numWeights = weights.length;
//     final ptr = _module!._malloc(numWeights * 4);
//     for (int i = 0; i < numWeights; i++) {
//       _module!
//           .setValue((ptr.toDartInt + (i * 4)).toJS, weights[i].toJS, "float");
//     }
//     final result = _module!.ccall(
//         "set_morph_target_weights",
//         "bool",
//         ["void*".toJS, "int".toJS, "float*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS, ptr, numWeights.toJS].toJS,
//         null) as JSBoolean;
//     _module!._free(ptr);
//     if (!result.toDart) {
//       throw Exception("Failed to set morph target weights");
//     }
//   }

//   @override
//   Future setParent(ThermionEntity child, ThermionEntity parent,
//       {bool preserveScaling = false}) async {
//     _module!.ccall(
//         "set_parent",
//         "void",
//         ["void*".toJS, "int".toJS, "int".toJS, "bool".toJS].toJS,
//         [_sceneManager!, child.toJS, parent.toJS, preserveScaling.toJS].toJS,
//         null);
//   }

//   @override
//   Future setPriority(ThermionEntity entityId, int priority) {
//     // TODO: implement setPriority
//     throw UnimplementedError();
//   }

//   @override
//   Future setRecording(bool recording) async {
//     _module!.ccall("set_recording", "void", ["void*".toJS, "bool".toJS].toJS,
//         [_viewer!, recording.toJS].toJS, null);
//   }

//   @override
//   Future setRecordingOutputDirectory(String outputDirectory) async {
//     _module!.ccall(
//         "set_recording_output_directory",
//         "void",
//         ["void*".toJS, "string".toJS].toJS,
//         [_viewer!, outputDirectory.toJS].toJS,
//         null);
//   }

//   Timer? _renderLoop;

//   @override
//   Future setRendering(bool render) async {
//     if (render && !_rendering) {
//       _rendering = true;
//       _renderLoop = Timer.periodic(Duration(microseconds: 16667), (_) {
//         this.render();
//       });
//     } else if (!render && _rendering) {
//       _rendering = false;
//       _renderLoop?.cancel();
//       _renderLoop = null;
//     }
//   }

//   @override
//   Future setScale(ThermionEntity entity, double scale) async {
//     _module!.ccall(
//         "set_scale",
//         "void",
//         ["void*".toJS, "int".toJS, "float".toJS].toJS,
//         [_sceneManager!, entity.toJS, scale.toJS].toJS,
//         null);
//   }

//   @override
//   Future setToneMapping(ToneMapper mapper) async {
//     _module!.ccall("set_tone_mapping", "void", ["void*".toJS, "int".toJS].toJS,
//         [_viewer!, mapper.index.toJS].toJS, null);
//   }

//   @override
//   Future setTransform(ThermionEntity entity, Matrix4 transform) async {
//     final ptr = _module!._malloc(16 * 4);
//     for (int i = 0; i < 16; i++) {
//       _module!.setValue(
//           (ptr.toDartInt + (i * 4)).toJS, transform.storage[i].toJS, "float");
//     }
//     final result = _module!.ccall(
//         "set_transform",
//         "bool",
//         ["void*".toJS, "int".toJS, "float*".toJS].toJS,
//         [_sceneManager!, entity.toJS, ptr].toJS,
//         null) as JSBoolean;
//     _module!._free(ptr);
//     if (!result.toDart) {
//       throw Exception("Failed to set transform");
//     }
//   }

//   @override
//   Future setViewFrustumCulling(bool enabled) async {
//     _module!.ccall("set_view_frustum_culling", "void",
//         ["void*".toJS, "bool".toJS].toJS, [_viewer!, enabled.toJS].toJS, null);
//   }

//   @override
//   Future stopAnimation(ThermionEntity entity, int animationIndex) async {
//     _module!.ccall(
//         "stop_animation",
//         "void",
//         ["void*".toJS, "int".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS, animationIndex.toJS].toJS,
//         null);
//   }

//   @override
//   Future stopAnimationByName(ThermionEntity entity, String name) async {
//     final namePtr = _allocateString(name);
//     _module!.ccall(
//         "stop_animation_by_name",
//         "void",
//         ["void*".toJS, "int".toJS, "char*".toJS].toJS,
//         [_sceneManager!, entity.toJS, namePtr].toJS,
//         null);
//     _module!._free(namePtr);
//   }

//   @override
//   Future testCollisions(ThermionEntity entity) async {
//     final result = _module!.ccall(
//         "test_collisions",
//         "bool",
//         ["void*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null) as JSBoolean;
//     return result.toDart;
//   }

//   @override
//   Future transformToUnitCube(ThermionEntity entity) async {
//     _module!.ccall(
//         "transform_to_unit_cube",
//         "void",
//         ["void*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null);
//   }

//   @override
//   Future updateBoneMatrices(ThermionEntity entity) async {
//     _module!.ccall(
//         "update_bone_matrices",
//         "void",
//         ["void*".toJS, "int".toJS].toJS,
//         [_sceneManager!, entity.toJS].toJS,
//         null);
//   }

//   @override
//   Future zoomBegin() async {
//     _module!.ccall(
//         "scroll_begin", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
//   }

//   @override
//   Future zoomEnd() async {
//     _module!.ccall(
//         "scroll_end", "void", ["void*".toJS].toJS, [_viewer!].toJS, null);
//   }

//   @override
//   Future zoomUpdate(double x, double y, double z) async {
//     _module!.ccall(
//         "scroll_update",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS, "float".toJS].toJS,
//         [_viewer!, x.toJS, y.toJS, z.toJS].toJS,
//         null);
//   }

// // Helper method to allocate a string in the WASM memory
//   JSNumber _allocateString(String str) {
//     final bytes = utf8.encode(str);
//     final ptr = _module!._malloc(bytes.length + 1);
//     for (var i = 0; i < bytes.length; i++) {
//       _module!.setValue((ptr.toDartInt + i).toJS, bytes[i].toJS, "i8");
//     }
//     _module!.setValue(
//         (ptr.toDartInt + bytes.length).toJS, 0.toJS, "i8"); // Null terminator
//     return ptr;
//   }

//   @override
//   Future setShadowType(ShadowType shadowType) async {
//     _module!.ccall("set_shadow_type", "void", ["void*".toJS, "int".toJS].toJS,
//         [_viewer!, shadowType.index.toJS].toJS, null);
//   }

//   @override
//   Future setShadowsEnabled(bool enabled) async {
//     _module!.ccall("set_shadows_enabled", "void",
//         ["void*".toJS, "bool".toJS].toJS, [_viewer!, enabled.toJS].toJS, null);
//   }

//   @override
//   Future setSoftShadowOptions(
//       double penumbraScale, double penumbraRatioScale) async {
//     _module!.ccall(
//         "set_soft_shadow_options",
//         "void",
//         ["void*".toJS, "float".toJS, "float".toJS].toJS,
//         [_viewer!, penumbraScale.toJS, penumbraRatioScale.toJS].toJS,
//         null);
//   }

//   @override
//   Future<Aabb2> getBoundingBox(ThermionEntity entity) {
//     var minX = _module!._malloc(4);
//     var minY = _module!._malloc(4);
//     var maxX = _module!._malloc(4);
//     var maxY = _module!._malloc(4);
//     _module!.ccall(
//         "get_bounding_box_to_out",
//         "void",
//         [
//           "void*".toJS,
//           "int".toJS,
//           "float*".toJS,
//           "float*".toJS,
//           "float*".toJS,
//           "float*".toJS
//         ].toJS,
//         [_sceneManager!, entity.toJS, minX, minY, maxX, maxY].toJS,
//         null);

//     final min = Vector2(
//         (_module!.getValue(minX, "float") as JSNumber).toDartDouble,
//         (_module!.getValue(minY, "float") as JSNumber).toDartDouble);
//     final max = Vector2(
//         (_module!.getValue(maxX, "float") as JSNumber).toDartDouble,
//         (_module!.getValue(maxY, "float") as JSNumber).toDartDouble);

//     final box = Aabb2.minMax(min, max);
//     _module!._free(minX);
//     _module!._free(minY);
//     _module!._free(maxX);
//     _module!._free(maxY);

//     return Future.value(box);
//   }

//   @override
//   Future<double> getCameraFov(bool horizontal) async {
//     var fov = _module!.ccall(
//         "Camera_getFov",
//         "float",
//         ["void*".toJS, "bool".toJS].toJS,
//         [_viewer!, horizontal.toJS].toJS,
//         null);
//     return (fov as JSNumber).toDartDouble;
//   }

//   @override
//   Future queueRelativePositionUpdateWorldAxis(ThermionEntity entity,
//       double viewportX, double viewportY, double x, double y, double z) async {
//     _module!.ccall(
//         "queue_relative_position_update_world_axis",
//         "void",
//         [
//           "void*".toJS,
//           "int".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS,
//           "float".toJS
//         ].toJS,
//         [
//           _sceneManager!,
//           entity.toJS,
//           viewportX.toJS,
//           viewportY.toJS,
//           x.toJS,
//           y.toJS,
//           z.toJS
//         ].toJS,
//         null);
//   }

//   @override
//   Future setLayerEnabled(int layer, bool enabled) async {
//     _module!.ccall(
//         "set_layer_visibility",
//         "void",
//         [
//           "void*".toJS,
//           "int".toJS,
//           "bool".toJS,
//         ].toJS,
//         [
//           _sceneManager!,
//           layer.toJS,
//           enabled.toJS,
//         ].toJS,
//         null);
//   }

//   @override
//   Future createIbl(double r, double g, double b, double intensity) async {
//     _module!.ccall(
//         "create_ibl",
//         "void",
//         [
//           "void*".toJS,
//           "double".toJS,
//           "double".toJS,
//           "double".toJS,
//           "double".toJS,
//         ].toJS,
//         [_sceneManager!, r.toJS, g.toJS, b.toJS, intensity.toJS].toJS,
//         null);
//   }

//   late JSNumber _pickGizmoCallbackPtr;

//   void _onPickGizmoCallback(ThermionEntity entity, int x, int y) {
//     _gizmoPickResultController
//         .add((entity: entity, x: x.toDouble(), y: y.toDouble()));
//   }

//   @override
//   void pickGizmo(int x, int y) {
//     x = (x * pixelRatio).ceil();
//     y = (viewportDimensions.$2 - (y * pixelRatio)).ceil();

//     _module!.ccall(
//         "pick_gizmo",
//         "void",
//         [
//           "void*".toJS,
//           "int".toJS,
//           "int".toJS,
//           "void*".toJS,
//         ].toJS,
//         [_sceneManager!, x.toJS, y.toJS, _pickGizmoCallbackPtr].toJS,
//         null);
//   }

//   @override
//   Future setGizmoVisibility(bool visible) async {
//     _module!.ccall(
//         "set_gizmo_visibility",
//         "void",
//         [
//           "void*".toJS,
//           "bool".toJS,
//         ].toJS,
//         [_sceneManager!, visible.toJS].toJS,
//         null);
//   }

//   @override
//   Future setLightDirection(
//       ThermionEntity lightEntity, Vector3 direction) async {
//     direction.normalize();
//     _module!.ccall(
//         "set_light_direction",
//         "void",
//         ["void*".toJS, "double".toJS, "double".toJS, "double".toJS].toJS,
//         [_viewer!, direction.x.toJS, direction.y.toJS, direction.z.toJS].toJS,
//         null);
//   }

//   @override
//   Future setLightPosition(
//       ThermionEntity lightEntity, double x, double y, double z) async {
//     _module!.ccall(
//         "set_light_position",
//         "void",
//         ["void*".toJS, "double".toJS, "double".toJS, "double".toJS].toJS,
//         [_viewer!, x.toJS, y.toJS, z.toJS].toJS,
//         null);
//   }

//   @override
//   Future<ThermionEntity?> getAncestor(ThermionEntity entity) {
//     // TODO: implement getAncestor
//     throw UnimplementedError();
//   }

//   @override
//   Future queuePositionUpdateFromViewportCoords(
//       ThermionEntity entity, double x, double y) {
//     // TODO: implement queuePositionUpdateFromViewportCoords
//     throw UnimplementedError();
//   }

//   @override
//   Future removeStencilHighlight(ThermionEntity entity) {
//     // TODO: implement removeStencilHighlight
//     throw UnimplementedError();
//   }

//   @override
//   Future setStencilHighlight(ThermionEntity entity,
//       {double r = 1.0, double g = 0.0, double b = 0.0}) {
//     // TODO: implement setStencilHighlight
//     throw UnimplementedError();
//   }

//   @override
//   // TODO: implement entitiesAdded
//   Stream<ThermionEntity> get entitiesAdded => throw UnimplementedError();

//   @override
//   // TODO: implement entitiesRemoved
//   Stream<ThermionEntity> get entitiesRemoved => throw UnimplementedError();

//   @override
//   Future<double> getCameraNear() {
//     // TODO: implement getCameraNear
//     throw UnimplementedError();
//   }

//   @override
//   Future<Aabb2> getViewportBoundingBox(ThermionEntity entity) {
//     // TODO: implement getViewportBoundingBox
//     throw UnimplementedError();
//   }

//   @override
//   // TODO: implement lightsAdded
//   Stream<ThermionEntity> get lightsAdded => throw UnimplementedError();

//   @override
//   // TODO: implement lightsRemoved
//   Stream<ThermionEntity> get lightsRemoved => throw UnimplementedError();

//   @override
//   Future setCameraModelMatrix4(Matrix4 matrix) {
//     // TODO: implement setCameraModelMatrix4
//     throw UnimplementedError();
//   }

//   @override
//   Future setMaterialPropertyFloat(ThermionEntity entity, String propertyName,
//       int materialIndex, double value) {
//     // TODO: implement setMaterialPropertyFloat
//     throw UnimplementedError();
//   }

//   @override
//   Future setMaterialPropertyFloat4(ThermionEntity entity, String propertyName,
//       int materialIndex, double f1, double f2, double f3, double f4) {
//     // TODO: implement setMaterialPropertyFloat4
//     throw UnimplementedError();
//   }

//   @override
//   Future<ThermionEntity> addDirectLight(DirectLight light) {
//     // TODO: implement addDirectLight
//     throw UnimplementedError();
//   }

//   @override
//   Future applyTexture(covariant ThermionTexture texture, ThermionEntity entity,
//       {int materialIndex = 0, String parameterName = "baseColorMap"}) {
//     // TODO: implement applyTexture
//     throw UnimplementedError();
//   }

//   @override
//   Future<ThermionTexture> createTexture(td.Uint8List data) {
//     // TODO: implement createTexture
//     throw UnimplementedError();
//   }

//   @override
//   Future<MaterialInstance> createUbershaderMaterialInstance(
//       {bool doubleSided = false,
//       bool unlit = false,
//       bool hasVertexColors = false,
//       bool hasBaseColorTexture = false,
//       bool hasNormalTexture = false,
//       bool hasOcclusionTexture = false,
//       bool hasEmissiveTexture = false,
//       bool useSpecularGlossiness = false,
//       AlphaMode alphaMode = AlphaMode.OPAQUE,
//       bool enableDiagnostics = false,
//       bool hasMetallicRoughnessTexture = false,
//       int metallicRoughnessUV = 0,
//       int baseColorUV = 0,
//       bool hasClearCoatTexture = false,
//       int clearCoatUV = 0,
//       bool hasClearCoatRoughnessTexture = false,
//       int clearCoatRoughnessUV = 0,
//       bool hasClearCoatNormalTexture = false,
//       int clearCoatNormalUV = 0,
//       bool hasClearCoat = false,
//       bool hasTransmission = false,
//       bool hasTextureTransforms = false,
//       int emissiveUV = 0,
//       int aoUV = 0,
//       int normalUV = 0,
//       bool hasTransmissionTexture = false,
//       int transmissionUV = 0,
//       bool hasSheenColorTexture = false,
//       int sheenColorUV = 0,
//       bool hasSheenRoughnessTexture = false,
//       int sheenRoughnessUV = 0,
//       bool hasVolumeThicknessTexture = false,
//       int volumeThicknessUV = 0,
//       bool hasSheen = false,
//       bool hasIOR = false,
//       bool hasVolume = false}) {
//     // TODO: implement createUbershaderMaterialInstance
//     throw UnimplementedError();
//   }

//   @override
//   Future<MaterialInstance> createUnlitMaterialInstance() {
//     // TODO: implement createUnlitMaterialInstance
//     throw UnimplementedError();
//   }

//   @override
//   Future destroyMaterialInstance(covariant MaterialInstance materialInstance) {
//     // TODO: implement destroyMaterialInstance
//     throw UnimplementedError();
//   }

//   @override
//   Future destroyTexture(covariant ThermionTexture texture) {
//     // TODO: implement destroyTexture
//     throw UnimplementedError();
//   }

//   @override
//   Future<ThermionEntity> getMainCameraEntity() async {
//     final entityId = _module!.ccall(
//             "get_main_camera", "int", ["void*".toJS].toJS, [_viewer].toJS, null)
//         as JSNumber;
//     if (entityId.toDartInt == -1) {
//       throw Exception("Failed to get main camera");
//     }
//     return entityId.toDartInt;
//   }

//   @override
//   Future<MaterialInstance?> getMaterialInstanceAt(
//       ThermionEntity entity, int index) {
//     // TODO: implement getMaterialInstanceAt
//     throw UnimplementedError();
//   }

//   @override
//   Future requestFrame() async {
//     // TODO: implement requestFrame
//   }

//   @override
//   // TODO: implement sceneUpdated
//   Stream<SceneUpdateEvent> get sceneUpdated => throw UnimplementedError();

//   @override
//   Future setLayerVisibility(int layer, bool visible) {
//     // TODO: implement setLayerVisibility
//     throw UnimplementedError();
//   }

//   @override
//   Future setMaterialPropertyInt(ThermionEntity entity, String propertyName,
//       int materialIndex, int value) {
//     // TODO: implement setMaterialPropertyInt
//     throw UnimplementedError();
//   }

//   @override
//   Future setVisibilityLayer(ThermionEntity entity, int layer) {
//     // TODO: implement setVisibilityLayer
//     throw UnimplementedError();
//   }
  
//   @override
//   Future setCameraLensProjection({double near = kNear, double far = kFar, double? aspect, double focalLength = kFocalLength}) {
//     // TODO: implement setCameraLensProjection
//     throw UnimplementedError();
//   }
  
//   @override
//   Future<Camera> createCamera() {
//     // TODO: implement createCamera
//     throw UnimplementedError();
//   }
    
//   @override
//   Future setActiveCamera(covariant Camera camera) {
//     // TODO: implement setActiveCamera
//     throw UnimplementedError();
//   }
  
//   final _hooks = <Future Function()>[];

//   @override
//   Future registerRequestFrameHook(Future Function() hook) async {
//     if (!_hooks.contains(hook)) {
//       _hooks.add(hook);
//     }
//   }

//   @override
//   Future unregisterRequestFrameHook(Future Function() hook) async {
//     if (_hooks.contains(hook)) {
//       _hooks.remove(hook);
//     }
//   }
// }
