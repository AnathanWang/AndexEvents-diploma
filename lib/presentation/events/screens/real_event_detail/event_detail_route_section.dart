import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../events/screens/real_event_detail/real_event_detail_widgets.dart';
import '../../../../data/models/event_model.dart';

class EventDetailRouteSection extends StatelessWidget {
  const EventDetailRouteSection({
    super.key,
    required this.event,
    required this.onOpenRoute,
  });

  final EventModel event;
  final VoidCallback onOpenRoute;

  @override
  Widget build(BuildContext context) {
    if (event.isOnline) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: EventDetailSectionContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EventDetailSectionTitle(
              'Маршрут',
              subtitle: 'Карта и быстрый переход в навигацию',
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 180,
                child: IgnorePointer(
                  child: YandexMap(
                    onMapCreated: (controller) {
                      controller.moveCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: Point(
                              latitude: event.latitude,
                              longitude: event.longitude,
                            ),
                            zoom: 13,
                          ),
                        ),
                      );
                    },
                    mapObjects: [
                      PlacemarkMapObject(
                        mapId: const MapObjectId('event_detail_point'),
                        point: Point(
                          latitude: event.latitude,
                          longitude: event.longitude,
                        ),
                        icon: PlacemarkIcon.single(
                          PlacemarkIconStyle(
                            image: BitmapDescriptor.fromAssetImage(
                              'assets/icons/map_arrow.png',
                            ),
                            scale: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpenRoute,
                icon: const Icon(Icons.route),
                label: const Text('Построить маршрут'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

