import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:polyvox_filament/animations/bone_animation_data.dart';
import 'package:polyvox_filament/animations/morph_animation_data.dart';

typedef AssetManager = int;
typedef FilamentEntity = int;
const FilamentEntity FILAMENT_ASSET_ERROR = 0;

enum ToneMapper { ACES, FILMIC, LINEAR }

class FilamentController {
  late MethodChannel _channel = MethodChannel("app.polyvox.filament/event");

  double _pixelRatio = 1.0;
  ui.Size size = ui.Size.zero;

  int? _textureId;
  final _textureIdController = StreamController<int?>.broadcast();
  Stream<int?> get textureId => _textureIdController.stream;

  Completer _isReadyForScene = Completer();
  Future get isReadyForScene => _isReadyForScene.future;

  late AssetManager _assetManager;

  int? _viewer;

  ///
  /// This controller uses platform channels to bridge Dart with the C/C++ code for the Filament API.
  /// Setting up the context/texture (since this is platform-specific) and the render ticker are platform-specific; all other methods are passed through by the platform channel to the methods specified in PolyvoxFilamentApi.h.
  ///
  FilamentController() {
    _channel.setMethodCallHandler((call) async {
      throw Exception("Unknown method channel invocation ${call.method}");
    });
  }

  Future setRendering(bool render) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    return _channel.invokeMethod("setRendering", render);
  }

  Future render() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("render");
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
    await _channel.invokeMethod("destroyViewer");
    _isReadyForScene = Completer();
  }

  Future destroyTexture() async {
    await _channel.invokeMethod("destroyTexture");
    _textureId = null;
    _assetManager = 0;
    _textureIdController.add(null);
  }

  ///
  /// The process for creating/initializing the Filament layer is as follows:
  /// 1) Create a FilamentController
  /// 2) Insert a FilamentWidget into the rendering tree
  /// 3) Initially, this widget will only contain an empty Container. After the first frame is rendered, the widget itself will automatically call [createViewer] with the width/height from its constraints
  /// 4) The FilamentWidget will replace the empty Container with the Texture widget.
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

    _textureId =
        await _channel.invokeMethod("createTexture", [size.width, size.height]);

    _viewer = await _channel
        .invokeMethod("createFilamentViewer", [size.width, size.height]);

    await _channel.invokeMethod("updateViewportAndCameraProjection",
        [size.width.toInt(), size.height.toInt(), 1.0]);
    _assetManager = await _channel.invokeMethod("getAssetManager");

    _textureIdController.add(_textureId);

    _isReadyForScene.complete(true);
  }

  bool _resizing = false;

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
    await _channel.invokeMethod("clearBackgroundImage");
  }

  Future setBackgroundImage(String path, {bool fillHeight = false}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setBackgroundImage", [path, fillHeight]);
  }

  Future setBackgroundColor(Color color) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setBackgroundColor", [
      color.red.toDouble() / 255.0,
      color.green.toDouble() / 255.0,
      color.blue.toDouble() / 255.0,
      color.alpha.toDouble() / 255.0
    ]);
  }

  Future setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel
        .invokeMethod("setBackgroundImagePosition", [x, y, clamp ? 1 : 0]);
  }

  Future loadSkybox(String skyboxPath) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("loadSkybox", skyboxPath);
  }

  Future loadIbl(String lightingPath, {double intensity = 30000}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("loadIbl", [lightingPath, intensity]);
  }

  Future removeSkybox() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("removeSkybox");
  }

  Future removeIbl() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("removeIbl");
  }

  // copied from LightManager.h
  //  enum class Type : uint8_t {
  //       SUN,            //!< Directional light that also draws a sun's disk in the sky.
  //       DIRECTIONAL,    //!< Directional light, emits light in a given direction.
  //       POINT,          //!< Point light, emits light from a position, in all directions.
  //       FOCUSED_SPOT,   //!< Physically correct spot light.
  //       SPOT,           //!< Spot light with coupling of outer cone and illumination disabled.
  //   };
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
    var entity = await _channel.invokeMethod("addLight", [
      type,
      colour,
      intensity,
      posX,
      posY,
      posZ,
      dirX,
      dirY,
      dirZ,
      castShadows ? 1 : 0
    ]);
    return entity as FilamentEntity;
  }

  Future removeLight(FilamentEntity light) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("removeLight", light);
  }

  Future clearLights() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("clearLights");
  }

  Future<FilamentEntity> loadGlb(String path, {bool unlit = false}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var asset =
        await _channel.invokeMethod("loadGlb", [_assetManager, path, unlit]);
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
    var entity = await _channel
        .invokeMethod("loadGltf", [_assetManager, path, relativeResourcePath]);
    return entity as FilamentEntity;
  }

  Future panStart(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel
        .invokeMethod("grabBegin", [x * _pixelRatio, y * _pixelRatio, 1]);
  }

  Future panUpdate(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel
        .invokeMethod("grabUpdate", [x * _pixelRatio, y * _pixelRatio]);
  }

  Future panEnd() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("grabEnd");
  }

  Future rotateStart(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel
        .invokeMethod("grabBegin", [x * _pixelRatio, y * _pixelRatio, 0]);
  }

  Future rotateUpdate(double x, double y) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel
        .invokeMethod("grabUpdate", [x * _pixelRatio, y * _pixelRatio]);
  }

  Future rotateEnd() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("grabEnd");
  }

  Future setMorphTargetWeights(
      FilamentEntity asset, String meshName, List<double> weights) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setMorphTargetWeights",
        [_assetManager, asset, meshName, weights, weights.length]);
  }

  Future<List<String>> getMorphTargetNames(
      FilamentEntity asset, String meshName) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var names = await _channel
        .invokeMethod("getMorphTargetNames", [_assetManager, asset, meshName]);
    return names.cast<String>();
  }

  Future<List<String>> getAnimationNames(FilamentEntity asset) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var names = await _channel
        .invokeMethod("getAnimationNames", [_assetManager, asset]);
    return names.cast<String>();
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
        "getAnimationDuration", [_assetManager, asset, animationIndex]);
    return duration as double;
  }

  ///
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  ///
  Future setMorphAnimationData(
      FilamentEntity asset, MorphAnimationData animation) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setMorphAnimation", [
      _assetManager,
      asset,
      animation.meshName,
      animation.data,
      animation.animatedMorphIndices,
      animation.numMorphTargets,
      animation.numFrames,
      animation.frameLengthInMs
    ]);
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
    //   _assetManager,
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
    await _channel.invokeMethod("removeAsset", asset);
  }

  Future clearAssets() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("clearAssets");
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
    await _channel.invokeMethod("scrollUpdate", [0.0, 0.0, z]);
  }

  Future zoomEnd() async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("scrollEnd");
  }

  Future playAnimation(FilamentEntity asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("playAnimation",
        [_assetManager, asset, index, loop, reverse, replaceActive, crossfade]);
  }

  Future setAnimationFrame(
      FilamentEntity asset, int index, int animationFrame) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod(
        "setAnimationFrame", [_assetManager, asset, index, animationFrame]);
  }

  Future stopAnimation(FilamentEntity asset, int animationIndex) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel
        .invokeMethod("stopAnimation", [_assetManager, asset, animationIndex]);
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
    if (!await _channel.invokeMethod("setToneMapping", mapper.index)) {
      throw Exception("Failed to set tone mapper");
    }
  }

  Future setBloom(double bloom) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    if (!await _channel.invokeMethod("setBloom", bloom)) {
      throw Exception("Failed to set bloom");
    }
  }

  Future setCameraFocalLength(double focalLength) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setCameraFocalLength", focalLength);
  }

  Future setCameraFocusDistance(double focusDistance) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setCameraFocusDistance", focusDistance);
  }

  Future setCameraPosition(double x, double y, double z) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setCameraPosition", [x, y, z]);
  }

  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod(
        "setCameraExposure", [aperture, shutterSpeed, sensitivity]);
  }

  Future setCameraRotation(double rads, double x, double y, double z) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setCameraRotation", [rads, x, y, z]);
  }

  Future setCameraModelMatrix(List<double> matrix) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    assert(matrix.length == 16);
    await _channel.invokeMethod("setCameraModelMatrix", matrix);
  }

  Future setTexture(FilamentEntity asset, String assetPath,
      {int renderableIndex = 0}) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setTexture", [_assetManager, asset]);
  }

  Future setMaterialColor(FilamentEntity asset, String meshName,
      int materialIndex, Color color) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    var result = await _channel.invokeMethod("setMaterialColor", [
      _assetManager,
      asset,
      meshName,
      materialIndex,
      [
        color.red.toDouble() / 255.0,
        color.green.toDouble() / 255.0,
        color.blue.toDouble() / 255.0,
        color.alpha.toDouble() / 255.0
      ]
    ]);
    if (!result) {
      throw Exception("Failed to set material color");
    }
  }

  Future transformToUnitCube(FilamentEntity asset) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("transformToUnitCube", [_assetManager, asset]);
  }

  Future setPosition(FilamentEntity asset, double x, double y, double z) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setPosition", [_assetManager, asset, x, y, z]);
  }

  Future setScale(FilamentEntity asset, double scale) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel.invokeMethod("setScale", [_assetManager, asset, scale]);
  }

  Future setRotation(
      FilamentEntity asset, double rads, double x, double y, double z) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    await _channel
        .invokeMethod("setRotation", [_assetManager, asset, rads, x, y, z]);
  }

  Future hide(FilamentEntity asset, String meshName) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    if (await _channel
            .invokeMethod("hideMesh", [_assetManager, asset, meshName]) !=
        1) {
      throw Exception("Failed to hide mesh $meshName");
    }
  }

  Future reveal(FilamentEntity asset, String meshName) async {
    if (_viewer == null || _resizing) {
      throw Exception("No viewer available, ignoring");
    }
    if (await _channel
            .invokeMethod("revealMesh", [_assetManager, asset, meshName]) !=
        1) {
      throw Exception("Failed to reveal mesh $meshName");
    }
  }
}
