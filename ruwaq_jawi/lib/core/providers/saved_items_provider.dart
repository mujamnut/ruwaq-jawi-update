import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_item.dart';
import '../models/kitab.dart';
import '../models/ebook.dart';
import '../services/local_saved_items_service.dart';

class SavedItemsProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<SavedItem> _savedItems = [];
  List<Kitab> _savedKitab = [];
  List<Ebook> _savedEbooks = [];
  bool _isLoading = false;
  String? _error;
  bool _useLocalOnly = false;

  List<SavedItem> get savedItems => _savedItems;
  List<Kitab> get savedKitab => _savedKitab;
  List<Ebook> get savedEbooks => _savedEbooks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Method untuk test - add kitab langsung ke local storage
  Future<bool> addKitabToLocal(Kitab kitab) async {
    try {
      await LocalSavedItemsService.saveKitab(kitab);
      await _loadFromLocalStorage();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error saving kitab locally: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeKitabFromLocal(String kitabId) async {
    try {
      await LocalSavedItemsService.removeKitab(kitabId);
      await _loadFromLocalStorage();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error removing kitab locally: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> isKitabSaved(String kitabId) async {
    return await LocalSavedItemsService.isKitabSaved(kitabId);
  }

  // Ebook methods
  Future<bool> addEbookToLocal(Ebook ebook) async {
    try {
      await LocalSavedItemsService.saveEbook(ebook.toJson());
      await _loadFromLocalStorage();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error saving ebook locally: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeEbookFromLocal(String ebookId) async {
    try {
      await LocalSavedItemsService.removeEbook(ebookId);
      await _loadFromLocalStorage();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error removing ebook locally: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> isEbookSaved(String ebookId) async {
    return await LocalSavedItemsService.isEbookSaved(ebookId);
  }

  // Episode methods
  bool isEpisodeSaved(String episodeId) {
    return _savedItems.any((item) =>
        item.itemType == 'video' && item.videoId == episodeId);
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
      _error = 'Error saving episode locally: $e';
      notifyListeners();
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

      await LocalSavedItemsService.removeVideo(episode.kitabId ?? '', episodeId);
      await loadSavedItems();
      return true;
    } catch (e) {
      _error = 'Error removing episode locally: $e';
      notifyListeners();
      return false;
    }
  }

  // Video methods untuk compatibility dengan save_video_button
  bool isVideoSaved(String videoId) {
    return _savedItems.any((item) => 
        item.itemType == 'video' && item.videoId == videoId);
  }

  Future<bool> addVideoToSaved(String videoId, String videoTitle, String? videoUrl) async {
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // ONLY use local storage for now (skip Supabase completely)
      await _loadFromLocalStorage();
      _error = null; // Always clear error for local storage
      print('Loaded ${_savedKitab.length} kitab and ${_savedEbooks.length} ebooks from local storage');
      
    } catch (e) {
      _error = 'Error loading from local storage: $e';
      print('Error loading from local storage: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadFromLocalStorage() async {
    final savedKitab = await LocalSavedItemsService.getSavedKitab();
    _savedKitab = savedKitab;

    // Load saved ebooks
    final savedEbooksData = await LocalSavedItemsService.getSavedEbooks();
    _savedEbooks = savedEbooksData.map((ebookData) => Ebook.fromJson(ebookData)).toList();
  }

  Future<void> _loadFromSupabase() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Get saved items with kitab details
    final response = await _supabase
        .from('saved_items')
        .select('''
          *,
          kitab:kitab_id (
            *,
            categories:category_id (
              id,
              name,
              description
            )
          )
        ''')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    _savedItems = (response as List)
        .map((item) => SavedItem.fromJson(item))
        .toList();

    _savedKitab = (response as List)
        .where((item) => item['kitab'] != null)
        .map((item) => Kitab.fromJson(item['kitab']))
        .toList();

    // Save to local storage for offline access
    for (final kitab in _savedKitab) {
      await LocalSavedItemsService.saveKitab(kitab);
    }
  }

  Future<bool> addToSaved(String kitabId, {String folderName = 'Default'}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        notifyListeners();
        return false;
      }

      print('Adding to saved: user_id=${user.id}, kitab_id=$kitabId, folder_name=$folderName');

      final response = await _supabase.from('saved_items').insert({
        'user_id': user.id,
        'kitab_id': kitabId,
        'folder_name': folderName,
        'item_type': 'kitab',
      }).select();

      print('Insert response: $response');

      // Reload saved items
      await loadSavedItems();
      return true;
    } catch (e) {
      print('Error adding to saved: $e');
      return false;
    }
  }

  Future<bool> removeFromSaved(String kitabId) async {
    try {
      // Remove from local storage
      await LocalSavedItemsService.removeKitab(kitabId);
      
      // Try to remove from Supabase if possible
      try {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          await _supabase
              .from('saved_items')
              .delete()
              .eq('user_id', user.id)
              .eq('kitab_id', kitabId);
        }
      } catch (e) {
        print('Error removing from Supabase: $e');
        // Continue with local storage success
      }

      // Reload from local storage
      await _loadFromLocalStorage();
      notifyListeners();
      return true;
    } catch (e) {
      print('Error removing from saved: $e');
      return false;
    }
  }

  bool isSaved(String kitabId) {
    return _savedItems.any((item) => item.kitabId == kitabId);
  }

  Future<void> refresh() async {
    _error = null;
    notifyListeners();
    await loadSavedItems();
  }
}