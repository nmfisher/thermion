import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:polyvox_filament/view/filament_view.dart';

import '../filament_controller.dart';
import 'filament_view_platform.dart';

int _nextFilamentCreationId = 0;

class FilamentWidget extends StatefulWidget {
  final FilamentController controller;

  const FilamentWidget({Key? key, required this.controller}) : super(key: key);

  @override
  _FilamentWidgetState createState() => _FilamentWidgetState();
}

class _FilamentWidgetState extends State<FilamentWidget> {
  final _viewId = _nextFilamentCreationId++;

  @override
  Widget build(BuildContext context) {
    return FilamentViewPlatform.instance
        .buildView(_viewId, widget.controller.onFilamentViewCreated);
  }
}
