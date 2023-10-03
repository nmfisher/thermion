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
    late DynamicLibrary dl;
    if (Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
      dl = DynamicLibrary.process();
    } else {
      dl = DynamicLibrary.open("libpolyvox_filament_android.so");
    }
    _lib = NativeLibrary(dl);
  }

  @override
  Future setRendering(bool render) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_rendering_ffi(_viewer!, render);
  }

  @override
  Future render() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.render_ffi(_viewer!);
  }

  @override
  Future setFrameRate(int framerate) async {
    _lib.set_frame_interval_ffi(1.0 / framerate);
  }

  @override
  void setPixelRatio(double ratio) {
    _pixelRatio = ratio;
  }

  @override
  Future destroyViewer() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _viewer = null;
    _assetManager = null;
    _lib.destroy_filament_viewer_ffi(_viewer!);
    _isReadyForScene = Completer();
  }

  @override
  Future destroyTexture() async {
    await _channel.invokeMethod("destroyTexture");
    _textureId = null;
    _textureIdController.add(null);
  }

  ///
  /// Called by `FilamentWidget`. You do not need to call this yourself.
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

    // void* on iOS (pointer to pixel buffer), void* on Android (pointer to native window), null on Windows/macOS
    var surfaceAddress = textures[1] as int? ?? 0;

    // null on iOS/Android, void* on MacOS (pointer to metal texture), GLuid on Windows/Linux
    var nativeTexture = textures[2] as int? ?? 0;

    var driver = nullptr.cast<Void>();
    if (Platform.isWindows) {
      driver = Pointer<Void>.fromAddress(
          await _channel.invokeMethod("getDriverPlatform"));
    }

    var renderCallbackResult = await _channel.invokeMethod("getRenderCallback");
    var renderCallback =
        Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(
            renderCallbackResult[0]);
    var renderCallbackOwner =
        Pointer<Void>.fromAddress(renderCallbackResult[1]);

    var sharedContext = await _channel.invokeMethod("getSharedContext");
    print("Got shared context : $sharedContext");
    var loader = await _channel.invokeMethod("getResourceLoaderWrapper");

    _viewer = _lib.create_filament_viewer_ffi(
        Pointer<Void>.fromAddress(sharedContext ?? 0),
        driver,
        Pointer<ResourceLoaderWrapper>.fromAddress(loader),
        renderCallback,
        renderCallbackOwner);

    if (_viewer!.address == 0) {
      throw Exception("Failed to create viewer. Check logs for details");
    }

    _lib.create_swap_chain_ffi(
        _viewer!, Pointer<Void>.fromAddress(surfaceAddress), width, height);
    if (nativeTexture != 0) {
      assert(surfaceAddress == 0);
      _lib.create_render_target(_viewer!, nativeTexture, width, height);
    }

    _lib.update_viewport_and_camera_projection_ffi(
        _viewer!, width, height, 1.0);

    _assetManager = _lib.get_asset_manager(_viewer!);

    _textureIdController.add(_textureId);

    _isReadyForScene.complete(true);
  }

  @override
  Future resize(int width, int height, {double scaleFactor = 1.0}) async {
    _resizing = true;
    setRendering(false);
    _textureId = await _channel.invokeMethod(
        "resize", [width * _pixelRatio, height * _pixelRatio, scaleFactor]);
    _textureIdController.add(_textureId);
    _lib.update_viewport_and_camera_projection_ffi(
        _viewer!, width, height, scaleFactor);
    _resizing = false;
    setRendering(true);
  }

  @override
  Future clearBackgroundImage() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.clear_background_image_ffi(_viewer!);
  }

  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_background_image_ffi(
        _viewer!, path.toNativeUtf8().cast<Char>(), fillHeight);
  }

  @override
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

  @override
  Future setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_background_image_position_ffi(_viewer!, x, y, clamp);
  }

  @override
  Future loadSkybox(String skyboxPath) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.load_skybox_ffi(_viewer!, skyboxPath.toNativeUtf8().cast<Char>());
  }

  @override
  Future loadIbl(String lightingPath, {double intensity = 30000}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.load_ibl_ffi(
        _viewer!, lightingPath.toNativeUtf8().cast<Char>(), intensity);
  }

  @override
  Future removeSkybox() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_skybox_ffi(_viewer!);
  }

  @override
  Future removeIbl() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_ibl_ffi(_viewer!);
  }

  @override
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
        posY, posZ, dirX, dirY, dirZ, castShadows);
    return entity;
  }

  @override
  Future removeLight(FilamentEntity light) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_light_ffi(_viewer!, light);
  }

  @override
  Future clearLights() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.clear_lights_ffi(_viewer!);
  }

  @override
  Future<FilamentEntity> loadGlb(String path, {bool unlit = false}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    if (unlit) {
      throw Exception("Not yet implemented");
    }
    var asset = _lib.load_glb_ffi(
        _assetManager!, path.toNativeUtf8().cast<Char>(), unlit);
    if (asset == FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    return asset;
  }

  @override
  Future<FilamentEntity> loadGltf(String path, String relativeResourcePath,
      {bool force = false}) async {
    if (Platform.isWindows && !force) {
      throw Exception(
          "loadGltf has a race condition on Windows which is likely to crash your program. If you really want to try, pass force=true to loadGltf");
    }
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var asset = _lib.load_gltf_ffi(
        _assetManager!,
        path.toNativeUtf8().cast<Char>(),
        relativeResourcePath.toNativeUtf8().cast<Char>());
    if (asset == FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    return asset;
  }

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  @override
  Future panStart(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_begin(_viewer!, x * _pixelRatio, y * _pixelRatio, true);
  }

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  @override
  Future panUpdate(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_update(_viewer!, x * _pixelRatio, y * _pixelRatio);
  }

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  @override
  Future panEnd() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_end(_viewer!);
  }

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  @override
  Future rotateStart(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_begin(_viewer!, x * _pixelRatio, y * _pixelRatio, false);
  }

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  @override
  Future rotateUpdate(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_update(_viewer!, x * _pixelRatio, y * _pixelRatio);
  }

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  @override
  Future rotateEnd() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_end(_viewer!);
  }

  ///
  /// Set the weights for all morph targets under node [meshName] in [asset] to [weights].
  ///
  @override
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

  @override
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

  @override
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
  @override
  Future<double> getAnimationDuration(
      FilamentEntity asset, int animationIndex) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var duration =
        _lib.get_animation_duration_ffi(_assetManager!, asset, animationIndex);

    return duration;
  }

  ///
  /// Create/start a dynamic morph target animation for [asset].
  ///
  @override
  Future setMorphAnimationData(
      FilamentEntity asset, MorphAnimationData animation) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }

    var dataPtr = calloc<Float>(animation.data.length);
    for (int i = 0; i < animation.data.length; i++) {
      dataPtr.elementAt(i).value = animation.data[i];
    }

    Pointer<Int> idxPtr = calloc<Int>(animation.animatedMorphIndices.length);
    for (int i = 0; i < animation.numMorphTargets; i++) {
      idxPtr.elementAt(i).value = animation.animatedMorphIndices[i];
    }

    _lib.set_morph_animation(
        _assetManager!,
        asset,
        animation.meshName.toNativeUtf8().cast<Char>(),
        dataPtr,
        idxPtr,
        animation.numMorphTargets,
        animation.numFrames,
        (animation.frameLengthInMs));
    calloc.free(dataPtr);
    calloc.free(idxPtr);
  }

  ///
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  /// for now we only allow animating a single bone (though multiple skinned targets are supported)
  ///
  @override
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

  ///
  /// Removes/destroys the specified entity from the scene.
  /// [asset] will no longer be a valid handle after this method is called; ensure you immediately discard all references once this method is complete.
  ///
  @override
  Future removeAsset(FilamentEntity asset) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_asset_ffi(_viewer!, asset);
  }

  ///
  /// Removes/destroys all renderable entities from the scene (including cameras).
  /// All [FilamentEntity] handles will no longer be valid after this method is called; ensure you immediately discard all references to all entities once this method is complete.
  ///
  @override
  Future clearAssets() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.clear_assets_ffi(_viewer!);
  }

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  @override
  Future zoomBegin() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.scroll_begin(_viewer!);
  }

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  @override
  Future zoomUpdate(double z) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.scroll_update(_viewer!, 0.0, 0.0, z);
  }

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  @override
  Future zoomEnd() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.scroll_end(_viewer!);
  }

  ///
  /// Schedules the glTF animation at [index] in [asset] to start playing on the next frame.
  ///
  @override
  Future playAnimation(FilamentEntity asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.play_animation_ffi(
        _assetManager!, asset, index, loop, reverse, replaceActive, crossfade);
  }

  Future setAnimationFrame(
      FilamentEntity asset, int index, int animationFrame) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_animation_frame(_assetManager!, asset, index, animationFrame);
  }

  Future stopAnimation(FilamentEntity asset, int animationIndex) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.stop_animation(_assetManager!, asset, animationIndex);
  }

  ///
  /// Sets the current scene camera to the glTF camera under [name] in [asset].
  ///
  @override
  Future setCamera(FilamentEntity asset, String? name) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var result = _lib.set_camera(
        _viewer!, asset, name?.toNativeUtf8()?.cast<Char>() ?? nullptr);
    if (!result) {
      throw Exception("Failed to set camera");
    }
  }

  ///
  /// Sets the tone mapping.
  ///
  @override
  Future setToneMapping(ToneMapper mapper) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }

    _lib.set_tone_mapping_ffi(_viewer!, mapper.index);
  }

  ///
  /// Sets the strength of the bloom.
  ///
  @override
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

  ///
  /// Enables/disables frustum culling. Currently we don't expose a method for manipulating the camera projection/culling matrices so this is your only option to deal with unwanted near/far clipping.
  ///
  @override
  Future setViewFrustumCulling(bool enabled) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_view_frustum_culling(_viewer!, enabled);
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
