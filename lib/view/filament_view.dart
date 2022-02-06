import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../filament_controller.dart';
import 'filament_view_platform.dart';

class FilamentView extends FilamentViewPlatform {
  static const FILAMENT_VIEW_ID = 'app.polyvox.filament/filament_view';

  @override
  Widget buildView(
    int creationId,
    FilamentViewCreatedCallback onFilamentViewCreated,
  ) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidView(
            viewType: FILAMENT_VIEW_ID,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            onPlatformViewCreated: (id) {
              print("onplatformview created $id");
              onFilamentViewCreated(id);
            });
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: FILAMENT_VIEW_ID,
          onPlatformViewCreated: (int id) {
            onFilamentViewCreated(id);
          },
        );
      case TargetPlatform.windows:
        return Text("Flutter doesn't support platform view on Windows yet.");
      default:
        return Text(
            '$defaultTargetPlatform is not yet implemented by Filament plugin.');
    }
  }
}
