import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class _NotificationTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// Кастомные уведомления (overlay, top "eye level" + анимация)
class CustomNotification {
  static OverlayEntry? _activeEntry;
  static AnimationController? _activeController;

  static void _dismissActive() {
    _activeController?.stop();
    _activeController?.dispose();
    _activeController = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Более мягкие цвета, но в рамках текущей ColorScheme
    final backgroundColor = isError ? colorScheme.errorContainer : colorScheme.primaryContainer;
    final foregroundColor =
        isError ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;
    final accentColor = isError ? colorScheme.error : colorScheme.primary;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _dismissActive();

    final media = MediaQuery.of(context);
    final topOffset = media.padding.top + 80;

    final controller = AnimationController(
      vsync: _NotificationTickerProvider(),
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _activeController = controller;

    final animation = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    final fade = Tween<double>(begin: 0, end: 1).animate(animation);
    final slide = Tween<Offset>(begin: const Offset(0, -0.22), end: Offset.zero).animate(animation);

    late final OverlayEntry entry;
    void dismiss() async {
      if (_activeEntry != entry) return;
      try {
        await controller.reverse();
      } finally {
        _dismissActive();
      }
    }

    entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          top: topOffset,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slide,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 22,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        isError ? Icons.error_outline : Icons.check_circle_outline,
                        color: accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: dismiss,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.close, color: foregroundColor, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);
    controller.forward();

    Future<void>.delayed(duration, () {
      if (_activeEntry == entry) {
        dismiss();
      }
    });
  }

  /// Успешное уведомление
  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message, isError: false, duration: duration);
  }

  /// Уведомление об ошибке
  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    show(context, message, isError: true, duration: duration);
  }
}
