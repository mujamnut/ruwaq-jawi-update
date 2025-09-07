// ignore_for_file: unused_import

import '../../../core/services/supabase_service.dart';
import '../../../core/models/kitab.dart';
import '../../../core/models/kitab_video.dart';
import '../../../core/models/category.dart';

class AdminContentService {
  // Kitab management
  static Future<List<Kitab>> getAllKitab({
    String? categoryFilter,
    bool? activeFilter,
    bool? premiumFilter,
    String? searchQuery,
  }) async {
    var query = SupabaseService.from('kitab').select('''
          *,
          categories:category_id(name),
          kitab_videos:kitab_id(id, title, duration_minutes, is_active)
        ''');

    // Apply filters
    if (categoryFilter != null) {
      query = query.eq('category_id', categoryFilter);
    }

    if (activeFilter != null) {
      query = query.eq('is_active', activeFilter);
    }

    if (premiumFilter != null) {
      query = query.eq('is_premium', premiumFilter);
    }

    final response = await query.order('updated_at', ascending: false);
    var kitabList = (response as List)
        .map((json) => Kitab.fromJson(json))
        .toList();

    // Apply text search if provided
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchLower = searchQuery.toLowerCase();
      kitabList = kitabList.where((kitab) {
        return kitab.title.toLowerCase().contains(searchLower) ||
            (kitab.author?.toLowerCase().contains(searchLower) ?? false) ||
            (kitab.description?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    return kitabList;
  }

  static Future<Kitab> createKitab(Map<String, dynamic> kitabData) async {
    // Set default values
    kitabData['created_at'] = DateTime.now().toIso8601String();
    kitabData['updated_at'] = DateTime.now().toIso8601String();
    kitabData['sort_order'] = await _getNextSortOrder();

    final response = await SupabaseService.from(
      'kitab',
    ).insert(kitabData).select().single();

    return Kitab.fromJson(response);
  }

  static Future<Kitab> updateKitab(
    String kitabId,
    Map<String, dynamic> kitabData,
  ) async {
    kitabData['updated_at'] = DateTime.now().toIso8601String();

    final response = await SupabaseService.from(
      'kitab',
    ).update(kitabData).eq('id', kitabId).select().single();

    return Kitab.fromJson(response);
  }

  static Future<void> deleteKitab(String kitabId) async {
    // First delete all associated videos
    await SupabaseService.from('kitab_videos').delete().eq('kitab_id', kitabId);

    // Then delete the kitab
    await SupabaseService.from('kitab').delete().eq('id', kitabId);
  }

  static Future<Kitab> duplicateKitab(
    String kitabId, {
    String? newTitle,
  }) async {
    // Get original kitab
    final originalResponse = await SupabaseService.from(
      'kitab',
    ).select().eq('id', kitabId).single();

    final original = Kitab.fromJson(originalResponse);

    // Prepare duplicate data
    final duplicateData = original.toJson();
    duplicateData.remove('id');
    duplicateData['title'] = newTitle ?? '${original.title} (Salinan)';
    duplicateData['created_at'] = DateTime.now().toIso8601String();
    duplicateData['updated_at'] = DateTime.now().toIso8601String();
    duplicateData['is_active'] = false; // Make inactive by default
    duplicateData['sort_order'] = await _getNextSortOrder();

    // Create duplicate
    final response = await SupabaseService.from(
      'kitab',
    ).insert(duplicateData).select().single();

    final newKitab = Kitab.fromJson(response);

    // Duplicate associated videos
    await _duplicateKitabVideos(kitabId, newKitab.id);

    return newKitab;
  }

  static Future<void> toggleKitabStatus(String kitabId, bool isActive) async {
    await SupabaseService.from('kitab')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', kitabId);
  }

  static Future<void> bulkUpdateKitab(
    List<String> kitabIds,
    Map<String, dynamic> updates,
  ) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    await SupabaseService.from(
      'kitab',
    ).update(updates).filter('id', 'in', '(${kitabIds.join(',')})');
  }

  // Video management
  static Future<List<KitabVideo>> getKitabVideos(String kitabId) async {
    final response = await SupabaseService.from(
      'kitab_videos',
    ).select().eq('kitab_id', kitabId).order('part_number');

    return (response as List).map((json) => KitabVideo.fromJson(json)).toList();
  }

  static Future<KitabVideo> createKitabVideo(
    Map<String, dynamic> videoData,
  ) async {
    videoData['created_at'] = DateTime.now().toIso8601String();
    videoData['updated_at'] = DateTime.now().toIso8601String();

    final response = await SupabaseService.from(
      'kitab_videos',
    ).insert(videoData).select().single();

    // Update parent kitab stats
    await _updateKitabVideoStats(videoData['kitab_id']);

    return KitabVideo.fromJson(response);
  }

  static Future<KitabVideo> updateKitabVideo(
    String videoId,
    Map<String, dynamic> videoData,
  ) async {
    videoData['updated_at'] = DateTime.now().toIso8601String();

    final response = await SupabaseService.from(
      'kitab_videos',
    ).update(videoData).eq('id', videoId).select().single();

    final video = KitabVideo.fromJson(response);

    // Update parent kitab stats
    await _updateKitabVideoStats(video.kitabId);

    return video;
  }

  static Future<void> deleteKitabVideo(String videoId) async {
    // Get video info before deleting
    final videoResponse = await SupabaseService.from(
      'kitab_videos',
    ).select('kitab_id').eq('id', videoId).single();

    final kitabId = videoResponse['kitab_id'] as String;

    // Delete the video
    await SupabaseService.from('kitab_videos').delete().eq('id', videoId);

    // Update parent kitab stats
    await _updateKitabVideoStats(kitabId);
  }

  static Future<void> reorderKitabVideos(
    String kitabId,
    List<String> videoIds,
  ) async {
    for (int i = 0; i < videoIds.length; i++) {
      await SupabaseService.from('kitab_videos')
          .update({
            'part_number': i + 1,
            'sort_order': i,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', videoIds[i]);
    }

    // Update parent kitab stats
    await _updateKitabVideoStats(kitabId);
  }

  // Analytics and stats
  static Future<Map<String, dynamic>> getContentStats() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      // Basic counts - using simple select and length
      final totalKitabResult = await SupabaseService.from('kitab').select('id');
      final activeKitabResult = await SupabaseService.from(
        'kitab',
      ).select('id').eq('is_active', true);
      final premiumKitabResult = await SupabaseService.from(
        'kitab',
      ).select('id').eq('is_premium', true);
      final totalVideosResult = await SupabaseService.from(
        'kitab_videos',
      ).select('id');
      final activeVideosResult = await SupabaseService.from(
        'kitab_videos',
      ).select('id').eq('is_active', true);

      // This month's additions
      final thisMonthKitabResult = await SupabaseService.from('kitab')
          .select('id')
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String());

      final thisMonthVideosResult = await SupabaseService.from('kitab_videos')
          .select('id')
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String());

      // Calculate total duration
      final videosWithDuration = await SupabaseService.from(
        'kitab_videos',
      ).select('duration_minutes').not('duration_minutes', 'is', null);

      final totalDurationMinutes = (videosWithDuration as List).fold<int>(
        0,
        (sum, video) => sum + (video['duration_minutes'] as int? ?? 0),
      );

      // Categories stats
      final categoriesResult = await SupabaseService.from(
        'categories',
      ).select('id');

      // Complete vs incomplete kitab
      final completeKitab = await SupabaseService.from(
        'kitab',
      ).select('id, pdf_url, youtube_video_id').eq('is_active', true);

      int completeCount = 0;
      for (final kitab in completeKitab) {
        final hasPdf =
            kitab['pdf_url'] != null && (kitab['pdf_url'] as String).isNotEmpty;
        final hasVideo =
            kitab['youtube_video_id'] != null &&
            (kitab['youtube_video_id'] as String).isNotEmpty;

        // Also check if has videos in kitab_videos table
        final hasVideoEpisodes = await SupabaseService.from(
          'kitab_videos',
        ).select('id').eq('kitab_id', kitab['id']).eq('is_active', true);

        if ((hasPdf && hasVideo) || (hasPdf && hasVideoEpisodes.length > 0)) {
          completeCount++;
        }
      }

      return {
        'totalKitab': totalKitabResult.length,
        'activeKitab': activeKitabResult.length,
        'premiumKitab': premiumKitabResult.length,
        'freeKitab': totalKitabResult.length - premiumKitabResult.length,
        'completeKitab': completeCount,
        'incompleteKitab': activeKitabResult.length - completeCount,
        'totalVideos': totalVideosResult.length,
        'activeVideos': activeVideosResult.length,
        'totalCategories': categoriesResult.length,
        'totalDurationMinutes': totalDurationMinutes,
        'thisMonthKitab': thisMonthKitabResult.length,
        'thisMonthVideos': thisMonthVideosResult.length,
      };
    } catch (e) {
      throw Exception('Failed to get content stats: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getCategoryStats() async {
    final categories = await SupabaseService.getActiveCategories();
    final List<Map<String, dynamic>> categoryStats = [];

    for (final category in categories) {
      final kitabCount = await SupabaseService.from(
        'kitab',
      ).select('id').eq('category_id', category.id).eq('is_active', true);

      final totalKitabCount = await SupabaseService.from(
        'kitab',
      ).select('id').eq('category_id', category.id);

      categoryStats.add({
        'category': category,
        'activeKitab': kitabCount.length,
        'totalKitab': totalKitabCount.length,
      });
    }

    // Sort by active kitab count descending
    categoryStats.sort(
      (a, b) => (b['activeKitab'] as int).compareTo(a['activeKitab'] as int),
    );

    return categoryStats;
  }

  // Utility methods
  static Future<int> _getNextSortOrder() async {
    final result = await SupabaseService.from(
      'kitab',
    ).select('sort_order').order('sort_order', ascending: false).limit(1);

    if (result.isEmpty) return 0;
    return (result[0]['sort_order'] as int? ?? 0) + 1;
  }

  static Future<void> _updateKitabVideoStats(String kitabId) async {
    try {
      // Get all videos for this kitab
      final videos = await SupabaseService.from(
        'kitab_videos',
      ).select('duration_minutes, is_active').eq('kitab_id', kitabId);

      final totalVideos = videos.length;
      final activeVideos = videos.where((v) => v['is_active'] == true).length;
      final totalDurationMinutes = videos.fold<int>(
        0,
        (sum, video) => sum + (video['duration_minutes'] as int? ?? 0),
      );

      // Update kitab with stats
      await SupabaseService.from('kitab')
          .update({
            'has_multiple_videos': totalVideos > 1,
            'total_videos': totalVideos,
            'total_duration_minutes': totalDurationMinutes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', kitabId);
    } catch (e) {
      print('Error updating kitab video stats: $e');
    }
  }

  static Future<void> _duplicateKitabVideos(
    String originalKitabId,
    String newKitabId,
  ) async {
    try {
      final originalVideos = await SupabaseService.from(
        'kitab_videos',
      ).select().eq('kitab_id', originalKitabId).order('part_number');

      for (final videoJson in originalVideos) {
        final duplicateVideoData = Map<String, dynamic>.from(videoJson);
        duplicateVideoData.remove('id');
        duplicateVideoData['kitab_id'] = newKitabId;
        duplicateVideoData['title'] =
            '${duplicateVideoData['title']} (Salinan)';
        duplicateVideoData['created_at'] = DateTime.now().toIso8601String();
        duplicateVideoData['updated_at'] = DateTime.now().toIso8601String();
        duplicateVideoData['is_active'] = false; // Make inactive by default

        await SupabaseService.from('kitab_videos').insert(duplicateVideoData);
      }

      // Update parent kitab stats
      await _updateKitabVideoStats(newKitabId);
    } catch (e) {
      print('Error duplicating kitab videos: $e');
    }
  }

  // Search and filters
  static List<Kitab> applyAdvancedFilters(
    List<Kitab> kitabList, {
    String? searchQuery,
    List<String>? categoryIds,
    bool? isActive,
    bool? isPremium,
    bool? hasVideo,
    bool? hasPdf,
    bool? isComplete,
    DateTime? createdAfter,
    DateTime? createdBefore,
  }) {
    var filtered = List<Kitab>.from(kitabList);

    // Text search
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchLower = searchQuery.toLowerCase();
      filtered = filtered.where((kitab) {
        return kitab.title.toLowerCase().contains(searchLower) ||
            (kitab.author?.toLowerCase().contains(searchLower) ?? false) ||
            (kitab.description?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    // Category filter
    if (categoryIds != null && categoryIds.isNotEmpty) {
      filtered = filtered
          .where(
            (kitab) =>
                kitab.categoryId != null &&
                categoryIds.contains(kitab.categoryId),
          )
          .toList();
    }

    // Status filters
    if (isActive != null) {
      filtered = filtered.where((kitab) => kitab.isActive == isActive).toList();
    }

    if (isPremium != null) {
      filtered = filtered
          .where((kitab) => kitab.isPremium == isPremium)
          .toList();
    }

    // Media filters
    if (hasVideo != null) {
      filtered = filtered.where((kitab) => kitab.hasVideo == hasVideo).toList();
    }

    if (hasPdf != null) {
      filtered = filtered.where((kitab) => kitab.hasPdf == hasPdf).toList();
    }

    if (isComplete != null) {
      filtered = filtered
          .where((kitab) => kitab.isComplete == isComplete)
          .toList();
    }

    // Date filters
    if (createdAfter != null) {
      filtered = filtered
          .where((kitab) => kitab.createdAt.isAfter(createdAfter))
          .toList();
    }

    if (createdBefore != null) {
      filtered = filtered
          .where((kitab) => kitab.createdAt.isBefore(createdBefore))
          .toList();
    }

    return filtered;
  }

  // Export/Import utilities
  static Future<List<Map<String, dynamic>>> exportKitabData({
    List<String>? kitabIds,
    bool includeVideos = true,
  }) async {
    var query = SupabaseService.from('kitab').select('''
      *,
      categories:category_id(*)
    ''');

    if (kitabIds != null && kitabIds.isNotEmpty) {
      query = query.filter('id', 'in', '(${kitabIds.join(',')})');
    }

    final kitabData = await query;
    final List<Map<String, dynamic>> exportData = [];

    for (final kitab in kitabData) {
      final kitabExport = Map<String, dynamic>.from(kitab);

      if (includeVideos) {
        final videos = await SupabaseService.from(
          'kitab_videos',
        ).select().eq('kitab_id', kitab['id']).order('part_number');
        kitabExport['videos'] = videos;
      }

      exportData.add(kitabExport);
    }

    return exportData;
  }

  // Validation utilities
  static String? validateKitabData(Map<String, dynamic> data) {
    if (data['title'] == null || (data['title'] as String).trim().isEmpty) {
      return 'Tajuk kitab diperlukan';
    }

    if (data['category_id'] == null) {
      return 'Kategori diperlukan';
    }

    // Check for required fields based on type
    final isPremium = data['is_premium'] as bool? ?? true;
    if (isPremium) {
      // Premium content validation - could add specific requirements
    }

    return null; // No validation errors
  }

  static String? validateVideoData(Map<String, dynamic> data) {
    if (data['title'] == null || (data['title'] as String).trim().isEmpty) {
      return 'Tajuk episode diperlukan';
    }

    if (data['kitab_id'] == null) {
      return 'Kitab ID diperlukan';
    }

    if (data['part_number'] == null || (data['part_number'] as int) < 1) {
      return 'Nombor episode tidak sah';
    }

    // Validate YouTube video ID format if provided
    final videoId = data['youtube_video_id'] as String?;
    if (videoId != null && videoId.isNotEmpty) {
      final videoIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
      if (!videoIdRegex.hasMatch(videoId)) {
        return 'Format YouTube Video ID tidak sah';
      }
    }

    return null; // No validation errors
  }
}
