import 'package:flutter/material.dart';

class EbookHelpers {
  /// Calculate estimated reading time based on page count
  /// Assumes 2 minutes per page average reading speed
  static String getEstimatedReadingTime(int pages) {
    final totalMinutes = pages * 2;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return '${hours}j ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get reading level (currently hardcoded, can be enhanced)
  static String getReadingLevel() {
    return 'Pemula';
  }
}

/// Custom painter for decorative pattern background
class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;

    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}