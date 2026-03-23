import 'package:flutter/material.dart';

class EventPreview {
  const EventPreview({
    required this.id, // Добавлено поле id
    required this.title,
    required this.category,
    required this.time,
    required this.distance,
    required this.badgeColor,
    required this.attendees,
    required this.date,
    required this.location,
    this.price,
    this.attendeeNames = const <String>[],
  });

  final String id; // Добавлено поле id
  final String title;
  final String category;
  final String time;
  final String distance;
  final Color badgeColor;
  final int attendees;
  final DateTime date;
  final String location;
  final int? price;
  final List<String> attendeeNames;
  
  bool get isFree => price == null || price == 0;
}
