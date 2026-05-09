class AdminAuditLogModel {
  const AdminAuditLogModel({
    required this.id,
    required this.actorUserId,
    required this.targetUserId,
    required this.action,
    required this.details,
    required this.createdAt,
  });

  final String id;
  final String actorUserId;
  final String? targetUserId;
  final String action;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  factory AdminAuditLogModel.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    return AdminAuditLogModel(
      id: json['id'] as String,
      actorUserId: json['actorUserId'] as String,
      targetUserId: json['targetUserId'] as String?,
      action: json['action'] as String,
      details: rawDetails is Map<String, dynamic>
          ? rawDetails
          : <String, dynamic>{},
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
