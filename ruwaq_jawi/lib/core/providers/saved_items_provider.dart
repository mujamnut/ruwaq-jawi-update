import 'package:flutter/foundation.dart';

import '../models/ebook.dart';
import '../models/kitab.dart';
import '../models/saved_item.dart';
import '../services/local_saved_items_service.dart';
import '../utils/auth_utils.dart';
import '../utils/database_utils.dart';
import '../utils/provider_utils.dart';

class SavedItemsProvider extends BaseProvider {
  List<SavedItem> _savedItems = [];
  List<Kitab> _savedKitab = [];
  List<Ebook> _savedEbooks = [];

  List<SavedItem> get savedItems => _savedItems;
  List<Kitab> get savedKitab => _savedKitab;
  List<Ebook> get savedEbooks => _savedEbooks;
  String? get error => errorMessage;

  /// Add kitab to local storage
  Future<bool> addKitabToLocal(Kitab kitab) async {
    return await _executeWithErrorHandling(() async {
      await LocalSavedItemsService.saveKitab(kitab);
      await _loadFromLocalStorage();
      return true;
    }) ?? false;
  }

  Future<bool> removeKitabFromLocal(String kitabId) async {
    return await _executeWithErrorHandling(() async {
      await LocalSavedItemsService.removeKitab(kitabId);
      await _loadFromLocalStorage();
      return true;
    }) ?? false;
  }

  Future<bool> isKitabSaved(String kitabId) async {
    return await LocalSavedItemsService.isKitabSaved(kitabId);
  }

  /// Add ebook to local storage
  Future<bool> addEbookToLocal(Ebook ebook) async {
    return await _executeWithErrorHandling(() async {
      await LocalSavedItemsService.saveEbook(ebook.toJson());
      await _loadFromLocalStorage();
      return true;
    }) ?? false;
  }

  /// Remove ebook from local storage
  Future<bool> removeEbookFromLocal(String ebookId) async {
    return await _executeWithErrorHandling(() async {
      await LocalSavedItemsService.removeEbook(ebookId);
      await _loadFromLocalStorage();
      return true;
    }) ?? false;
  }

  Future<bool> isEbookSaved(String ebookId) async {
    return await LocalSavedItemsService.isEbookSaved(ebookId);
  }

  // Episode methods
  bool isEpisodeSaved(String episodeId) {
    return _savedItems.any(
      (item) => item.itemType == 'video' && item.videoId == episodeId,
    );
  }

  Future<bool> addEpisodeToLocal(dynamic episode) async {
    try {
      await LocalSavedItemsService.saveVideo({
        'kitabId': episode.videoKitabId,
        'episodeId': episode.id,
        'title': episode.title,
        'url': episode.youtubeWatchUrl,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await loadSavedItems();
      return true;
    } catch (e) {
      setError('Error saving episode locally: $e');
      return false;
    }
  }

  Future<bool> removeEpisodeFromLocal(String episodeId) async {
    try {
      // Find the episode first to get kitabId
      final episode = _savedItems.firstWhere(
        (item) => item.itemType == 'video' && item.videoId == episodeId,
        orElse: () => SavedItem(
          id: '',
          userId: '',
          kitabId: '',
          folderName: 'default',
          itemType: 'video',
          videoId: episodeId,
          createdAt: DateTime.now(),
        ),
      );

      await LocalSavedItemsService.removeVideo(
        episode.kitabId ?? '',
        episodeId,
      );
      await loadSavedItems();
      return true;
    } catch (e) {
      setError('Error removing episode locally: $e');
      return false;
    }
  }

  // Video methods untuk compatibility dengan save_video_button
  bool isVideoSaved(String videoId) {
    return _savedItems.any(
      (item) => item.itemType == 'video' && item.videoId == videoId,
    );
  }

  Future<bool> addVideoToSaved(
    String videoId,
    String videoTitle,
    String? videoUrl,
  ) async {
    try {
      // Save to local storage only
      await LocalSavedItemsService.saveVideo({
        'kitabId': videoId,
        'episodeId': videoId,
        'title': videoTitle,
        'url': videoUrl,
        'createdAt': DateTime.now().toIso8601String(),
      });

      print('Video saved to local storage: $videoTitle');
      await loadSavedItems();
      return true;
    } catch (e) {
      print('Error adding video to saved: $e');
      return false;
    }
  }

  Future<bool> removeVideoFromSaved(String videoId) async {
    try {
      // Remove from local storage only
      await LocalSavedItemsService.removeVideo(videoId, videoId);

      print('Video removed from local storage: $videoId');
      await loadSavedItems();
      return true;
    } catch (e) {
      print('Error removing video from saved: $e');
      return false;
    }
  }

  Future<void> loadSavedItems() async {
    await withLoading(() async {
      await _loadFromLocalStorage();
      if (kDebugMode) {
        print('Loaded ${_savedKitab.length} kitab and ${_savedEbooks.length} ebooks from local storage');
      }
    });
  }

  Future<void> _loadFromLocalStorage() async {
    final savedKitab = await LocalSavedItemsService.getSavedKitab();
    _savedKitab = savedKitab;

    // Load saved ebooks
    final savedEbooksData = await LocalSavedItemsService.getSavedEbooks();
    _savedEbooks = savedEbooksData
        .map((ebookData) => Ebook.fromJson(ebookData))
        .toList();
  }

  Future<void> _loadFromSupabase() async {
    return await AuthUtils.withRequiredUserAsync((user) async {
      final response = await DatabaseUtils.getUserRecords(
        'saved_items',
        select: '''
          *,
          kitab:kitab_id (
            *,
            categories:category_id (
              id,
              name,
              description
            )
          )
        ''',
      );

      _savedItems = response.map((item) => SavedItem.fromJson(item)).toList();
      _savedKitab = response
          .where((item) => item['kitab'] != null)
          .map((item) => Kitab.fromJson(item['kitab']))
          .toList();

      // Save to local storage for offline access
      for (final kitab in _savedKitab) {
        await LocalSavedItemsService.saveKitab(kitab);
      }
    });
  }

  Future<bool> addToSaved(
    String kitabId, {
    String folderName = 'Default',
  }) async {
    return await _executeWithErrorHandling(() async {
      return await AuthUtils.withRequiredUserAsync((user) async {
        await DatabaseUtils.insert('saved_items', {
          'user_id': user.id,
          'kitab_id': kitabId,
          'folder_name': folderName,
          'item_type': 'kitab',
        });

        await loadSavedItems();
        return true;
      });
    }) ?? false;
  }

  Future<bool> removeFromSaved(String kitabId) async {
    return await _executeWithErrorHandling(() async {
      // Remove from local storage
      await LocalSavedItemsService.removeKitab(kitabId);

      // Try to remove from Supabase if possible
      await AuthUtils.withUserAsync((user) async {
        await DatabaseUtils.getAll(
          'saved_items',
          filters: {'user_id': user.id, 'kitab_id': kitabId},
        ).then((items) async {
          for (final item in items) {
            await DatabaseUtils.delete('saved_items', item['id']);
          }
        });
      });

      await _loadFromLocalStorage();
      return true;
    }) ?? false;
  }

  bool isSaved(String kitabId) {
    return _savedItems.any((item) => item.kitabId == kitabId);
  }

  @override
  Future<void> refresh() async {
    clearError();
    await loadSavedItems();
  }

  /// Helper method for executing operations with error handling
  Future<T?> _executeWithErrorHandling<T>(Future<T> Function() callback) async {
    try {
      return await callback();
    } catch (e) {
      setError('Error: $e');
      if (kDebugMode) {
        print('SavedItemsProvider error: $e');
      }
      return null;
    }
  }

  @override
  void clear() {
    super.clear();
    _savedItems.clear();
    _savedKitab.clear();
    _savedEbooks.clear();
  }
}
