import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';

/// Interactive star rating input widget
/// Allows user to select rating from 1-5 stars
class RatingInputWidget extends StatefulWidget {
  final int initialRating; // 0 to 5 (0 = no rating)
  final ValueChanged<int> onRatingChanged;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final Color hoverColor;

  const RatingInputWidget({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.size = 40,
    this.activeColor = Colors.amber,
    this.inactiveColor = const Color(0xFFE0E0E0),
    this.hoverColor = const Color(0xFFFFC107),
  });

  @override
  State<RatingInputWidget> createState() => _RatingInputWidgetState();
}

class _RatingInputWidgetState extends State<RatingInputWidget> {
  late int _currentRating;
  int _hoveredRating = 0;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  void _handleRatingTap(int rating) {
    setState(() {
      _currentRating = rating;
    });
    widget.onRatingChanged(rating);

    // Haptic feedback
    HapticFeedback.selectionClick();
  }

  void _handleHover(int rating, bool isHovering) {
    setState(() {
      _hoveredRating = isHovering ? rating : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isActive = starValue <= (_hoveredRating > 0 ? _hoveredRating : _currentRating);

        return MouseRegion(
          onEnter: (_) => _handleHover(starValue, true),
          onExit: (_) => _handleHover(starValue, false),
          child: GestureDetector(
            onTap: () => _handleRatingTap(starValue),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(4),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedStar,
                color: isActive
                    ? (_hoveredRating > 0 ? widget.hoverColor : widget.activeColor)
                    : widget.inactiveColor,
                size: widget.size,
              ),
            ),
          ),
        );
      }),
    );
  }
}
