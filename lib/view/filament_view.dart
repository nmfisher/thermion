import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../filament_controller.dart';
import 'filament_view_platform.dart';

class FilamentView extends FilamentViewPlatform {
  static const FILAMENT_VIEW_ID = 'mimetic.app/filament_view';

  @override
  Widget buildView(
    int creationId,
    FilamentViewCreatedCallback onFilamentViewCreated,
  ) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return PlatformViewLink(
          viewType: FILAMENT_VIEW_ID,
          surfaceFactory:
              (BuildContext context, PlatformViewController controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers: const <
                  Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
          onCreatePlatformView: (PlatformViewCreationParams params) {
            return PlatformViewsService.initSurfaceAndroidView(
              id: params.id,
              viewType: FILAMENT_VIEW_ID,
              layoutDirection: TextDirection.ltr,
              creationParams: {},
              creationParamsCodec: StandardMessageCodec(),
            )
              ..addOnPlatformViewCreatedListener((int id) {
                onFilamentViewCreated(id);
                params.onPlatformViewCreated(id);
              })
              ..create();
          },
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: FILAMENT_VIEW_ID,
          onPlatformViewCreated: (int id) {
            onFilamentViewCreated(id);
          },
        );
      default:
        return Text(
            '$defaultTargetPlatform is not yet implemented by Filament plugin.');
    }
  }
}
