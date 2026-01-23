import 'package:flutter/material.dart' hide View;
import 'package:thermion_flutter/thermion_flutter.dart';

import '../../../platform/src/platform_texture_descriptor.dart';

// A stub implementation to satisfy the analyzer.
class ThermionWidgetInternal extends StatelessWidget {
  
  final View view;
  
  final void Function(PlatformTextureDescriptor? descriptor)? onTextureUpdated;

  const ThermionWidgetInternal(
      {super.key, required this.view, this.onTextureUpdated});

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}
