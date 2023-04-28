import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';

import 'package:flutter/services.dart';
import 'package:polyvox_filament/animations/bone_animation_data.dart';
import 'package:polyvox_filament/animations/morph_animation_data.dart';
import 'package:polyvox_filament/generated_bindings.dart';

typedef AssetManager = Pointer<Void>;
typedef FilamentViewer = Pointer<Void>;
typedef FilamentEntity = int;
const FilamentEntity FILAMENT_ASSET_ERROR = 0;

class FilamentController {
  late MethodChannel _channel = MethodChannel("app.polyvox.filament/event");

  double _pixelRatio = 1.0;
  ui.Size size = ui.Size.zero;

  int? _textureId;
  final _textureIdController = StreamController<int?>.broadcast();
  Stream<int?> get textureId => _textureIdController.stream;

  final _onInitRequestedController = StreamController.broadcast();
  Stream get onInitializationRequested => _onInitRequestedController.stream;

  final _initialized = Completer();
  Future get initialized => _initialized.future;

  late NativeLibrary _nativeLibrary;

  late FilamentViewer _viewer;
  late AssetManager _assetManager;

  bool _rendering = false;

  final TickerProvider _tickerProvider;
  Ticker? _ticker;

  ///
  /// This now uses an FFI implementation.
  /// Platform channels are only used to setup the context/texture (since this is platform-specific) and the render ticker.
  /// All other methods directly invoke the FFI functions defined in PolyvoxFilamentApi.cpp,
  /// which itself uses a threadpool so that calls are run on a separate thread.
  ///
  FilamentController(this._tickerProvider) {
    _channel.setMethodCallHandler((call) async {
      throw Exception("Unknown method channel invocation ${call.method}");
    });

    _textureIdController.onListen = () {
      _textureIdController.add(_textureId);
    };

    _nativeLibrary = NativeLibrary(Platform.isAndroid || Platform.isLinux
        ? DynamicLibrary.open("libpolyvox_filament_plugin.so")
        : DynamicLibrary.process());
  }

  Future initialize() async {
    _onInitRequestedController.add(true);
    return _initialized.future;
  }

  Future setRendering(bool render) async {
    _rendering = render;
  }

  void render() {
    _nativeLibrary.render(_viewer, 0);
  }

  int _frameLengthInMicroseconds = 1000000 ~/ 60;

  Future setFrameRate(int framerate) async {
    _frameLengthInMicroseconds = 1000000 ~/ framerate;
    _nativeLibrary.set_frame_interval(_viewer, 1 / framerate);
  }

  void setPixelRatio(double ratio) {
    _pixelRatio = ratio;
  }

  int _last = 0;

  Future createViewer(int width, int height) async {
    size = ui.Size(width * _pixelRatio, height * _pixelRatio);
    _textureId =
        await _channel.invokeMethod("createTexture", [size.width, size.height]);
    _textureIdController.add(_textureId);

    var glContext =
        Pointer<Void>.fromAddress(await _channel.invokeMethod("getContext"));
    final resourceLoader = Pointer<ResourceLoaderWrapper>.fromAddress(
        await _channel.invokeMethod("getResourceLoader"));

    _viewer = _nativeLibrary.create_filament_viewer(glContext, resourceLoader);
    if (Platform.isLinux) {
      // don't pass a surface to the SwapChain as we are effectively creating a headless SwapChain that will render into a RenderTarget associated with a texture
      _nativeLibrary.create_swap_chain(
          _viewer, nullptr, size.width.toInt(), size.height.toInt());

      var glTextureId = await _channel.invokeMethod("getGlTextureId");

      _nativeLibrary.create_render_target(
          _viewer, glTextureId, size.width.toInt(), size.height.toInt());
    } else {
      var surface =
          Pointer<Void>.fromAddress(await _channel.invokeMethod("getSurface"));
      _nativeLibrary.create_swap_chain(
          _viewer, surface, size.width.toInt(), size.height.toInt());
    }

    _nativeLibrary.update_viewport_and_camera_projection(
        _viewer, size.width.toInt(), size.height.toInt(), 1.0);

    _initialized.complete(true);
    _assetManager = _nativeLibrary.get_asset_manager(_viewer);

    _ticker = _tickerProvider.createTicker((Duration elapsed) async {
      if (elapsed.inMicroseconds - _last > _frameLengthInMicroseconds) {
        render();
        _last = elapsed.inMicroseconds;
      }
    });
    _ticker!.start();
  }

  Future resize(int width, int height,
      {double contentScaleFactor = 1.0}) async {
    // await setRendering(false);
    // _textureIdController.add(null);
    // _nativeLibrary.destroy_swap_chain(_viewer);
    // size = ui.Size(width * _pixelRatio, height * _pixelRatio);

    // _textureId = await _channel.invokeMethod("resize",
    //     [width * _pixelRatio, height * _pixelRatio, contentScaleFactor]);

    // _textureIdController.add(_textureId);
    // _nativeLibrary.create_swap_chain(_viewer, nullptr, width, height);
    // _nativeLibrary.create_render_target(
    //     _viewer, await _channel.invokeMethod("getGlTextureId"), width, height);
    // _nativeLibrary.update_viewport_and_camera_projection(
    //     _viewer, width, height, contentScaleFactor);
    // await setRendering(true);
  }

  void clearBackgroundImage() async {
    _nativeLibrary.clear_background_image(_viewer);
  }

  void setBackgroundImage(String path) async {
    _nativeLibrary.set_background_image(
        _viewer, path.toNativeUtf8().cast<Char>());
  }

  void setBackgroundColor(Color color) async {
    _nativeLibrary.set_background_color(
        _viewer,
        color.red.toDouble() / 255.0,
        color.green.toDouble() / 255.0,
        color.blue.toDouble() / 255.0,
        color.alpha.toDouble() / 255.0);
  }

  void setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    _nativeLibrary.set_background_image_position(_viewer, x, y, clamp ? 1 : 0);
  }

  void loadSkybox(String skyboxPath) async {
    _nativeLibrary.load_skybox(_viewer, skyboxPath.toNativeUtf8().cast<Char>());
  }

  void loadIbl(String lightingPath, {double intensity = 30000}) async {
    _nativeLibrary.load_ibl(
        _viewer, lightingPath.toNativeUtf8().cast<Char>(), intensity);
  }

  void removeSkybox() async {
    _nativeLibrary.remove_skybox(_viewer);
  }

  void removeIbl() async {
    _nativeLibrary.remove_ibl(_viewer);
  }

  // copied from LightManager.h
  //  enum class Type : uint8_t {
  //       SUN,            //!< Directional light that also draws a sun's disk in the sky.
  //       DIRECTIONAL,    //!< Directional light, emits light in a given direction.
  //       POINT,          //!< Point light, emits light from a position, in all directions.
  //       FOCUSED_SPOT,   //!< Physically correct spot light.
  //       SPOT,           //!< Spot light with coupling of outer cone and illumination disabled.
  //   };

  FilamentEntity addLight(
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
    return _nativeLibrary.add_light(_viewer, type, colour, intensity, posX,
        posY, posZ, dirX, dirY, dirZ, castShadows ? 1 : 0);
  }

  void removeLight(FilamentEntity light) async {
    _nativeLibrary.remove_light(_viewer, light);
  }

  void clearLights() async {
    _nativeLibrary.clear_lights(_viewer);
  }

  FilamentEntity loadGlb(String path, {bool unlit = false}) {
    var asset = _nativeLibrary.load_glb(
        _assetManager, path.toNativeUtf8().cast<Char>(), unlit ? 1 : 0);
    if (asset == FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    return asset;
  }

  FilamentEntity loadGltf(String path, String relativeResourcePath) {
    return _nativeLibrary.load_gltf(
        _assetManager,
        path.toNativeUtf8().cast<Char>(),
        relativeResourcePath.toNativeUtf8().cast<Char>());
  }

  void panStart(double x, double y) async {
    _nativeLibrary.grab_begin(_viewer, x * _pixelRatio, y * _pixelRatio, 1);
  }

  void panUpdate(double x, double y) async {
    _nativeLibrary.grab_update(_viewer, x * _pixelRatio, y * _pixelRatio);
  }

  void panEnd() async {
    _nativeLibrary.grab_end(_viewer);
  }

  void rotateStart(double x, double y) async {
    _nativeLibrary.grab_begin(_viewer, x * _pixelRatio, y * _pixelRatio, 0);
  }

  void rotateUpdate(double x, double y) async {
    _nativeLibrary.grab_update(_viewer, x * _pixelRatio, y * _pixelRatio);
  }

  void rotateEnd() async {
    _nativeLibrary.grab_end(_viewer);
  }

  void setMorphTargetWeights(FilamentEntity asset, List<double> weights) {
    throw Exception("TODO");
    // _nativeLibrary.set_morph_target_weights(_assetManager, asset, Float32List.fromList(weights));
  }

  List<String> getMorphTargetNames(FilamentEntity asset, String meshName) {
    var meshNamePtr = meshName.toNativeUtf8().cast<Char>();
    var count = _nativeLibrary.get_morph_target_name_count(
        _assetManager, asset, meshNamePtr);
    var names = <String>[];
    for (int i = 0; i < count; i++) {
      var outPtr = calloc<Char>(255);
      _nativeLibrary.get_morph_target_name(
          _assetManager, asset, meshNamePtr, outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }
    return names;
  }

  List<String> getAnimationNames(FilamentEntity asset) {
    var count = _nativeLibrary.get_animation_count(_assetManager, asset);
    var names = <String>[];
    for (int i = 0; i < count; i++) {
      var outPtr = calloc<Char>(255);
      _nativeLibrary.get_animation_name(_assetManager, asset, outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }
    return names;
  }

  ///
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  ///
  void setMorphAnimationData(
      FilamentEntity asset, MorphAnimationData animation) async {
    var data = calloc<Float>(animation.data.length);
    for (int i = 0; i < animation.data.length; i++) {
      data.elementAt(i).value = animation.data[i];
    }
    _nativeLibrary.set_morph_animation(
        _assetManager,
        asset,
        animation.meshName.toNativeUtf8().cast<Char>(),
        data,
        animation.numMorphWeights,
        animation.numFrames,
        animation.frameLengthInMs);
    calloc.free(data);
  }

  ///
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  /// for now we only allow animating a single bone (though multiple skinned targets are supported)
  ///
  void setBoneAnimation(
      FilamentEntity asset, BoneAnimationData animation) async {
    var data = calloc<Float>(animation.frameData.length);
    int offset = 0;
    var numFrames = animation.frameData.length ~/ 7;
    var boneNames = calloc<Pointer<Char>>(1);
    boneNames.elementAt(0).value =
        animation.boneName.toNativeUtf8().cast<Char>();

    var meshNames = calloc<Pointer<Char>>(animation.meshNames.length);
    for (int i = 0; i < animation.meshNames.length; i++) {
      meshNames.elementAt(i).value =
          animation.meshNames[i].toNativeUtf8().cast<Char>();
    }

    for (int i = 0; i < animation.frameData.length; i++) {
      data.elementAt(offset).value = animation.frameData[i];
      offset += 1;
    }

    _nativeLibrary.set_bone_animation(
        _assetManager,
        asset,
        data,
        numFrames,
        1,
        boneNames,
        meshNames,
        animation.meshNames.length,
        animation.frameLengthInMs);
    calloc.free(data);
  }

  void removeAsset(FilamentEntity asset) async {
    _nativeLibrary.remove_asset(_viewer, asset);
  }

  void clearAssets() async {
    _nativeLibrary.clear_assets(_viewer);
  }

  void zoomBegin() async {
    _nativeLibrary.scroll_begin(_viewer);
  }

  void zoomUpdate(double z) async {
    _nativeLibrary.scroll_update(_viewer, 0.0, 0.0, z);
  }

  void zoomEnd() async {
    _nativeLibrary.scroll_end(_viewer);
  }

  void playAnimation(FilamentEntity asset, int index,
      {bool loop = false, bool reverse = false}) async {
    _nativeLibrary.play_animation(
        _assetManager, asset, index, loop ? 1 : 0, reverse ? 1 : 0);
  }

  void setAnimationFrame(
      FilamentEntity asset, int index, int animationFrame) async {
    _nativeLibrary.set_animation_frame(
        _assetManager, asset, index, animationFrame);
  }

  void stopAnimation(FilamentEntity asset, int animationIndex) async {
    _nativeLibrary.stop_animation(_assetManager, asset, animationIndex);
  }

  void setCamera(FilamentEntity asset, String name) async {
    _nativeLibrary.set_camera(_viewer, asset, name.toNativeUtf8().cast<Char>());
  }

  void setCameraFocalLength(double focalLength) async {
    _nativeLibrary.set_camera_focal_length(_viewer, focalLength);
  }

  void setCameraFocusDistance(double focusDistance) async {
    _nativeLibrary.set_camera_focus_distance(_viewer, focusDistance);
  }

  void setCameraPosition(double x, double y, double z) async {
    _nativeLibrary.set_camera_position(_viewer, x, y, z);
  }

  void setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    _nativeLibrary.set_camera_exposure(
        _viewer, aperture, shutterSpeed, sensitivity);
  }

  void setCameraRotation(double rads, double x, double y, double z) async {
    _nativeLibrary.set_camera_rotation(_viewer, rads, x, y, z);
  }

  void setCameraModelMatrix(List<double> matrix) async {
    assert(matrix.length == 16);
    var ptr = calloc<Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr.elementAt(i).value = matrix[i];
    }
    _nativeLibrary.set_camera_model_matrix(_viewer, ptr);
  }

  void setTexture(FilamentEntity asset, String assetPath,
      {int renderableIndex = 0}) async {
    _nativeLibrary.set_texture(_assetManager, asset);
  }

  void transformToUnitCube(FilamentEntity asset) async {
    _nativeLibrary.transform_to_unit_cube(_assetManager, asset);
  }

  void setPosition(FilamentEntity asset, double x, double y, double z) async {
    _nativeLibrary.set_position(_assetManager, asset, x, y, z);
  }

  void setScale(FilamentEntity asset, double scale) async {
    _nativeLibrary.set_scale(_assetManager, asset, scale);
  }

  void setRotation(
      FilamentEntity asset, double rads, double x, double y, double z) async {
    _nativeLibrary.set_rotation(_assetManager, asset, rads, x, y, z);
  }
}
