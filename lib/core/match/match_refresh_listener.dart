import 'dart:async';

import 'package:flutter/widgets.dart';

import 'match_refresh_bus.dart';

/// Subscribes a [StatefulWidget] to [MatchRefreshBus] updates.
mixin MatchRefreshListener<T extends StatefulWidget> on State<T> {
  StreamSubscription<void>? _matchRefreshSubscription;

  /// Called when match/like data should be re-fetched from the server.
  @protected
  void onMatchesShouldRefresh();

  @override
  void initState() {
    super.initState();
    _matchRefreshSubscription = MatchRefreshBus.instance.stream.listen((_) {
      if (!mounted) return;
      onMatchesShouldRefresh();
    });
  }

  @override
  void dispose() {
    _matchRefreshSubscription?.cancel();
    super.dispose();
  }
}
