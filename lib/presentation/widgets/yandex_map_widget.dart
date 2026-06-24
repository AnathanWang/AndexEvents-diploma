import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../core/services/logger_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/location_utils.dart';
import '../../core/utils/map_viewport_utils.dart';
import '../../data/models/event_model.dart';
import '../../data/models/map_user_preview.dart';

class YandexMapWidget extends StatefulWidget {
  final List<EventModel> events;
  final List<MapUserPreview> users;
  final bool isInteractive;
  final void Function(YandexMapController)? onMapCreated;
  final void Function(Point)? onUserLocationUpdated;
  final void Function(EventModel)? onEventMarkerTapped;
  final void Function(MapUserPreview)? onUserMarkerTapped;
  final void Function(
    CameraPosition cameraPosition,
    CameraUpdateReason reason,
    bool finished,
  )? onCameraPositionChanged;

  const YandexMapWidget({
    super.key,
    required this.events,
    this.users = const [],
    this.isInteractive = true,
    this.onMapCreated,
    this.onUserLocationUpdated,
    this.onEventMarkerTapped,
    this.onUserMarkerTapped,
    this.onCameraPositionChanged,
  });

  @override
  State<YandexMapWidget> createState() => _YandexMapWidgetState();
}

class _YandexMapWidgetState extends State<YandexMapWidget> {
  static const int _maxMarkers = 15;
  static const int _maxUserMarkers = 25;
  static const double _markerScale = 0.68;
  static const MapObjectId _eventsClusterId =
      MapObjectId('events_cluster_collection');

  YandexMapController? _mapController;
  BitmapDescriptor? _eventMarkerDescriptor;
  BitmapDescriptor? _userMarkerDescriptor;
  Point? _userLocation;
  List<MapObject> _cachedMapObjects = const [];
  List<String> _cachedEventIds = const [];
  List<String> _cachedUserIds = const [];
  bool _cachedUserMarkersVisible = false;
  double _cameraZoom = 13;
  bool _initialCameraApplied = false;
  bool _userLayerEnabled = false;

  final Point _initialTarget = const Point(
    latitude: 58.603591,
    longitude: 49.668023,
  );

  @override
  void initState() {
    super.initState();
    _initMarkerIcons();
    unawaited(_prefetchUserLocation());
  }

  Future<void> _prefetchUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await LocationUtils.resolvePosition(
        freshTimeout: const Duration(seconds: 5),
      );
      if (!mounted || position == null) return;

      _userLocation = Point(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      widget.onUserLocationUpdated?.call(_userLocation!);
      _applyInitialCamera();
    } catch (e) {
      LoggerService.warning('[YandexMapWidget] prefetch location failed: $e');
    }
  }

  @override
  void dispose() {
    _mapController = null;
    super.dispose();
  }

  Future<void> _enableUserLayer(YandexMapController controller) async {
    if (_userLayerEnabled) return;
    try {
      await controller.toggleUserLayer(
        visible: true,
        headingEnabled: false,
        autoZoomEnabled: false,
      );
      _userLayerEnabled = true;

      final userCamera = await controller.getUserCameraPosition();
      if (userCamera != null && mounted) {
        _userLocation = userCamera.target;
        widget.onUserLocationUpdated?.call(_userLocation!);
        _applyInitialCamera();
      }
    } catch (e) {
      LoggerService.error('Error enabling user layer: $e');
    }
  }

  void _applyInitialCamera() {
    if (_initialCameraApplied || _mapController == null) return;
    _initialCameraApplied = true;

    final target = _userLocation ??
        (widget.events.isNotEmpty
            ? Point(
                latitude: widget.events.first.latitude,
                longitude: widget.events.first.longitude,
              )
            : _initialTarget);

    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 13.5),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant YandexMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshMapObjectsIfNeeded(force: false);
  }

  List<String> _eventIds(List<EventModel> events) {
    return events.map((event) => event.id).toList(growable: false);
  }

  void _refreshMapObjectsIfNeeded({required bool force}) {
    if (_eventMarkerDescriptor == null || _userMarkerDescriptor == null) {
      return;
    }

    final nextEventIds = _eventIds(widget.events);
    final nextUserIds = widget.users.map((user) => user.id).toList();
    final usersVisible = shouldShowMapUserMarkers(_cameraZoom);
    if (!force &&
        _listEquals(_cachedEventIds, nextEventIds) &&
        _listEquals(_cachedUserIds, nextUserIds) &&
        usersVisible == _cachedUserMarkersVisible &&
        _cachedMapObjects.isNotEmpty) {
      return;
    }

    _cachedEventIds = nextEventIds;
    _cachedUserIds = nextUserIds;
    _cachedUserMarkersVisible = usersVisible;
    _cachedMapObjects = _buildMarkers();
    if (mounted) {
      setState(() {});
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _initMarkerIcons() async {
    final results = await Future.wait<Uint8List>([
      _createEventMarkerIcon(),
      _createUserMarkerIcon(),
    ]);

    if (!mounted) return;

    setState(() {
      _eventMarkerDescriptor = BitmapDescriptor.fromBytes(results[0]);
      _userMarkerDescriptor = BitmapDescriptor.fromBytes(results[1]);
    });
    _refreshMapObjectsIfNeeded(force: true);
  }

  Future<Uint8List> _createEventMarkerIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const width = 52.0;
    const height = 66.0;
    const centerX = width / 2;
    const centerY = height / 2;

    final mainPaint = Paint()
      ..color = const Color(0xFF0961F6)
      ..style = PaintingStyle.fill;

    final dropPath = Path()
      ..moveTo(centerX - 18, 12)
      ..quadraticBezierTo(centerX - 22, 4, centerX, 4)
      ..quadraticBezierTo(centerX + 22, 4, centerX + 18, 12)
      ..quadraticBezierTo(centerX + 26, 20, centerX + 24, 34)
      ..quadraticBezierTo(centerX + 22, 48, centerX + 8, 62)
      ..quadraticBezierTo(centerX, 76, centerX - 8, 62)
      ..quadraticBezierTo(centerX - 22, 48, centerX - 24, 34)
      ..quadraticBezierTo(centerX - 26, 20, centerX - 18, 12)
      ..close();

    canvas.drawPath(dropPath, mainPaint);

    final borderPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(dropPath, borderPaint);

    final holePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY - 6), 9, holePaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _createUserMarkerIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const size = 44.0;
    const center = size / 2;

    final outerPaint = Paint()
      ..color = const Color(0xFF9C5CFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(center, center), 18, outerPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(center, center), 18, borderPaint);

    final innerPaint = Paint()
      ..color = const Color(0xFFFF6BB5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(center, center), 8, innerPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  List<MapObject> _buildMarkers() {
    final eventDescriptor = _eventMarkerDescriptor;
    final userDescriptor = _userMarkerDescriptor;
    if (eventDescriptor == null || userDescriptor == null) return [];

    final eventsForMarkers = widget.events.length > _maxMarkers
        ? widget.events.take(_maxMarkers).toList()
        : widget.events;

    final placemarks = <PlacemarkMapObject>[];
    for (final event in eventsForMarkers) {
      placemarks.add(
        PlacemarkMapObject(
          mapId: MapObjectId('event_${event.id}'),
          point: Point(latitude: event.latitude, longitude: event.longitude),
          consumeTapEvents: true,
          onTap: (_, __) => widget.onEventMarkerTapped?.call(event),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: eventDescriptor,
              scale: _markerScale,
            ),
          ),
          opacity: 1.0,
          zIndex: 0,
        ),
      );
    }

    final usersForMarkers = shouldShowMapUserMarkers(_cameraZoom)
        ? (widget.users.length > _maxUserMarkers
            ? widget.users.take(_maxUserMarkers).toList()
            : widget.users)
        : const <MapUserPreview>[];

    final userPlacemarks = <PlacemarkMapObject>[];
    for (final user in usersForMarkers) {
      userPlacemarks.add(
        PlacemarkMapObject(
          mapId: MapObjectId('user_${user.id}'),
          point: Point(latitude: user.latitude, longitude: user.longitude),
          consumeTapEvents: true,
          onTap: (_, __) => widget.onUserMarkerTapped?.call(user),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: userDescriptor,
              scale: 0.9,
            ),
          ),
          opacity: 1.0,
          zIndex: 1,
        ),
      );
    }

    final mapObjects = <MapObject>[...userPlacemarks];

    if (placemarks.isEmpty) {
      return mapObjects;
    }

    mapObjects.add(
      ClusterizedPlacemarkCollection(
        mapId: _eventsClusterId,
        radius: 42,
        minZoom: 13,
        placemarks: placemarks,
        onClusterTap: (self, cluster) {
          final controller = _mapController;
          if (controller == null) return;
          unawaited(
            controller.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: cluster.appearance.point,
                  zoom: 15,
                ),
              ),
              animation: const MapAnimation(
                type: MapAnimationType.smooth,
                duration: 0.35,
              ),
            ),
          );
        },
      ),
    );

    return mapObjects;
  }

  void _handleCameraPositionChanged(
    CameraPosition cameraPosition,
    CameraUpdateReason reason,
    bool finished,
  ) {
    final wasVisible = shouldShowMapUserMarkers(_cameraZoom);
    _cameraZoom = cameraPosition.zoom;
    if (wasVisible != shouldShowMapUserMarkers(_cameraZoom)) {
      _refreshMapObjectsIfNeeded(force: true);
    }
    widget.onCameraPositionChanged?.call(cameraPosition, reason, finished);
  }

  @override
  Widget build(BuildContext context) {
    final bool liteGestures =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return ClipRRect(
      borderRadius: widget.isInteractive
          ? BorderRadius.zero
          : BorderRadius.circular(16),
      child: Stack(
        children: <Widget>[
          YandexMap(
            key: const ValueKey('yandex_explore_map'),
            onMapCreated: (YandexMapController controller) {
              _mapController = controller;
              widget.onMapCreated?.call(controller);
              unawaited(_enableUserLayer(controller));
              _applyInitialCamera();
            },
            mapObjects: _cachedMapObjects,
            nightModeEnabled: false,
            rotateGesturesEnabled: widget.isInteractive && !liteGestures,
            scrollGesturesEnabled: widget.isInteractive,
            tiltGesturesEnabled: false,
            zoomGesturesEnabled: widget.isInteractive,
            fastTapEnabled: widget.isInteractive,
            onCameraPositionChanged: _handleCameraPositionChanged,
          ),
          if (!widget.isInteractive)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          if (!widget.isInteractive)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Text(
                '${widget.events.length} ${_getEventWord(widget.events.length)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getEventWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'событие';
    } else if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'события';
    } else {
      return 'событий';
    }
  }
}
