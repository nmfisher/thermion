import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';
import 'package:polyvox_filament/filament_controller.dart';

import 'package:polyvox_filament/animations/animation_data.dart';
import 'package:polyvox_filament/generated_bindings.dart';

const FilamentEntity _FILAMENT_ASSET_ERROR = 0;

class FilamentControllerFFI extends FilamentController {
  late MethodChannel _channel = MethodChannel("app.polyvox.filament/event");

  double _pixelRatio = 1.0;

  late Pointer<Void>? _assetManager;

  late NativeLibrary _lib;

  Pointer<Void>? _viewer;

  final String? uberArchivePath;

  Stream<bool> get hasViewer => _hasViewerController.stream;
  final _hasViewerController = StreamController<bool>();

  Stream<FilamentEntity> get pickResult => _pickResultController.stream;
  final _pickResultController = StreamController<FilamentEntity>.broadcast();

  @override
  TextureDetails? textureDetails;

  ///
  /// This controller uses platform channels to bridge Dart with the C/C++ code for the Filament API.
  /// Setting up the context/texture (since this is platform-specific) and the render ticker are platform-specific; all other methods are passed through by the platform channel to the methods specified in PolyvoxFilamentApi.h.
  ///
  FilamentControllerFFI({this.uberArchivePath}) {
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

  bool _rendering = false;
  bool get rendering => _rendering;

  @override
  Future setRendering(bool render) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _rendering = render;
    _lib.set_rendering_ffi(_viewer!, render);
  }

  @override
  Future render() async {
    if (_viewer == null) {
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
    print("Set pixel ratio to $ratio");
  }

  @override
  Future destroy() async {
    await destroyViewer();
    await destroyTexture();
  }

  @override
  Future destroyViewer() async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    var viewer = _viewer;

    _viewer = null;

    _assetManager = null;
    _lib.destroy_filament_viewer_ffi(viewer!);
    _hasViewerController.add(false);
  }

  @override
  Future destroyTexture() async {
    if (textureDetails != null) {
      await _channel.invokeMethod("destroyTexture", textureDetails!.textureId);
    }
    print("Texture destroyed");
  }

  Pointer<Void> _driver = nullptr.cast<Void>();


  ///
  /// Called by `FilamentWidget`. You do not need to call this yourself.
  ///
  @override
  Future createViewer(int width, int height) async {
    if (_viewer != null) {
      throw Exception(
          "Viewer already exists, make sure you call destroyViewer first");
    }
    if (textureDetails != null) {
      throw Exception(
          "Texture already exists, make sure you call destroyTexture first");
    }

    var loader = Pointer<ResourceLoaderWrapper>.fromAddress(
        await _channel.invokeMethod("getResourceLoaderWrapper"));
    if (loader == nullptr) {
      throw Exception("Failed to get resource loader");
    }

    var size = ui.Size(width * _pixelRatio, height * _pixelRatio);

    print("Creating viewer with size $size");

    var textures =
        await _channel.invokeMethod("createTexture", [size.width, size.height]);
    var flutterTextureId = textures[0];

    // void* on iOS (pointer to pixel buffer), void* on Android (pointer to native window), null on Windows/macOS
    var surfaceAddress = textures[1] as int? ?? 0;

    // null on iOS/Android, void* on MacOS (pointer to metal texture), GLuid on Windows/Linux
    var nativeTexture = textures[2] as int? ?? 0;

    print("Using flutterTextureId $flutterTextureId, surface $surfaceAddress and nativeTexture $nativeTexture");

    if (Platform.isWindows) {
      _driver = Pointer<Void>.fromAddress(
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

    _viewer = _lib.create_filament_viewer_ffi(
        Pointer<Void>.fromAddress(sharedContext ?? 0),
        _driver,
        uberArchivePath?.toNativeUtf8().cast<Char>() ?? nullptr,
        loader,
        renderCallback,
        renderCallbackOwner);

    if (_viewer!.address == 0) {
      throw Exception("Failed to create viewer. Check logs for details");
    }

    _lib.create_swap_chain_ffi(
        _viewer!,
        Pointer<Void>.fromAddress(surfaceAddress),
        size.width.toInt(),
        size.height.toInt());
    if (nativeTexture != 0) {
      assert(surfaceAddress == 0);
      print("Creating render target from native texture  $nativeTexture");
      _lib.create_render_target_ffi(
          _viewer!, nativeTexture, size.width.toInt(), size.height.toInt());
    }

    _lib.update_viewport_and_camera_projection_ffi(
        _viewer!, size.width.toInt(), size.height.toInt(), 1.0);

    _assetManager = _lib.get_asset_manager(_viewer!);

    textureDetails = TextureDetails(
        textureId: flutterTextureId!, width: width, height: height);
    _hasViewerController.add(true);
  }

  ///
  /// When a FilamentWidget is resized, it will call [resize]. This method will tear down/recreate the swapchain and propagate a new texture ID back to the FilamentWidget.
  /// For "once-off" resizes, this is fine.
  /// However, this can be problematic for consecutive resizes (e.g. dragging to expand/contract the parent window on desktop, or animating the size of the FilamentWidget itself).
  /// It is too expensive to recreate the swapchain multiple times per second.
  /// We therefore add a timer to FilamentWidget so that the call to [resize] is delayed (e.g. 50ms).
  /// Any subsequent resizes before the delay window elapses will cancel the earlier call.
  ///
  ///  The overall process looks like this:
  /// 1) the window is resized
  /// 2) (Windows only) PixelBufferTexture is requested to provide a new pixel buffer with a new size, and we return an empty texture
  /// 3) After Xms, [resize] is invoked
  /// 4) the viewer is instructed to stop rendering (synchronous)
  /// 5) the existing Filament swapchain is destroyed (synchronous)
  /// 6) the Flutter texture is unregistered
  ///   a) this is asynchronous, but
  ///   b) *** SEE NOTE BELOW ON WINDOWS *** by passing the method channel result through to the callback, we make this synchronous from the Flutter side,
  //    c) in this async callback, the glTexture is destroyed
  /// 7) a new Flutter/OpenGL texture is created (synchronous)
  /// 8) a new swapchain is created (synchronous)
  /// 9) if the viewer was rendering prior to the resize, the viewer is instructed to recommence rendering
  /// 10) the new texture ID is pushed to the FilamentWidget
  /// 11) the FilamentWidget updates the Texture widget with the new texture.
  ///
  /// #### (Windows-only) ############################################################
  /// # As soon as the widget/window is resized, the PixelBufferTexture will be
  /// # requested to provide a new pixel buffer for the new size.
  /// # Even with zero delay to the call to [resize], this will be triggered *before*
  /// # we have had a chance to anything else (like tear down the swapchain).
  /// # On the backend, we deal with this by simply returning an empty texture as soon
  /// # as the size changes, and will rely on the followup call to [resize] to actually
  /// # destroy/recreate the pixel buffer and Flutter texture.
  ///
  /// NOTE RE ASYNC CALLBACK
  /// # The bigger problem is a race condition when resize is called multiple times in quick succession (e.g dragging to resize on Windows).
  /// # It looks like occasionally, the backend OpenGL texture is being destroyed while its corresponding swapchain is still active, causing a crash.
  /// # I'm not exactly sure how/where this is occurring, but something clearly isn't synchronized between destroy_swap_chain_ffi and
  /// # the asynchronous callback passed to FlutterTextureRegistrar::UnregisterTexture.
  /// # Theoretically this could occur if resize_2 starts before resize_1 completes, i.e.
  /// # 1) resize_1 destroys swapchain/texture and creates new texture
  /// # 2) resize_2 destroys swapchain/texture
  /// # 3) resize_1 creates new swapchain but texture isn't available, ergo crash
  /// #
  /// # I don't think this should happen if:
  /// # 1) we add a flag on the Flutter side to ensure only one call to destroy/recreate the swapchain/texture is active at any given time, and
  /// # 2) on the Flutter side, we are sure that calling destroyTexture only returns once the async callback on the native side has completed.
  /// # For (1), checking if textureId is null at the entrypoint should be sufficient.
  /// # For (2), we invoke flutter::MethodResult<flutter::EncodableValue>->Success in the UnregisterTexture callback.
  /// #
  /// # Maybe (2) doesn't actually make Flutter wait?
  /// #
  /// # The other possibility is that both (1) and (2) are fine and the issue is elsewhere.
  /// #
  /// # Either way, the current solution is to basically setup a double-buffer on resize.
  /// # When destroyTexture is called, the active texture isn't destroyed yet, it's only marked as inactive.
  /// # On subsequent calls to destroyTexture, the inactive texture is destroyed.
  /// # This seems to work fine.
  ///
  /// # Another option is to only use a single large (e.g. 4k) texture and simply crop whenever a resize is requested.
  /// # This might be preferable for other reasons (e.g. don't need to destroy/recreate the pixel buffer or swapchain).
  /// # Given we don't do this on other platforms, I'm OK to stick with the existing solution for the time being.
  /// ############################################################################
  ///

  @override
  Future resize(int width, int height, {double scaleFactor = 1.0}) async {
    // we defer to the FilamentWidget to ensure that every call to [resize] is synchronized
    // so this exception should never be thrown (right?)
    if (textureDetails == null) {
      throw Exception("Resize currently underway, ignoring");
    }

    var _textureDetails = textureDetails;

    _lib.set_rendering_ffi(_viewer!, false);

    if (_textureDetails != null) {
      if (_viewer != null) {
        _lib.destroy_swap_chain_ffi(_viewer!);
      }
      await _channel.invokeMethod("destroyTexture", _textureDetails!.textureId);
      print("Destroyed texture ${_textureDetails!.textureId}");
    }

    var newSize = ui.Size(width * _pixelRatio, height * _pixelRatio);

    print("Size after pixel ratio : $width x $height ");

    var textures = await _channel
        .invokeMethod("createTexture", [newSize.width, newSize.height]);

    // void* on iOS (pointer to pixel buffer), void* on Android (pointer to native window), null on Windows/macOS
    var surfaceAddress = textures[1] as int? ?? 0;

    // null on iOS/Android, void* on MacOS (pointer to metal texture), GLuid on Windows/Linux
    var nativeTexture = textures[2] as int? ?? 0;

    _lib.create_swap_chain_ffi(
        _viewer!,
        Pointer<Void>.fromAddress(surfaceAddress),
        newSize.width.toInt(),
        newSize.height.toInt());
    if (nativeTexture != 0) {
      assert(surfaceAddress == 0);
      print("Creating render target from native texture  $nativeTexture");
      _lib.create_render_target_ffi(_viewer!, nativeTexture,
          newSize.width.toInt(), newSize.height.toInt());
    }

    _lib.update_viewport_and_camera_projection_ffi(
        _viewer!, newSize.width.toInt(), newSize.height.toInt(), 1.0);

    await setRendering(_rendering);
    textureDetails =
        TextureDetails(textureId: textures[0]!, width: width, height: height);
  }

  @override
  Future clearBackgroundImage() async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.clear_background_image_ffi(_viewer!);
  }

  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_background_image_ffi(
        _viewer!, path.toNativeUtf8().cast<Char>(), fillHeight);
  }

  @override
  Future setBackgroundColor(Color color) async {
    if (_viewer == null) {
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
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_background_image_position_ffi(_viewer!, x, y, clamp);
  }

  @override
  Future loadSkybox(String skyboxPath) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.load_skybox_ffi(_viewer!, skyboxPath.toNativeUtf8().cast<Char>());
  }

  @override
  Future loadIbl(String lightingPath, {double intensity = 30000}) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.load_ibl_ffi(
        _viewer!, lightingPath.toNativeUtf8().cast<Char>(), intensity);
  }

  @override
  Future removeSkybox() async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_skybox_ffi(_viewer!);
  }

  @override
  Future removeIbl() async {
    if (_viewer == null) {
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
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    var entity = _lib.add_light_ffi(_viewer!, type, colour, intensity, posX,
        posY, posZ, dirX, dirY, dirZ, castShadows);
    return entity;
  }

  @override
  Future removeLight(FilamentEntity light) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_light_ffi(_viewer!, light);
  }

  @override
  Future clearLights() async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.clear_lights_ffi(_viewer!);
  }

  @override
  Future<FilamentEntity> loadGlb(String path, {bool unlit = false}) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    if (unlit) {
      throw Exception("Not yet implemented");
    }
    var asset = _lib.load_glb_ffi(
        _assetManager!, path.toNativeUtf8().cast<Char>(), unlit);
    if (asset == _FILAMENT_ASSET_ERROR) {
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
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    var asset = _lib.load_gltf_ffi(
        _assetManager!,
        path.toNativeUtf8().cast<Char>(),
        relativeResourcePath.toNativeUtf8().cast<Char>());
    if (asset == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    return asset;
  }

  @override
  Future panStart(double x, double y) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_begin(_viewer!, x * _pixelRatio, y * _pixelRatio, true);
  }

  @override
  Future panUpdate(double x, double y) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_update(_viewer!, x * _pixelRatio, y * _pixelRatio);
  }

  @override
  Future panEnd() async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_end(_viewer!);
  }

  @override
  Future rotateStart(double x, double y) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_begin(_viewer!, x * _pixelRatio, y * _pixelRatio, false);
  }

  @override
  Future rotateUpdate(double x, double y) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_update(_viewer!, x * _pixelRatio, y * _pixelRatio);
  }

  @override
  Future rotateEnd() async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.grab_end(_viewer!);
  }

  @override
  Future setMorphTargetWeights(
      FilamentEntity asset, String meshName, List<double> weights) async {
    if (_viewer == null) {
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
    if (_viewer == null) {
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
    if (_viewer == null) {
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

  @override
  Future<double> getAnimationDuration(
      FilamentEntity asset, int animationIndex) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    var duration =
        _lib.get_animation_duration(_assetManager!, asset, animationIndex);

    return duration;
  }

  @override
  Future setMorphAnimationData(
      FilamentEntity entity, MorphAnimationData animation) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }

    var dataPtr = calloc<Float>(animation.data.length);
    for (int i = 0; i < animation.data.length; i++) {
      dataPtr.elementAt(i).value = animation.data[i];
    }

    // the morph targets in [animation] might be a subset of those that actually exist in the mesh (and might not have the same order)
    // we don't want to reorder the data (?? or do we? this is probably more efficient for the backend?)
    // so let's get the actual list of morph targets from the mesh and pass the relevant indices to the native side.
    var meshMorphTargets =
        await getMorphTargetNames(entity, animation.meshName);

    Pointer<Int> idxPtr = calloc<Int>(animation.morphTargets.length);
    for (int i = 0; i < animation.numMorphTargets; i++) {
      var index = meshMorphTargets.indexOf(animation.morphTargets[i]);
      if (index == -1) {
        calloc.free(dataPtr);
        calloc.free(idxPtr);
        throw Exception(
            "Morph target ${animation.morphTargets[i]} is specified in the animation but could not be found in the mesh ${animation.meshName} under entity ${entity}");
      }
      idxPtr.elementAt(i).value = index;
    }

    _lib.set_morph_animation(
        _assetManager!,
        entity,
        animation.meshName.toNativeUtf8().cast<Char>(),
        dataPtr,
        idxPtr,
        animation.numMorphTargets,
        animation.numFrames,
        (animation.frameLengthInMs));
    calloc.free(dataPtr);
    calloc.free(idxPtr);
  }

  @override
  Future setBoneAnimation(
      FilamentEntity asset, BoneAnimationData animation) async {
    if (_viewer == null) {
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

  @override
  Future removeAsset(FilamentEntity asset) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.remove_asset_ffi(_viewer!, asset);
  }

  @override
  Future clearAssets() async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.clear_assets_ffi(_viewer!);
  }

  @override
  Future zoomBegin() async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.scroll_begin(_viewer!);
  }

  @override
  Future zoomUpdate(double x, double y, double z) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.scroll_update(_viewer!, x, y, z);
  }

  @override
  Future zoomEnd() async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.scroll_end(_viewer!);
  }

  @override
  Future playAnimation(FilamentEntity asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.play_animation_ffi(
        _assetManager!, asset, index, loop, reverse, replaceActive, crossfade);
  }

  Future setAnimationFrame(
      FilamentEntity asset, int index, int animationFrame) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_animation_frame(_assetManager!, asset, index, animationFrame);
  }

  Future stopAnimation(FilamentEntity asset, int animationIndex) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.stop_animation(_assetManager!, asset, animationIndex);
  }

  @override
  Future setCamera(FilamentEntity asset, String? name) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    var result = _lib.set_camera(
        _viewer!, asset, name?.toNativeUtf8()?.cast<Char>() ?? nullptr);
    if (!result) {
      throw Exception("Failed to set camera");
    }
  }

  @override
  Future setToneMapping(ToneMapper mapper) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }

    _lib.set_tone_mapping_ffi(_viewer!, mapper.index);
  }

  @override
  Future setPostProcessing(bool enabled) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }

    _lib.set_post_processing_ffi(_viewer!, enabled);
  }

  @override
  Future setBloom(double bloom) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_bloom_ffi(_viewer!, bloom);
  }

  Future setCameraFocalLength(double focalLength) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_camera_focal_length(_viewer!, focalLength);
  }

  Future setCameraFocusDistance(double focusDistance) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_camera_focus_distance(_viewer!, focusDistance);
  }

  Future setCameraPosition(double x, double y, double z) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_camera_position(_viewer!, x, y, z);
  }

  Future moveCameraToAsset(FilamentEntity asset) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.move_camera_to_asset(_viewer!, asset);
  }

  @override
  Future setViewFrustumCulling(bool enabled) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_view_frustum_culling(_viewer!, enabled);
  }

  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_camera_exposure(_viewer!, aperture, shutterSpeed, sensitivity);
  }

  Future setCameraRotation(double rads, double x, double y, double z) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_camera_rotation(_viewer!, rads, x, y, z);
  }

  Future setCameraModelMatrix(List<double> matrix) async {
    if (_viewer == null) {
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
    if (_viewer == null) {
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
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.transform_to_unit_cube(_assetManager!, asset);
  }

  Future setPosition(FilamentEntity asset, double x, double y, double z) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_position(_assetManager!, asset, x, y, z);
  }

  Future setScale(FilamentEntity asset, double scale) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_scale(_assetManager!, asset, scale);
  }

  Future setRotation(
      FilamentEntity asset, double rads, double x, double y, double z) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    _lib.set_rotation(_assetManager!, asset, rads, x, y, z);
  }

  Future hide(FilamentEntity asset, String meshName) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    if (_lib.hide_mesh(
            _assetManager!, asset, meshName.toNativeUtf8().cast<Char>()) !=
        1) {}
  }

  Future reveal(FilamentEntity asset, String meshName) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    if (_lib.reveal_mesh(
            _assetManager!, asset, meshName.toNativeUtf8().cast<Char>()) !=
        1) {
      throw Exception("Failed to reveal mesh $meshName");
    }
  }

  String? getNameForEntity(FilamentEntity entity) {
    final result = _lib.get_name_for_entity(_assetManager!, entity);
    if (result == nullptr) {
      return null;
    }
    return result.cast<Utf8>().toDartString();
  }

  void pick(int x, int y) async {
    if (_viewer == null) {
      throw Exception("No viewer available, ignoring");
    }
    final outPtr = calloc<EntityId>(1);
    outPtr.value = 0;

    _lib.pick_ffi(_viewer!, x, textureDetails!.height - y, outPtr);
    int wait = 0;
    while (outPtr.value == 0) {
      await Future.delayed(Duration(milliseconds: 50));
      wait++;
      if (wait > 10) {
        calloc.free(outPtr);
        throw Exception("Failed to get picking result");
      }
    }
    var entityId = outPtr.value;
    _pickResultController.add(entityId);
    calloc.free(outPtr);
  }
}
