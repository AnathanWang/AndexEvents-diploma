import 'dart:async';

import 'match_refresh_bus.dart';
import '../events/event_refresh_bus.dart';

/// Periodically signals match and event UIs to reload while the app is active.
class MatchAutoRefresh {
  MatchAutoRefresh._();

  static final MatchAutoRefresh instance = MatchAutoRefresh._();

  static const Duration interval = Duration(seconds: 20);

  Timer? _timer;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) {
      MatchRefreshBus.instance.notify();
      EventRefreshBus.instance.notify();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
