import 'package:hive_flutter/hive_flutter.dart';

class VideoProgressService {
  static const String _boxName = 'video_progress';
  static const String _videoProgressKey = 'video_positions';

  static Box<dynamic>? _box;

  /// Initialize the video progress service
  static Future<void> initialize() async {
    try {
      _box = await Hive.openBox(_boxName);
    } catch (e) {
      print('Error initializing VideoProgressService: $e');
    }
  }

  /// Get the progress box
  static Box<dynamic> get _progressBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception(
        'VideoProgressService not initialized. Call initialize() first.',
      );
    }
    return _box!;
  }

  /// Save video progress position
  static Future<bool> saveVideoPosition(
    String videoId,
    int positionSeconds,
  ) async {
    try {
      final allProgress =
          _progressBox.get(_videoProgressKey, defaultValue: <String, dynamic>{})
              as Map;
      final updatedProgress = Map<String, dynamic>.from(allProgress);

      updatedProgress[videoId] = {
        'position_seconds': positionSeconds,
        'last_watched': DateTime.now().toIso8601String(),
      };

      await _progressBox.put(_videoProgressKey, updatedProgress);
      return true;
    } catch (e) {
      print('Error saving video position: $e');
      return false;
    }
  }

  /// Get saved video position
  static int getVideoPosition(String videoId) {
    try {
      final allProgress =
          _progressBox.get(_videoProgressKey, defaultValue: <String, dynamic>{})
              as Map;
      final videoProgress = allProgress[videoId] as Map<String, dynamic>?;

      if (videoProgress != null && videoProgress['position_seconds'] != null) {
        return videoProgress['position_seconds'] as int;
      }

      return 0; // Start from beginning if no progress saved
    } catch (e) {
      print('Error getting video position: $e');
      return 0;
    }
  }

  /// Get last watched timestamp for a video
  static DateTime? getLastWatchedTime(String videoId) {
    try {
      final allProgress =
          _progressBox.get(_videoProgressKey, defaultValue: <String, dynamic>{})
              as Map;
      final videoProgress = allProgress[videoId] as Map<String, dynamic>?;

      if (videoProgress != null && videoProgress['last_watched'] != null) {
        return DateTime.parse(videoProgress['last_watched'] as String);
      }

      return null;
    } catch (e) {
      print('Error getting last watched time: $e');
      return null;
    }
  }

  /// Check if video has been watched (has any progress)
  static bool hasWatchProgress(String videoId) {
    try {
      final position = getVideoPosition(videoId);
      return position > 10; // Consider watched if more than 10 seconds
    } catch (e) {
      print('Error checking watch progress: $e');
      return false;
    }
  }

  /// Get all videos with progress (for recently watched list)
  static Map<String, Map<String, dynamic>> getAllVideoProgress() {
    try {
      final allProgress =
          _progressBox.get(_videoProgressKey, defaultValue: <String, dynamic>{})
              as Map;
      return Map<String, Map<String, dynamic>>.from(allProgress);
    } catch (e) {
      print('Error getting all video progress: $e');
      return {};
    }
  }

  /// Get recently watched videos (sorted by last watched time)
  static List<String> getRecentlyWatchedVideoIds({int limit = 10}) {
    try {
      final allProgress = getAllVideoProgress();

      final sortedEntries = allProgress.entries.toList();
      sortedEntries.sort((a, b) {
        final timeA = DateTime.tryParse(a.value['last_watched'] ?? '');
        final timeB = DateTime.tryParse(b.value['last_watched'] ?? '');

        if (timeA == null || timeB == null) return 0;
        return timeB.compareTo(timeA); // Most recent first
      });

      return sortedEntries.take(limit).map((entry) => entry.key).toList();
    } catch (e) {
      print('Error getting recently watched videos: $e');
      return [];
    }
  }

  /// Remove progress for a specific video
  static Future<bool> removeVideoProgress(String videoId) async {
    try {
      final allProgress =
          _progressBox.get(_videoProgressKey, defaultValue: <String, dynamic>{})
              as Map;
      final updatedProgress = Map<String, dynamic>.from(allProgress);

      updatedProgress.remove(videoId);
      await _progressBox.put(_videoProgressKey, updatedProgress);

      return true;
    } catch (e) {
      print('Error removing video progress: $e');
      return false;
    }
  }

  /// Clear all video progress (for reset/cleanup)
  static Future<void> clearAllProgress() async {
    try {
      await _progressBox.delete(_videoProgressKey);
    } catch (e) {
      print('Error clearing all video progress: $e');
    }
  }

  /// Format seconds to readable time string (e.g., "5:30", "1:23:45")
  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  /// Calculate progress percentage
  static double getProgressPercentage(
    String videoId,
    int totalDurationSeconds,
  ) {
    if (totalDurationSeconds <= 0) return 0.0;

    final currentPosition = getVideoPosition(videoId);
    return (currentPosition / totalDurationSeconds * 100).clamp(0.0, 100.0);
  }

  /// Close the progress box
  static Future<void> close() async {
    try {
      await _box?.close();
      _box = null;
    } catch (e) {
      print('Error closing VideoProgressService: $e');
    }
  }
}
