import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/glass_scene_stack.dart';

class AuthGlassScaffold extends StatelessWidget {
  const AuthGlassScaffold({
    super.key,
    this.extendBodyBehindAppBar = false,
    this.appBar,
    required this.child,
  });

  final bool extendBodyBehindAppBar;
  final PreferredSizeWidget? appBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: GlassSceneStack(child: child),
    );
  }
}

