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

  String get _initials {
    final parts = match.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenProfile,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 14,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF75878A).withValues(alpha: 0.14),
                backgroundImage: match.avatar != null && match.avatar!.isNotEmpty
                    ? NetworkImage(match.avatar!)
                    : null,
                child: match.avatar == null || match.avatar!.isEmpty
                    ? Text(
                        _initials,
                        style: const TextStyle(
                          color: Color(0xFF75878A),
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      match.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      match.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onOpenProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF75878A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Профиль'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
