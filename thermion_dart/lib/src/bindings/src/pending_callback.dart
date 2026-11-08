/// Retains a native callback registration until accepted requests finish.
/// All methods run on the owning Dart isolate. Native delivery must complete
/// exactly one request, even when application-level handlers are suppressed.
class PendingCallback {
  PendingCallback(this._close);

  final void Function() _close;
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
    _disposed = true;
    _closeIfFinished();
  }

  void _closeIfFinished() {
    if (_disposed && _pending == 0 && !_closed) {
      _closed = true;
      _close();
    }
  }
}
