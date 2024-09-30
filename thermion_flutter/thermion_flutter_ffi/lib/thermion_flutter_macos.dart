import 'dart:async';
import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter_ffi/thermion_flutter_method_channel_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:logging/logging.dart';

///
/// An implementation of [ThermionFlutterPlatform] that uses
/// Flutter platform channels to create a rendering context,
/// resource loaders, and surface/render target(s).
///
class ThermionFlutterMacOS extends ThermionFlutterMethodChannelInterface {
  final _channel = const MethodChannel("dev.thermion.flutter/event");
  final _logger = Logger("ThermionFlutterMacOS");

  static SwapChain? _swapChain;

  ThermionFlutterMacOS._();

  static ThermionFlutterMacOS? instance;

  static void registerWith() {
    instance ??= ThermionFlutterMacOS._();
    ThermionFlutterPlatform.instance = instance!;
  }

  @override
  Future<ThermionViewer> createViewer({ThermionFlutterOptions? options}) async {
    var viewer = await super.createViewer(options: options);
    if (_swapChain != null) {
      throw Exception("Only a single swapchain can be created");
    }
    // this is the headless swap chain
    // since we will be using render targets, the actual dimensions don't matter
    _swapChain = await viewer.createSwapChain(1, 1);
    return viewer;
  }

  // On desktop platforms, textures are always created
  Future<ThermionFlutterTexture?> createTexture(int width, int height) async {
    var texture = MacOSMethodChannelFlutterTexture(_channel);
    await texture.resize(width, height, 0, 0);
    return texture;
  }

  // On MacOS, we currently use textures/render targets, so there's no window to resize
  @override
  Future<ThermionFlutterTexture?> resizeWindow(
      int width, int height, int offsetTop, int offsetRight) {
    throw UnimplementedError();
  }
}

class TextureCacheEntry {
  final int flutterId;
  final int hardwareId;
  final DateTime creationTime;
  DateTime? removalTime;
  bool inUse;

  TextureCacheEntry(this.flutterId, this.hardwareId, {this.removalTime, this.inUse = true})
      : creationTime = DateTime.now();
}


class MacOSMethodChannelFlutterTexture extends MethodChannelFlutterTexture {
  final _logger = Logger("MacOSMethodChannelFlutterTexture");

  int flutterId = -1;
  int hardwareId = -1;
  int width = -1;
  int height = -1;

  static final Map<String, List<TextureCacheEntry>> _textureCache = {};

  MacOSMethodChannelFlutterTexture(super.channel);

  @override
  Future<void> resize(
      int newWidth, int newHeight, int newLeft, int newTop) async {
    if (newWidth == this.width &&
        newHeight == this.height &&
        newLeft == 0 &&
        newTop == 0) {
      return;
    }

    this.width = newWidth;
    this.height = newHeight;

    // Clean up old textures
    await _cleanupOldTextures();

    final cacheKey = '${width}x$height';
    final availableTextures =
        _textureCache[cacheKey]?.where((entry) => !entry.inUse) ?? [];
    if (availableTextures.isNotEmpty) {
      final cachedTexture = availableTextures.first;
      flutterId = cachedTexture.flutterId;
      hardwareId = cachedTexture.hardwareId;
      cachedTexture.inUse = true;
      _logger.info(
          "Using cached texture: flutter id $flutterId, hardware id $hardwareId");
    } else {
      var result =
          await channel.invokeMethod("createTexture", [width, height, 0, 0]);
      if (result == null || (result[0] == -1)) {
        throw Exception("Failed to create texture");
      }
      flutterId = result[0] as int;
      hardwareId = result[1] as int;

      final newEntry = TextureCacheEntry(flutterId, hardwareId, inUse: true);
      _textureCache.putIfAbsent(cacheKey, () => []).add(newEntry);
      _logger.info(
          "Created new MacOS texture: flutter id $flutterId, hardware id $hardwareId");
    }

    // Mark old texture as not in use
    if (this.width != -1 && this.height != -1) {
      final oldCacheKey = '${this.width}x${this.height}';
      final oldEntry = _textureCache[oldCacheKey]?.firstWhere(
        (entry) => entry.flutterId == this.flutterId,
        orElse: () => TextureCacheEntry(-1, -1),
      );
      if (oldEntry != null && oldEntry.flutterId != -1) {
        oldEntry.inUse = false;
        oldEntry.removalTime = DateTime.now();
      }
    }
  }

  Future _cleanupOldTextures() async {
    final now = DateTime.now();
    final entriesToRemove = <String, List<TextureCacheEntry>>{};

    for (var entry in _textureCache.entries) {
      final expiredTextures = entry.value.where((texture) {
        return !texture.inUse &&
               texture.removalTime != null &&
               now.difference(texture.removalTime!).inSeconds > 5;
      }).toList();

      if (expiredTextures.isNotEmpty) {
        entriesToRemove[entry.key] = expiredTextures;
      }
    }

    for (var entry in entriesToRemove.entries) {
      for (var texture in entry.value) {
        await _destroyTexture(texture.flutterId, texture.hardwareId);
        _logger.info("Destroying texture: ${texture.flutterId}");
        _textureCache[entry.key]?.remove(texture);
      }
      if (_textureCache[entry.key]?.isEmpty ?? false) {
        _textureCache.remove(entry.key);
      }
    }
  }

  Future<void> _destroyTexture(int flutterId, int hardwareId) async {
    try {
      await channel.invokeMethod("destroyTexture", [flutterId, hardwareId]);
      _logger.info("Destroyed old texture: flutter id $flutterId, hardware id $hardwareId");
    } catch (e) {
      _logger.severe("Failed to destroy texture: $e");
    }
  }
}
