import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_item.dart';
import '../models/kitab.dart';

class SavedItemsProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<SavedItem> _savedItems = [];
  List<Kitab> _savedKitab = [];
  bool _isLoading = false;
  String? _error;

  List<SavedItem> get savedItems => _savedItems;
  List<Kitab> get savedKitab => _savedKitab;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSavedItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
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

  Future<bool> addVideoToSaved(String videoId, String videoTitle, String? videoUrl) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('saved_items')
          .insert({
            'user_id': user.id,
            'kitab_id': null, // null for videos
            'folder_name': 'Videos', // Default folder for videos
            'item_type': 'video',
            'video_id': videoId,
            'video_title': videoTitle,
            'video_url': videoUrl,
          });

      await loadSavedItems();
      return true;
    } catch (e) {
      print('Error adding video to saved: $e');
      return false;
    }
  }

  Future<bool> removeVideoFromSaved(String videoId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('saved_items')
          .delete()
          .eq('user_id', user.id)
          .eq('video_id', videoId);

      await loadSavedItems();
      return true;
    } catch (e) {
      print('Error removing video from saved: $e');
      return false;
    }
  }

  bool isVideoSaved(String videoId) {
    return _savedItems.any((item) => 
        item.itemType == 'video' && item.videoId == videoId);
  }

  Future<bool> removeFromSaved(String kitabId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('saved_items')
          .delete()
          .eq('user_id', user.id)
          .eq('kitab_id', kitabId);

      // Reload saved items
      await loadSavedItems();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  bool isKitabSaved(String kitabId) {
    return _savedItems.any((item) => item.kitabId == kitabId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
