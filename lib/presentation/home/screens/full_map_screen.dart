import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/event_model.dart';
import '../../events/screens/real_event_detail_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../events/bloc/event_bloc.dart';

class FullMapScreen extends StatefulWidget {
  final List<EventModel> events;
  final Point? userLocation;
  
  const FullMapScreen({super.key, required this.events, this.userLocation});

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  YandexMapController? _mapController;
  Uint8List? _markerIcon;
  Uint8List? _userMarkerIcon;
  Point? _currentUserLocation;
  bool _showEventsList = false;
  
  // Киров по умолчанию
  final Point _initialTarget = const Point(latitude: 58.603591, longitude: 49.668023);

  @override
  void initState() {
    super.initState();
    _currentUserLocation = widget.userLocation;
    _initMarkerIcon();
  }

  Future<void> _initMarkerIcon() async {
    final icon = await _createMarkerIcon();
    final userIcon = await _createUserMarkerIcon();
    if (mounted) {
      setState(() {
        _markerIcon = icon;
        _userMarkerIcon = userIcon;
      });
    }
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

    canvas.drawCircle(const Offset(radius, radius), radius - 2, paint);
    canvas.drawCircle(const Offset(radius, radius), radius - 2, borderPaint);

    final textPainter = TextPainter(
      text: const TextSpan(text: '📍', style: TextStyle(fontSize: 24)),
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

  Future<void> _centerOnUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      final userPoint = Point(latitude: position.latitude, longitude: position.longitude);
      
      setState(() {
        _currentUserLocation = userPoint;
      });

      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userPoint, zoom: 14),
        ),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.0),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка определения местоположения: $e')),
        );
      }
    }
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
          onTap: (placemark, point) {
            _showEventDetails(event);
          },
        );
      }),
    );
    
    // Добавляем маркер пользователя
    if (_currentUserLocation != null && _userMarkerIcon != null) {
      markers.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('user_location'),
          point: _currentUserLocation!,
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

  void _showEventDetails(EventModel event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(event.category, style: const TextStyle(color: Color(0xFF5E60CE))),
            const SizedBox(height: 8),
            Text(event.location),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (context) => EventBloc(),
                      child: RealEventDetailScreen(eventId: event.id),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E60CE),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Подробнее'),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Полноэкранная карта
          YandexMap(
            onMapCreated: (YandexMapController controller) {
              _mapController = controller;
              
              final targetPoint = _currentUserLocation ??
                  (widget.events.isNotEmpty
                      ? Point(
                          latitude: widget.events.first.latitude,
                          longitude: widget.events.first.longitude,
                        )
                      : _initialTarget);
              
              _mapController?.moveCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: targetPoint, zoom: 12),
                ),
              );
            },
            mapObjects: _buildMarkers(),
            nightModeEnabled: false,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            zoomGesturesEnabled: true,
            fastTapEnabled: true,
          ),
          
          // Верхняя панель с кнопкой назад
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: <Widget>[
                  // Кнопка назад
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(Icons.arrow_back, color: Color(0xFF5E60CE)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Заголовок
                  const Expanded(
                    child: Text(
                      'Карта событий',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Кнопки зума
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 80,
            child: Column(
              children: [
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 4,
                  child: InkWell(
                    onTap: () {
                      _mapController?.moveCamera(
                        CameraUpdate.zoomIn(),
                        animation: const MapAnimation(
                          type: MapAnimationType.smooth,
                          duration: 0.3,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(Icons.add, color: Color(0xFF5E60CE)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 4,
                  child: InkWell(
                    onTap: () {
                      _mapController?.moveCamera(
                        CameraUpdate.zoomOut(),
                        animation: const MapAnimation(
                          type: MapAnimationType.smooth,
                          duration: 0.3,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(Icons.remove, color: Color(0xFF5E60CE)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Нижняя панель с информацией
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!_showEventsList) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '${widget.events.length} ${_getEventWord(widget.events.length)} сегодня',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A4D6A),
                          ),
                        ),
                        const Text(
                          'В радиусе 5 км',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showEventsList = !_showEventsList;
                              });
                            },
                            icon: const Icon(Icons.list),
                            label: const Text('Показать список'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5E60CE),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: _centerOnUserLocation,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              child: const Icon(
                                Icons.my_location,
                                color: Color(0xFF5E60CE),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Список событий',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A4D6A),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showEventsList = false;
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: ListView.builder(
                        itemCount: widget.events.length,
                        itemBuilder: (context, index) {
                          final event = widget.events[index];
                          return ListTile(
                            leading: const Icon(Icons.event, color: Color(0xFF5E60CE)),
                            title: Text(event.title),
                            subtitle: Text(event.location),
                            onTap: () {
                              setState(() {
                                _showEventsList = false;
                              });
                              _mapController?.moveCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(
                                    target: Point(
                                      latitude: event.latitude,
                                      longitude: event.longitude,
                                    ),
                                    zoom: 15,
                                  ),
                                ),
                                animation: const MapAnimation(
                                  type: MapAnimationType.smooth,
                                  duration: 1.0,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
