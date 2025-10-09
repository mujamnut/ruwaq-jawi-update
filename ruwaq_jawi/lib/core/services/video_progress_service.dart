import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class VideoProgressService {
  static const String _boxName = 'video_progress';
  static const String _videoProgressKey = 'video_positions';

  static Box<dynamic>? _box;
  static bool _isInitialized = false;

  /// Initialize the video progress service
  static Future<void> initialize() async {
    if (_isInitialized && _box != null && _box!.isOpen) {
      return; // Already initialized
    }

    try {
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing VideoProgressService: $e');
      _isInitialized = false;
      // Don't throw - allow app to continue without video progress tracking
    }
  }

  /// Get the progress box with safe initialization
  static Box<dynamic>? get _progressBox {
    if (_box == null || !_box!.isOpen) {
      debugPrint(
        'VideoProgressService not initialized. Attempting to initialize...',
      );
      // Try to initialize on demand
      initialize().then((_) {});
      return null;
    }
    return _box;
  }

  /// Save video progress position
  static Future<bool> saveVideoPosition(
    String videoId,
    int positionSeconds,
  ) async {
    try {
      final box = _progressBox;
      if (box == null) {
        debugPrint('Cannot save video position: box not initialized');
        return false;
      }

      final allProgress =
          box.get(_videoProgressKey, defaultValue: <String, dynamic>{})
              as Map? ??
          <String, dynamic>{};
      final updatedProgress = Map<String, dynamic>.from(allProgress);

      updatedProgress[videoId] = {
        'position_seconds': positionSeconds,
        'last_watched': DateTime.now().toIso8601String(),
      };

      await box.put(_videoProgressKey, updatedProgress);
      return true;
    } catch (e) {
      debugPrint('Error saving video position: $e');
      return false;
    }
  }

  /// Get saved video position
  static int getVideoPosition(String videoId) {
    try {
      final box = _progressBox;
      if (box == null) {
        debugPrint('Cannot get video position: box not initialized');
        return 0;
      }

      final allProgress =
          box.get(_videoProgressKey, defaultValue: <String, dynamic>{})
              as Map? ??
          <String, dynamic>{};
      final videoProgress = allProgress[videoId] as Map<String, dynamic>?;

      if (videoProgress != null && videoProgress['position_seconds'] != null) {
        final position = videoProgress['position_seconds'];
        if (position is int) {
          return position;
        } else if (position is double) {
          return position.toInt();
        }
      }

      return 0; // Start from beginning if no progress saved
    } catch (e) {
      debugPrint('Error getting video position for $videoId: $e');
      return 0;
    }
  }

  /// Get last watched timestamp for a video
  static DateTime? getLastWatchedTime(String videoId) {
    try {
      final box = _progressBox;
      if (box == null) {
        debugPrint('Cannot get last watched time: box not initialized');
        return null;
      }

      final allProgress =
          box.get(_videoProgressKey, defaultValue: <String, dynamic>{}) as Map;
      final videoProgress = allProgress[videoId] as Map<String, dynamic>?;

      if (videoProgress != null && videoProgress['last_watched'] != null) {
        return DateTime.parse(videoProgress['last_watched'] as String);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting last watched time: $e');
      return null;
    }
  }

  /// Check if video has been watched (has any progress)
  static bool hasWatchProgress(String videoId) {
    try {
      final position = getVideoPosition(videoId);
      return position > 10; // Consider watched if more than 10 seconds
    } catch (e) {
      debugPrint('Error checking watch progress: $e');
      return false;
    }
  }

  /// Get all videos with progress (for recently watched list)
  static Map<String, Map<String, dynamic>> getAllVideoProgress() {
    try {
      final box = _progressBox;
      if (box == null) {
        debugPrint('Cannot get all video progress: box not initialized');
        return {};
      }

      final allProgress =
          box.get(_videoProgressKey, defaultValue: <String, dynamic>{})
              as Map? ??
          <String, dynamic>{};
      return Map<String, Map<String, dynamic>>.from(allProgress);
    } catch (e) {
      debugPrint('Error getting all video progress: $e');
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
      debugPrint('Error getting recently watched videos: $e');
      return [];
    }
  }

  /// Remove progress for a specific video
  static Future<bool> removeVideoProgress(String videoId) async {
    try {
      final box = _progressBox;
      if (box == null) {
        debugPrint('Cannot remove video progress: box not initialized');
        return false;
      }

      final allProgress =
          box.get(_videoProgressKey, defaultValue: <String, dynamic>{}) as Map;
      final updatedProgress = Map<String, dynamic>.from(allProgress);

      updatedProgress.remove(videoId);
      await box.put(_videoProgressKey, updatedProgress);

      return true;
    } catch (e) {
      debugPrint('Error removing video progress: $e');
      return false;
    }
  }

  /// Clear all video progress (for reset/cleanup)
  static Future<void> clearAllProgress() async {
    try {
      final box = _progressBox;
      if (box != null) {
        await box.delete(_videoProgressKey);
      }
    } catch (e) {
      debugPrint('Error clearing all video progress: $e');
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
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error closing VideoProgressService: $e');
    }
  }
}
