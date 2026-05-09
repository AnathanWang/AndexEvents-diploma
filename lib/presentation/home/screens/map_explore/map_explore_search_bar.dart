import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MapExploreSearchBar extends StatelessWidget {
  const MapExploreSearchBar({
    super.key,
    required this.controller,
    required this.onOpenSearch,
    required this.onQueryChanged,
    required this.onClearQuery,
    this.horizontalInset = 30,
  });

  final TextEditingController controller;
  final VoidCallback onOpenSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: horizontalInset,
      right: horizontalInset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.dark.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  controller: controller,
                  onTap: onOpenSearch,
                  onChanged: onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Поиск по карте',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      CupertinoIcons.search,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    suffixIcon: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) {
                        if (controller.text.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid),
                          color: AppColors.primary,
                          onPressed: onClearQuery,
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

