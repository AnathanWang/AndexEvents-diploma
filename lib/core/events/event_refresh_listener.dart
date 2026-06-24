import 'dart:async';

import 'package:flutter/widgets.dart';

import 'event_refresh_bus.dart';

/// Subscribes a screen to [EventRefreshBus] updates.
mixin EventRefreshListener<T extends StatefulWidget> on State<T> {
  StreamSubscription<void>? _eventRefreshSubscription;

  @protected
  void onEventsShouldRefresh();

  @override
  void initState() {
    super.initState();
    _eventRefreshSubscription = EventRefreshBus.instance.stream.listen((_) {
      if (!mounted) return;
      onEventsShouldRefresh();
    });
  }

  @override
  void dispose() {
    _eventRefreshSubscription?.cancel();
    super.dispose();
  }
}
