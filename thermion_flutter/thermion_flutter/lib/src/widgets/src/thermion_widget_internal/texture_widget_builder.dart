import 'package:flutter/material.dart' hide View;
import '../../../platform/src/platform_texture_descriptor.dart';

Widget surfaceWidgetBuilder(PlatformTextureDescriptor? descriptor) {
  if (descriptor == null) {
    return const SizedBox.shrink();
  }
  return Texture(
    key: ObjectKey("flutter_texture_${descriptor.flutterTextureId}"),
    textureId: descriptor.flutterTextureId,
    filterQuality: FilterQuality.none,
    freeze: false,
  );
}
