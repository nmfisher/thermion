import 'package:flutter/material.dart' hide View;
import 'package:thermion_dart/thermion_dart.dart' show View;

import '../../../platform/src/platform_texture_descriptor.dart';

Widget surfaceWidgetBuilder(PlatformTextureDescriptor? descriptor, View view) {
  if (descriptor == null) {
    return const SizedBox.shrink();
  }
  return buildTextureWidget(descriptor);
}

@visibleForTesting
Widget buildTextureWidget(PlatformTextureDescriptor descriptor) {
  final texture = Texture(
    key: ObjectKey("flutter_texture_${descriptor.flutterTextureId}"),
    textureId: descriptor.flutterTextureId,
    filterQuality: FilterQuality.none,
    freeze: false,
  );
  if (!descriptor.flipVertically) return texture;
  return Transform.flip(flipY: true, child: texture);
}
