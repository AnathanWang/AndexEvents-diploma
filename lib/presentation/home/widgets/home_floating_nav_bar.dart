import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomeFloatingNavBar extends StatelessWidget {
  const HomeFloatingNavBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.onTapCreate,
    required this.navItemWidth,
    required this.sideGap,
    required this.centerGap,
    required this.isFullBanActive,
    required this.isCreateEventBlocked,
  });

  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onTapCreate;
  final double navItemWidth;
  final double sideGap;
  final double centerGap;
  final bool isFullBanActive;
  final bool isCreateEventBlocked;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double rowWidth =
                        (navItemWidth * 4) + (sideGap * 2) + centerGap;
                    final double startX = (constraints.maxWidth - rowWidth) / 2;
                    final double indicatorWidth = navItemWidth + 2;

                    double itemLeft(int i) {
                      switch (i) {
                        case 0:
                          return startX;
                        case 1:
                          return startX + navItemWidth + sideGap;
                        case 2:
                          return startX + (navItemWidth * 2) + sideGap + centerGap;
                        case 3:
                          return startX +
                              (navItemWidth * 3) +
                              (sideGap * 2) +
                              centerGap;
                        default:
                          return startX;
                      }
                    }

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          left: (itemLeft(index) - 1).clamp(
                            0.0,
                            constraints.maxWidth - indicatorWidth,
                          ),
                          top: 1,
                          child: IgnorePointer(
                            child: Container(
                              width: indicatorWidth,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.12),
                                    AppColors.primary.withValues(alpha: 0.22),
                                    AppColors.primary.withValues(alpha: 0.12),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            _NavItem(
                              icon: CupertinoIcons.map,
                              label: 'Карта',
                              index: 0,
                              selectedIndex: index,
                              itemWidth: navItemWidth,
                              onTap: onTap,
                            ),
                            SizedBox(width: sideGap),
                            _NavItem(
                              icon: CupertinoIcons.calendar,
                              label: 'Афиша',
                              index: 1,
                              selectedIndex: index,
                              itemWidth: navItemWidth,
                              onTap: onTap,
                            ),
                            SizedBox(width: centerGap),
                            _NavItem(
                              icon: CupertinoIcons.heart,
                              label: 'Матчи',
                              index: 2,
                              selectedIndex: index,
                              itemWidth: navItemWidth,
                              onTap: onTap,
                            ),
                            SizedBox(width: sideGap),
                            _NavItem(
                              icon: CupertinoIcons.person,
                              label: 'Профиль',
                              index: 3,
                              selectedIndex: index,
                              itemWidth: navItemWidth,
                              onTap: onTap,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (!isFullBanActive)
          Positioned(
            left: 0,
            right: 0,
            top: -10,
            child: Center(
              child: GestureDetector(
                onTap: onTapCreate,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isCreateEventBlocked
                        ? AppColors.dark.withValues(alpha: 0.6)
                        : AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.9),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isCreateEventBlocked
                                ? AppColors.dark.withValues(alpha: 0.6)
                                : AppColors.primary)
                            .withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCreateEventBlocked
                        ? CupertinoIcons.lock_fill
                        : CupertinoIcons.add,
                    color: AppColors.accent,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.itemWidth,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final double itemWidth;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = selectedIndex == index;
    return SizedBox(
      width: itemWidth,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.dark.withValues(alpha: 0.58),
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.dark.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

