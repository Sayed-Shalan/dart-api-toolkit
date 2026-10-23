import 'dart:async';

final class CancelledException implements Exception {
  const CancelledException();
}

/// Cooperative cancellation. Cancelling completes [cancelled] and does not
/// by itself close a socket. [HttpTransport] checks the token before reading
/// the response and closes the client request when it can.
class CancellationToken {
  bool _cancelled = false;
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _cancelled;

  Future<void> get cancelled => _completer.future;

  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    _completer.complete();
  }
}
