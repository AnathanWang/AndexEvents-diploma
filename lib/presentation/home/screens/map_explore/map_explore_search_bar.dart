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
    this.readOnly = false,
  });

  final TextEditingController controller;
  final VoidCallback onOpenSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final double horizontalInset;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: horizontalInset,
      right: horizontalInset,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {},
        child: RepaintBoundary(
          child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: readOnly ? 0.78 : 0.34),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.08),
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
            readOnly: readOnly,
            onTap: readOnly
                ? () {
                    FocusScope.of(context).unfocus();
                    onOpenSearch();
                  }
                : null,
            onChanged: readOnly ? null : onQueryChanged,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
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
              suffixIcon: readOnly
                  ? null
                  : ListenableBuilder(
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
          ),
        ),
      ),
    );
  }
}
