import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/logger_service.dart';
import '../../../data/services/geocoding_service.dart';
import '../../../core/theme/app_colors.dart';

class MapLocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const MapLocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late YandexMapController _mapController;
  final GeocodingService _geocodingService = GeocodingService();
  
  Point? _selectedPoint;
  String? _selectedAddress;
  bool _isLoadingAddress = false;
  Uint8List? _markerIcon;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint = Point(
        latitude: widget.initialLatitude!,
        longitude: widget.initialLongitude!,
      );
      _selectedAddress = widget.initialAddress;
    }
    _initMarkerIcon();
  }

  Future<void> _initMarkerIcon() async {
    _markerIcon = await _createMarkerIcon();
    if (mounted) setState(() {});
  }

  Future<void> _getUserLocation() async {
    try {
      // Проверяем разрешения
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          LoggerService.debug('Location permissions are denied');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        LoggerService.debug('Location permissions are permanently denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      final userPoint = Point(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      setState(() {
        _selectedPoint = userPoint;
      });
      
      // Перемещаем камеру к пользователю
      await _mapController.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userPoint, zoom: 15),
        ),
      );
    } catch (e) {
      LoggerService.error('Error getting user location: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onMapCreated(YandexMapController controller) async {
    _mapController = controller;
    
    // Если есть начальные координаты - центрируем карту
    if (_selectedPoint != null) {
      await _mapController.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _selectedPoint!, zoom: 15),
        ),
      );
    } else {
      // Если начальных координат нет - получаем местоположение пользователя
      await _getUserLocation();
    }
  }

  Future<void> _onMapTap(Point point) async {
    setState(() {
      _selectedPoint = point;
      _isLoadingAddress = true;
      _selectedAddress = null;
    });

    try {
      final address = await _geocodingService.getAddressFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (mounted) {
        setState(() {
          _selectedAddress = address ?? '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error getting address: $e');
      if (mounted) {
        setState(() {
          _selectedAddress = '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<Uint8List> _createMarkerIcon() async {
    // Создаем маркер в стиле приложения
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Рисуем круг с белой обводкой + небольшой "блик"
    canvas.drawCircle(const Offset(30, 30), 15, strokePaint);
    canvas.drawCircle(const Offset(30, 30), 15, paint);
    canvas.drawCircle(
      const Offset(24, 24),
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(60, 60);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }



  void _confirmSelection() {
    if (_selectedPoint != null && _selectedAddress != null) {
      Navigator.of(context).pop({
        'latitude': _selectedPoint!.latitude,
        'longitude': _selectedPoint!.longitude,
        'address': _selectedAddress,
      });
    }
  }

  BoxDecoration _glassCardDecoration({
    double radius = 24,
    double alpha = 0.72,
    double borderAlpha = 0.14,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.primary.withValues(alpha: borderAlpha)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: AppColors.dark.withValues(alpha: 0.12),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.86),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Выберите место',
          style: TextStyle(
            color: AppColors.dark.withValues(alpha: 0.88),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close_rounded,
            color: AppColors.dark.withValues(alpha: 0.78),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFFEAF2FF),
                    Color(0xFFD9E8FF),
                    Color(0xFFEFF5FF),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: -120,
            top: -140,
            child: _BlurCircle(size: 260, color: Color(0x330961F6)),
          ),
          const Positioned(
            right: -140,
            bottom: -180,
            child: _BlurCircle(size: 320, color: AppColors.accent),
          ),
          // Карта
          YandexMap(
            onMapCreated: _onMapCreated,
            onMapTap: (argument) => _onMapTap(argument),
            mapObjects: _selectedPoint != null && _markerIcon != null
                ? [
                    PlacemarkMapObject(
                      mapId: const MapObjectId('selected_location'),
                      point: _selectedPoint!,
                      opacity: 1.0,
                      icon: PlacemarkIcon.single(
                        PlacemarkIconStyle(
                          image: BitmapDescriptor.fromBytes(_markerIcon!),
                          scale: 1.0,
                        ),
                      ),
                    ),
                  ]
                : [],
          ),

          // Кнопки управления зумом
          Positioned(
            right: 16,
            bottom: 132,
            child: Column(
              children: [
                _MapFab(
                  heroTag: 'locate_me',
                  icon: Icons.my_location_rounded,
                  onPressed: _getUserLocation,
                ),
                const SizedBox(height: 8),
                _MapFab(
                  heroTag: 'zoom_in',
                  icon: Icons.add_rounded,
                  onPressed: () async {
                    await _mapController.moveCamera(
                      CameraUpdate.zoomIn(),
                      animation: const MapAnimation(
                        type: MapAnimationType.smooth,
                        duration: 0.3,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _MapFab(
                  heroTag: 'zoom_out',
                  icon: Icons.remove_rounded,
                  onPressed: () async {
                    await _mapController.moveCamera(
                      CameraUpdate.zoomOut(),
                      animation: const MapAnimation(
                        type: MapAnimationType.smooth,
                        duration: 0.3,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Выбранный адрес
          if (_selectedAddress != null)
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: SafeArea(
                top: false,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _glassCardDecoration(radius: 24, alpha: 0.78),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Выбранное место',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedPoint = null;
                                    _selectedAddress = null;
                                  });
                                },
                                icon: const Icon(Icons.close_rounded),
                                color: AppColors.dark.withValues(alpha: 0.62),
                                tooltip: 'Сбросить',
                              ),
                            ],
                          ),
                          if (_isLoadingAddress)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          else
                            Text(
                              _selectedAddress!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark.withValues(alpha: 0.84),
                                height: 1.25,
                              ),
                            ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_selectedPoint != null && !_isLoadingAddress)
                                  ? _confirmSelection
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Подтвердить',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(width: size, height: size, color: color),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.heroTag,
    required this.icon,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      elevation: 0,
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      foregroundColor: AppColors.primary,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}
