import '../models/video_kitab.dart';
import 'supabase_service.dart';

class VideoKitabService {
  static const String _tableName = 'video_kitab';

  // Get all video kitab with optional filters
  static Future<List<VideoKitab>> getVideoKitabs({
    String? categoryId,
    bool? isPremium,
    bool? isActive,
    String? searchQuery,
    int? limit,
    int? offset,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      // Build base query
      dynamic query = SupabaseService.from(_tableName)
          .select('''
            id, title, author, description, category_id, pdf_url,
            pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
            total_videos, total_duration_minutes, is_premium,
            is_active, views_count, created_at, updated_at,
            categories(id, name)
          ''');

      // Apply filters conditionally
      if (categoryId != null && isPremium != null && isActive != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              total_videos, total_duration_minutes, is_premium,
              is_active, views_count, created_at, updated_at,
              categories(id, name)
            ''')
            .eq('category_id', categoryId)
            .eq('is_premium', isPremium)
            .eq('is_active', isActive);
      } else if (categoryId != null && isPremium != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              total_videos, total_duration_minutes, is_premium,
              is_active, views_count, created_at, updated_at,
              categories(id, name)
            ''')
            .eq('category_id', categoryId)
            .eq('is_premium', isPremium);
      } else if (categoryId != null && isActive != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              total_videos, total_duration_minutes, is_premium,
              is_active, views_count, created_at, updated_at,
              categories(id, name)
            ''')
            .eq('category_id', categoryId)
            .eq('is_active', isActive);
      } else if (isPremium != null && isActive != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              total_videos, total_duration_minutes, is_premium,
              is_active, views_count, created_at, updated_at,
              categories(id, name)
            ''')
            .eq('is_premium', isPremium)
            .eq('is_active', isActive);
      } else if (categoryId != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              total_videos, total_duration_minutes, is_premium,
              is_active, views_count, created_at, updated_at,
              categories(id, name)
            ''')
            .eq('category_id', categoryId);
      } else if (isPremium != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              total_videos, total_duration_minutes, is_premium,
              is_active, views_count, created_at, updated_at,
              categories(id, name)
            ''')
            .eq('is_premium', isPremium);
      } else if (isActive != null) {
        query = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              total_videos, total_duration_minutes, is_premium,
              is_active, views_count, created_at, updated_at,
              categories(id, name)
            ''')
            .eq('is_active', isActive);
      }

      // Apply search filter
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final baseQuery = SupabaseService.from(_tableName)
            .select('''
              id, title, author, description, category_id, pdf_url,
              pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
              total_videos, total_duration_minutes, is_premium,
              is_active, views_count, created_at, updated_at,
              categories(id, name)
            ''')
            .or('title.ilike.%$searchQuery%,author.ilike.%$searchQuery%');
        
        if (categoryId != null) {
          query = baseQuery.eq('category_id', categoryId);
        } else if (isPremium != null) {
          query = baseQuery.eq('is_premium', isPremium);
        } else if (isActive != null) {
          query = baseQuery.eq('is_active', isActive);
        } else {
          query = baseQuery;
        }
      }

      // Execute with ordering and pagination
      final response = await query
          .order(orderBy, ascending: ascending)
          .limit(limit ?? 50)
          .range(offset ?? 0, (offset ?? 0) + (limit ?? 50) - 1);
      
      return List<Map<String, dynamic>>.from(response)
          .map((json) => VideoKitab.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch video kitabs: $e');
    }
  }

  // Get single video kitab by ID
  static Future<VideoKitab?> getVideoKitabById(String id) async {
    try {
      final response = await SupabaseService.from(_tableName)
          .select('''
            id, title, author, description, category_id, pdf_url,
            pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
            total_videos, total_duration_minutes, is_premium,
            is_active, views_count, created_at, updated_at,
            categories(id, name)
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return VideoKitab.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch video kitab: $e');
    }
  }

  // Create new video kitab
  static Future<VideoKitab> createVideoKitab(Map<String, dynamic> kitabData) async {
    try {
      final data = {
        ...kitabData,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_active': kitabData['is_active'] ?? true,
        'is_premium': kitabData['is_premium'] ?? true,
        'total_videos': kitabData['total_videos'] ?? 0,
        'total_duration_minutes': kitabData['total_duration_minutes'] ?? 0,
        'views_count': 0,
      };

      final response = await SupabaseService.from(_tableName)
          .insert(data)
          .select('''
            id, title, author, description, category_id, pdf_url,
            pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
            total_videos, total_duration_minutes, is_premium,
            is_active, views_count, created_at, updated_at,
            categories(id, name)
          ''')
          .single();

      return VideoKitab.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create video kitab: $e');
    }
  }

  // Update video kitab
  static Future<VideoKitab> updateVideoKitab(String id, Map<String, dynamic> updates) async {
    try {
      // Clean the updates data to remove any null values or invalid fields
      final cleanedUpdates = <String, dynamic>{};

      // Only include valid fields that exist in the table
      final validFields = [
        'title', 'author', 'description', 'category_id', 'pdf_url',
        'pdf_storage_path', 'pdf_file_size', 'thumbnail_url', 'total_pages',
        'total_videos', 'total_duration_minutes', 'is_premium', 'is_active',
        'views_count', 'youtube_playlist_id', 'youtube_playlist_url',
        'auto_sync_enabled', 'last_synced_at'
      ];

      for (final entry in updates.entries) {
        if (validFields.contains(entry.key) && entry.value != null) {
          cleanedUpdates[entry.key] = entry.value;
        }
      }

      final data = {
        ...cleanedUpdates,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await SupabaseService.from(_tableName)
          .update(data)
          .eq('id', id)
          .select('''
            id, title, author, description, category_id, pdf_url,
            pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
            total_videos, total_duration_minutes, is_premium,
            is_active, views_count, created_at, updated_at,
            categories(id, name)
          ''')
          .single();

      return VideoKitab.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update video kitab: $e');
    }
  }

  // Admin update function - direct update without triggers (triggers removed)
  static Future<VideoKitab> updateVideoKitabAdmin(String id, Map<String, dynamic> updates) async {
    // Debug logging removed
    // Debug logging removed
    // Debug logging removed

    try {
      // Debug logging removed

      // Direct update - no triggers causing issues anymore
      final response = await SupabaseService.from(_tableName)
          .update(updates)
          .eq('id', id)
          .select('''
            id, title, author, description, category_id, pdf_url,
            pdf_storage_path, pdf_file_size, thumbnail_url, total_pages,
            total_videos, total_duration_minutes, is_premium,
            is_active, views_count, created_at, updated_at,
            categories(id, name)
          ''')
          .single();

      // Debug logging removed

      final videoKitab = VideoKitab.fromJson(response);
      // Debug logging removed

      return videoKitab;
    } catch (e) {
      // Debug logging removed
      // Debug logging removed
      // Debug logging removed
      throw Exception('Failed to update video kitab: $e');
    }
  }

  // Delete video kitab
  static Future<void> deleteVideoKitab(String id) async {
    try {
      await SupabaseService.from(_tableName).delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete video kitab: $e');
    }
  }

  // Toggle video kitab active status
  static Future<VideoKitab> toggleVideoKitabStatus(String id, bool isActive) async {
    try {
      return await updateVideoKitab(id, {'is_active': isActive});
    } catch (e) {
      throw Exception('Failed to toggle video kitab status: $e');
    }
  }

  // Admin-specific toggle - direct update (no triggers)
  static Future<VideoKitab> toggleVideoKitabStatusAdmin(String id, bool isActive) async {
    try {
      return await updateVideoKitabAdmin(id, {'is_active': isActive});
    } catch (e) {
      throw Exception('Failed to toggle video kitab status: $e');
    }
  }

  // Get video kitab statistics
  static Future<Map<String, int>> getVideoKitabStats({String? categoryId}) async {
    try {
      dynamic query = SupabaseService.from(_tableName)
          .select('id, is_active, is_premium, views_count, total_videos');
      
      if (categoryId != null) {
        query = SupabaseService.from(_tableName)
            .select('id, is_active, is_premium, views_count, total_videos')
            .eq('category_id', categoryId);
      }

      final response = await query;
      final stats = List<Map<String, dynamic>>.from(response);

      int totalVideoKitabs = stats.length;
      int activeVideoKitabs = stats.where((s) => s['is_active'] == true).length;
      int premiumVideoKitabs = stats.where((s) => s['is_premium'] == true).length;
      int freeVideoKitabs = stats.where((s) => s['is_premium'] == false).length;
      int totalViews = stats.fold(0, (sum, s) => sum + (s['views_count'] as int? ?? 0));
      int totalVideos = stats.fold(0, (sum, s) => sum + (s['total_videos'] as int? ?? 0));

      return {
        'total_video_kitabs': totalVideoKitabs,
        'active_video_kitabs': activeVideoKitabs,
        'inactive_video_kitabs': totalVideoKitabs - activeVideoKitabs,
        'premium_video_kitabs': premiumVideoKitabs,
        'free_video_kitabs': freeVideoKitabs,
        'total_views': totalViews,
        'total_videos': totalVideos,
      };
    } catch (e) {
      throw Exception('Failed to get video kitab statistics: $e');
    }
  }

  // Get popular video kitabs (by views)
  static Future<List<VideoKitab>> getPopularVideoKitabs({int limit = 10}) async {
    try {
      return await getVideoKitabs(
        limit: limit,
        orderBy: 'views_count',
        ascending: false,
        isActive: true,
      );
    } catch (e) {
      throw Exception('Failed to get popular video kitabs: $e');
    }
  }

  // Get recent video kitabs
  static Future<List<VideoKitab>> getRecentVideoKitabs({int limit = 10}) async {
    try {
      return await getVideoKitabs(
        limit: limit,
        orderBy: 'created_at',
        ascending: false,
        isActive: true,
      );
    } catch (e) {
      throw Exception('Failed to get recent video kitabs: $e');
    }
  }

  // Search video kitabs
  static Future<List<VideoKitab>> searchVideoKitabs(String query, {int limit = 50}) async {
    try {
      if (query.trim().isEmpty) {
        return await getVideoKitabs(limit: limit, isActive: true);
      }

      return await getVideoKitabs(
        searchQuery: query.trim(),
        limit: limit,
        isActive: true,
      );
    } catch (e) {
      throw Exception('Failed to search video kitabs: $e');
    }
  }

  // Get video kitabs by category
  static Future<List<VideoKitab>> getVideoKitabsByCategory(String categoryId, {int limit = 50}) async {
    try {
      return await getVideoKitabs(
        categoryId: categoryId,
        limit: limit,
        isActive: true,
      );
    } catch (e) {
      throw Exception('Failed to get video kitabs by category: $e');
    }
  }

  // Increment view count
  static Future<void> incrementViewCount(String id) async {
    try {
      final current = await SupabaseService.from(_tableName)
          .select('views_count')
          .eq('id', id)
          .single();
      
      final newCount = (current['views_count'] as int? ?? 0) + 1;
      
      await SupabaseService.from(_tableName)
          .update({'views_count': newCount})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to increment view count: $e');
    }
  }

  // Update video counts and duration when videos are added/removed
  static Future<void> updateVideoCounts(String videoKitabId) async {
    try {
      // Get video episodes for this video kitab
      final episodes = await SupabaseService.from('video_episodes')
          .select('duration_minutes')
          .eq('video_kitab_id', videoKitabId)
          .eq('is_active', true);

      final totalVideos = episodes.length;
      final totalDuration = episodes.fold<int>(
        0, 
        (sum, episode) => sum + (episode['duration_minutes'] as int? ?? 0)
      );

      await updateVideoKitab(videoKitabId, {
        'total_videos': totalVideos,
        'total_duration_minutes': totalDuration,
      });
    } catch (e) {
      throw Exception('Failed to update video counts: $e');
    }
  }
}
