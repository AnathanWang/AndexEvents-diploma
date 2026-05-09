import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/widgets/auth_glass_scaffold.dart';

class AdminScreenScaffold extends StatelessWidget {
  const AdminScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AuthGlassScaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        actions: actions,
      ),
      child: SafeArea(child: body),
    );
  }
}

