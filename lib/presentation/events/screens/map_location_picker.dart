import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/services/geocoding_service.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final GeocodingService _geocodingService = GeocodingService();
  
  Point? _selectedPoint;
  String? _selectedAddress;
  bool _isSearching = false;
  List<GeocodingResult> _searchResults = [];
  bool _isLoadingAddress = false;
  Uint8List? _markerIcon;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
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
          print('Location permissions are denied');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
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
      print('Error getting user location: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 3) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        return;
      }

      setState(() {
        _isSearching = true;
      });

      try {
        final results = await _geocodingService.searchAddresses(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
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
      print('Error getting address: $e');
      if (mounted) {
        setState(() {
          _selectedAddress = '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<Uint8List> _createMarkerIcon() async {
    // Создаем простую красную точку как маркер
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Рисуем большой круг с белой обводкой
    canvas.drawCircle(const Offset(30, 30), 15, strokePaint);
    canvas.drawCircle(const Offset(30, 30), 15, paint);
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(60, 60);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }



  void _selectSearchResult(GeocodingResult result) {
    setState(() {
      _selectedPoint = Point(
        latitude: result.latitude,
        longitude: result.longitude,
      );
      _selectedAddress = result.address;
      _searchResults = [];
      _searchController.clear();
    });

    _mapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _selectedPoint!,
          zoom: 15,
        ),
      ),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите место'),
        actions: [
          IconButton(
            onPressed: _selectedPoint != null ? _confirmSelection : null,
            icon: Icon(
              Icons.check_circle,
              color: _selectedPoint != null ? Colors.green : Colors.grey.shade400,
              size: 32,
            ),
            tooltip: 'Подтвердить',
          ),
        ],
      ),
      body: Stack(
        children: [
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
            bottom: 100,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: 'zoom_in',
                  onPressed: () async {
                    await _mapController.moveCamera(
                      CameraUpdate.zoomIn(),
                      animation: const MapAnimation(
                        type: MapAnimationType.smooth,
                        duration: 0.3,
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: 'zoom_out',
                  onPressed: () async {
                    await _mapController.moveCamera(
                      CameraUpdate.zoomOut(),
                      animation: const MapAnimation(
                        type: MapAnimationType.smooth,
                        duration: 0.3,
                      ),
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // Поиск адреса
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Поле поиска
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Введите адрес вручную',
                      helperText: 'Кликните на карту для выбора места',
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.location_on),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () {
                                // Используем введенный адрес
                                if (_selectedPoint != null) {
                                  setState(() {
                                    _selectedAddress = _searchController.text;
                                  });
                                }
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),

                // Результаты поиска
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )
                else if (_searchResults.isNotEmpty)
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text(result.address),
                            onTap: () => _selectSearchResult(result),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Выбранный адрес
          if (_selectedAddress != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Выбранное место:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_isLoadingAddress)
                        const CircularProgressIndicator()
                      else
                        Text(
                          _selectedAddress!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
