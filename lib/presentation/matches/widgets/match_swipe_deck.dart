import 'dart:math' as math;

import '../../widgets/common/app_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/performance_utils.dart';
import '../../models/match_preview.dart';

enum MatchSwipeAction { like, dislike, later, info }

class MatchSwipeDeck extends StatefulWidget {
  const MatchSwipeDeck({
    super.key,
    required this.matches,
    required this.onOpenProfile,
    required this.onSwipe,
    required this.onDeckEmpty,
    this.topPadding,
    this.bottomReserve,
    this.showCommonInterests = false,
  });

  final List<MatchPreview> matches;
  final ValueChanged<MatchPreview> onOpenProfile;
  final void Function(MatchSwipeAction action, MatchPreview match) onSwipe;
  final VoidCallback onDeckEmpty;

  final double? topPadding;
  final double? bottomReserve;
  final bool showCommonInterests;

  @override
  State<MatchSwipeDeck> createState() => _MatchSwipeDeckState();
}

class _MatchSwipeDeckState extends State<MatchSwipeDeck>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Offset> _dragPosition = ValueNotifier(Offset.zero);
  bool _isAnimating = false;
  late final AnimationController _motionController;
  Animation<Offset>? _motionAnimation;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(vsync: this);
    _motionController.addListener(() {
      final animation = _motionAnimation;
      if (animation != null) {
        _dragPosition.value = animation.value;
      }
    });
  }

  @override
  void dispose() {
    _motionController.dispose();
    _dragPosition.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MatchSwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.matches.isEmpty) {
      _resetDrag();
      _isAnimating = false;
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating) return;
    _motionController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    _dragPosition.value = _dragPosition.value + details.delta;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating) return;
    if (widget.matches.isEmpty) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final match = widget.matches.first;
    final drag = _dragPosition.value;

    if (drag.dy < -screenHeight * 0.25) {
      _animateCardOut(
        const Offset(0, -1000),
        () => widget.onSwipe(MatchSwipeAction.later, match),
      );
      return;
    }

    if (drag.dy > screenHeight * 0.18) {
      widget.onOpenProfile(match);
      _animateDragTo(Offset.zero, duration: const Duration(milliseconds: 280));
      return;
    }

    if (drag.dx < -screenWidth * 0.4) {
      _animateCardOut(
        const Offset(-1000, 0),
        () => widget.onSwipe(MatchSwipeAction.dislike, match),
      );
      return;
    }

    if (drag.dx > screenWidth * 0.4) {
      _animateCardOut(
        const Offset(1000, 0),
        () => widget.onSwipe(MatchSwipeAction.like, match),
      );
      return;
    }

    _animateDragTo(Offset.zero, duration: const Duration(milliseconds: 280));
  }

  void _resetDrag() {
    _motionController.stop();
    _dragPosition.value = Offset.zero;
  }

  Future<void> _animateDragTo(
    Offset target, {
    required Duration duration,
    VoidCallback? onComplete,
  }) async {
    _isAnimating = true;
    _motionController.duration = duration;
    _motionAnimation = Tween<Offset>(
      begin: _dragPosition.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _motionController,
      curve: Curves.easeOutCubic,
    ));
    await _motionController.forward(from: 0);
    _isAnimating = false;
    onComplete?.call();
  }

  void _animateCardOut(Offset targetPosition, VoidCallback onComplete) {
    _isAnimating = true;
    _motionController.duration = const Duration(milliseconds: 380);
    _motionAnimation = Tween<Offset>(
      begin: _dragPosition.value,
      end: targetPosition,
    ).animate(CurvedAnimation(
      parent: _motionController,
      curve: Curves.easeInCubic,
    ));
    _motionController.forward(from: 0).then((_) {
      if (!mounted) return;
      _isAnimating = false;
      onComplete();
      _finishCard();
    });
  }

  void _finishCard() {
    if (!mounted) return;
    _resetDrag();
    if (widget.matches.isEmpty) {
      widget.onDeckEmpty();
    }
  }

  double _rotationFor(Offset drag, double screenWidth) {
    if (drag.dx == 0) return 0;
    const maxRotation = 0.1;
    return (drag.dx / screenWidth) * maxRotation;
  }

  Color _indicatorColor(Offset drag) {
    if (drag.dx > 50) return Colors.green;
    if (drag.dx < -50) return Colors.red;
    if (drag.dy < -50) return Colors.blue;
    if (drag.dy > 50) return AppColors.primary;
    return Colors.transparent;
  }

  String _indicatorText(Offset drag) {
    if (drag.dx > 50) return 'НРАВИТСЯ';
    if (drag.dx < -50) return 'НЕ НРАВИТСЯ';
    if (drag.dy < -50) return 'ЕЩЁ ПОДУМАЮ';
    if (drag.dy > 50) return 'ПРОФИЛЬ';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matches.isEmpty) {
      return const SizedBox.shrink();
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomNavReserve = widget.bottomReserve ?? (kBottomNavigationBarHeight + 10);
    final top = widget.topPadding ?? (MediaQuery.of(context).padding.top + 22);
    final screenWidth = MediaQuery.sizeOf(context).width;

    final current = widget.matches.first;

    return Stack(
      children: [
        if (widget.matches.length > 1)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: Transform.scale(
                  scale: 0.965,
                  child: Opacity(
                    opacity: 0.55,
                    child: _MatchCard(
                      match: widget.matches[1],
                      top: top,
                      bottom: bottomInset + bottomNavReserve + 22,
                      showCommonInterests: widget.showCommonInterests,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ListenableBuilder(
          listenable: _dragPosition,
          builder: (context, _) {
            final drag = _dragPosition.value;
            return Positioned.fill(
              child: RepaintBoundary(
                child: Transform.translate(
                  offset: drag,
                  child: Transform.rotate(
                    angle: _rotationFor(drag, screenWidth),
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: _MatchCard(
                        match: current,
                        top: top,
                        bottom: bottomInset + bottomNavReserve + 22,
                        showCommonInterests: widget.showCommonInterests,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        ListenableBuilder(
          listenable: _dragPosition,
          builder: (context, _) {
            final drag = _dragPosition.value;
            final distance = drag.distance;
            if (distance <= 30) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: IgnorePointer(
                child: _SwipeIndicator(
                  color: _indicatorColor(drag),
                  text: _indicatorText(drag),
                  opacity: math.min(distance / 100, 1.0),
                  dragPosition: drag,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.top,
    required this.bottom,
    this.showCommonInterests = false,
  });

  final MatchPreview match;
  final double top;
  final double bottom;
  final bool showCommonInterests;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: top, bottom: bottom, left: 12, right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    AppColors.primary.withValues(alpha: 0.92),
                    const Color(0xFF2E8BFF).withValues(alpha: 0.88),
                    AppColors.accent.withValues(alpha: 0.82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            if (match.photoUrl != null)
              AppNetworkImage(
                imageUrl: match.photoUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: imageMemCachePx(320, context),
                memCacheHeight: imageMemCachePx(420, context),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.28),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 22,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                match.name,
                                style: TextStyle(
                                  color: AppColors.dark.withValues(alpha: 0.88),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (match.age != null)
                              Text(
                                '${match.age}',
                                style: TextStyle(
                                  color: AppColors.dark.withValues(alpha: 0.88),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        if (match.bio != null && match.bio!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            match.bio!,
                            style: TextStyle(
                              color: AppColors.dark.withValues(alpha: 0.68),
                              fontSize: 13,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (showCommonInterests && match.commonInterests.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: match.commonInterests
                                .take(3)
                                .map(
                                  (interest) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.72),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Text(
                                      interest,
                                      style: TextStyle(
                                        color: AppColors.dark.withValues(alpha: 0.70),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeIndicator extends StatelessWidget {
  const _SwipeIndicator({
    required this.color,
    required this.text,
    required this.opacity,
    required this.dragPosition,
  });

  final Color color;
  final String text;
  final double opacity;
  final Offset dragPosition;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final IconData icon;
    final String caption;
    if (dragPosition.dx > 50) {
      icon = Icons.favorite_rounded;
      caption = 'Отпустите, чтобы поставить лайк';
    } else if (dragPosition.dx < -50) {
      icon = Icons.block_rounded;
      caption = 'Отпустите, чтобы пропустить';
    } else if (dragPosition.dy < -50) {
      icon = Icons.bookmark_add_rounded;
      caption = 'Отпустите, чтобы вернуться позже';
    } else if (dragPosition.dy > 50) {
      icon = Icons.person_rounded;
      caption = 'Отпустите, чтобы открыть профиль';
    } else {
      return const SizedBox.shrink();
    }

    final panelColor = Color.lerp(
      Colors.white.withValues(alpha: 0.78),
      color.withValues(alpha: 0.20),
      0.55,
    );

    return Container(
      color: color.withValues(alpha: 0.05 * opacity),
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: panelColor ?? Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.45),
                  width: 1.4,
                ),
              ),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.14),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          text,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          caption,
                          style: const TextStyle(
                            color: Color(0xFF4E568A),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}
