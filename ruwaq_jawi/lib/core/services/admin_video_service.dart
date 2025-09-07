import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminVideoService {
  final SupabaseClient _supabase;

  AdminVideoService(this._supabase);

  // =====================================================
  // VIDEO EPISODES MANAGEMENT
  // =====================================================

  /// Dapatkan semua episodes untuk kitab
  Future<List<Map<String, dynamic>>> getKitabEpisodes({
    required String kitabId,
    bool? isActive,
    bool? isPreview,
    String orderBy = 'part_number',
    bool ascending = true,
  }) async {
    try {
      var query = _supabase
          .from('kitab_videos')
          .select()
          .eq('kitab_id', kitabId);

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      if (isPreview != null) {
        query = query.eq('is_preview', isPreview);
      }

      // Apply ordering dan execute query
      final response = ascending 
          ? await query.order(orderBy)
          : await query.order(orderBy, ascending: false);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Ralat mendapatkan episodes: $e');
    }
  }

  /// Tambah episode baru untuk kitab
  Future<Map<String, dynamic>> addEpisode({
    required String kitabId,
    required String title,
    required String youtubeVideoId,
    required int partNumber,
    String? description,
    String? youtubeVideoUrl,
    String? thumbnailUrl,
    int? durationMinutes,
    int? durationSeconds,
    bool isActive = true,
    bool isPreview = false,
    int? sortOrder,
  }) async {
    try {
      // Validasi kitab exists
      final kitabExists = await _supabase
          .from('kitab')
          .select('id, has_multiple_videos')
          .eq('id', kitabId)
          .eq('is_active', true)
          .maybeSingle();

      if (kitabExists == null) {
        throw Exception('Kitab tidak dijumpai atau tidak aktif');
      }

      // Validasi part_number unik dalam kitab ini
      final existingPart = await _supabase
          .from('kitab_videos')
          .select('id')
          .eq('kitab_id', kitabId)
          .eq('part_number', partNumber)
          .maybeSingle();

      if (existingPart != null) {
        throw Exception('Nombor episode sudah wujud untuk kitab ini');
      }

      // Validasi YouTube video ID
      if (youtubeVideoId.isEmpty) {
        throw Exception('ID video YouTube diperlukan');
      }

      // Extract video info dari YouTube jika perlu
      Map<String, dynamic> videoInfo = {};
      try {
        videoInfo = await _getYouTubeVideoInfo(youtubeVideoId);
      } catch (e) {
        print('Warning: Tidak dapat mendapatkan info video dari YouTube: $e');
      }

      // Set default values dari YouTube info jika ada
      if (youtubeVideoUrl == null && videoInfo.containsKey('url')) {
        youtubeVideoUrl = videoInfo['url'];
      }
      if (thumbnailUrl == null && videoInfo.containsKey('thumbnail')) {
        thumbnailUrl = videoInfo['thumbnail'];
      }
      if (durationSeconds == null && videoInfo.containsKey('duration')) {
        durationSeconds = videoInfo['duration'];
        durationMinutes = durationSeconds != null ? (durationSeconds / 60).ceil() : 0;
      }

      // Dapatkan sort_order seterusnya jika tidak diberikan
      if (sortOrder == null) {
        final maxOrderResult = await _supabase
            .from('kitab_videos')
            .select('sort_order')
            .eq('kitab_id', kitabId)
            .order('sort_order', ascending: false)
            .limit(1)
            .maybeSingle();
        
        sortOrder = (maxOrderResult?['sort_order'] as int? ?? 0) + 1;
      }

      final episodeData = {
        'kitab_id': kitabId,
        'title': title,
        'description': description,
        'youtube_video_id': youtubeVideoId,
        'youtube_video_url': youtubeVideoUrl,
        'thumbnail_url': thumbnailUrl,
        'duration_minutes': durationMinutes ?? 0,
        'duration_seconds': durationSeconds ?? 0,
        'part_number': partNumber,
        'sort_order': sortOrder,
        'is_active': isActive,
        'is_preview': isPreview,
      };

      final response = await _supabase
          .from('kitab_videos')
          .insert(episodeData)
          .select()
          .single();

      // Update kitab counters dan status
      await _updateKitabVideoStats(kitabId);

      return response;
    } catch (e) {
      throw Exception('Ralat menambah episode: $e');
    }
  }

  /// Update episode
  Future<Map<String, dynamic>> updateEpisode({
    required String episodeId,
    String? title,
    String? description,
    String? youtubeVideoId,
    String? youtubeVideoUrl,
    String? thumbnailUrl,
    int? partNumber,
    int? durationMinutes,
    int? durationSeconds,
    int? sortOrder,
    bool? isActive,
    bool? isPreview,
  }) async {
    try {
      // Check episode exists dan dapatkan kitab_id
      final existing = await _supabase
          .from('kitab_videos')
          .select('id, kitab_id, part_number')
          .eq('id', episodeId)
          .maybeSingle();

      if (existing == null) {
        throw Exception('Episode tidak dijumpai');
      }

      final kitabId = existing['kitab_id'];

      // Validasi part_number unik jika berubah
      if (partNumber != null && partNumber != existing['part_number']) {
        final partCheck = await _supabase
            .from('kitab_videos')
            .select('id')
            .eq('kitab_id', kitabId)
            .eq('part_number', partNumber)
            .neq('id', episodeId)
            .maybeSingle();

        if (partCheck != null) {
          throw Exception('Nombor episode sudah wujud untuk kitab ini');
        }
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (youtubeVideoId != null) updateData['youtube_video_id'] = youtubeVideoId;
      if (youtubeVideoUrl != null) updateData['youtube_video_url'] = youtubeVideoUrl;
      if (thumbnailUrl != null) updateData['thumbnail_url'] = thumbnailUrl;
      if (partNumber != null) updateData['part_number'] = partNumber;
      if (durationMinutes != null) updateData['duration_minutes'] = durationMinutes;
      if (durationSeconds != null) updateData['duration_seconds'] = durationSeconds;
      if (sortOrder != null) updateData['sort_order'] = sortOrder;
      if (isActive != null) updateData['is_active'] = isActive;
      if (isPreview != null) updateData['is_preview'] = isPreview;

      final response = await _supabase
          .from('kitab_videos')
          .update(updateData)
          .eq('id', episodeId)
          .select()
          .single();

      // Update kitab counters
      await _updateKitabVideoStats(kitabId);

      return response;
    } catch (e) {
      throw Exception('Ralat mengupdate episode: $e');
    }
  }

  /// Padam episode
  Future<void> deleteEpisode(String episodeId) async {
    try {
      // Get kitab_id sebelum delete
      final episode = await _supabase
          .from('kitab_videos')
          .select('kitab_id')
          .eq('id', episodeId)
          .single();

      final kitabId = episode['kitab_id'];

      await _supabase
          .from('kitab_videos')
          .delete()
          .eq('id', episodeId);

      // Update kitab counters selepas delete
      await _updateKitabVideoStats(kitabId);
    } catch (e) {
      throw Exception('Ralat memadam episode: $e');
    }
  }

  /// Batch delete episodes
  Future<void> deleteMultipleEpisodes(List<String> episodeIds) async {
    try {
      if (episodeIds.isEmpty) return;

      // Get kitab_id dari episode pertama
      final firstEpisode = await _supabase
          .from('kitab_videos')
          .select('kitab_id')
          .eq('id', episodeIds.first)
          .single();

      final kitabId = firstEpisode['kitab_id'];

      // Use individual deletes as fallback (more reliable)
      for (final episodeId in episodeIds) {
        await _supabase
            .from('kitab_videos')
            .delete()
            .eq('id', episodeId);
      }

      // Update kitab counters
      await _updateKitabVideoStats(kitabId);
    } catch (e) {
      throw Exception('Ralat memadam episodes: $e');
    }
  }

  /// Toggle status aktif episode
  Future<Map<String, dynamic>> toggleEpisodeStatus(String episodeId) async {
    try {
      final episode = await _supabase
          .from('kitab_videos')
          .select('is_active, kitab_id')
          .eq('id', episodeId)
          .single();

      final newStatus = !(episode['is_active'] as bool? ?? false);
      final kitabId = episode['kitab_id'];

      final response = await _supabase
          .from('kitab_videos')
          .update({
            'is_active': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', episodeId)
          .select()
          .single();

      // Update kitab counters
      await _updateKitabVideoStats(kitabId);

      return response;
    } catch (e) {
      throw Exception('Ralat menukar status episode: $e');
    }
  }

  /// Reorder episodes (drag & drop)
  Future<void> reorderEpisodes(String kitabId, List<String> episodeIds) async {
    try {
      final batch = <Map<String, dynamic>>[];
      
      for (int i = 0; i < episodeIds.length; i++) {
        batch.add({
          'id': episodeIds[i],
          'sort_order': i + 1,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await _supabase
          .from('kitab_videos')
          .upsert(batch);
    } catch (e) {
      throw Exception('Ralat menyusun semula episodes: $e');
    }
  }

  /// Auto-renumber episodes
  Future<void> autoRenumberEpisodes(String kitabId) async {
    try {
      // Get all episodes untuk kitab ini
      final episodes = await _supabase
          .from('kitab_videos')
          .select('id')
          .eq('kitab_id', kitabId)
          .order('sort_order', ascending: true);

      final batch = <Map<String, dynamic>>[];
      
      for (int i = 0; i < episodes.length; i++) {
        batch.add({
          'id': episodes[i]['id'],
          'part_number': i + 1,
          'sort_order': i + 1,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (batch.isNotEmpty) {
        await _supabase
            .from('kitab_videos')
            .upsert(batch);
      }
    } catch (e) {
      throw Exception('Ralat auto-renumber episodes: $e');
    }
  }

  /// Duplicate episode
  Future<Map<String, dynamic>> duplicateEpisode(String episodeId, String newTitle) async {
    try {
      // Get original episode
      final original = await _supabase
          .from('kitab_videos')
          .select()
          .eq('id', episodeId)
          .single();

      // Get next part number
      final maxPartResult = await _supabase
          .from('kitab_videos')
          .select('part_number')
          .eq('kitab_id', original['kitab_id'])
          .order('part_number', ascending: false)
          .limit(1)
          .maybeSingle();

      final nextPartNumber = (maxPartResult?['part_number'] as int? ?? 0) + 1;

      // Prepare duplicate data
      final duplicateData = Map<String, dynamic>.from(original);
      duplicateData.remove('id'); // Remove ID untuk auto-generate
      duplicateData['title'] = newTitle;
      duplicateData['part_number'] = nextPartNumber;
      duplicateData['created_at'] = DateTime.now().toIso8601String();
      duplicateData['updated_at'] = DateTime.now().toIso8601String();
      
      // Set sebagai inactive by default
      duplicateData['is_active'] = false;

      // Insert duplicate
      final response = await _supabase
          .from('kitab_videos')
          .insert(duplicateData)
          .select()
          .single();

      // Update kitab counters
      await _updateKitabVideoStats(original['kitab_id']);

      return response;
    } catch (e) {
      throw Exception('Ralat menduplicate episode: $e');
    }
  }

  /// Migrate single video kitab ke multi-episode
  Future<void> migrateToMultiEpisode(String kitabId) async {
    try {
      // Get kitab info
      final kitab = await _supabase
          .from('kitab')
          .select('youtube_video_id, youtube_video_url, title, duration_minutes')
          .eq('id', kitabId)
          .single();

      // Jika ada single video, buat episode pertama
      if (kitab['youtube_video_id'] != null && kitab['youtube_video_id'].isNotEmpty) {
        await addEpisode(
          kitabId: kitabId,
          title: '${kitab['title']} - Episode 1',
          youtubeVideoId: kitab['youtube_video_id'],
          partNumber: 1,
          youtubeVideoUrl: kitab['youtube_video_url'],
          durationMinutes: kitab['duration_minutes'],
          isPreview: false,
          isActive: true,
        );

        // Clear single video fields dari kitab
        await _supabase
            .from('kitab')
            .update({
              'youtube_video_id': null,
              'youtube_video_url': null,
              'has_multiple_videos': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', kitabId);
      }
    } catch (e) {
      throw Exception('Ralat migrate ke multi-episode: $e');
    }
  }

  // =====================================================
  // HELPER FUNCTIONS
  // =====================================================

  /// Update kitab video statistics
  Future<void> _updateKitabVideoStats(String kitabId) async {
    try {
      // Count active episodes
      final activeEpisodesResponse = await _supabase
          .from('kitab_videos')
          .select('duration_seconds')
          .eq('kitab_id', kitabId)
          .eq('is_active', true);

      final activeEpisodes = List<Map<String, dynamic>>.from(activeEpisodesResponse);
      final totalVideos = activeEpisodes.length;
      final totalDurationSeconds = activeEpisodes.fold<int>(
        0, 
        (sum, episode) => sum + (episode['duration_seconds'] as int? ?? 0)
      );
      final totalDurationMinutes = (totalDurationSeconds / 60).ceil();

      // Update kitab
      await _supabase
          .from('kitab')
          .update({
            'total_videos': totalVideos,
            'total_duration_minutes': totalDurationMinutes,
            'has_multiple_videos': totalVideos > 0,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', kitabId);
    } catch (e) {
      print('Error updating kitab video stats: $e');
    }
  }

  /// Get YouTube video information
  Future<Map<String, dynamic>> _getYouTubeVideoInfo(String videoId) async {
    try {
      // Basic implementation - boleh integrate dengan YouTube API nanti
      return {
        'url': getYouTubeVideoUrl(videoId),
        'thumbnail': getDefaultThumbnailUrl(videoId, quality: 'maxresdefault'),
        'duration': null, // Perlu YouTube API untuk dapat duration
      };
    } catch (e) {
      throw Exception('Ralat mendapatkan info video YouTube: $e');
    }
  }

  /// Validate YouTube video ID
  bool isValidYouTubeVideoId(String videoId) {
    // YouTube video ID biasanya 11 characters
    final RegExp regex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return regex.hasMatch(videoId);
  }

  /// Extract video ID dari YouTube URL atau return ID jika sudah dalam format yang betul
  String? extractYouTubeVideoId(String input) {
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

    if (uri == null || uri.host.isEmpty) return null;

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

  /// Generate default YouTube thumbnail URL
  String getDefaultThumbnailUrl(String videoId, {String quality = 'hqdefault'}) {
    // Available qualities: default, mqdefault, hqdefault, sddefault, maxresdefault
    return 'https://img.youtube.com/vi/$videoId/$quality.jpg';
  }

  /// Check if input looks like a YouTube URL or ID
  bool isLikelyYouTubeUrl(String input) {
    final id = extractYouTubeVideoId(input);
    return id != null;
  }

  /// Get YouTube video URL from video ID
  String getYouTubeVideoUrl(String videoId) {
    return 'https://www.youtube.com/watch?v=$videoId';
  }
}
