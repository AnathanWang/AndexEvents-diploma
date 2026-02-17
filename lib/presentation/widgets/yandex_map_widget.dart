import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/event_model.dart';
import './common/custom_notification.dart';

class YandexMapWidget extends StatefulWidget {
  final List<EventModel> events;
  final bool isInteractive;
  final void Function(YandexMapController)? onMapCreated;
  final void Function(Point)? onUserLocationUpdated;
  final void Function(EventModel)? onEventMarkerTapped;

  const YandexMapWidget({
    super.key,
    required this.events,
    this.isInteractive = true,
    this.onMapCreated,
    this.onUserLocationUpdated,
    this.onEventMarkerTapped,
  });

  @override
  State<YandexMapWidget> createState() => _YandexMapWidgetState();
}

class _YandexMapWidgetState extends State<YandexMapWidget> {
  YandexMapController? _mapController;
  final Map<String, Uint8List> _markerIcons = {}; // Маркеры по категориям
  Uint8List? _userMarkerIcon;
  Point? _userLocation;

  // Киров по умолчанию
  final Point _initialTarget = const Point(
    latitude: 58.603591,
    longitude: 49.668023,
  );

  @override
  void initState() {
    super.initState();
    _initMarkerIcons();
    _getUserLocation();
  }

  @override
  void dispose() {
    _mapController = null;
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();

      if (mounted) {
        setState(() {
          _userLocation = Point(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        });

        widget.onUserLocationUpdated?.call(_userLocation!);
      }

      if (_mapController != null && mounted) {
        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _userLocation!, zoom: 12),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting user location: $e');
    }
  }

  Future<void> _initMarkerIcons() async {
    final eventIcon = await _createMarkerIcon();
    final userIcon = await _loadUserMarkerIcon();

    if (mounted) {
      setState(() {
        _markerIcons['event'] = eventIcon;
        _userMarkerIcon = userIcon;
      });
    }
  }

  Future<Uint8List> _createMarkerIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const width = 90.0;
    const height = 115.0;
    const centerX = width / 2;
    const centerY = height / 2;

    // Основная форма капли
    final mainPaint = Paint()
      ..color = const Color(0xFF5E60CE)
      ..style = PaintingStyle.fill;

    final dropPath = Path()
      // Верхняя закругленная часть
      ..moveTo(centerX - 26, 18)
      ..quadraticBezierTo(centerX - 32, 6, centerX, 6)
      ..quadraticBezierTo(centerX + 32, 6, centerX + 26, 18)
      // Правая сторона
      ..quadraticBezierTo(centerX + 38, 30, centerX + 36, 48)
      ..quadraticBezierTo(centerX + 32, 68, centerX + 12, 88)
      // Острие внизу
      ..quadraticBezierTo(centerX, 108, centerX - 12, 88)
      // Левая сторона
      ..quadraticBezierTo(centerX - 32, 68, centerX - 36, 48)
      ..quadraticBezierTo(centerX - 38, 30, centerX - 26, 18)
      ..close();

    canvas.drawPath(dropPath, mainPaint);

    // Белая обводка
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(dropPath, borderPaint);

    // Отверстие в центре (белое)
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX, centerY - 8), 13, holePaint);

    // Обводка для отверстия (темная)
    final holeStrokePaint = Paint()
      ..color = const Color(0xFF5E60CE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(centerX, centerY - 8), 13, holeStrokePaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _loadUserMarkerIcon() async {
    try {
      debugPrint('🔄 Рисуем точку...');
      return await _createDotIcon();
    } catch (e) {
      debugPrint('❌ Error drawing dot: $e');
      return await _createDotIcon();
    }
  }

  Future<Uint8List> _createDotIcon() async {
    const size = 50.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Прозрачный фон
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size, size),
      Paint()..color = Colors.transparent,
    );

    // Рисуем фиолетовую точку в центре (гармонирует со стилем)
    final dotPaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 4, dotPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    debugPrint('✅ Точка успешно нарисована');
    return byteData!.buffer.asUint8List();
  }

  List<MapObject> _buildMarkers() {
    if (_markerIcons.isEmpty) return [];

    final markers = <MapObject>[];

    // Добавляем маркеры событий
    markers.addAll(
      widget.events.map((event) {
        final icon = _markerIcons['event'] ?? _markerIcons.values.first;

        return PlacemarkMapObject(
          mapId: MapObjectId('event_${event.id}'),
          point: Point(latitude: event.latitude, longitude: event.longitude),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(icon),
              scale: 1.0,
            ),
          ),
          opacity: 1.0,
          zIndex: 0,
        );
      }),
    );

    // Маркер пользователя добавляем последним, чтобы он был поверх других
    if (_userLocation != null && _userMarkerIcon != null) {
      markers.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('user_location'),
          point: _userLocation!,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(_userMarkerIcon!),
              scale: 1.0,
            ),
          ),
          opacity: 1.0,
          zIndex: 100,
        ),
      );
    }

    return markers;
  }

  void _handleMapTap(Point tappedPoint) {
    const double tapRadius = 0.01;
    const double userLocationTapRadius =
        0.003; // Меньше радиус для точки пользователя

    // Проверяем нажатие на точку пользователя
    if (_userLocation != null) {
      final distance = _calculateDistance(tappedPoint, _userLocation!);
      if (distance < userLocationTapRadius) {
        _showUserLocationSnackBar();
        return;
      }
    }

    // Проверяем нажатие на события
    for (final event in widget.events) {
      final eventPoint = Point(
        latitude: event.latitude,
        longitude: event.longitude,
      );

      final distance = _calculateDistance(tappedPoint, eventPoint);

      if (distance < tapRadius) {
        widget.onEventMarkerTapped?.call(event);
        return;
      }
    }
  }

  void _showUserLocationSnackBar() {
    final context = this.context;
    if (context.mounted) {
      CustomNotification.success(
        context,
        'Вы здесь',
        duration: const Duration(seconds: 2),
      );
    }
  }

  double _calculateDistance(Point p1, Point p2) {
    final dLat = (p2.latitude - p1.latitude).abs();
    final dLon = (p2.longitude - p1.longitude).abs();
    return sqrt(dLat * dLat + dLon * dLon);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.isInteractive
          ? BorderRadius.zero
          : BorderRadius.circular(16),
      child: Stack(
        children: <Widget>[
          YandexMap(
            onMapCreated: (YandexMapController controller) {
              _mapController = controller;

              widget.onMapCreated?.call(controller);

              if (_userLocation != null) {
                _mapController?.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _userLocation!, zoom: 12),
                  ),
                );
              } else if (widget.events.isNotEmpty) {
                final firstEvent = widget.events.first;
                _mapController?.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: Point(
                        latitude: firstEvent.latitude,
                        longitude: firstEvent.longitude,
                      ),
                      zoom: 12,
                    ),
                  ),
                );
              } else {
                _mapController?.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _initialTarget, zoom: 12),
                  ),
                );
              }
            },
            mapObjects: _buildMarkers(),
            nightModeEnabled: false,
            rotateGesturesEnabled: widget.isInteractive,
            scrollGesturesEnabled: widget.isInteractive,
            tiltGesturesEnabled: widget.isInteractive,
            zoomGesturesEnabled: widget.isInteractive,
            fastTapEnabled: widget.isInteractive,
            onMapTap: (point) {
              _handleMapTap(point);
            },
          ),

          if (!widget.isInteractive)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),

          if (!widget.isInteractive)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '${widget.events.length} ${_getEventWord(widget.events.length)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
