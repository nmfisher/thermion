import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';
import 'package:polyvox_filament/filament_controller.dart';
import 'package:polyvox_filament/animations/bone_animation_data.dart';
import 'package:polyvox_filament/animations/morph_animation_data.dart';
import 'package:polyvox_filament/generated_bindings.dart';

class FilamentControllerFFI extends FilamentController {
  late MethodChannel _channel = MethodChannel("app.polyvox.filament/event");

  double _pixelRatio = 1.0;
  ui.Size size = ui.Size.zero;

  int? _textureId;
  final _textureIdController = StreamController<int?>.broadcast();
  Stream<int?> get textureId => _textureIdController.stream;

  Completer _isReadyForScene = Completer();
  Future get isReadyForScene => _isReadyForScene.future;

  late Pointer<Void>? _assetManager;

  late NativeLibrary _lib;

  Pointer<Void>? _viewer;

  bool _resizing = false;

  ///
  /// This controller uses platform channels to bridge Dart with the C/C++ code for the Filament API.
  /// Setting up the context/texture (since this is platform-specific) and the render ticker are platform-specific; all other methods are passed through by the platform channel to the methods specified in PolyvoxFilamentApi.h.
  ///
  FilamentControllerFFI() {
    _channel.setMethodCallHandler((call) async {
      throw Exception("Unknown method channel invocation ${call.method}");
    });
    _lib = NativeLibrary(Platform.isIOS || Platform.isMacOS
        ? DynamicLibrary.process()
        : DynamicLibrary.open("libpolyvox_filament.so"));
  }

  Future setRendering(bool render) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_rendering_ffi(_viewer!, render ? 1 : 0);
  }

  Future render() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.render_ffi(_viewer!);
  }

  Future setFrameRate(int framerate) async {
    await _channel.invokeMethod("setFrameInterval", 1.0 / framerate);
  }

  void setPixelRatio(double ratio) {
    _pixelRatio = ratio;
  }

  Future destroyViewer() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _viewer = null;
    _assetManager = null;
    _lib.destroy_filament_viewer_ffi(_viewer!);
    _isReadyForScene = Completer();
  }

  Future destroyTexture() async {
    await _channel.invokeMethod("destroyTexture");
    _textureId = null;
    _textureIdController.add(null);
  }

  ///
  /// You can insert a Filament viewport into the Flutter rendering hierarchy as follows:
  /// 1) Create a FilamentController
  /// 2) Insert a FilamentWidget into the rendering tree, passing this instance of FilamentController
  /// 3) Initially, the FilamentWidget will only contain an empty Container (by default, with a solid red background).
  ///    This widget will render a single frame to get its actual size, then will itself call [createViewer]. You do not need to call [createViewer] yourself.
  /// 4) The FilamentController
  /// 4) The FilamentWidget will replace the empty Container with a Texture widget
  /// If you need to wait
  ///
  Future createViewer(int width, int height) async {
    if (_viewer != null) {
      throw Exception(
          "Viewer already exists, make sure you call destroyViewer first");
    }
    if (_isReadyForScene.isCompleted) {
      throw Exception(
          "Do not call createViewer when a viewer has already been created without calling destroyViewer");
    }
    size = ui.Size(width * _pixelRatio, height * _pixelRatio);

    var textures =
        await _channel.invokeMethod("createTexture", [size.width, size.height]);
    var flutterTextureId = textures[0];
    _textureId = flutterTextureId;
    var pixelBuffer = textures[1] as int;
    var nativeTexture = textures[2] as int;

    var renderCallbackResult = await _channel.invokeMethod("getRenderCallback");
    var renderCallback =
        Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(
            renderCallbackResult[0]);
    var renderCallbackOwner =
        Pointer<Void>.fromAddress(renderCallbackResult[1]);

    var sharedContext = await _channel.invokeMethod("getSharedContext");
    var loader = await _channel.invokeMethod("getResourceLoaderWrapper");

    _viewer = _lib.create_filament_viewer_ffi(
        Pointer<Void>.fromAddress(sharedContext ?? 0),
        Pointer<ResourceLoaderWrapper>.fromAddress(loader),
        renderCallback,
        renderCallbackOwner);

    _lib.create_swap_chain(
        _viewer!, Pointer<Void>.fromAddress(pixelBuffer), width, height);

    _lib.create_render_target(_viewer!, nativeTexture, width, height);

    _lib.update_viewport_and_camera_projection_ffi(
        _viewer!, width, height, 1.0);

    _assetManager = _lib.get_asset_manager(_viewer!);

    _textureIdController.add(_textureId);

    _isReadyForScene.complete(true);
  }

  Future resize(int width, int height,
      {double contentScaleFactor = 1.0}) async {
    _resizing = true;
    _textureId = await _channel.invokeMethod("resize",
        [width * _pixelRatio, height * _pixelRatio, contentScaleFactor]);
    _textureIdController.add(_textureId);
    _resizing = false;
  }

  Future clearBackgroundImage() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.clear_background_image_ffi(_viewer!);
  }

  Future setBackgroundImage(String path, {bool fillHeight = false}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_background_image_ffi(
        _viewer!, path.toNativeUtf8().cast<Char>(), fillHeight ? 1 : 0);
  }

  Future setBackgroundColor(Color color) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_background_color_ffi(
        _viewer!,
        color.red.toDouble() / 255.0,
        color.green.toDouble() / 255.0,
        color.blue.toDouble() / 255.0,
        color.alpha.toDouble() / 255.0);
  }

  Future setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_background_image_position_ffi(_viewer!, x, y, clamp ? 1 : 0);
  }

  Future loadSkybox(String skyboxPath) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.load_skybox_ffi(_viewer!, skyboxPath.toNativeUtf8().cast<Char>());
  }

  Future loadIbl(String lightingPath, {double intensity = 30000}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.load_ibl_ffi(
        _viewer!, lightingPath.toNativeUtf8().cast<Char>(), intensity);
  }

  Future removeSkybox() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_skybox_ffi(_viewer!);
  }

  Future removeIbl() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_ibl_ffi(_viewer!);
  }

  Future<FilamentEntity> addLight(
      int type,
      double colour,
      double intensity,
      double posX,
      double posY,
      double posZ,
      double dirX,
      double dirY,
      double dirZ,
      bool castShadows) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var entity = _lib.add_light_ffi(_viewer!, type, colour, intensity, posX,
        posY, posZ, dirX, dirY, dirZ, castShadows ? 1 : 0);
    return entity;
  }

  Future removeLight(FilamentEntity light) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_light_ffi(_viewer!, light);
  }

  Future clearLights() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.clear_lights_ffi(_viewer!);
  }

  Future<FilamentEntity> loadGlb(String path, {bool unlit = false}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    if (unlit) {
      throw Exception("Not yet implemented");
    }
    var asset = _lib.load_glb_ffi(
        _assetManager!, path.toNativeUtf8().cast<Char>(), unlit ? 1 : 0);
    if (asset == FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    return asset;
  }

  Future<FilamentEntity> loadGltf(
      String path, String relativeResourcePath) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var entity = _lib.load_gltf_ffi(
        _assetManager!,
        path.toNativeUtf8().cast<Char>(),
        relativeResourcePath.toNativeUtf8().cast<Char>());
    return entity;
  }

  Future panStart(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_begin(_viewer!, x * _pixelRatio, y * _pixelRatio, 1);
  }

  Future panUpdate(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_update(_viewer!, x * _pixelRatio, y * _pixelRatio);
  }

  Future panEnd() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_end(_viewer!);
  }

  Future rotateStart(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_begin(_viewer!, x * _pixelRatio, y * _pixelRatio, 0);
  }

  Future rotateUpdate(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_update(_viewer!, x * _pixelRatio, y * _pixelRatio);
  }

  Future rotateEnd() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_end(_viewer!);
  }

  Future setMorphTargetWeights(
      FilamentEntity asset, String meshName, List<double> weights) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var weightsPtr = calloc<Float>(weights.length);

    for (int i = 0; i < weights.length; i++) {
      weightsPtr.elementAt(i).value = weights[i];
    }
    _lib.set_morph_target_weights_ffi(_assetManager!, asset,
        meshName.toNativeUtf8().cast<Char>(), weightsPtr, weights.length);
    calloc.free(weightsPtr);
  }

  Future<List<String>> getMorphTargetNames(
      FilamentEntity asset, String meshName) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var names = <String>[];
    var count = _lib.get_morph_target_name_count_ffi(
        _assetManager!, asset, meshName.toNativeUtf8().cast<Char>());
    var outPtr = calloc<Char>(255);
    for (int i = 0; i < count; i++) {
      _lib.get_morph_target_name(_assetManager!, asset,
          meshName.toNativeUtf8().cast<Char>(), outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }
    calloc.free(outPtr);
    return names.cast<String>();
  }

  Future<List<String>> getAnimationNames(FilamentEntity asset) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var animationCount = _lib.get_animation_count(_assetManager!, asset);
    var names = <String>[];
    var outPtr = calloc<Char>(255);
    for (int i = 0; i < animationCount; i++) {
      _lib.get_animation_name_ffi(_assetManager!, asset, outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }

    return names;
  }

  ///
  /// Returns the length (in seconds) of the animation at the given index.
  ///
  Future<double> getAnimationDuration(
      FilamentEntity asset, int animationIndex) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var duration = await _channel.invokeMethod(
        "getAnimationDuration", [_assetManager!, asset, animationIndex]);
    return duration as double;
  }

  ///
  /// Create/start a dynamic morph target animation for [asset].
  ///
  Future setMorphAnimationData(
      FilamentEntity asset, MorphAnimationData animation) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }

    var dataPtr = calloc<Float>(animation.data.length);
    for (int i = 0; i < animation.data.length; i++) {
      dataPtr.elementAt(i).value = animation.data[i];
    }

    var morphIndicesPtr = calloc<Int>(animation.animatedMorphIndices.length);
    for (int i = 0; i < animation.numMorphTargets; i++) {
      // morphIndicesPtr.elementAt(i) = animation.animatedMorphIndices[i];
    }

    _lib.set_morph_animation(
        _assetManager!,
        asset,
        animation.meshName.toNativeUtf8().cast<Char>(),
        dataPtr,
        morphIndicesPtr,
        animation.numMorphTargets,
        animation.numFrames,
        (animation.frameLengthInMs));
    calloc.free(dataPtr);
    calloc.free(morphIndicesPtr);
  }

  ///
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  /// for now we only allow animating a single bone (though multiple skinned targets are supported)
  ///
  Future setBoneAnimation(
      FilamentEntity asset, BoneAnimationData animation) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    // var data = calloc<Float>(animation.frameData.length);
    // int offset = 0;
    // var numFrames = animation.frameData.length ~/ 7;
    // var boneNames = calloc<Pointer<Char>>(1);
    // boneNames.elementAt(0).value =
    //     animation.boneName.toNativeUtf8().cast<Char>();

    // var meshNames = calloc<Pointer<Char>>(animation.meshNames.length);
    // for (int i = 0; i < animation.meshNames.length; i++) {
    //   meshNames.elementAt(i).value =
    //       animation.meshNames[i].toNativeUtf8().cast<Char>();
    // }

    // for (int i = 0; i < animation.frameData.length; i++) {
    //   data.elementAt(offset).value = animation.frameData[i];
    //   offset += 1;
    // }

    // await _channel.invokeMethod("setBoneAnimation", [
    //   _assetManager!,
    //   asset,
    //   data,
    //   numFrames,
    //   1,
    //   boneNames,
    //   meshNames,
    //   animation.meshNames.length,
    //   animation.frameLengthInMs
    // ]);
    // calloc.free(data);
  }

  Future removeAsset(FilamentEntity asset) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_asset_ffi(_assetManager!, asset);
  }

  Future clearAssets() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.clear_assets_ffi(_viewer!);
  }

  Future zoomBegin() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("scrollBegin");
  }

  Future zoomUpdate(double z) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.scroll_update(_viewer!, 0.0, 0.0, z);
  }

  Future zoomEnd() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.scroll_end(_viewer!);
  }

  Future playAnimation(FilamentEntity asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.play_animation_ffi(_assetManager!, asset, index, loop ? 1 : 0,
        reverse ? 1 : 0, replaceActive ? 1 : 0, crossfade);
  }

  Future setAnimationFrame(
      FilamentEntity asset, int index, int animationFrame) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod(
        "setAnimationFrame", [_assetManager!, asset, index, animationFrame]);
  }

  Future stopAnimation(FilamentEntity asset, int animationIndex) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel
        .invokeMethod("stopAnimation", [_assetManager!, asset, animationIndex]);
  }

  Future setCamera(FilamentEntity asset, String? name) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    if (await _channel.invokeMethod("setCamera", [asset, name]) != true) {
      throw Exception("Failed to set camera");
    }
  }

  Future setToneMapping(ToneMapper mapper) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }

    _lib.set_tone_mapping_ffi(_viewer!, mapper.index);
  }

  Future setBloom(double bloom) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_bloom_ffi(_viewer!, bloom);
  }

  Future setCameraFocalLength(double focalLength) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_camera_focal_length(_viewer!, focalLength);
  }

  Future setCameraFocusDistance(double focusDistance) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_camera_focus_distance(_viewer!, focusDistance);
  }

  Future setCameraPosition(double x, double y, double z) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_camera_position(_viewer!, x, y, z);
  }

  Future moveCameraToAsset(FilamentEntity asset) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.move_camera_to_asset(_viewer!, asset);
  }

  Future setViewFrustumCulling(bool enabled) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_view_frustum_culling(_viewer!, enabled ? 1 : 0);
  }

  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_camera_exposure(_viewer!, aperture, shutterSpeed, sensitivity);
  }

  Future setCameraRotation(double rads, double x, double y, double z) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_camera_rotation(_viewer!, rads, x, y, z);
  }

  Future setCameraModelMatrix(List<double> matrix) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    assert(matrix.length == 16);
    var ptr = calloc<Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr.elementAt(i).value = matrix[i];
    }
    _lib.set_camera_model_matrix(_viewer!, ptr);
    calloc.free(ptr);
  }

  Future setMaterialColor(FilamentEntity asset, String meshName,
      int materialIndex, Color color) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var result = _lib.set_material_color(
        _assetManager!,
        asset,
        meshName.toNativeUtf8().cast<Char>(),
        materialIndex,
        color.red.toDouble() / 255.0,
        color.green.toDouble() / 255.0,
        color.blue.toDouble() / 255.0,
        color.alpha.toDouble() / 255.0);
    if (result != 1) {
      throw Exception("Failed to set material color");
    }
  }

  Future transformToUnitCube(FilamentEntity asset) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.transform_to_unit_cube(_assetManager!, asset);
  }

  Future setPosition(FilamentEntity asset, double x, double y, double z) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_position(_assetManager!, asset, x, y, z);
  }

  Future setScale(FilamentEntity asset, double scale) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_scale(_assetManager!, asset, scale);
  }

  Future setRotation(
      FilamentEntity asset, double rads, double x, double y, double z) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_rotation(_assetManager!, asset, rads, x, y, z);
  }

  Future hide(FilamentEntity asset, String meshName) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    if (_lib.hide_mesh(
            _assetManager!, asset, meshName.toNativeUtf8().cast<Char>()) !=
        1) {}
  }

  Future reveal(FilamentEntity asset, String meshName) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    if (_lib.reveal_mesh(
            _assetManager!, asset, meshName.toNativeUtf8().cast<Char>()) !=
        1) {
      throw Exception("Failed to reveal mesh $meshName");
    }
  }
}
