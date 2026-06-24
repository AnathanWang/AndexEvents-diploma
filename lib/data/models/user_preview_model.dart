import '../../core/utils/media_url_utils.dart';

class UserPreviewModel {
  const UserPreviewModel({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.email,
  });

  final String id;
  final String displayName;
  final String? photoUrl;
  final String? email;

  factory UserPreviewModel.fromJson(Map<String, dynamic> json) {
    return UserPreviewModel(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'Unknown',
      photoUrl: MediaUrlUtils.normalize(json['photoUrl'] as String?),
      email: json['email'] as String?,
    );
  }
}

