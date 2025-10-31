import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../home/screens/full_map_screen.dart';

class YandexMapWidget extends StatefulWidget {
  const YandexMapWidget({super.key});

  @override
  State<YandexMapWidget> createState() => _YandexMapWidgetState();
}

class _YandexMapWidgetState extends State<YandexMapWidget> {
  YandexMapController? _mapController;
  
  // Москва, центр
  final Point _initialTarget = const Point(latitude: 55.7558, longitude: 37.6173);

  void _openFullMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const FullMapScreen(),
      ),
    );
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
              _mapController?.moveCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _initialTarget,
                    zoom: 12,
                  ),
                ),
              );
            },
            mapObjects: const <MapObject>[
              // TODO: Добавить маркеры событий
            ],
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
                const Text(
                  '4 события сегодня',
                  style: TextStyle(
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
}
