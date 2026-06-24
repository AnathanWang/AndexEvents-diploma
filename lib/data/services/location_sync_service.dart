import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../core/services/logger_service.dart';
import '../../core/utils/location_utils.dart';
import 'user_service.dart';

/// Синхронизация геолокации с backend: при старте, каждые 30 с или при смещении ≥ 50 м.
class LocationSyncService {
  LocationSyncService._();

  static final LocationSyncService instance = LocationSyncService._();

  static const double _minDistanceMeters = 50;
  static const Duration _minInterval = Duration(seconds: 30);

  final UserService _userService = UserService();

  StreamSubscription<Position>? _positionStream;
  Timer? _fallbackTimer;
  Position? _lastSyncedPosition;
  DateTime? _lastSyncedAt;
  bool _isSyncing = false;
  bool _isStarted = false;

  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;

    await syncNow(reason: 'startup');

    final hasPermission = await _ensurePermission();
    if (!hasPermission) {
      LoggerService.warning('[LocationSyncService] No location permission');
      _startFallbackTimer();
      return;
    }

    _positionStream ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 50,
      ),
    ).listen(
      (position) => unawaited(_onPosition(position, reason: 'stream')),
      onError: (Object error) {
        LoggerService.error('[LocationSyncService] Stream error: $error');
        _startFallbackTimer();
      },
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    _isStarted = false;
    await _positionStream?.cancel();
    _positionStream = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  Future<void> syncNow({required String reason}) async {
    try {
      final hasPermission = await _ensurePermission();
      if (!hasPermission) return;

      final position = await LocationUtils.resolvePosition(
        freshTimeout: const Duration(seconds: 6),
        accuracy: LocationAccuracy.medium,
      );
      if (position != null) {
        await _onPosition(position, reason: reason, forceSync: true);
        return;
      }

      await _touchPresence(reason: reason);
    } catch (e) {
      LoggerService.error('[LocationSyncService] syncNow($reason) failed: $e');
      await _touchPresence(reason: '$reason-fallback');
    }
  }

  Future<void> _onPosition(
    Position position, {
    required String reason,
    bool forceSync = false,
  }) async {
    if (!forceSync && !_shouldSync(position)) return;
    await _syncPosition(position, reason: reason);
  }

  bool _shouldSync(Position position) {
    if (_lastSyncedAt == null || _lastSyncedPosition == null) {
      return true;
    }

    final elapsed = DateTime.now().difference(_lastSyncedAt!);
    if (elapsed >= _minInterval) return true;

    final moved = Geolocator.distanceBetween(
      _lastSyncedPosition!.latitude,
      _lastSyncedPosition!.longitude,
      position.latitude,
      position.longitude,
    );
    return moved >= _minDistanceMeters;
  }

  Future<void> _syncPosition(Position position, {required String reason}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _userService.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _lastSyncedPosition = position;
      _lastSyncedAt = DateTime.now();
      LoggerService.debug(
        '[LocationSyncService] Synced ($reason): '
        '${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      LoggerService.error('[LocationSyncService] updateLocation failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _touchPresence({required String reason}) async {
    try {
      await _userService.touchPresence();
      _lastSyncedAt = DateTime.now();
      LoggerService.debug('[LocationSyncService] Presence ping ($reason)');
    } catch (e) {
      LoggerService.error('[LocationSyncService] touchPresence failed: $e');
    }
  }

  void _startFallbackTimer() {
    if (_positionStream != null) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(_minInterval, (_) {
      if (!_isStarted) return;
      unawaited(syncNow(reason: 'timer'));
    });
  }

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
