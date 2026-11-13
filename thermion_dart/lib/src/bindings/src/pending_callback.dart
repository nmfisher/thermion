/// Retains a native callback registration until accepted requests finish.
/// All methods run on the owning Dart isolate. Native delivery must complete
/// exactly one request, even when application-level handlers are suppressed.
class PendingCallback {
  PendingCallback(this._close, {void Function()? onDispose}) : _onDispose = onDispose;

  final void Function() _close;
  final void Function()? _onDispose;
  int _pending = 0;
  bool _disposed = false;
  bool _closed = false;

  bool get isDisposed => _disposed;

  void begin() {
    if (_disposed) throw StateError('Callback disposal has started');
    _pending++;
  }

  void complete() {
    assert(_pending > 0);
    _pending--;
    _closeIfFinished();
  }

  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _onDispose?.call();
    }
    _closeIfFinished();
  }

  void _closeIfFinished() {
    if (_disposed && _pending == 0 && !_closed) {
      _closed = true;
      _close();
    }
  }
}
