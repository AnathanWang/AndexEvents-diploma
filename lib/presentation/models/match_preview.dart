import 'package:flutter/material.dart';

class MatchPreview {
  const MatchPreview({
    required this.name,
    required this.subtitle,
    required this.avatarColor,
    this.matchPercentage = 85,
    this.commonInterests = const <String>[],
  });

  final String name;
  final String subtitle;
  final Color avatarColor;
  final int matchPercentage;
  final List<String> commonInterests;
}
