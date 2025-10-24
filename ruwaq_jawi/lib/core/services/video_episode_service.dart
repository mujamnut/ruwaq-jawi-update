import '../models/video_episode.dart';
import 'supabase_service.dart';

class VideoEpisodeService {
  static const String _tableName = 'video_episodes';

  // Get all episodes for a video kitab
  static Future<List<VideoEpisode>> getEpisodesForVideoKitab(
    String videoKitabId, {
    bool? isActive,
    String orderBy = 'part_number',
    bool ascending = true,
  }) async {
    try {
      dynamic query = SupabaseService.from(
        _tableName,
      ).select().eq('video_kitab_id', videoKitabId);

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final response = await query.order(orderBy, ascending: ascending);

      return List<Map<String, dynamic>>.from(
        response,
      ).map((json) => VideoEpisode.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch episodes: $e');
    }
  }

  // Get single episode by ID
  static Future<VideoEpisode?> getEpisodeById(String id) async {
    try {
      final response = await SupabaseService.from(
        _tableName,
      ).select().eq('id', id).maybeSingle();

      if (response == null) return null;
      return VideoEpisode.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch episode: $e');
    }
  }

  // Create new episode
  static Future<VideoEpisode> createEpisode(
    Map<String, dynamic> episodeData,
  ) async {
    try {
      // Validate required fields
      if (episodeData['video_kitab_id'] == null ||
          episodeData['video_kitab_id'].toString().isEmpty) {
        throw Exception('Video Kitab ID is required');
      }
      if (episodeData['title'] == null ||
          episodeData['title'].toString().isEmpty) {
        throw Exception('Episode title is required');
      }
      if (episodeData['youtube_video_id'] == null ||
          episodeData['youtube_video_id'].toString().isEmpty) {
        throw Exception('YouTube Video ID is required');
      }
      if (episodeData['part_number'] == null) {
        throw Exception('Part number is required');
      }

      // Check if part number already exists for this video kitab
      final existingEpisode = await SupabaseService.from(_tableName)
          .select('id')
          .eq('video_kitab_id', episodeData['video_kitab_id'])
          .eq('part_number', episodeData['part_number'])
          .maybeSingle();

      if (existingEpisode != null) {
        throw Exception(
          'Part number ${episodeData['part_number']} already exists for this video kitab',
        );
      }

      final data = {
        ...episodeData,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_active': episodeData['is_active'] ?? true,
        'is_preview': episodeData['is_preview'] ?? false,
        'duration_minutes': episodeData['duration_minutes'] ?? 0,
      };

      final response = await SupabaseService.from(
        _tableName,
      ).insert(data).select().single();

      // Note: Video kitab stats are automatically updated by database trigger
      // No need to manually call _updateVideoKitabStats

      return VideoEpisode.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create episode: $e');
    }
  }

  // Update episode
  static Future<VideoEpisode> updateEpisode(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Get existing episode to validate video kitab ID
      final existing = await getEpisodeById(id);
      if (existing == null) {
        throw Exception('Episode not found');
      }

      // If part number is being changed, validate uniqueness
      if (updates.containsKey('part_number') &&
          updates['part_number'] != existing.partNumber) {
        final conflictingEpisode = await SupabaseService.from(_tableName)
            .select('id')
            .eq('video_kitab_id', existing.videoKitabId)
            .eq('part_number', updates['part_number'])
            .neq('id', id)
            .maybeSingle();

        if (conflictingEpisode != null) {
          throw Exception(
            'Part number ${updates['part_number']} already exists for this video kitab',
          );
        }
      }

      final data = {...updates, 'updated_at': DateTime.now().toIso8601String()};

      final response = await SupabaseService.from(
        _tableName,
      ).update(data).eq('id', id).select().single();

      // Update video kitab stats
      await _updateVideoKitabStats(existing.videoKitabId);

      return VideoEpisode.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update episode: $e');
    }
  }

  // Delete episode
  static Future<void> deleteEpisode(String id) async {
    try {
      // Get episode to know which video kitab to update stats for
      final episode = await getEpisodeById(id);
      if (episode == null) {
        throw Exception('Episode not found');
      }

      await SupabaseService.from(_tableName).delete().eq('id', id);

      // Update video kitab stats
      await _updateVideoKitabStats(episode.videoKitabId);
    } catch (e) {
      throw Exception('Failed to delete episode: $e');
    }
  }

  // Toggle episode active status
  static Future<VideoEpisode> toggleEpisodeStatus(
    String id,
    bool isActive,
  ) async {
    try {
      return await updateEpisode(id, {'is_active': isActive});
    } catch (e) {
      throw Exception('Failed to toggle episode status: $e');
    }
  }

  // Get next available part number for a video kitab
  static Future<int> getNextPartNumber(String videoKitabId) async {
    try {
      final response = await SupabaseService.from(_tableName)
          .select('part_number')
          .eq('video_kitab_id', videoKitabId)
          .order('part_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return 1; // First episode
      }

      return (response['part_number'] as int? ?? 0) + 1;
    } catch (e) {
      throw Exception('Failed to get next part number: $e');
    }
  }

  // YouTube video ID validation and extraction
  static String? extractYouTubeVideoId(String input) {
    final trimmed = input.trim();

    // Check if already a video ID (11 characters, alphanumeric + - and _)
    final idRegex = RegExp(r'^[0-9A-Za-z_-]{11}$');
    if (idRegex.hasMatch(trimmed)) return trimmed;

    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return null;
    }

    if (uri.host.isEmpty) return null;

    final host = uri.host.replaceFirst('www.', '');
    final segs = uri.pathSegments;

    // youtu.be/VIDEO_ID format
    if (host == 'youtu.be') {
      return segs.isNotEmpty ? segs.first : null;
    }

    // youtube.com formats
    if (host.endsWith('youtube.com') || host.endsWith('youtube-nocookie.com')) {
      // Watch URL: /watch?v=VIDEO_ID
      if (uri.path == '/watch' && uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }

      // Embed/shorts/live: /embed/VIDEO_ID, /shorts/VIDEO_ID, /live/VIDEO_ID
      if (segs.length >= 2 &&
          (segs[0] == 'embed' ||
              segs[0] == 'shorts' ||
              segs[0] == 'live' ||
              segs[0] == 'v')) {
        return segs[1];
      }
    }

    return null;
  }

  // Validate YouTube video ID
  static bool isValidYouTubeVideoId(String videoId) {
    final idRegex = RegExp(r'^[0-9A-Za-z_-]{11}$');
    return idRegex.hasMatch(videoId);
  }

  // Generate YouTube URLs
  static String getYouTubeWatchUrl(String videoId) {
    return 'https://www.youtube.com/watch?v=$videoId';
  }

  static String getYouTubeEmbedUrl(String videoId) {
    return 'https://www.youtube.com/embed/$videoId';
  }

  static String getYouTubeThumbnailUrl(
    String videoId, {
    String quality = 'hqdefault',
  }) {
    return 'https://img.youtube.com/vi/$videoId/$quality.jpg';
  }

  // Private helper to update video kitab statistics
  static Future<void> _updateVideoKitabStats(String videoKitabId) async {
    try {
      // Get active episodes for this video kitab
      final episodes = await getEpisodesForVideoKitab(
        videoKitabId,
        isActive: true,
        orderBy: 'part_number',
        ascending: true,
      );

      final totalVideos = episodes.length;
      final totalDuration = episodes.fold<int>(
        0,
        (sum, episode) => sum + episode.durationMinutes,
      );

      // Update video kitab
      await SupabaseService.from('video_kitab')
          .update({
            'total_videos': totalVideos,
            'total_duration_minutes': totalDuration,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', videoKitabId);
    } catch (e) {
      // Don't throw error for stats update failure
      // Debug logging removed
    }
  }
}
