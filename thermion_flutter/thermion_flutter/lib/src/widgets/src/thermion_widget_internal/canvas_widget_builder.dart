import 'package:flutter/material.dart' hide View;

import '../../../platform/src/platform_texture_descriptor.dart';

Widget surfaceWidgetBuilder(PlatformTextureDescriptor? descriptor) {
  return Container(color: Colors.transparent);
}
