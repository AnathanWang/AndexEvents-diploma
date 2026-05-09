enum EventSanctionType {
  hideVisibility,
  freezeParticipation,
  limitEdits,
}

EventSanctionType eventSanctionTypeFromBackend(String value) {
  switch (value.toUpperCase().trim()) {
    case 'HIDE_VISIBILITY':
      return EventSanctionType.hideVisibility;
    case 'FREEZE_PARTICIPATION':
      return EventSanctionType.freezeParticipation;
    case 'LIMIT_EDITS':
      return EventSanctionType.limitEdits;
    default:
      return EventSanctionType.hideVisibility;
  }
}

String eventSanctionTypeToBackend(EventSanctionType type) {
  switch (type) {
    case EventSanctionType.hideVisibility:
      return 'HIDE_VISIBILITY';
    case EventSanctionType.freezeParticipation:
      return 'FREEZE_PARTICIPATION';
    case EventSanctionType.limitEdits:
      return 'LIMIT_EDITS';
  }
}

class EventSanctionModel {
  const EventSanctionModel({
    required this.id,
    required this.eventId,
    required this.type,
    required this.reason,
    required this.createdById,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.revokedAt,
    this.revokedById,
  });

  final String id;
  final String eventId;
  final EventSanctionType type;
  final String reason;
  final String? createdById;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final String? revokedById;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive =>
      revokedAt == null && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory EventSanctionModel.fromJson(Map<String, dynamic> json) {
    return EventSanctionModel(
      id: (json['id'] ?? '').toString(),
      eventId: (json['eventId'] ?? '').toString(),
      type: eventSanctionTypeFromBackend((json['type'] ?? '').toString()),
      reason: (json['reason'] ?? '').toString(),
      createdById: (json['createdById'] as String?),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      revokedAt: json['revokedAt'] != null
          ? DateTime.tryParse(json['revokedAt'].toString())
          : null,
      revokedById: (json['revokedById'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
    );
  }
}

