import 'dart:ffi';
import 'dart:developer' as dev;

class RenderingSurface {
  final int flutterTextureId;
  final Pointer<Void> surface;
  final int textureHandle;
  final int sharedContext;

  factory RenderingSurface.from(dynamic platformMessage) {
    var flutterTextureId = platformMessage[0];

    // void* on iOS (pointer to pixel buffer), Android (pointer to native window), null on macOS/Windows
    var surfaceAddress = platformMessage[1] as int? ?? 0;

    // null on iOS/Android, void* on MacOS (pointer to metal texture), GLuid on Windows/Linux
    var nativeTexture = platformMessage[2] as int? ?? 0;

    if (nativeTexture != 0) {
      assert(surfaceAddress == 0);
    }

    var sharedContext = platformMessage[3] as int? ?? 0;

    dev.log(
        "Using flutterTextureId $flutterTextureId, surface $surfaceAddress nativeTexture $nativeTexture and sharedContext $sharedContext");
    return RenderingSurface(
        sharedContext: sharedContext,
        flutterTextureId: flutterTextureId,
        surface: Pointer<Void>.fromAddress(surfaceAddress),
        textureHandle: nativeTexture);
  }

  RenderingSurface(
      {required this.sharedContext,
      required this.flutterTextureId,
      required this.surface,
      required this.textureHandle});
}
