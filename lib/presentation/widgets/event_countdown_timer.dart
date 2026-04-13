import 'dart:async';
import 'package:flutter/material.dart';

class EventCountdownTimer extends StatefulWidget {
  final DateTime expirationTime;
  final VoidCallback? onExpired;
  final TextStyle? textStyle;
  final bool isMinimal;

  const EventCountdownTimer({
    super.key,
    required this.expirationTime,
    this.onExpired,
    this.textStyle,
    this.isMinimal = false,
  });

  @override
  State<EventCountdownTimer> createState() => _EventCountdownTimerState();
}

class _EventCountdownTimerState extends State<EventCountdownTimer> {
  Timer? _timer;
  late Duration _timeLeft;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    if (!_expired) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _calculateTimeLeft();
      });
    }
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    if (now.isAfter(widget.expirationTime)) {
      if (!_expired) {
        setState(() {
          _expired = true;
          _timeLeft = Duration.zero;
        });
        _timer?.cancel();
        if (widget.onExpired != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onExpired!();
          });
        }
      }
    } else {
      setState(() {
        _timeLeft = widget.expirationTime.difference(now);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String days = duration.inDays > 0 ? '${duration.inDays}д ' : '';
    final String hours = twoDigits(duration.inHours.remainder(24));
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$days$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_expired) {
      if (widget.isMinimal) {
        return Text(
          'Завершено',
          style: (widget.textStyle ?? const TextStyle()).copyWith(
            color: const Color(0xFFF75555),
            fontWeight: FontWeight.bold,
            fontSize: widget.textStyle?.fontSize ?? 10,
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFDBDB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFFF75555)),
            const SizedBox(width: 4),
            Text(
              'Завершено',
              style: (widget.textStyle ?? const TextStyle()).copyWith(
                color: const Color(0xFFF75555),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }
    
    if (widget.isMinimal) {
      return Text(
        _formatDuration(_timeLeft),
        style: (widget.textStyle ?? const TextStyle()).copyWith(
          color: const Color(0xFF5E60CE),
          fontWeight: FontWeight.bold,
          fontSize: widget.textStyle?.fontSize ?? 10,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: widget.textStyle?.color ?? const Color(0xFF5E60CE)),
          const SizedBox(width: 4),
          Text(
            _formatDuration(_timeLeft),
            style: (widget.textStyle ?? const TextStyle()).copyWith(
              color: const Color(0xFF5E60CE),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
