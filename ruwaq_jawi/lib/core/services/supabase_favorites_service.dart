import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing user favorites using Supabase user_interactions tables
/// Provides cloud-synced favorites across devices
class SupabaseFavoritesService {
  static final _supabase = Supabase.instance.client;

  // ==================== VIDEO KITAB ====================

  /// Check if video kitab is saved
  static Future<bool> isVideoKitabSaved(String videoKitabId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('video_kitab_user_interactions')
          .select('is_saved')
          .eq('user_id', userId)
          .eq('video_kitab_id', videoKitabId)
          .maybeSingle();

      return response?['is_saved'] ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking video kitab save status: $e');
      }
      return false;
    }
  }

  /// Save video kitab
  static Future<bool> saveVideoKitab(String videoKitabId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) print('❌ No user ID for saving video kitab');
        return false;
      }

      if (kDebugMode) {
        print('🔄 Attempting to save video kitab: $videoKitabId (user: $userId)');
      }

      final response = await _supabase
          .from('video_kitab_user_interactions')
          .upsert({
            'user_id': userId,
            'video_kitab_id': videoKitabId,
            'is_saved': true,
          }, onConflict: 'user_id,video_kitab_id')
          .select();

      if (kDebugMode) {
        print('✅ Video kitab saved successfully: $videoKitabId');
        print('   Response: $response');
      }
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error saving video kitab: $videoKitabId');
        print('   Error: $e');
        print('   Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Unsave video kitab
  static Future<bool> unsaveVideoKitab(String videoKitabId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.from('video_kitab_user_interactions').upsert({
        'user_id': userId,
        'video_kitab_id': videoKitabId,
        'is_saved': false,
      }, onConflict: 'user_id,video_kitab_id');

      if (kDebugMode) {
        print('✅ Video kitab unsaved: $videoKitabId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error unsaving video kitab: $e');
      }
      return false;
    }
  }

  /// Get all saved video kitab IDs
  static Future<List<String>> getSavedVideoKitabIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('video_kitab_user_interactions')
          .select('video_kitab_id')
          .eq('user_id', userId)
          .eq('is_saved', true);

      return (response as List)
          .map((item) => item['video_kitab_id'] as String)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting saved video kitabs: $e');
      }
      return [];
    }
  }

  // ==================== EBOOK ====================

  /// Check if ebook is saved
  static Future<bool> isEbookSaved(String ebookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('ebook_user_interactions')
          .select('is_saved')
          .eq('user_id', userId)
          .eq('ebook_id', ebookId)
          .maybeSingle();

      return response?['is_saved'] ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking ebook save status: $e');
      }
      return false;
    }
  }

  /// Save ebook
  static Future<bool> saveEbook(String ebookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) print('❌ No user ID for saving ebook');
        return false;
      }

      if (kDebugMode) {
        print('🔄 Attempting to save ebook: $ebookId (user: $userId)');
      }

      final response = await _supabase
          .from('ebook_user_interactions')
          .upsert({
            'user_id': userId,
            'ebook_id': ebookId,
            'is_saved': true,
          }, onConflict: 'user_id,ebook_id')
          .select();

      if (kDebugMode) {
        print('✅ Ebook saved successfully: $ebookId');
        print('   Response: $response');
      }
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error saving ebook: $ebookId');
        print('   Error: $e');
        print('   Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Unsave ebook
  static Future<bool> unsaveEbook(String ebookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.from('ebook_user_interactions').upsert({
        'user_id': userId,
        'ebook_id': ebookId,
        'is_saved': false,
      }, onConflict: 'user_id,ebook_id');

      if (kDebugMode) {
        print('✅ Ebook unsaved: $ebookId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error unsaving ebook: $e');
      }
      return false;
    }
  }

  /// Get all saved ebook IDs
  static Future<List<String>> getSavedEbookIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('ebook_user_interactions')
          .select('ebook_id')
          .eq('user_id', userId)
          .eq('is_saved', true);

      return (response as List)
          .map((item) => item['ebook_id'] as String)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting saved ebooks: $e');
      }
      return [];
    }
  }

  // ==================== VIDEO EPISODE ====================

  /// Check if video episode is saved
  static Future<bool> isVideoEpisodeSaved(String episodeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('video_episode_user_interactions')
          .select('is_saved')
          .eq('user_id', userId)
          .eq('episode_id', episodeId)
          .maybeSingle();

      return response?['is_saved'] ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking video episode save status: $e');
      }
      return false;
    }
  }

  /// Save video episode
  static Future<bool> saveVideoEpisode(String episodeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) print('❌ No user ID for saving video episode');
        return false;
      }

      if (kDebugMode) {
        print('🔄 Attempting to save video episode: $episodeId (user: $userId)');
      }

      final response = await _supabase
          .from('video_episode_user_interactions')
          .upsert({
            'user_id': userId,
            'episode_id': episodeId,
            'is_saved': true,
          }, onConflict: 'user_id,episode_id')
          .select();

      if (kDebugMode) {
        print('✅ Video episode saved successfully: $episodeId');
        print('   Response: $response');
      }
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error saving video episode: $episodeId');
        print('   Error: $e');
        print('   Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Unsave video episode
  static Future<bool> unsaveVideoEpisode(String episodeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.from('video_episode_user_interactions').upsert({
        'user_id': userId,
        'episode_id': episodeId,
        'is_saved': false,
      }, onConflict: 'user_id,episode_id');

      if (kDebugMode) {
        print('✅ Video episode unsaved: $episodeId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error unsaving video episode: $e');
      }
      return false;
    }
  }

  /// Get all saved video episode IDs
  static Future<List<String>> getSavedVideoEpisodeIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('video_episode_user_interactions')
          .select('episode_id')
          .eq('user_id', userId)
          .eq('is_saved', true);

      return (response as List)
          .map((item) => item['episode_id'] as String)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting saved video episodes: $e');
      }
      return [];
    }
  }

  // ==================== BATCH OPERATIONS ====================

  /// Batch save multiple items (for migration)
  static Future<bool> batchSaveVideoKitabs(List<String> kitabIds) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) print('❌ No user ID for batch saving video kitabs');
        return false;
      }

      if (kitabIds.isEmpty) {
        if (kDebugMode) print('⚠️ No video kitabs to save');
        return true;
      }

      if (kDebugMode) {
        print('🔄 Batch saving ${kitabIds.length} video kitabs...');
        print('   Sample IDs: ${kitabIds.take(3).join(", ")}');
      }

      final data = kitabIds
          .map((id) => {
                'user_id': userId,
                'video_kitab_id': id,
                'is_saved': true,
              })
          .toList();

      final response = await _supabase
          .from('video_kitab_user_interactions')
          .upsert(data, onConflict: 'user_id,video_kitab_id')
          .select();

      if (kDebugMode) {
        print('✅ Batch saved ${kitabIds.length} video kitabs successfully');
        print('   Inserted/updated: ${response.length} rows');
      }
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error batch saving video kitabs');
        print('   Error: $e');
        print('   Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Batch save multiple ebooks (for migration)
  static Future<bool> batchSaveEbooks(List<String> ebookIds) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) print('❌ No user ID for batch saving ebooks');
        return false;
      }

      if (ebookIds.isEmpty) {
        if (kDebugMode) print('⚠️ No ebooks to save');
        return true;
      }

      if (kDebugMode) {
        print('🔄 Batch saving ${ebookIds.length} ebooks...');
        print('   Sample IDs: ${ebookIds.take(3).join(", ")}');
      }

      final data = ebookIds
          .map((id) => {
                'user_id': userId,
                'ebook_id': id,
                'is_saved': true,
              })
          .toList();

      final response = await _supabase
          .from('ebook_user_interactions')
          .upsert(data, onConflict: 'user_id,ebook_id')
          .select();

      if (kDebugMode) {
        print('✅ Batch saved ${ebookIds.length} ebooks successfully');
        print('   Inserted/updated: ${response.length} rows');
      }
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error batch saving ebooks');
        print('   Error: $e');
        print('   Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Batch save multiple video episodes (for migration)
  static Future<bool> batchSaveVideoEpisodes(List<String> episodeIds) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) print('❌ No user ID for batch saving video episodes');
        return false;
      }

      if (episodeIds.isEmpty) {
        if (kDebugMode) print('⚠️ No video episodes to save');
        return true;
      }

      if (kDebugMode) {
        print('🔄 Batch saving ${episodeIds.length} video episodes...');
        print('   Sample IDs: ${episodeIds.take(3).join(", ")}');
      }

      final data = episodeIds
          .map((id) => {
                'user_id': userId,
                'episode_id': id,
                'is_saved': true,
              })
          .toList();

      final response = await _supabase
          .from('video_episode_user_interactions')
          .upsert(data, onConflict: 'user_id,episode_id')
          .select();

      if (kDebugMode) {
        print('✅ Batch saved ${episodeIds.length} video episodes successfully');
        print('   Inserted/updated: ${response.length} rows');
      }
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error batch saving video episodes');
        print('   Error: $e');
        print('   Stack trace: $stackTrace');
      }
      return false;
    }
  }
}
