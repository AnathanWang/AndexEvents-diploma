import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../data/models/event_model.dart';

/// User markers appear only when zoomed in enough to avoid cluttering the city view.
const double mapUserMarkersMinZoom = 14.0;

bool shouldShowMapUserMarkers(double zoom) => zoom >= mapUserMarkersMinZoom;

/// Center of the map viewport.
Point mapViewportCenter(VisibleRegion region) {
  final lat = (region.topLeft.latitude +
          region.topRight.latitude +
          region.bottomLeft.latitude +
          region.bottomRight.latitude) /
      4;
  final lon = (region.topLeft.longitude +
          region.topRight.longitude +
          region.bottomLeft.longitude +
          region.bottomRight.longitude) /
      4;
  return Point(latitude: lat, longitude: lon);
}

/// Radius in meters that covers the visible map area (center → farthest corner + buffer).
int mapViewportRadiusMeters(
  VisibleRegion region, {
  double bufferFactor = 1.25,
  int minRadiusMeters = 1500,
}) {
  final center = mapViewportCenter(region);
  final corners = <Point>[
    region.topLeft,
    region.topRight,
    region.bottomLeft,
    region.bottomRight,
  ];

  var maxDistance = 0.0;
  for (final corner in corners) {
    final distance = Geolocator.distanceBetween(
      center.latitude,
      center.longitude,
      corner.latitude,
      corner.longitude,
    );
    maxDistance = math.max(maxDistance, distance);
  }

  final radius = (maxDistance * bufferFactor).round();
  return math.max(radius, minRadiusMeters);
}

/// Whether the camera moved enough to request a new batch of events.
bool shouldReloadMapEvents({
  required Point? lastCenter,
  required int? lastRadiusMeters,
  required Point nextCenter,
  required int nextRadiusMeters,
  double moveFactor = 0.35,
  double zoomFactor = 0.25,
}) {
  if (lastCenter == null || lastRadiusMeters == null) {
    return true;
  }

  final movedMeters = Geolocator.distanceBetween(
    lastCenter.latitude,
    lastCenter.longitude,
    nextCenter.latitude,
    nextCenter.longitude,
  );

  final moveThreshold = lastRadiusMeters * moveFactor;
  if (movedMeters >= moveThreshold) {
    return true;
  }

  final radiusDelta = (nextRadiusMeters - lastRadiusMeters).abs();
  return radiusDelta >= lastRadiusMeters * zoomFactor;
}

/// Approximate viewport radius from zoom (avoids native [getVisibleRegion] on every pan).
int mapViewportRadiusFromZoom(
  double zoom,
  double latitude, {
  double halfViewportPx = 220,
  double bufferFactor = 1.25,
  int minRadiusMeters = 1500,
}) {
  final latRad = latitude * math.pi / 180;
  final metersPerPixel =
      156543.03392 * math.cos(latRad) / math.pow(2, zoom);
  final radius = (metersPerPixel * halfViewportPx * bufferFactor).round();
  return math.max(radius, minRadiusMeters);
}

double distanceToPointMeters(Point from, Point to) {
  return Geolocator.distanceBetween(
    from.latitude,
    from.longitude,
    to.latitude,
    to.longitude,
  );
}

List<EventModel> eventsWithinRadius(
  List<EventModel> events,
  Point center,
  int radiusMeters,
) {
  return events
      .where(
        (event) =>
            distanceToPointMeters(
              center,
              Point(latitude: event.latitude, longitude: event.longitude),
            ) <=
            radiusMeters,
      )
      .toList();
}

List<EventModel> eventsNearestToPoint(
  List<EventModel> events,
  Point center, {
  int limit = 15,
}) {
  if (events.length <= limit) {
    return List<EventModel>.from(events);
  }

  final scored = events
      .map(
        (event) => (
          event: event,
          distance: distanceToPointMeters(
            center,
            Point(latitude: event.latitude, longitude: event.longitude),
          ),
        ),
      )
      .toList()
    ..sort((a, b) => a.distance.compareTo(b.distance));

  return scored.take(limit).map((entry) => entry.event).toList();
}

bool isPointInsideVisibleRegion(Point point, VisibleRegion region) {
  final minLat = math.min(
    math.min(region.bottomLeft.latitude, region.bottomRight.latitude),
    math.min(region.topLeft.latitude, region.topRight.latitude),
  );
  final maxLat = math.max(
    math.max(region.bottomLeft.latitude, region.bottomRight.latitude),
    math.max(region.topLeft.latitude, region.topRight.latitude),
  );
  final minLon = math.min(
    math.min(region.bottomLeft.longitude, region.bottomRight.longitude),
    math.min(region.topLeft.longitude, region.topRight.longitude),
  );
  final maxLon = math.max(
    math.max(region.bottomLeft.longitude, region.bottomRight.longitude),
    math.max(region.topLeft.longitude, region.topRight.longitude),
  );

  return point.latitude >= minLat &&
      point.latitude <= maxLat &&
      point.longitude >= minLon &&
      point.longitude <= maxLon;
}
