import 'package:flutter/material.dart';

import '../../models/match_preview.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key, required this.matches});

  final List<MatchPreview> matches;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  int _currentIndex = 0;

  void _handleSwipe(bool isLike) {
    setState(() {
      if (_currentIndex < widget.matches.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Icon(Icons.favorite_border, size: 80, color: Color(0xFFBDBDBD)),
            SizedBox(height: 20),
            Text(
              'Совпадений пока нет',
              style: TextStyle(fontSize: 18, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Посещайте события, чтобы встретить людей',
              style: TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
            ),
          ],
        ),
      );
    }

    final MatchPreview currentMatch = widget.matches[_currentIndex % widget.matches.length];

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF5E60CE), Color(0xFF4ECCA3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            currentMatch.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Совпадений: ${currentMatch.matchPercentage}%',
                            style: const TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: currentMatch.commonInterests
                                .map((String interest) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        interest,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FloatingActionButton(
                heroTag: 'dislike',
                onPressed: () => _handleSwipe(false),
                backgroundColor: Colors.white,
                child: const Icon(Icons.close, color: Colors.red, size: 32),
              ),
              const SizedBox(width: 40),
              FloatingActionButton.large(
                heroTag: 'like',
                onPressed: () => _handleSwipe(true),
                backgroundColor: const Color(0xFF5E60CE),
                child: const Icon(Icons.favorite, color: Colors.white, size: 36),
              ),
              const SizedBox(width: 40),
              FloatingActionButton(
                heroTag: 'superlike',
                onPressed: () => _handleSwipe(true),
                backgroundColor: Colors.white,
                child: const Icon(Icons.star, color: Colors.amber, size: 32),
              ),
            ],
          ),
        ),
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.matches.length,
              (int index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _currentIndex % widget.matches.length ? Colors.white : Colors.white38,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
