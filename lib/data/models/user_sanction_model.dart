class UserSanctionModel {
  const UserSanctionModel({
    required this.id,
    required this.targetUserId,
    required this.createdByUserId,
    required this.type,
    required this.reason,
    this.expiresAt,
    this.revokedAt,
    this.revokedByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String targetUserId;
  final String createdByUserId;
  final String type;
  final String reason;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final String? revokedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive {
    if (revokedAt != null) return false;
    if (expiresAt == null) return true;
    return expiresAt!.isAfter(DateTime.now().toUtc());
  }

  factory UserSanctionModel.fromJson(Map<String, dynamic> json) {
    return UserSanctionModel(
      id: json['id'] as String,
      targetUserId: json['targetUserId'] as String,
      createdByUserId: json['createdByUserId'] as String,
      type: json['type'] as String,
      reason: json['reason'] as String? ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      revokedAt: json['revokedAt'] != null
          ? DateTime.parse(json['revokedAt'] as String)
          : null,
      revokedByUserId: json['revokedByUserId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now().toUtc(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now().toUtc(),
    );
  }
}
