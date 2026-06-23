import '../../core/utils/media_url_utils.dart';

class MapUserPreview {
  const MapUserPreview({
    required this.id,
    this.displayName,
    this.photoUrl,
    this.age,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String? displayName;
  final String? photoUrl;
  final int? age;
  final double latitude;
  final double longitude;

  factory MapUserPreview.fromJson(Map<String, dynamic> json) {
    return MapUserPreview(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: MediaUrlUtils.normalize(json['photoUrl'] as String?),
      age: json['age'] as int?,
      latitude: (json['lastLatitude'] as num).toDouble(),
      longitude: (json['lastLongitude'] as num).toDouble(),
    );
  }
}
