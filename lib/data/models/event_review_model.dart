class EventReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const EventReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory EventReviewModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? user = json['user'] as Map<String, dynamic>?;
    final rawName =
        json['userName'] ?? json['reviewerName'] ?? json['authorName'] ?? user?['displayName'] ?? user?['name'];
    final rawPhoto =
        json['userPhotoUrl'] ?? json['reviewerPhotoUrl'] ?? json['authorPhotoUrl'] ?? user?['photoUrl'] ?? user?['avatarUrl'];
    final rawCreatedAt = json['createdAt'] ?? json['created_at'];
    final rawComment = json['comment'] ??
        json['details'] ??
        json['text'] ??
        json['review'] ??
        json['message'] ??
        json['content'] ??
        json['body'];

    return EventReviewModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? json['authorId'] ?? user?['id'] ?? '').toString(),
      userName: (rawName ?? 'Без имени').toString(),
      userPhotoUrl: rawPhoto?.toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: rawComment?.toString(),
      createdAt: rawCreatedAt != null
          ? DateTime.parse(rawCreatedAt.toString())
          : DateTime.now(),
    );
  }
}
