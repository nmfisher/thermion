import 'dart:io';

import 'package:flutter/services.dart';

import 'android_platform_texture_descriptor.dart';
import 'darwin_platform_texture_descriptor.dart';
import 'method_channel_platform_texture_descriptor.dart';
import 'platform_texture_descriptor.dart';

Future<PlatformTextureDescriptor> createPlatformTextureDescriptor(
  MethodChannel channel,
  int width,
  int height,
) async {
  if (Platform.isMacOS || Platform.isIOS) {
    return DarwinPlatformTextureDescriptorImpl.allocate(width, height);
  }
  if (Platform.isAndroid) {
    return AndroidPlatformTextureDescriptor.allocate(channel, width, height);
  }
  return MethodChannelPlatformTextureDescriptor.allocate(
    channel,
    width,
    height,
  );
}
