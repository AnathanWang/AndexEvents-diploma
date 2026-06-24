import 'dart:async';

/// Broadcasts when match/like data should be reloaded from the server.
class MatchRefreshBus {
  MatchRefreshBus._();

  static final MatchRefreshBus instance = MatchRefreshBus._();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }
}
