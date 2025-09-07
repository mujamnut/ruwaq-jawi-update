import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reading_progress.dart';
import 'supabase_service.dart';

class ProgressTrackingService {
  static const String _localProgressKey = 'local_progress';
  static const Duration _syncInterval = Duration(seconds: 30);

  Timer? _syncTimer;
  Map<String, ReadingProgress> _localProgress = {};

  static final ProgressTrackingService _instance =
      ProgressTrackingService._internal();
  factory ProgressTrackingService() => _instance;
  ProgressTrackingService._internal();

  /// Initialize the service
  Future<void> initialize() async {
    await _loadLocalProgress();
    _startSyncTimer();
  }

  /// Start periodic sync timer
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => syncWithServer());
  }

  /// Stop sync timer (useful when user logs out)
  void stopSyncTimer() {
    _syncTimer?.cancel();
  }

  /// Load progress from local storage
  Future<void> _loadLocalProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString(_localProgressKey);

      if (progressJson != null) {
        final Map<String, dynamic> progressMap = json.decode(progressJson);
        _localProgress = progressMap.map(
          (key, value) => MapEntry(key, ReadingProgress.fromJson(value)),
        );
      }
    } catch (e) {
      print('Error loading local progress: $e');
      _localProgress = {};
    }
  }

  /// Save progress to local storage
  Future<void> _saveLocalProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressJson = json.encode(
        _localProgress.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString(_localProgressKey, progressJson);
    } catch (e) {
      print('Error saving local progress: $e');
    }
  }

  /// Update progress locally
  Future<void> updateProgress({
    required String userId,
    required String kitabId,
    int? videoProgressSeconds,
    int? pdfPage,
  }) async {
    final existingProgress = _localProgress[kitabId];

    if (existingProgress != null) {
      // Update existing progress
      _localProgress[kitabId] = existingProgress.copyWith(
        videoProgress: videoProgressSeconds ?? existingProgress.videoProgress,
        pdfPage: pdfPage ?? existingProgress.pdfPage,
        lastAccessed: DateTime.now(),
      );
    } else {
      // Create new progress entry
      _localProgress[kitabId] = ReadingProgress(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        kitabId: kitabId,
        videoProgress: videoProgressSeconds ?? 0,
        pdfPage: pdfPage ?? 1,
        lastAccessed: DateTime.now(),
        videoDuration: 0,
        completionPercentage: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    await _saveLocalProgress();
  }

  /// Get progress for specific kitab
  ReadingProgress? getProgress(String kitabId) {
    return _localProgress[kitabId];
  }

  /// Get all local progress
  Map<String, ReadingProgress> getAllProgress() {
    return Map.from(_localProgress);
  }

  /// Sync with server (upload local changes and download remote changes)
  Future<void> syncWithServer() async {
    if (!SupabaseService.isAuthenticated) {
      return;
    }

    try {
      final userId = SupabaseService.currentUser!.id;

      // Upload local changes to server
      await _uploadLocalChanges(userId);

      // Download recent changes from server
      await _downloadRecentChanges(userId);
    } catch (e) {
      print('Sync error: $e');
    }
  }

  /// Upload local changes to server
  Future<void> _uploadLocalChanges(String userId) async {
    for (final progress in _localProgress.values) {
      if (progress.userId == userId) {
        try {
          // Check if progress exists on server
          final existingResponse =
              await SupabaseService.from('reading_progress')
                  .select()
                  .eq('user_id', userId)
                  .eq('kitab_id', progress.kitabId)
                  .maybeSingle();

          if (existingResponse != null) {
            // Update existing record
            await SupabaseService.from('reading_progress')
                .update({
                  'video_progress': progress.videoProgress,
                  'pdf_page': progress.pdfPage,
                  'last_accessed': progress.lastAccessed.toIso8601String(),
                })
                .eq('user_id', userId)
                .eq('kitab_id', progress.kitabId);
          } else {
            // Insert new record
            await SupabaseService.from('reading_progress').insert({
              'user_id': userId,
              'kitab_id': progress.kitabId,
              'video_progress': progress.videoProgress,
              'pdf_page': progress.pdfPage,
              'last_accessed': progress.lastAccessed.toIso8601String(),
            });
          }
        } catch (e) {
          print('Error syncing progress for kitab ${progress.kitabId}: $e');
        }
      }
    }
  }

  /// Download recent changes from server
  Future<void> _downloadRecentChanges(String userId) async {
    try {
      final response = await SupabaseService.from(
        'reading_progress',
      ).select().eq('user_id', userId);

      for (final json in response as List) {
        final serverProgress = ReadingProgress.fromJson(json);
        final localProgress = _localProgress[serverProgress.kitabId];

        // Only update if server data is more recent
        if (localProgress == null ||
            serverProgress.lastAccessed.isAfter(localProgress.lastAccessed)) {
          _localProgress[serverProgress.kitabId] = serverProgress;
        }
      }

      await _saveLocalProgress();
    } catch (e) {
      print('Error downloading server progress: $e');
    }
  }

  /// Clear all progress data (useful for logout)
  Future<void> clearAllProgress() async {
    _localProgress.clear();
    await _saveLocalProgress();
    stopSyncTimer();
  }

  /// Force sync now
  Future<void> forcSync() async {
    await syncWithServer();
  }

  /// Get reading statistics
  Map<String, dynamic> getReadingStatistics() {
    final stats = <String, dynamic>{
      'totalKitabRead': _localProgress.length,
      'totalVideoTime': 0,
      'totalPagesRead': 0,
      'recentActivity': <String, dynamic>{},
    };

    int totalVideoSeconds = 0;
    int totalPages = 0;
    DateTime? lastActivity;

    for (final progress in _localProgress.values) {
      totalVideoSeconds += progress.videoProgress;
      totalPages += progress.pdfPage;

      if (lastActivity == null || progress.lastAccessed.isAfter(lastActivity)) {
        lastActivity = progress.lastAccessed;
      }
    }

    stats['totalVideoTime'] = totalVideoSeconds;
    stats['totalPagesRead'] = totalPages;
    stats['lastActivity'] = lastActivity?.toIso8601String();

    return stats;
  }

  /// Get completion percentage for a kitab
  double getCompletionPercentage(
    String kitabId, {
    int? totalVideoSeconds,
    int? totalPages,
  }) {
    final progress = _localProgress[kitabId];
    if (progress == null) return 0.0;

    double videoCompletion = 0.0;
    double pdfCompletion = 0.0;

    if (totalVideoSeconds != null && totalVideoSeconds > 0) {
      videoCompletion = progress.videoProgress / totalVideoSeconds;
      videoCompletion = videoCompletion.clamp(0.0, 1.0);
    }

    if (totalPages != null && totalPages > 0) {
      pdfCompletion = progress.pdfPage / totalPages;
      pdfCompletion = pdfCompletion.clamp(0.0, 1.0);
    }

    // Return average completion if both exist, otherwise return whichever exists
    if (totalVideoSeconds != null && totalPages != null) {
      return (videoCompletion + pdfCompletion) / 2;
    } else if (totalVideoSeconds != null) {
      return videoCompletion;
    } else if (totalPages != null) {
      return pdfCompletion;
    }

    return 0.0;
  }
}
