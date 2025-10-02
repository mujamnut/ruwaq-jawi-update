import 'package:hive/hive.dart';
import 'dart:convert';
import '../models/kitab.dart';
import '../models/saved_item.dart';
import 'local_favorites_service.dart';

class LocalSavedItemsService {
  static const String _boxName = 'saved_items';
  static const String _kitabBoxName = 'saved_kitab';
  static const String _videosBoxName = 'saved_videos';
  static const String _ebooksBoxName = 'saved_ebooks';
  
  static Box<String>? _savedItemsBox;
  static Box<String>? _savedKitabBox;
  static Box<String>? _savedVideosBox;
  static Box<String>? _savedEbooksBox;

  static Future<void> initialize() async {
    try {
      _savedItemsBox = await Hive.openBox<String>(_boxName);
      _savedKitabBox = await Hive.openBox<String>(_kitabBoxName);
      _savedVideosBox = await Hive.openBox<String>(_videosBoxName);
      _savedEbooksBox = await Hive.openBox<String>(_ebooksBoxName);
    } catch (e) {
      print('Error initializing LocalSavedItemsService: $e');
    }
  }

  // Saved Items (general)
  static Future<void> saveItem(SavedItem item) async {
    if (_savedItemsBox == null) return;
    
    try {
      final json = jsonEncode(item.toJson());
      await _savedItemsBox!.put(item.id, json);
    } catch (e) {
      print('Error saving item: $e');
    }
  }

  static Future<List<SavedItem>> getSavedItems() async {
    if (_savedItemsBox == null) return [];
    
    try {
      final items = <SavedItem>[];
      for (final value in _savedItemsBox!.values) {
        final json = jsonDecode(value);
        items.add(SavedItem.fromJson(json));
      }
      return items;
    } catch (e) {
      print('Error getting saved items: $e');
      return [];
    }
  }

  static Future<void> removeItem(String itemId) async {
    if (_savedItemsBox == null) return;
    
    try {
      await _savedItemsBox!.delete(itemId);
    } catch (e) {
      print('Error removing item: $e');
    }
  }

  // Saved Kitab (delegates to LocalFavoritesService for Supabase sync)
  static Future<void> saveKitab(Kitab kitab) async {
    if (_savedKitabBox == null) return;

    try {
      // Save to local Hive for backward compatibility
      final json = jsonEncode(kitab.toJson());
      await _savedKitabBox!.put(kitab.id, json);

      // Also save via LocalFavoritesService (dual-write to Supabase)
      await LocalFavoritesService.addVideoKitabToFavorites(kitab.id);
    } catch (e) {
      print('Error saving kitab: $e');
    }
  }

  static Future<List<Kitab>> getSavedKitab() async {
    if (_savedKitabBox == null) return [];
    
    try {
      final kitabs = <Kitab>[];
      for (final value in _savedKitabBox!.values) {
        final json = jsonDecode(value);
        kitabs.add(Kitab.fromJson(json));
      }
      return kitabs;
    } catch (e) {
      print('Error getting saved kitab: $e');
      return [];
    }
  }

  static Future<void> removeKitab(String kitabId) async {
    if (_savedKitabBox == null) return;

    try {
      // Remove from local Hive
      await _savedKitabBox!.delete(kitabId);

      // Also remove via LocalFavoritesService (sync to Supabase)
      await LocalFavoritesService.removeVideoKitabFromFavorites(kitabId);
    } catch (e) {
      print('Error removing kitab: $e');
    }
  }

  static Future<bool> isKitabSaved(String kitabId) async {
    if (_savedKitabBox == null) return false;
    return _savedKitabBox!.containsKey(kitabId);
  }

  // Saved Videos
  static Future<void> saveVideo(Map<String, dynamic> videoData) async {
    if (_savedVideosBox == null) return;
    
    try {
      final json = jsonEncode(videoData);
      final key = '${videoData['kitabId']}_${videoData['episodeId']}';
      await _savedVideosBox!.put(key, json);
    } catch (e) {
      print('Error saving video: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getSavedVideos() async {
    if (_savedVideosBox == null) return [];
    
    try {
      final videos = <Map<String, dynamic>>[];
      for (final value in _savedVideosBox!.values) {
        final json = jsonDecode(value);
        videos.add(Map<String, dynamic>.from(json));
      }
      return videos;
    } catch (e) {
      print('Error getting saved videos: $e');
      return [];
    }
  }

  static Future<void> removeVideo(String kitabId, String episodeId) async {
    if (_savedVideosBox == null) return;
    
    try {
      final key = '${kitabId}_$episodeId';
      await _savedVideosBox!.delete(key);
    } catch (e) {
      print('Error removing video: $e');
    }
  }

  static Future<bool> isVideoSaved(String kitabId, String episodeId) async {
    if (_savedVideosBox == null) return false;
    final key = '${kitabId}_$episodeId';
    return _savedVideosBox!.containsKey(key);
  }

  // Saved E-books (delegates to LocalFavoritesService for Supabase sync)
  static Future<void> saveEbook(Map<String, dynamic> ebookData) async {
    if (_savedEbooksBox == null) return;

    try {
      // Save to local Hive for backward compatibility
      final json = jsonEncode(ebookData);
      await _savedEbooksBox!.put(ebookData['id'], json);

      // Also save via LocalFavoritesService (dual-write to Supabase)
      final ebookId = ebookData['id'] as String;
      await LocalFavoritesService.addEbookToFavorites(ebookId);
    } catch (e) {
      print('Error saving ebook: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getSavedEbooks() async {
    if (_savedEbooksBox == null) return [];
    
    try {
      final ebooks = <Map<String, dynamic>>[];
      for (final value in _savedEbooksBox!.values) {
        final json = jsonDecode(value);
        ebooks.add(Map<String, dynamic>.from(json));
      }
      return ebooks;
    } catch (e) {
      print('Error getting saved ebooks: $e');
      return [];
    }
  }

  static Future<void> removeEbook(String ebookId) async {
    if (_savedEbooksBox == null) return;

    try {
      // Remove from local Hive
      await _savedEbooksBox!.delete(ebookId);

      // Also remove via LocalFavoritesService (sync to Supabase)
      await LocalFavoritesService.removeEbookFromFavorites(ebookId);
    } catch (e) {
      print('Error removing ebook: $e');
    }
  }

  static Future<bool> isEbookSaved(String ebookId) async {
    if (_savedEbooksBox == null) return false;
    return _savedEbooksBox!.containsKey(ebookId);
  }

  // Clear all saved data
  static Future<void> clearAllSavedItems() async {
    try {
      await _savedItemsBox?.clear();
      await _savedKitabBox?.clear();
      await _savedVideosBox?.clear();
      await _savedEbooksBox?.clear();
    } catch (e) {
      print('Error clearing saved items: $e');
    }
  }

  // Get statistics
  static Future<Map<String, int>> getStatistics() async {
    try {
      return {
        'kitab': _savedKitabBox?.length ?? 0,
        'videos': _savedVideosBox?.length ?? 0,
        'ebooks': _savedEbooksBox?.length ?? 0,
        'total': (_savedKitabBox?.length ?? 0) + 
                (_savedVideosBox?.length ?? 0) + 
                (_savedEbooksBox?.length ?? 0),
      };
    } catch (e) {
      print('Error getting statistics: $e');
      return {'kitab': 0, 'videos': 0, 'ebooks': 0, 'total': 0};
    }
  }
}