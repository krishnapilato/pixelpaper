import 'dart:async';

/// Runs async tasks one at a time, in call order. A failing task does not
/// stop the ones queued after it.
class Serial {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;

  bool get isBusy => _pending > 0;

  Future<T> run<T>(Future<T> Function() task) {
    _pending++;
    final result = _tail.then((_) async {
      try {
        return await task();
      } finally {
        _pending--;
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
