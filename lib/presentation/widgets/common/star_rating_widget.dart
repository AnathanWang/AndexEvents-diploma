import 'package:flutter/material.dart';

class StarRatingWidget extends StatefulWidget {
  const StarRatingWidget({
    super.key,
    required this.rating,
    this.starCount = 5,
    this.starSize = 24.0,
    this.color = const Color(0xFFFACC15), // Yellow
    this.isInteractive = false,
    this.onRatingChanged,
  });

  final double rating;
  final int starCount;
  final double starSize;
  final Color color;
  final bool isInteractive;
  final ValueChanged<int>? onRatingChanged;

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.rating;
  }

  void _handleTap(int index) {
    if (widget.isInteractive && widget.onRatingChanged != null) {
      final newRating = index + 1;
      setState(() {
        _currentRating = newRating.toDouble();
      });
      widget.onRatingChanged!(newRating);
    }
  }

  Widget _buildStar(BuildContext context, int index) {
    IconData iconData;

    if (index >= _currentRating) {
      iconData = Icons.star_border_rounded;
    } else if (index > _currentRating - 1 && index < _currentRating) {
      iconData = Icons.star_half_rounded;
    } else {
      iconData = Icons.star_rounded;
    }

    final Widget star = Icon(
      iconData,
      color: widget.color,
      size: widget.starSize,
    );

    if (widget.isInteractive) {
      return GestureDetector(
        onTap: () => _handleTap(index),
        child: star,
      );
    }

    return star;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        widget.starCount,
        (index) => _buildStar(context, index),
      ),
    );
  }
}
