import 'dart:async';
import '../../input.dart';

/// A delegate that chains multiple delegates together, processing events through each in order.
///
/// Events are passed to each delegate in sequence. If a delegate handles the event
/// and returns true from a shouldStop-style check, processing stops.
///
/// This is useful for combining multiple input handling behaviors, e.g.:
/// - Gizmo attachment + drag (left mouse)
/// - Camera orbit (right mouse)
/// - Camera zoom (scroll wheel)
class ChainedDelegate extends InputHandlerDelegate {
  final List<InputHandlerDelegate> delegates;

  ChainedDelegate(this.delegates);

  @override
  Future<void> handle(List<InputEvent> events) async {
    for (final delegate in delegates) {
      await delegate.handle(events);
    }
  }

  @override
  Future<void> dispose() async {
    for (final delegate in delegates) {
      await delegate.dispose();
    }
  }
}
