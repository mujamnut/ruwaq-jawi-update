import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/preview_models.dart';
import 'supabase_service.dart';

/// Unified preview service for managing all content previews
class PreviewService {
  static final SupabaseClient _client = SupabaseService.client;

  /// Get all preview content with optional filtering
  static Future<List<PreviewContent>> getPreviewContent({
    PreviewQueryFilter? filter,
    bool includeContentDetails = false,
  }) async {
    try {
      String tableName = includeContentDetails
          ? 'preview_content_with_details'
          : 'preview_content';

      var query = _client
          .from(tableName)
          .select('*');

      // Apply filters
      if (filter != null) {
        final params = filter.toQueryParams();
        params.forEach((key, value) {
          query = query.eq(key, value);
        });
      }

      final data = await query.order('sort_order').order('created_at');

      return data.map<PreviewContent>((item) =>
          PreviewContent.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to get preview content: $e');
    }
  }

  /// Get preview content for a specific content item
  static Future<List<PreviewContent>> getPreviewForContent({
    required PreviewContentType contentType,
    required String contentId,
    bool onlyActive = true,
  }) async {
    final filter = PreviewQueryFilter(
      contentType: contentType,
      contentId: contentId,
      isActive: onlyActive ? true : null,
    );

    return getPreviewContent(filter: filter, includeContentDetails: true);
  }

  /// Check if content has preview available
  static Future<bool> hasPreview({
    required PreviewContentType contentType,
    required String contentId,
  }) async {
    try {
      final data = await _client
          .from('preview_content')
          .select('id')
          .eq('content_type', contentType.value)
          .eq('content_id', contentId)
          .eq('is_active', true)
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      print('Error checking preview availability: $e');
      return false;
    }
  }

  /// Get the primary preview for content (first active preview)
  static Future<PreviewContent?> getPrimaryPreview({
    required PreviewContentType contentType,
    required String contentId,
  }) async {
    try {
      final previews = await getPreviewForContent(
        contentType: contentType,
        contentId: contentId,
        onlyActive: true,
      );

      return previews.isNotEmpty ? previews.first : null;
    } catch (e) {
      print('Error getting primary preview: $e');
      return null;
    }
  }

  /// Create new preview content
  static Future<PreviewOperationResult> createPreview(
      PreviewConfig config) async {
    try {
      // Validate content exists
      final contentExists = await _validateContentExists(
        config.contentType,
        config.contentId,
      );

      if (!contentExists) {
        return PreviewOperationResult.failure(
          error: 'Content with ID ${config.contentId} not found',
        );
      }

      final data = await _client
          .from('preview_content')
          .insert(config.toJson())
          .select()
          .single();

      final previewContent = PreviewContent.fromJson(data);

      return PreviewOperationResult.success(
        message: 'Preview created successfully',
        previewContent: previewContent,
      );
    } catch (e) {
      return PreviewOperationResult.failure(
        error: 'Failed to create preview: $e',
      );
    }
  }

  /// Update existing preview content
  static Future<PreviewOperationResult> updatePreview({
    required String previewId,
    required PreviewConfig config,
  }) async {
    try {
      final data = await _client
          .from('preview_content')
          .update(config.toJson())
          .eq('id', previewId)
          .select()
          .single();

      final previewContent = PreviewContent.fromJson(data);

      return PreviewOperationResult.success(
        message: 'Preview updated successfully',
        previewContent: previewContent,
      );
    } catch (e) {
      return PreviewOperationResult.failure(
        error: 'Failed to update preview: $e',
      );
    }
  }

  /// Delete preview content
  static Future<PreviewOperationResult> deletePreview(String previewId) async {
    try {
      await _client
          .from('preview_content')
          .delete()
          .eq('id', previewId);

      return PreviewOperationResult.success(
        message: 'Preview deleted successfully',
      );
    } catch (e) {
      return PreviewOperationResult.failure(
        error: 'Failed to delete preview: $e',
      );
    }
  }

  /// Toggle preview active status
  static Future<PreviewOperationResult> togglePreviewStatus(
      String previewId) async {
    try {
      // First get current status
      final current = await _client
          .from('preview_content')
          .select('is_active')
          .eq('id', previewId)
          .single();

      final newStatus = !(current['is_active'] ?? false);

      final data = await _client
          .from('preview_content')
          .update({'is_active': newStatus})
          .eq('id', previewId)
          .select()
          .single();

      final previewContent = PreviewContent.fromJson(data);

      return PreviewOperationResult.success(
        message: newStatus
            ? 'Preview activated successfully'
            : 'Preview deactivated successfully',
        previewContent: previewContent,
      );
    } catch (e) {
      return PreviewOperationResult.failure(
        error: 'Failed to toggle preview status: $e',
      );
    }
  }

  /// Get preview statistics
  static Future<Map<String, dynamic>> getPreviewStats() async {
    try {
      // Get total preview count by type
      final data = await _client
          .from('preview_content')
          .select('content_type, preview_type, is_active');

      final stats = <String, dynamic>{
        'total': data.length,
        'active': data.where((item) => item['is_active'] == true).length,
        'inactive': data.where((item) => item['is_active'] == false).length,
        'by_content_type': <String, int>{},
        'by_preview_type': <String, int>{},
      };

      // Count by content type
      for (final item in data) {
        final contentType = item['content_type'] as String;
        stats['by_content_type'][contentType] =
            (stats['by_content_type'][contentType] ?? 0) + 1;
      }

      // Count by preview type
      for (final item in data) {
        final previewType = item['preview_type'] as String;
        stats['by_preview_type'][previewType] =
            (stats['by_preview_type'][previewType] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      throw Exception('Failed to get preview statistics: $e');
    }
  }

  /// Migrate legacy preview data (from video_episodes.is_preview)
  static Future<PreviewOperationResult> migrateLegacyPreviews() async {
    try {
      // Get video episodes with is_preview = true
      final episodes = await _client
          .from('video_episodes')
          .select('id, created_at')
          .eq('is_preview', true);

      int migratedCount = 0;

      for (final episode in episodes) {
        // Check if preview already exists
        final existing = await _client
            .from('preview_content')
            .select('id')
            .eq('content_type', 'video_episode')
            .eq('content_id', episode['id']);

        if (existing.isEmpty) {
          // Create preview entry
          await _client.from('preview_content').insert({
            'content_type': 'video_episode',
            'content_id': episode['id'],
            'preview_type': 'free_trial',
            'preview_description': 'Migrated from legacy preview system',
            'is_active': true,
            'created_at': episode['created_at'],
          });
          migratedCount++;
        }
      }

      return PreviewOperationResult.success(
        message: 'Successfully migrated $migratedCount preview entries',
      );
    } catch (e) {
      return PreviewOperationResult.failure(
        error: 'Failed to migrate legacy previews: $e',
      );
    }
  }

  /// Helper: Validate that content exists in the appropriate table
  static Future<bool> _validateContentExists(
    PreviewContentType contentType,
    String contentId,
  ) async {
    try {
      String tableName;
      switch (contentType) {
        case PreviewContentType.videoEpisode:
          tableName = 'video_episodes';
          break;
        case PreviewContentType.ebook:
          tableName = 'ebooks';
          break;
        case PreviewContentType.videoKitab:
          tableName = 'video_kitab';
          break;
      }

      final data = await _client
          .from(tableName)
          .select('id')
          .eq('id', contentId)
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      print('Error validating content exists: $e');
      return false;
    }
  }

  /// Helper: Get content details for display
  static Future<Map<String, dynamic>?> getContentDetails(
    PreviewContentType contentType,
    String contentId,
  ) async {
    try {
      String tableName;
      String selectFields;

      switch (contentType) {
        case PreviewContentType.videoEpisode:
          tableName = 'video_episodes';
          selectFields = 'id, title, thumbnail_url, duration_seconds';
          break;
        case PreviewContentType.ebook:
          tableName = 'ebooks';
          selectFields = 'id, title, thumbnail_url, total_pages';
          break;
        case PreviewContentType.videoKitab:
          tableName = 'video_kitab';
          selectFields = 'id, title, thumbnail_url, total_duration_minutes';
          break;
      }

      final data = await _client
          .from(tableName)
          .select(selectFields)
          .eq('id', contentId)
          .single();

      return data;
    } catch (e) {
      print('Error getting content details: $e');
      return null;
    }
  }

  /// Bulk operations for admin management
  static Future<PreviewOperationResult> bulkUpdatePreviewStatus({
    required List<String> previewIds,
    required bool isActive,
  }) async {
    try {
      await _client
          .from('preview_content')
          .update({'is_active': isActive})
          .inFilter('id', previewIds);

      final statusText = isActive ? 'activated' : 'deactivated';

      return PreviewOperationResult.success(
        message: 'Successfully $statusText ${previewIds.length} previews',
      );
    } catch (e) {
      return PreviewOperationResult.failure(
        error: 'Failed to bulk update previews: $e',
      );
    }
  }

  /// Get orphaned preview content (where original content no longer exists)
  static Future<List<PreviewContent>> getOrphanedPreviews() async {
    try {
      final allPreviews = await getPreviewContent();
      final orphanedPreviews = <PreviewContent>[];

      for (final preview in allPreviews) {
        final contentExists = await _validateContentExists(
          preview.contentType,
          preview.contentId,
        );

        if (!contentExists) {
          orphanedPreviews.add(preview);
        }
      }

      return orphanedPreviews;
    } catch (e) {
      throw Exception('Failed to get orphaned previews: $e');
    }
  }
}