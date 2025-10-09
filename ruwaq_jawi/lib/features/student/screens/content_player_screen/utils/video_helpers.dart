class VideoHelpers {
  /// Format duration to HH:MM:SS or MM:SS format
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  /// Calculate progress value for slider (0.0 to 1.0)
  static double calculateProgress(Duration position, Duration duration) {
    if (duration.inSeconds <= 0) return 0.0;
    return (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0);
  }

  /// Calculate new position from slider value
  static Duration calculatePositionFromValue(double value, Duration duration) {
    return Duration(seconds: (value * duration.inSeconds).toInt());
  }

  /// Check if position is on left side of screen
  static bool isLeftSide(double dx, double screenWidth) {
    return dx < screenWidth / 2;
  }

  /// Get skip seconds based on left/right side
  static int getSkipSeconds(bool isLeftSide) {
    return isLeftSide ? -10 : 10;
  }

  /// Clamp position to valid range
  static int clampPosition(int currentPosition, int skipSeconds, int videoDuration) {
    return (currentPosition + skipSeconds).clamp(0, videoDuration);
  }
}
