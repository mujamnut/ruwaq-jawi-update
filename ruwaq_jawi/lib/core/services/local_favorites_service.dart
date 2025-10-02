import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'supabase_favorites_service.dart';

class LocalFavoritesService {
  static const String _boxName = 'favorites';
  static const String _videoKitabFavoritesKey = 'video_kitab_favorites';
  static const String _ebookFavoritesKey = 'ebook_favorites';
  static const String _videoEpisodeFavoritesKey = 'video_episode_favorites';
  static const String _migrationCompleteKey = 'migration_to_supabase_complete';

  static Box<dynamic>? _box;

  /// Initialize the favorites service
  static Future<void> initialize() async {
    try {
      _box = await Hive.openBox(_boxName);
    } catch (e) {
      print('Error initializing LocalFavoritesService: $e');
    }
  }

  /// Get the favorites box
  static Box<dynamic> get _favoritesBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('LocalFavoritesService not initialized. Call initialize() first.');
    }
    return _box!;
  }

  /// Check if a video kitab is saved as favorite
  static bool isVideoKitabFavorite(String videoKitabId) {
    try {
      final favorites = _favoritesBox.get(_videoKitabFavoritesKey, defaultValue: <String>[]) as List;
      return favorites.contains(videoKitabId);
    } catch (e) {
      print('Error checking video kitab favorite status: $e');
      return false;
    }
  }

  /// Add video kitab to favorites (dual-write: local + Supabase)
  static Future<bool> addVideoKitabToFavorites(String videoKitabId) async {
    try {
      // Write to local Hive first (fast)
      final favorites = _favoritesBox.get(_videoKitabFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);

      if (!updatedFavorites.contains(videoKitabId)) {
        updatedFavorites.add(videoKitabId);
        await _favoritesBox.put(_videoKitabFavoritesKey, updatedFavorites);
      }

      // Then sync to Supabase (background)
      SupabaseFavoritesService.saveVideoKitab(videoKitabId).catchError((e) {
        if (kDebugMode) {
          print('Supabase sync failed (video kitab save): $e');
        }
      });

      return true;
    } catch (e) {
      print('Error adding video kitab to favorites: $e');
      return false;
    }
  }

  /// Remove video kitab from favorites (dual-write: local + Supabase)
  static Future<bool> removeVideoKitabFromFavorites(String videoKitabId) async {
    try {
      // Remove from local Hive first (fast)
      final favorites = _favoritesBox.get(_videoKitabFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);

      if (updatedFavorites.contains(videoKitabId)) {
        updatedFavorites.remove(videoKitabId);
        await _favoritesBox.put(_videoKitabFavoritesKey, updatedFavorites);
      }

      // Then sync to Supabase (background)
      SupabaseFavoritesService.unsaveVideoKitab(videoKitabId).catchError((e) {
        if (kDebugMode) {
          print('Supabase sync failed (video kitab unsave): $e');
        }
      });

      return true;
    } catch (e) {
      print('Error removing video kitab from favorites: $e');
      return false;
    }
  }

  /// Get all favorite video kitab IDs
  static List<String> getFavoriteVideoKitabIds() {
    try {
      final favorites = _favoritesBox.get(_videoKitabFavoritesKey, defaultValue: <String>[]) as List;
      return List<String>.from(favorites);
    } catch (e) {
      print('Error getting favorite video kitab IDs: $e');
      return [];
    }
  }

  /// Check if an ebook is saved as favorite
  static bool isEbookFavorite(String ebookId) {
    try {
      final favorites = _favoritesBox.get(_ebookFavoritesKey, defaultValue: <String>[]) as List;
      return favorites.contains(ebookId);
    } catch (e) {
      print('Error checking ebook favorite status: $e');
      return false;
    }
  }

  /// Add ebook to favorites (dual-write: local + Supabase)
  static Future<bool> addEbookToFavorites(String ebookId) async {
    try {
      final favorites = _favoritesBox.get(_ebookFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);

      if (!updatedFavorites.contains(ebookId)) {
        updatedFavorites.add(ebookId);
        await _favoritesBox.put(_ebookFavoritesKey, updatedFavorites);
      }

      // Sync to Supabase (background)
      SupabaseFavoritesService.saveEbook(ebookId).catchError((e) {
        if (kDebugMode) {
          print('Supabase sync failed (ebook save): $e');
        }
      });

      return true;
    } catch (e) {
      print('Error adding ebook to favorites: $e');
      return false;
    }
  }

  /// Remove ebook from favorites (dual-write: local + Supabase)
  static Future<bool> removeEbookFromFavorites(String ebookId) async {
    try {
      final favorites = _favoritesBox.get(_ebookFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);

      if (updatedFavorites.contains(ebookId)) {
        updatedFavorites.remove(ebookId);
        await _favoritesBox.put(_ebookFavoritesKey, updatedFavorites);
      }

      // Sync to Supabase (background)
      SupabaseFavoritesService.unsaveEbook(ebookId).catchError((e) {
        if (kDebugMode) {
          print('Supabase sync failed (ebook unsave): $e');
        }
      });

      return true;
    } catch (e) {
      print('Error removing ebook from favorites: $e');
      return false;
    }
  }

  /// Get all favorite ebook IDs
  static List<String> getFavoriteEbookIds() {
    try {
      final favorites = _favoritesBox.get(_ebookFavoritesKey, defaultValue: <String>[]) as List;
      return List<String>.from(favorites);
    } catch (e) {
      print('Error getting favorite ebook IDs: $e');
      return [];
    }
  }

  /// Check if a video episode is saved as favorite
  static bool isVideoEpisodeFavorite(String episodeId) {
    try {
      final favorites = _favoritesBox.get(_videoEpisodeFavoritesKey, defaultValue: <String>[]) as List;
      return favorites.contains(episodeId);
    } catch (e) {
      print('Error checking video episode favorite status: $e');
      return false;
    }
  }

  /// Add video episode to favorites (dual-write: local + Supabase)
  static Future<bool> addVideoEpisodeToFavorites(String episodeId) async {
    try {
      final favorites = _favoritesBox.get(_videoEpisodeFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);

      if (!updatedFavorites.contains(episodeId)) {
        updatedFavorites.add(episodeId);
        await _favoritesBox.put(_videoEpisodeFavoritesKey, updatedFavorites);
      }

      // Sync to Supabase (background)
      SupabaseFavoritesService.saveVideoEpisode(episodeId).catchError((e) {
        if (kDebugMode) {
          print('Supabase sync failed (episode save): $e');
        }
      });

      return true;
    } catch (e) {
      print('Error adding video episode to favorites: $e');
      return false;
    }
  }

  /// Remove video episode from favorites (dual-write: local + Supabase)
  static Future<bool> removeVideoEpisodeFromFavorites(String episodeId) async {
    try {
      final favorites = _favoritesBox.get(_videoEpisodeFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);

      if (updatedFavorites.contains(episodeId)) {
        updatedFavorites.remove(episodeId);
        await _favoritesBox.put(_videoEpisodeFavoritesKey, updatedFavorites);
      }

      // Sync to Supabase (background)
      SupabaseFavoritesService.unsaveVideoEpisode(episodeId).catchError((e) {
        if (kDebugMode) {
          print('Supabase sync failed (episode unsave): $e');
        }
      });

      return true;
    } catch (e) {
      print('Error removing video episode from favorites: $e');
      return false;
    }
  }

  /// Get all favorite video episode IDs
  static List<String> getFavoriteVideoEpisodeIds() {
    try {
      final favorites = _favoritesBox.get(_videoEpisodeFavoritesKey, defaultValue: <String>[]) as List;
      return List<String>.from(favorites);
    } catch (e) {
      print('Error getting favorite video episode IDs: $e');
      return [];
    }
  }

  /// Clear all favorites (for testing or reset)
  static Future<void> clearAllFavorites() async {
    try {
      await _favoritesBox.delete(_videoKitabFavoritesKey);
      await _favoritesBox.delete(_ebookFavoritesKey);
      await _favoritesBox.delete(_videoEpisodeFavoritesKey);
    } catch (e) {
      print('Error clearing all favorites: $e');
    }
  }

  /// Close the favorites box
  static Future<void> close() async {
    try {
      await _box?.close();
      _box = null;
    } catch (e) {
      print('Error closing LocalFavoritesService: $e');
    }
  }

  // ==================== MIGRATION LOGIC ====================

  /// Check if migration to Supabase is complete
  static bool isMigrationComplete() {
    try {
      return _favoritesBox.get(_migrationCompleteKey, defaultValue: false) as bool;
    } catch (e) {
      return false;
    }
  }

  /// Migrate all local favorites to Supabase (one-time operation)
  static Future<bool> migrateToSupabase() async {
    try {
      if (isMigrationComplete()) {
        if (kDebugMode) {
          print('✅ Migration already completed, skipping');
        }
        return true;
      }

      if (kDebugMode) {
        print('🔄 Starting migration of local favorites to Supabase...');
      }

      // Get all local favorites
      final videoKitabs = getFavoriteVideoKitabIds();
      final ebooks = getFavoriteEbookIds();
      final episodes = getFavoriteVideoEpisodeIds();

      if (kDebugMode) {
        print('📦 Found: ${videoKitabs.length} kitabs, ${ebooks.length} ebooks, ${episodes.length} episodes');
      }

      // Batch upload to Supabase
      bool success = true;

      if (videoKitabs.isNotEmpty) {
        final kitabSuccess = await SupabaseFavoritesService.batchSaveVideoKitabs(videoKitabs);
        success = success && kitabSuccess;
      }

      if (ebooks.isNotEmpty) {
        final ebookSuccess = await SupabaseFavoritesService.batchSaveEbooks(ebooks);
        success = success && ebookSuccess;
      }

      if (episodes.isNotEmpty) {
        final episodeSuccess = await SupabaseFavoritesService.batchSaveVideoEpisodes(episodes);
        success = success && episodeSuccess;
      }

      if (success) {
        // Mark migration as complete
        await _favoritesBox.put(_migrationCompleteKey, true);
        if (kDebugMode) {
          print('✅ Migration completed successfully!');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ Migration completed with some errors');
        }
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Migration failed: $e');
      }
      return false;
    }
  }

  /// Reset migration flag (for testing)
  static Future<void> resetMigrationFlag() async {
    try {
      await _favoritesBox.delete(_migrationCompleteKey);
      if (kDebugMode) {
        print('🔄 Migration flag reset');
      }
    } catch (e) {
      print('Error resetting migration flag: $e');
    }
  }
}