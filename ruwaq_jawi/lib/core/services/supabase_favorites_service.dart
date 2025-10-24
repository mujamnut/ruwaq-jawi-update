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
        // Debug logging removed
      }
      return false;
    }
  }

  /// Save video kitab
  static Future<bool> saveVideoKitab(String videoKitabId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return false;
      }

      if (kDebugMode) {
        // Debug logging removed
      }

      await _supabase
          .from('video_kitab_user_interactions')
          .upsert({
            'user_id': userId,
            'video_kitab_id': videoKitabId,
            'is_saved': true,
          }, onConflict: 'user_id,video_kitab_id')
          .select();

      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
        // Debug logging removed
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
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
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
        // Debug logging removed
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
        // Debug logging removed
      }
      return false;
    }
  }

  /// Save ebook
  static Future<bool> saveEbook(String ebookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return false;
      }

      if (kDebugMode) {
        // Debug logging removed
      }

      await _supabase
          .from('ebook_user_interactions')
          .upsert({
            'user_id': userId,
            'ebook_id': ebookId,
            'is_saved': true,
          }, onConflict: 'user_id,ebook_id')
          .select();

      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
        // Debug logging removed
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
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
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
        // Debug logging removed
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
        // Debug logging removed
      }
      return false;
    }
  }

  /// Save video episode
  static Future<bool> saveVideoEpisode(String episodeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return false;
      }

      if (kDebugMode) {
        // Debug logging removed
      }

      await _supabase
          .from('video_episode_user_interactions')
          .upsert({
            'user_id': userId,
            'episode_id': episodeId,
            'is_saved': true,
          }, onConflict: 'user_id,episode_id')
          .select();

      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
        // Debug logging removed
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
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
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
        // Debug logging removed
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
        if (kDebugMode) {
          // Debug logging removed
        }
        return false;
      }

      if (kitabIds.isEmpty) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return true;
      }

      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
      }

      final data = kitabIds
          .map((id) => {
                'user_id': userId,
                'video_kitab_id': id,
                'is_saved': true,
              })
          .toList();

      await _supabase
          .from('video_kitab_user_interactions')
          .upsert(data, onConflict: 'user_id,video_kitab_id')
          .select();

      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
        // Debug logging removed
      }
      return false;
    }
  }

  /// Batch save multiple ebooks (for migration)
  static Future<bool> batchSaveEbooks(List<String> ebookIds) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return false;
      }

      if (ebookIds.isEmpty) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return true;
      }

      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
      }

      final data = ebookIds
          .map((id) => {
                'user_id': userId,
                'ebook_id': id,
                'is_saved': true,
              })
          .toList();

      await _supabase
          .from('ebook_user_interactions')
          .upsert(data, onConflict: 'user_id,ebook_id')
          .select();

      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
        // Debug logging removed
      }
      return false;
    }
  }

  /// Batch save multiple video episodes (for migration)
  static Future<bool> batchSaveVideoEpisodes(List<String> episodeIds) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return false;
      }

      if (episodeIds.isEmpty) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return true;
      }

      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
      }

      final data = episodeIds
          .map((id) => {
                'user_id': userId,
                'episode_id': id,
                'is_saved': true,
              })
          .toList();

      await _supabase
          .from('video_episode_user_interactions')
          .upsert(data, onConflict: 'user_id,episode_id')
          .select();

      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
        // Debug logging removed
      }
      return false;
    }
  }
}
