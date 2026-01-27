import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart' hide View;
import 'package:logging/logging.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide BlendMode;
import 'package:web/web.dart' as web;
import '../../../platform/platform.dart';
import '../../../platform/src/platform_texture_descriptor.dart';

Widget surfaceWidgetBuilder(PlatformTextureDescriptor? descriptor) {
  return Container(color: Colors.transparent);
}
