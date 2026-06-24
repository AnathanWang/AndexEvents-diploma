import 'dart:async';

/// Broadcasts when event lists (feed, map, nearby hub) should reload.
class EventRefreshBus {
  EventRefreshBus._();

  static final EventRefreshBus instance = EventRefreshBus._();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }
}
