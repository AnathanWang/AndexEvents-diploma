import 'package:flutter/widgets.dart';

/// Single app-wide 1s ticker so list screens don't spawn dozens of Timers.
class EventCountdownTicker {
  EventCountdownTicker._();

  static final EventCountdownTicker instance = EventCountdownTicker._();

  final Set<VoidCallback> _listeners = <VoidCallback>{};

  bool _running = false;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    _ensureRunning();
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    if (_listeners.isEmpty) {
      _running = false;
    }
  }

  void _ensureRunning() {
    if (_running || _listeners.isEmpty) return;
    _running = true;
    _scheduleTick();
  }

  void _scheduleTick() {
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!_running || _listeners.isEmpty) {
        _running = false;
        return;
      }
      for (final listener in List<VoidCallback>.from(_listeners)) {
        listener();
      }
      _scheduleTick();
    });
  }
}

/// Pixel cache size for [CachedNetworkImage] thumbnails.
int imageMemCachePx(double logicalSize, BuildContext context) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalSize * dpr).round().clamp(48, 2048);
}
