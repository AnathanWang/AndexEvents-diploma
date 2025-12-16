import 'package:flutter/material.dart';

/// Анимация разворачивания из центра экрана, как на macOS
class ExpandTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const ExpandTransition({
    required this.animation,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Кривая для плавной анимации
        final curve = Curves.easeOutCubic;
        final curvedAnimation = curve.transform(animation.value);

        // Начинаем с масштаба 0.8 для более плавного входа
        final scale = Tween<double>(begin: 0.8, end: 1.0).evaluate(animation);

        // Плавное появление с кривой
        final opacity = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).transform(curvedAnimation);

        // Небольшой вертикальный сдвиг для более естественного появления
        final verticalShift = Tween<double>(
          begin: 20.0,
          end: 0.0,
        ).evaluate(animation);

        return Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(scale, scale)
              ..translate(0.0, verticalShift),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
