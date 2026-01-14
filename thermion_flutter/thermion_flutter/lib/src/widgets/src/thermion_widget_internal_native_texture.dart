import 'package:flutter/material.dart' hide View;
import 'package:logging/logging.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture;

class ThermionWidgetInternal extends StatefulWidget {
  final View view;

  ThermionWidgetInternal({required this.view});

  @override
  State<ThermionWidgetInternal> createState() => _ThermionWidgetInternalState();
}

class _ThermionWidgetInternalState extends State<ThermionWidgetInternal> {
  late final _logger = Logger(this.runtimeType.toString());

  PlatformTextureDescriptor? _texture;

  @override
  Widget build(BuildContext context) {
    var dpr = MediaQuery.of(context).devicePixelRatio;

    return LayoutBuilder(builder: (ctx, constraints) {
      var width = (constraints.maxWidth * dpr).ceil();
      var height = (constraints.maxHeight * dpr).ceil();

      if (width == 0 || height == 0) {
        return SizedBox.shrink();
      }

      return FutureBuilder(
          future: ThermionFlutterPlugin.instance
              .createTextureAndBindToView(widget.view, width, height),
          builder: (ctx, snapshot) {
            if (!snapshot.hasData) {
              return SizedBox.shrink();
            }
            final texture = snapshot.data!;

            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final old = _texture;
              _texture = texture;
              await old?.destroy();
            });

            return Texture(
              key: ObjectKey("flutter_texture_${texture.flutterTextureId}"),
              textureId: texture.flutterTextureId,
              filterQuality: FilterQuality.none,
              freeze: false,
            );
          });
    });
  }
}
