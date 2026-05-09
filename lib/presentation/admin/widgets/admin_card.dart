import 'package:flutter/material.dart';

import '../../auth/widgets/auth_glass_card.dart';

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AuthGlassCard(
      padding: padding is EdgeInsets ? padding as EdgeInsets : const EdgeInsets.all(14),
      child: child,
    );
  }
}

