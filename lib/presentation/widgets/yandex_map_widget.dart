import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import '../home/screens/full_map_screen.dart';
import '../../data/models/event_model.dart';

class YandexMapWidget extends StatefulWidget {
  final List<EventModel> events;
  
  const YandexMapWidget({super.key, required this.events});

  @override
  State<YandexMapWidget> createState() => _YandexMapWidgetState();
}

class _YandexMapWidgetState extends State<YandexMapWidget> {
  YandexMapController? _mapController;
  Uint8List? _markerIcon;
  Uint8List? _userMarkerIcon;
  Point? _userLocation;
  
  // Киров по умолчанию
  final Point _initialTarget = const Point(latitude: 58.603591, longitude: 49.668023);

  @override
  void initState() {
    super.initState();
    _initMarkerIcon();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = Point(latitude: position.latitude, longitude: position.longitude);
      });

      // Центрируем карту на пользователе если контроллер готов
      if (_mapController != null && mounted) {
        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _userLocation!,
              zoom: 12,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting user location: $e');
    }
  }

  Future<void> _initMarkerIcon() async {
    final icon = await _createMarkerIcon();
    final userIcon = await _createUserMarkerIcon();
    setState(() {
      _markerIcon = icon;
      _userMarkerIcon = userIcon;
    });
  }

  Future<Uint8List> _createMarkerIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = const Color(0xFF5E60CE);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const size = 48.0;
    const radius = size / 2;

    // Рисуем круг с белой обводкой
    canvas.drawCircle(
      const Offset(radius, radius),
      radius - 2,
      paint,
    );
    canvas.drawCircle(
      const Offset(radius, radius),
      radius - 2,
      borderPaint,
    );

    // Рисуем иконку события
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '📍',
        style: TextStyle(fontSize: 24),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(12, 12));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _createUserMarkerIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    const size = 40.0;
    const radius = size / 2;

    // Внешний круг (белый)
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(radius, radius), radius, outerPaint);

    // Внутренний круг (синий)
    final innerPaint = Paint()..color = const Color(0xFF5E60CE);
    canvas.drawCircle(const Offset(radius, radius), radius - 4, innerPaint);

    // Центральная точка (белая)
    final centerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(radius, radius), 6, centerPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _openFullMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => FullMapScreen(
          events: widget.events,
          userLocation: _userLocation,
        ),
      ),
    );
  }

  List<MapObject> _buildMarkers() {
    if (_markerIcon == null) return [];
    
    final markers = <MapObject>[];
    
    // Добавляем маркеры событий
    markers.addAll(
      widget.events.map((event) {
        return PlacemarkMapObject(
          mapId: MapObjectId('event_${event.id}'),
          point: Point(latitude: event.latitude, longitude: event.longitude),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(_markerIcon!),
              scale: 0.8,
            ),
          ),
          opacity: 1.0,
        );
      }),
    );
    
    // Добавляем маркер пользователя
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
        ),
      );
    }
    
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: <Widget>[
          // Яндекс карта
          YandexMap(
            onMapCreated: (YandexMapController controller) {
              _mapController = controller;
              
              // Если есть локация пользователя, центрируем на ней
              if (_userLocation != null) {
                _mapController?.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _userLocation!,
                      zoom: 12,
                    ),
                  ),
                );
              } else if (widget.events.isNotEmpty) {
                // Иначе на первом событии
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
                // Или на дефолтной позиции
                _mapController?.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _initialTarget,
                      zoom: 12,
                    ),
                  ),
                );
              }
            },
            mapObjects: _buildMarkers(),
            nightModeEnabled: false,
            rotateGesturesEnabled: false,
            scrollGesturesEnabled: false,
            tiltGesturesEnabled: false,
            zoomGesturesEnabled: false,
            fastTapEnabled: false,
          ),
          
          // Градиентный оверлей
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
          
          // Информация и кнопка
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
                ElevatedButton(
                  onPressed: _openFullMap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF5E60CE),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Открыть карту'),
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
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'события';
    } else {
      return 'событий';
    }
  }
}
