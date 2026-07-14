import 'dart:async';
import '../../input.dart';

/// A delegate that chains multiple delegates together, processing events through each in order.
///
/// After each delegate handles the events, its [consumesEvents] flag is
/// checked; if true, the remaining delegates in the chain are skipped. This
/// lets a higher-priority delegate (e.g. a gizmo drag) block a lower-priority
/// one (e.g. an orbit camera) from also reacting to the same event.
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
      if (delegate.consumesEvents) break;
    }
  }

  @override
  Future<void> dispose() async {
    for (final delegate in delegates) {
      await delegate.dispose();
    }
  }
}
