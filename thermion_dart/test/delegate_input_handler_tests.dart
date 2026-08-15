import 'dart:async';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

class _FakeViewer implements ThermionViewer {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingDelegate extends InputHandlerDelegate {
  final List<List<InputEvent>> batches = [];
  final disposedBatches = <List<InputEvent>>[];

  /// Gate that each handle() call waits on before completing, so tests can
  /// build up a backlog of queued events mid-flight.
  final gate = Completer<void>();
  bool holdBatch = true;
  bool throwOnHandle = false;
  bool disposed = false;

  @override
  Future handle(List<InputEvent> events) async {
    if (throwOnHandle) {
      throw StateError('delegate error');
    }
    if (holdBatch) {
      await gate.future;
    }
    batches.add(events);
  }

  @override
  Future dispose() async {
    disposed = true;
    // Record what had been handled at the moment dispose runs.
    disposedBatches.addAll(batches.map((b) => List<InputEvent>.of(b)));
  }
}

MouseEvent _move(double x) =>
    MouseEvent(MouseEventType.move, MouseButton.left, Vector2(x, 0), Vector2(1, 0));

MouseEvent _hover(double x) =>
    MouseEvent(MouseEventType.hover, null, Vector2(x, 0), Vector2(2, 0));

void main() {
  late _RecordingDelegate delegate;
  late DelegateInputHandler handler;

  setUp(() {
    delegate = _RecordingDelegate();
    handler = DelegateInputHandler(viewer: _FakeViewer(), delegate: delegate);
  });

  tearDown(() async {
    if (!delegate.disposed) {
      await handler.dispose();
    }
  });

  test('events are handled in dispatch order even when handler awaits', () async {
    delegate.holdBatch = false;
    // Alternate types so consecutive same-type events don't coalesce.
    for (var i = 0; i < 10; i++) {
      handler.handle(i.isEven ? _move(i.toDouble()) : _hover(i.toDouble()));
    }
    await Future<void>.delayed(Duration.zero);

    final events = delegate.batches.expand((b) => b).cast<MouseEvent>().toList();
    expect(events.map((e) => e.localPosition.x), List.generate(10, (i) => i.toDouble()));
  });

  test('queued events are drained before delegate is disposed', () async {
    handler.handle(_move(1));
    handler.handle(_move(2));

    final disposeFuture = handler.dispose();
    // Dispose must not complete while the batch is still gated.
    expect(delegate.disposed, isFalse);

    delegate.gate.complete();
    await disposeFuture;

    expect(delegate.disposed, isTrue);
    // The two moves were queued before any batch ran, so they arrive
    // coalesced into a single event (deltas accumulated, latest position).
    final handled = delegate.disposedBatches.expand((b) => b).cast<MouseEvent>().toList();
    expect(handled.length, 1);
    expect(handled[0].delta, Vector2(2, 0));
    expect(handled[0].localPosition.x, 2);
  });

  test('events dispatched after dispose begins are rejected', () async {
    handler.handle(_move(1));
    final disposeFuture = handler.dispose();
    handler.handle(_move(2));
    delegate.gate.complete();
    await disposeFuture;

    handler.handle(_move(3));
    await Future<void>.delayed(Duration.zero);

    // Only the event accepted before dispose began is handled.
    expect(delegate.batches.expand((b) => b).length, 1);
  });

  test('handler errors are captured and the next batch still runs', () async {
    delegate.throwOnHandle = true;
    handler.handle(_move(1));
    await Future<void>.delayed(Duration.zero);

    delegate.throwOnHandle = false;
    delegate.holdBatch = false;
    handler.handle(_move(2));
    await Future<void>.delayed(Duration.zero);

    expect(delegate.batches.length, 1);
  });

  test('backlogged move events of the same type are coalesced', () async {
    handler.handle(_move(1)); // gated, holds the pipeline
    await Future<void>.delayed(Duration.zero);

    handler.handle(_move(2));
    handler.handle(_move(3));
    handler.handle(_hover(4));

    delegate.holdBatch = false;
    delegate.gate.complete();
    await Future<void>.delayed(Duration.zero);

    // The two queued moves fold into one (deltas accumulate); the hover stays.
    final queued = delegate.batches[1].cast<MouseEvent>();
    expect(queued.length, 2);
    expect(queued[0].type, MouseEventType.move);
    expect(queued[0].delta, Vector2(2, 0));
    expect(queued[0].localPosition.x, 3);
    expect(queued[1].type, MouseEventType.hover);
  });

  test('dispose is idempotent', () async {
    delegate.holdBatch = false;
    await handler.dispose();
    await handler.dispose();
    expect(delegate.disposed, isTrue);
  });
}
