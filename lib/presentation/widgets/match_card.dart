import 'package:flutter/material.dart';

import '../models/match_preview.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.width});

  final MatchPreview match;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: match.avatarColor.withOpacity(0.14),
            child: Icon(Icons.favorite, color: match.avatarColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(match.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(match.subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: match.avatarColor,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Показать профиль'),
          ),
        ],
      ),
    );
  }
}
