import 'package:hive_flutter/hive_flutter.dart';

class LocalFavoritesService {
  static const String _boxName = 'favorites';
  static const String _videoKitabFavoritesKey = 'video_kitab_favorites';
  static const String _ebookFavoritesKey = 'ebook_favorites';
  static const String _videoEpisodeFavoritesKey = 'video_episode_favorites';
  
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

  /// Add video kitab to favorites
  static Future<bool> addVideoKitabToFavorites(String videoKitabId) async {
    try {
      final favorites = _favoritesBox.get(_videoKitabFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);
      
      if (!updatedFavorites.contains(videoKitabId)) {
        updatedFavorites.add(videoKitabId);
        await _favoritesBox.put(_videoKitabFavoritesKey, updatedFavorites);
      }
      
      return true;
    } catch (e) {
      print('Error adding video kitab to favorites: $e');
      return false;
    }
  }

  /// Remove video kitab from favorites
  static Future<bool> removeVideoKitabFromFavorites(String videoKitabId) async {
    try {
      final favorites = _favoritesBox.get(_videoKitabFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);
      
      if (updatedFavorites.contains(videoKitabId)) {
        updatedFavorites.remove(videoKitabId);
        await _favoritesBox.put(_videoKitabFavoritesKey, updatedFavorites);
      }
      
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

  /// Add ebook to favorites
  static Future<bool> addEbookToFavorites(String ebookId) async {
    try {
      final favorites = _favoritesBox.get(_ebookFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);
      
      if (!updatedFavorites.contains(ebookId)) {
        updatedFavorites.add(ebookId);
        await _favoritesBox.put(_ebookFavoritesKey, updatedFavorites);
      }
      
      return true;
    } catch (e) {
      print('Error adding ebook to favorites: $e');
      return false;
    }
  }

  /// Remove ebook from favorites
  static Future<bool> removeEbookFromFavorites(String ebookId) async {
    try {
      final favorites = _favoritesBox.get(_ebookFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);
      
      if (updatedFavorites.contains(ebookId)) {
        updatedFavorites.remove(ebookId);
        await _favoritesBox.put(_ebookFavoritesKey, updatedFavorites);
      }
      
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

  /// Add video episode to favorites
  static Future<bool> addVideoEpisodeToFavorites(String episodeId) async {
    try {
      final favorites = _favoritesBox.get(_videoEpisodeFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);
      
      if (!updatedFavorites.contains(episodeId)) {
        updatedFavorites.add(episodeId);
        await _favoritesBox.put(_videoEpisodeFavoritesKey, updatedFavorites);
      }
      
      return true;
    } catch (e) {
      print('Error adding video episode to favorites: $e');
      return false;
    }
  }

  /// Remove video episode from favorites
  static Future<bool> removeVideoEpisodeFromFavorites(String episodeId) async {
    try {
      final favorites = _favoritesBox.get(_videoEpisodeFavoritesKey, defaultValue: <String>[]) as List;
      final updatedFavorites = List<String>.from(favorites);
      
      if (updatedFavorites.contains(episodeId)) {
        updatedFavorites.remove(episodeId);
        await _favoritesBox.put(_videoEpisodeFavoritesKey, updatedFavorites);
      }
      
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
}