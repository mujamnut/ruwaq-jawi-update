import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/kitab.dart';
import '../models/ebook.dart';
import '../models/video_episode.dart';

/// Service to fetch saved items from Supabase user interaction tables
/// for the currently authenticated user
class SupabaseSavedItemsService {
  static final _supabase = Supabase.instance.client;

  /// Get all saved kitabs for current user from video_kitab_user_interactions
  static Future<List<Kitab>> getSavedKitabs() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        // Debug logging removed
        return [];
      }

      // Debug logging removed

      final response = await _supabase
          .from('video_kitab_user_interactions')
          .select('''
            id,
            is_saved,
            video_kitab:video_kitab_id (
              id,
              title,
              author,
              description,
              thumbnail_url,
              category_id,
              is_premium,
              is_active,
              total_duration_minutes,
              views_count,
              created_at,
              updated_at
            )
          ''')
          .eq('user_id', user.id)
          .eq('is_saved', true)
          .order('updated_at', ascending: false);

      // Debug logging removed

      final List<Kitab> kitabs = [];
      for (final item in response) {
        if (item['video_kitab'] != null) {
          final kitabData = item['video_kitab'] as Map<String, dynamic>;
          kitabs.add(Kitab.fromJson(kitabData));
        }
      }

      // Debug logging removed
      return kitabs;
    } catch (e) {
      // Debug logging removed
      return [];
    }
  }

  /// Get all saved episodes for current user from video_episode_user_interactions
  static Future<List<VideoEpisode>> getSavedEpisodes() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        // Debug logging removed
        return [];
      }

      // Debug logging removed

      final response = await _supabase
          .from('video_episode_user_interactions')
          .select('''
            id,
            is_saved,
            video_episodes:episode_id (
              id,
              title,
              description,
              youtube_video_id,
              youtube_video_url,
              thumbnail_url,
              duration_minutes,
              duration_seconds,
              part_number,
              video_kitab_id,
              is_premium,
              is_active,
              created_at,
              updated_at
            )
          ''')
          .eq('user_id', user.id)
          .eq('is_saved', true)
          .order('updated_at', ascending: false);

      // Debug logging removed

      final List<VideoEpisode> episodes = [];
      for (final item in response) {
        if (item['video_episodes'] != null) {
          final episodeData = item['video_episodes'] as Map<String, dynamic>;
          episodes.add(VideoEpisode.fromJson(episodeData));
        }
      }

      // Debug logging removed
      return episodes;
    } catch (e) {
      // Debug logging removed
      return [];
    }
  }

  /// Get all saved ebooks for current user from ebook_user_interactions
  static Future<List<Ebook>> getSavedEbooks() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        // Debug logging removed
        return [];
      }

      // Debug logging removed

      final response = await _supabase
          .from('ebook_user_interactions')
          .select('''
            id,
            is_saved,
            ebooks:ebook_id (
              id,
              title,
              author,
              description,
              category_id,
              pdf_url,
              pdf_storage_path,
              pdf_file_size,
              thumbnail_url,
              total_pages,
              is_premium,
              is_active,
              created_at,
              updated_at
            )
          ''')
          .eq('user_id', user.id)
          .eq('is_saved', true)
          .order('updated_at', ascending: false);

      // Debug logging removed

      final List<Ebook> ebooks = [];
      for (final item in response) {
        if (item['ebooks'] != null) {
          final ebookData = item['ebooks'] as Map<String, dynamic>;
          ebooks.add(Ebook.fromJson(ebookData));
        }
      }

      // Debug logging removed
      return ebooks;
    } catch (e) {
      // Debug logging removed
      return [];
    }
  }

  /// Toggle save status for a kitab
  static Future<bool> toggleKitabSaved(String kitabId, bool isSaved) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        // Debug logging removed
        return false;
      }

      // Check if interaction exists
      final existing = await _supabase
          .from('video_kitab_user_interactions')
          .select('id')
          .eq('user_id', user.id)
          .eq('video_kitab_id', kitabId)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await _supabase
            .from('video_kitab_user_interactions')
            .update({'is_saved': isSaved, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', existing['id']);
      } else {
        // Insert new
        await _supabase.from('video_kitab_user_interactions').insert({
          'user_id': user.id,
          'video_kitab_id': kitabId,
          'is_saved': isSaved,
        });
      }

      return true;
    } catch (e) {
      // Debug logging removed
      return false;
    }
  }

  /// Toggle save status for an episode
  static Future<bool> toggleEpisodeSaved(String episodeId, bool isSaved) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        // Debug logging removed
        return false;
      }

      // Check if interaction exists
      final existing = await _supabase
          .from('video_episode_user_interactions')
          .select('id')
          .eq('user_id', user.id)
          .eq('episode_id', episodeId)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await _supabase
            .from('video_episode_user_interactions')
            .update({'is_saved': isSaved, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', existing['id']);
      } else {
        // Insert new
        await _supabase.from('video_episode_user_interactions').insert({
          'user_id': user.id,
          'episode_id': episodeId,
          'is_saved': isSaved,
        });
      }

      return true;
    } catch (e) {
      // Debug logging removed
      return false;
    }
  }

  /// Toggle save status for an ebook
  static Future<bool> toggleEbookSaved(String ebookId, bool isSaved) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        // Debug logging removed
        return false;
      }

      // Check if interaction exists
      final existing = await _supabase
          .from('ebook_user_interactions')
          .select('id')
          .eq('user_id', user.id)
          .eq('ebook_id', ebookId)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await _supabase
            .from('ebook_user_interactions')
            .update({'is_saved': isSaved, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', existing['id']);
      } else {
        // Insert new
        await _supabase.from('ebook_user_interactions').insert({
          'user_id': user.id,
          'ebook_id': ebookId,
          'is_saved': isSaved,
        });
      }

      return true;
    } catch (e) {
      // Debug logging removed
      return false;
    }
  }

  /// Check if a kitab is saved
  static Future<bool> isKitabSaved(String kitabId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('video_kitab_user_interactions')
          .select('is_saved')
          .eq('user_id', user.id)
          .eq('video_kitab_id', kitabId)
          .maybeSingle();

      return response?['is_saved'] == true;
    } catch (e) {
      // Debug logging removed
      return false;
    }
  }

  /// Check if an episode is saved
  static Future<bool> isEpisodeSaved(String episodeId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('video_episode_user_interactions')
          .select('is_saved')
          .eq('user_id', user.id)
          .eq('episode_id', episodeId)
          .maybeSingle();

      return response?['is_saved'] == true;
    } catch (e) {
      // Debug logging removed
      return false;
    }
  }

  /// Check if an ebook is saved
  static Future<bool> isEbookSaved(String ebookId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('ebook_user_interactions')
          .select('is_saved')
          .eq('user_id', user.id)
          .eq('ebook_id', ebookId)
          .maybeSingle();

      return response?['is_saved'] == true;
    } catch (e) {
      // Debug logging removed
      return false;
    }
  }
}
