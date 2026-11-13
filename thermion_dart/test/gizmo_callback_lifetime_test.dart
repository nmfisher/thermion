@TestOn('vm')
library;

import 'dart:async';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_gizmo.dart';

class _View implements View<Pointer<TView>> {
  final viewport = Completer<Viewport>();

  @override
  Future<Viewport> getViewport() => viewport.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _App implements FFIFilamentApp {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('disposal during viewport lookup cancels the unsubmitted native pick', () async {
    final view = _View();
    final gizmo = FFIGizmo(
      // An accidental native dispatch dereferences this invalid handle. The
      // disposed gizmo must return before submitting or obtaining its callback.
      handle: Pointer<TGizmo>.fromAddress(1),
      view: view,
      entities: {},
      app: _App(),
    );
    final pending = gizmo.pick(1, 1);
    await gizmo.dispose();
    view.viewport.complete(Viewport(0, 0, 16, 16));
    await pending;
    await expectLater(gizmo.pick(1, 1), throwsStateError);
    await gizmo.dispose();
  });
}
