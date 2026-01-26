import 'package:flutter/material.dart';

import '../models/match_preview.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    this.width,
    this.onOpenProfile,
  });

  final MatchPreview match;
  final double? width;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenProfile,
        borderRadius: BorderRadius.circular(24),
        child: Container(
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
                backgroundColor: const Color(0xFF5E60CE).withOpacity(0.14),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFF5E60CE),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(match.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(match.subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onOpenProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E60CE),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Показать профиль'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
