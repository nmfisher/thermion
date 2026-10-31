@TestOn('js')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/bindings.dart' show Pointer, TJobThread, TEngine, TView;
import 'package:thermion_dart/src/bindings/src/js_interop.dart' as js;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/thermion_dart.dart' show PickResult, Viewport;

class _App implements FFIFilamentApp {
  @override
  final engine = Pointer<TEngine>.fromAddress(1);

  @override
  final jobThreadHandle = Pointer<TJobThread>.fromAddress(3);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _View extends FFIView {
  Future<Viewport> Function() readViewport = () async => Viewport(0, 0, 100, 80);

  _View() : super(Pointer<TView>.fromAddress(2), _App());

  @override
  Future<Viewport> getViewport() => readViewport();
}

void main() {
  final callbacks = <int, JSFunction>{};
  final removed = <int>[];
  final picks = <({int request, int callback, int x, int y})>[];
  var nextCallback = 0;
  int? destructionCallback;
  var failSubmission = false;
  var completeDestructionImmediately = true;
  late Completer<void> destructionSubmitted;
  late void Function() finishDestruction;

  void completePick(int index) {
    final pick = picks[index];
    final callback = callbacks[pick.callback];
    expect(callback, isNotNull, reason: 'A pending native pick still owns this callback');
    callback!.callMethodVarArgs<JSAny?>('call'.toJS, [
      null,
      pick.request.toJS,
      42.toJS,
      0.5.toJS,
      10.0.toJS,
      20.0.toJS,
      0.5.toJS,
    ]);
  }

  setUpAll(() {
    final module = JSObject();
    module.setProperty(
      'addFunction'.toJS,
      ((JSFunction callback, JSString signature) {
        callbacks[++nextCallback] = callback;
        return nextCallback;
      }).toJS,
    );
    module.setProperty(
      'removeFunction'.toJS,
      ((int address) {
        expect(callbacks.remove(address), isNotNull);
        removed.add(address);
      }).toJS,
    );
    module.setProperty('_View_getRenderTarget'.toJS, ((int view) => 0).toJS);
    module.setProperty(
      '_View_pickJobThread'.toJS,
      ((int jobThread, int view, int request, int x, int y, int callback) {
        expect(jobThread, 3);
        if (failSubmission) throw StateError('Pick submission failed');
        picks.add((request: request, callback: callback, x: x, y: y));
      }).toJS,
    );
    module.setProperty(
      '_Engine_destroyViewJobThread'.toJS,
      ((int jobThread, int engine, int view, int request, int callback) {
        expect(jobThread, 3);
        destructionCallback = callback;
        finishDestruction = () => callbacks[callback]!.callAsFunction(null, request.toJS);
        destructionSubmitted.complete();
        if (completeDestructionImmediately) scheduleMicrotask(finishDestruction);
      }).toJS,
    );
    js.NativeLibrary.instance = module as js.NativeLibrary;
  });

  setUp(() {
    picks.clear();
    removed.clear();
    failSubmission = false;
    completeDestructionImmediately = true;
    destructionSubmitted = Completer<void>();
  });

  tearDown(() {
    // The shared void callback remains registered between requests.
    expect(callbacks.keys, destructionCallback == null ? isEmpty : [destructionCallback]);
  });

  test('a pick uses the viewport from submission and releases its callback on destruction', () async {
    final view = _View();
    final result = Completer<PickResult>();
    await view.pick(10, 12, result.complete);
    expect(picks.single.y, 68);
    view.readViewport = () => throw StateError('The result must not read the view again');

    completePick(0);
    final picked = await result.future;
    expect(picked.entity, 42);
    expect(picked.x, 10);
    expect(picked.y, 12);
    expect(picked.fragY, 60);
    expect(callbacks, contains(picks.single.callback));

    await view.destroy();
    expect(removed, [picks.single.callback]);
  });

  for (final afterDestruction in [false, true]) {
    test('pending results ${afterDestruction ? 'after' : 'during'} native destruction are ignored safely', () async {
      final view = _View();
      var handled = false;
      await view.pick(10, 12, (_) => handled = true);
      final pickCallback = picks.single.callback;
      completeDestructionImmediately = false;
      final destroyed = view.destroy();
      await destructionSubmitted.future;
      view.readViewport = () => throw StateError('The view is being destroyed');
      expect(callbacks, contains(pickCallback));

      if (afterDestruction) {
        finishDestruction();
        await destroyed;
        expect(callbacks, contains(pickCallback));
      }
      completePick(0);
      expect(handled, isFalse);
      if (!afterDestruction) {
        expect(callbacks, contains(pickCallback));
        finishDestruction();
        await destroyed;
      }
      expect(removed, [pickCallback]);
    });
  }

  test('the callback stays registered until every pending result arrives', () async {
    final view = _View();
    await view.pick(10, 12, (_) => fail('A cancelled pick must not reach its handler'));
    await view.pick(20, 24, (_) => fail('A cancelled pick must not reach its handler'));
    await view.destroy();

    completePick(1);
    expect(callbacks, contains(picks.first.callback));
    expect(removed, isEmpty);
    completePick(0);
    expect(removed, [picks.first.callback]);
  });

  test('overwritten handler slots do not release the native callback early', () async {
    final view = _View();
    for (var i = 0; i <= FFIView.kMaxPickRequests; i++) {
      await view.pick(10, 12, (_) => fail('A cancelled pick must not reach its handler'));
    }
    await view.destroy();
    for (var i = 0; i < picks.length - 1; i++) {
      completePick(i);
    }
    expect(removed, isEmpty);
    completePick(picks.length - 1);
    expect(removed, [picks.first.callback]);
  });

  test('destruction cancels a pick that is still awaiting its viewport', () async {
    final view = _View();
    final viewport = Completer<Viewport>();
    view.readViewport = () => viewport.future;
    final submitted = view.pick(10, 12, (_) => fail('This pick must not be submitted'));
    await view.destroy();
    viewport.complete(Viewport(0, 0, 100, 80));
    await submitted;
    expect(picks, isEmpty);

    view.readViewport = () => throw StateError('A destroyed view must not be read');
    await expectLater(view.pick(0, 0, (_) {}), throwsStateError);
  });

  test('failed submission does not retain a callback after view destruction', () async {
    final view = _View();
    failSubmission = true;
    await expectLater(view.pick(10, 12, (_) {}), throwsStateError);
    expect(picks, isEmpty);
    await view.destroy();
    expect(removed, hasLength(1));
  });
}
