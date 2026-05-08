import 'package:flutter/material.dart';

class EventDraftModel {
  const EventDraftModel({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.locationText,
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    required this.isFree,
    required this.priceText,
    required this.selectedDate,
    required this.selectedTime,
    required this.hasEndDateTime,
    required this.selectedEndDate,
    required this.selectedEndTime,
    required this.selectedCategories,
    required this.customCategory,
    required this.uploadedPhotoUrls,
    required this.savedAt,
  });

  final String id;
  final String name;
  final String title;
  final String description;
  final String locationText;
  final double? latitude;
  final double? longitude;
  final bool isOnline;
  final bool isFree;
  final String priceText;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final bool hasEndDateTime;
  final DateTime selectedEndDate;
  final TimeOfDay selectedEndTime;
  final List<String> selectedCategories;
  final String customCategory;
  final List<String> uploadedPhotoUrls;
  final DateTime savedAt;

  EventDraftModel copyWith({
    String? id,
    String? name,
    String? title,
    String? description,
    String? locationText,
    double? latitude,
    double? longitude,
    bool? isOnline,
    bool? isFree,
    String? priceText,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    bool? hasEndDateTime,
    DateTime? selectedEndDate,
    TimeOfDay? selectedEndTime,
    List<String>? selectedCategories,
    String? customCategory,
    List<String>? uploadedPhotoUrls,
    DateTime? savedAt,
  }) {
    return EventDraftModel(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      locationText: locationText ?? this.locationText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isOnline: isOnline ?? this.isOnline,
      isFree: isFree ?? this.isFree,
      priceText: priceText ?? this.priceText,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      hasEndDateTime: hasEndDateTime ?? this.hasEndDateTime,
      selectedEndDate: selectedEndDate ?? this.selectedEndDate,
      selectedEndTime: selectedEndTime ?? this.selectedEndTime,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      customCategory: customCategory ?? this.customCategory,
      uploadedPhotoUrls: uploadedPhotoUrls ?? this.uploadedPhotoUrls,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'title': title,
      'description': description,
      'locationText': locationText,
      'latitude': latitude,
      'longitude': longitude,
      'isOnline': isOnline,
      'isFree': isFree,
      'priceText': priceText,
      'selectedDate': selectedDate.toIso8601String(),
      'selectedTime': <String, dynamic>{
        'hour': selectedTime.hour,
        'minute': selectedTime.minute,
      },
      'hasEndDateTime': hasEndDateTime,
      'selectedEndDate': selectedEndDate.toIso8601String(),
      'selectedEndTime': <String, dynamic>{
        'hour': selectedEndTime.hour,
        'minute': selectedEndTime.minute,
      },
      'selectedCategories': selectedCategories,
      'customCategory': customCategory,
      'uploadedPhotoUrls': uploadedPhotoUrls,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory EventDraftModel.fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(dynamic raw) {
      final map = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
      final hour = (map['hour'] as num?)?.toInt() ?? 0;
      final minute = (map['minute'] as num?)?.toInt() ?? 0;
      return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
    }

    DateTime parseDate(dynamic raw, DateTime fallback) {
      try {
        final s = raw?.toString();
        if (s == null || s.trim().isEmpty) return fallback;
        return DateTime.parse(s);
      } catch (_) {
        return fallback;
      }
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).toList();
      }
      return <String>[];
    }

    final now = DateTime.now();

    return EventDraftModel(
      id: (json['id'] as String?) ?? now.microsecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? 'Черновик',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      locationText: (json['locationText'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isOnline: (json['isOnline'] as bool?) ?? false,
      isFree: (json['isFree'] as bool?) ?? true,
      priceText: (json['priceText'] as String?) ?? '',
      selectedDate: parseDate(json['selectedDate'], now),
      selectedTime: parseTime(json['selectedTime']),
      hasEndDateTime: (json['hasEndDateTime'] as bool?) ?? false,
      selectedEndDate: parseDate(json['selectedEndDate'], now),
      selectedEndTime: parseTime(json['selectedEndTime']),
      selectedCategories: parseStringList(json['selectedCategories']),
      customCategory: (json['customCategory'] as String?) ?? '',
      uploadedPhotoUrls: parseStringList(json['uploadedPhotoUrls']),
      savedAt: parseDate(json['savedAt'], now),
    );
  }
}

