import 'package:flutter/material.dart';

/// Manager for handling data operations in home screen
class HomeDataManager {
  final VoidCallback onStateChanged;

  HomeDataManager({required this.onStateChanged});

  /// Get initials from user name
  String getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return 'U';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  /// Generate gradient colors based on first letter for premium users
  List<Color> getGradientFromLetter(String letter) {
    final colors = [
      [const Color(0xFFE91E63), const Color(0xFFAD1457)], // Pink
      [const Color(0xFF9C27B0), const Color(0xFF6A1B9A)], // Purple
      [const Color(0xFF673AB7), const Color(0xFF4527A0)], // Deep Purple
      [const Color(0xFF3F51B5), const Color(0xFF283593)], // Indigo
      [const Color(0xFF2196F3), const Color(0xFF1565C0)], // Blue
      [const Color(0xFF03A9F4), const Color(0xFF0277BD)], // Light Blue
      [const Color(0xFF00BCD4), const Color(0xFF00838F)], // Cyan
      [const Color(0xFF009688), const Color(0xFF00695C)], // Teal
      [const Color(0xFF4CAF50), const Color(0xFF2E7D32)], // Green
      [const Color(0xFF8BC34A), const Color(0xFF558B2F)], // Light Green
      [const Color(0xFFCDDC39), const Color(0xFF9E9D24)], // Lime
      [const Color(0xFFFFEB3B), const Color(0xFFF9A825)], // Yellow
      [const Color(0xFFFFC107), const Color(0xFFFF8F00)], // Amber
      [const Color(0xFFFF9800), const Color(0xFFEF6C00)], // Orange
      [const Color(0xFFFF5722), const Color(0xFFD84315)], // Deep Orange
      [const Color(0xFF795548), const Color(0xFF5D4037)], // Brown
    ];

    final index = letter.codeUnitAt(0) % colors.length;
    return colors[index];
  }
}
