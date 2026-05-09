import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/logger_service.dart';
import '../../../data/services/geocoding_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/widgets/auth_glass_card.dart';
import '../../auth/widgets/auth_glass_scaffold.dart';

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

    if (_selectedPoint != null) {
      await _mapController.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _selectedPoint!, zoom: 15),
        ),
      );
    } else {
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
          _selectedAddress = address ??
              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      LoggerService.error('Error getting address: $e');
      if (mounted) {
        setState(() {
          _selectedAddress =
              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<Uint8List> _createMarkerIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

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

  @override
  Widget build(BuildContext context) {
    return AuthGlassScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Выберите место',
          style: TextStyle(
            color: Color(0xFF1F3552),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Color(0xFF273043)),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          YandexMap(
            onMapCreated: _onMapCreated,
            onMapTap: _onMapTap,
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
          if (_selectedAddress != null)
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: SafeArea(
                top: false,
                child: AuthGlassCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
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
        ],
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}
