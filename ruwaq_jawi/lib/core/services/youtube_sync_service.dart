import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class YouTubeSyncService {
  static final _supabase = Supabase.instance.client;

  /// Manually trigger sync for all enabled playlists
  static Future<Map<String, dynamic>> triggerAutoSync() async {
    try {
      final response = await _supabase.functions.invoke(
        'youtube-auto-sync',
        body: {
          'triggered_by': 'manual',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (response.status == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      } else {
        throw Exception('Sync failed with status: ${response.status}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get sync logs for a specific kitab
  static Future<List<Map<String, dynamic>>> getSyncLogs({
    String? kitabId,
    int limit = 50,
  }) async {
    try {
      final query = _supabase
          .from('youtube_sync_logs')
          .select('''
            *,
            video_kitab:video_kitab_id (
              id,
              title,
              youtube_playlist_id
            )
          ''');

      final PostgrestFilterBuilder filteredQuery = kitabId != null
          ? query.eq('video_kitab_id', kitabId)
          : query;

      final response = await filteredQuery
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching sync logs: $e');
      return [];
    }
  }

  /// Get sync settings
  static Future<Map<String, String>> getSyncSettings() async {
    try {
      final response = await _supabase
          .from('youtube_sync_settings')
          .select('setting_key, setting_value');

      final Map<String, String> settings = {};
      for (final row in response) {
        settings[row['setting_key']] = row['setting_value'];
      }
      return settings;
    } catch (e) {
      debugPrint('Error fetching sync settings: $e');
      return {};
    }
  }

  /// Update sync settings (admin only)
  static Future<bool> updateSyncSetting(String key, String value) async {
    try {
      await _supabase
          .from('youtube_sync_settings')
          .update({
            'setting_value': value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('setting_key', key);
      return true;
    } catch (e) {
      debugPrint('Error updating sync setting: $e');
      return false;
    }
  }

  /// Check if auto sync is enabled
  static Future<bool> isAutoSyncEnabled() async {
    try {
      final settings = await getSyncSettings();
      return settings['auto_sync_enabled'] == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Get playlists that need syncing
  static Future<List<Map<String, dynamic>>> getPlaylistsForSync() async {
    try {
      final response = await _supabase.rpc('get_playlists_for_sync');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching playlists for sync: $e');
      return [];
    }
  }

  /// Sync a specific playlist manually
  static Future<Map<String, dynamic>> syncPlaylist({
    required String playlistUrl,
    required String categoryId,
    bool isPremium = false,
    bool isActive = true,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'youtube-playlist-sync',
        body: {
          'playlist_url': playlistUrl,
          'category_id': categoryId,
          'is_premium': isPremium,
          'is_active': isActive,
        },
      );

      if (response.status == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      } else {
        throw Exception('Sync failed with status: ${response.status}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Check if a YouTube URL is a valid playlist
  static bool isValidPlaylistUrl(String url) {
    final playlistRegex = RegExp(r'[?&]list=([^&]+)');
    return playlistRegex.hasMatch(url);
  }

  /// Extract playlist ID from URL
  static String? extractPlaylistId(String url) {
    final match = RegExp(r'[?&]list=([^&]+)').firstMatch(url);
    return match?.group(1);
  }

  /// Format sync status for display
  static String formatSyncStatus(String status) {
    switch (status) {
      case 'success':
        return 'Successful';
      case 'error':
        return 'Failed';
      case 'pending':
        return 'In Progress';
      default:
        return 'Unknown';
    }
  }

  /// Format sync type for display
  static String formatSyncType(String type) {
    switch (type) {
      case 'manual':
        return 'Manual';
      case 'auto':
        return 'Automatic';
      case 'scheduled':
        return 'Scheduled';
      default:
        return 'Unknown';
    }
  }
}