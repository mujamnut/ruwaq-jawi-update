import 'package:flutter/foundation.dart';

import '../models/ebook.dart';
import '../models/kitab.dart';
import '../models/video_episode.dart';
import '../services/supabase_saved_items_service.dart';
import '../services/supabase_favorites_service.dart';

/// Provider untuk manage saved items (favorites) - SUPABASE ONLY
/// Guna interaction tables:
/// - ebook_user_interactions
/// - video_kitab_user_interactions
/// - video_episode_user_interactions
class SavedItemsProvider extends ChangeNotifier {
  List<Kitab> _savedKitab = [];
  List<Ebook> _savedEbooks = [];
  List<VideoEpisode> _savedEpisodes = [];

  bool _isLoading = false;
  String? _error;

  List<Kitab> get savedKitab => _savedKitab;
  List<Ebook> get savedEbooks => _savedEbooks;
  List<VideoEpisode> get savedEpisodes => _savedEpisodes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all saved items from Supabase interaction tables
  Future<void> loadSavedItems() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final results = await Future.wait([
        SupabaseSavedItemsService.getSavedKitabs(),
        SupabaseSavedItemsService.getSavedEpisodes(),
        SupabaseSavedItemsService.getSavedEbooks(),
      ]);

      _savedKitab = results[0] as List<Kitab>;
      _savedEpisodes = results[1] as List<VideoEpisode>;
      _savedEbooks = results[2] as List<Ebook>;

      debugPrint('✅ Loaded saved items: ${_savedKitab.length} kitabs, ${_savedEpisodes.length} episodes, ${_savedEbooks.length} ebooks');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading saved items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== KITAB METHODS ====================

  /// Check if kitab is saved
  bool isKitabSaved(String kitabId) {
    return _savedKitab.any((k) => k.id == kitabId);
  }

  /// Check if kitab saved (async version untuk compatibility)
  Future<bool> isSaved(String kitabId) async {
    return isKitabSaved(kitabId);
  }

  /// Toggle kitab saved status
  Future<bool> toggleKitabSaved(Kitab kitab) async {
    try {
      final isSaved = isKitabSaved(kitab.id);

      if (isSaved) {
        // Unsave
        await SupabaseFavoritesService.unsaveVideoKitab(kitab.id);
        _savedKitab.removeWhere((k) => k.id == kitab.id);
        debugPrint('✅ Video kitab unsaved: ${kitab.id}');
      } else {
        // Save
        await SupabaseFavoritesService.saveVideoKitab(kitab.id);
        _savedKitab.insert(0, kitab);
        debugPrint('✅ Video kitab saved: ${kitab.id}');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error toggling kitab saved: $e');
      notifyListeners();
      return false;
    }
  }

  /// Add kitab to saved (untuk compatibility)
  Future<bool> addToSaved(String kitabId, {String folderName = 'Default'}) async {
    try {
      await SupabaseFavoritesService.saveVideoKitab(kitabId);
      await loadSavedItems();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error adding kitab to saved: $e');
      return false;
    }
  }

  /// Remove kitab from saved (untuk compatibility)
  Future<bool> removeFromSaved(String kitabId) async {
    try {
      await SupabaseFavoritesService.unsaveVideoKitab(kitabId);
      _savedKitab.removeWhere((k) => k.id == kitabId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error removing kitab from saved: $e');
      return false;
    }
  }

  // ==================== EBOOK METHODS ====================

  /// Check if ebook is saved
  bool isEbookSaved(String ebookId) {
    return _savedEbooks.any((e) => e.id == ebookId);
  }

  /// Toggle ebook saved status
  Future<bool> toggleEbookSaved(Ebook ebook) async {
    try {
      final isSaved = isEbookSaved(ebook.id);

      if (isSaved) {
        // Unsave
        await SupabaseFavoritesService.unsaveEbook(ebook.id);
        _savedEbooks.removeWhere((e) => e.id == ebook.id);
        debugPrint('✅ Ebook unsaved: ${ebook.id}');
      } else {
        // Save
        await SupabaseFavoritesService.saveEbook(ebook.id);
        _savedEbooks.insert(0, ebook);
        debugPrint('✅ Ebook saved: ${ebook.id}');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error toggling ebook saved: $e');
      notifyListeners();
      return false;
    }
  }

  // ==================== EPISODE METHODS ====================

  /// Check if episode is saved
  bool isEpisodeSaved(String episodeId) {
    return _savedEpisodes.any((e) => e.id == episodeId);
  }

  /// Check if video saved (untuk compatibility)
  bool isVideoSaved(String videoId) {
    return isEpisodeSaved(videoId);
  }

  /// Toggle episode saved status
  Future<bool> toggleEpisodeSaved(VideoEpisode episode) async {
    try {
      final isSaved = isEpisodeSaved(episode.id);

      if (isSaved) {
        // Unsave
        await SupabaseFavoritesService.unsaveVideoEpisode(episode.id);
        _savedEpisodes.removeWhere((e) => e.id == episode.id);
        debugPrint('✅ Episode unsaved: ${episode.id}');
      } else {
        // Save
        await SupabaseFavoritesService.saveVideoEpisode(episode.id);
        _savedEpisodes.insert(0, episode);
        debugPrint('✅ Episode saved: ${episode.id}');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error toggling episode saved: $e');
      notifyListeners();
      return false;
    }
  }

  /// Add video to saved (untuk compatibility dengan save_video_button)
  Future<bool> addVideoToSaved(
    String videoId,
    String videoTitle,
    String? videoUrl,
  ) async {
    try {
      await SupabaseFavoritesService.saveVideoEpisode(videoId);
      await loadSavedItems();
      debugPrint('✅ Video saved: $videoTitle');
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error adding video to saved: $e');
      return false;
    }
  }

  /// Remove video from saved (untuk compatibility)
  Future<bool> removeVideoFromSaved(String videoId) async {
    try {
      await SupabaseFavoritesService.unsaveVideoEpisode(videoId);
      _savedEpisodes.removeWhere((e) => e.id == videoId);
      notifyListeners();
      debugPrint('✅ Video removed from saved: $videoId');
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error removing video from saved: $e');
      return false;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh saved items
  Future<void> refresh() async {
    clearError();
    await loadSavedItems();
  }

  /// Clear all data
  void clear() {
    _savedKitab.clear();
    _savedEbooks.clear();
    _savedEpisodes.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
