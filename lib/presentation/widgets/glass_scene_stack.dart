import 'package:flutter/material.dart';

/// Light-blue gradient + soft orbs behind content (same visual as [AuthGlassScaffold] body).
class GlassSceneStack extends StatelessWidget {
  const GlassSceneStack({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFEAF2FF),
            Color(0xFFD9E8FF),
            Color(0xFFEFF5FF),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -110,
            right: -75,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F6CF8).withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -85,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8CB9FF).withValues(alpha: 0.16),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
