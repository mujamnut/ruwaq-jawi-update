import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Display-only star rating widget (read-only)
/// Shows rating as filled/half/empty stars
class RatingStarsWidget extends StatelessWidget {
  final double rating; // 0.0 to 5.0
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final bool showRatingValue;

  const RatingStarsWidget({
    super.key,
    required this.rating,
    this.size = 16,
    this.activeColor = Colors.amber,
    this.inactiveColor = const Color(0xFFE0E0E0),
    this.showRatingValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final difference = rating - index;

          Widget star;
          if (difference >= 1) {
            // Full star
            star = HugeIcon(
              icon: HugeIcons.strokeRoundedStar,
              color: activeColor,
              size: size,
            );
          } else if (difference > 0) {
            // Half star (use stack to show half-filled)
            star = Stack(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedStar,
                  color: inactiveColor,
                  size: size,
                ),
                ClipRect(
                  clipper: _HalfClipper(),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedStar,
                    color: activeColor,
                    size: size,
                  ),
                ),
              ],
            );
          } else {
            // Empty star
            star = HugeIcon(
              icon: HugeIcons.strokeRoundedStar,
              color: inactiveColor,
              size: size,
            );
          }

          return Padding(
            padding: EdgeInsets.only(right: index < 4 ? 2 : 0),
            child: star,
          );
        }),
        if (showRatingValue) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.875,
              fontWeight: FontWeight.w600,
              color: activeColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// Clipper to show half star
class _HalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width / 2, size.height);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}
