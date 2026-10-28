/// No spinner in the app waits longer than this: past it the operation is
/// reported as failed and the screen becomes usable again.
abstract final class Limits {
  static const Duration wait = Duration(seconds: 20);
}

extension Bounded<T> on Future<T> {
  /// This future, failing with a `TimeoutException` after [Limits.wait].
  Future<T> bounded() => timeout(Limits.wait);
}
