import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bookmark.dart';

class BookmarkProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Bookmark> _bookmarks = [];
  bool _isLoading = false;
  String? _error;

  List<Bookmark> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Check if a kitab is bookmarked
  bool isBookmarked(String kitabId) {
    return _bookmarks.any((bookmark) => bookmark.kitabId == kitabId);
  }

  // Get bookmark for a specific kitab
  Bookmark? getBookmark(String kitabId) {
    try {
      return _bookmarks.firstWhere((bookmark) => bookmark.kitabId == kitabId);
    } catch (e) {
      return null;
    }
  }

  // Load bookmarks for current user
  Future<void> loadBookmarks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('bookmarks')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      _bookmarks = (response as List)
          .map((json) => Bookmark.fromJson(json))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add or update bookmark
  Future<bool> addBookmark({
    required String kitabId,
    required String title,
    String? description,
    required int videoPosition,
    required int pdfPage,
    required String contentType,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final bookmarkId = '${user.id}_$kitabId';
      final now = DateTime.now();

      // Do not include created_at so existing rows keep original created time on conflict
      final bookmarkData = {
        'id': bookmarkId,
        'user_id': user.id,
        'kitab_id': kitabId,
        'title': title,
        'description': description,
        'video_position': videoPosition,
        'pdf_page': pdfPage,
        'content_type': contentType,
        'updated_at': now.toIso8601String(),
      };

      // Atomic upsert to avoid duplicate key violations when cache is stale
      final result = await _supabase
          .from('bookmarks')
          .upsert(bookmarkData, onConflict: 'id')
          .select()
          .single();

      final updated = Bookmark.fromJson(result);
      final index = _bookmarks.indexWhere((b) => b.kitabId == kitabId);
      if (index != -1) {
        _bookmarks[index] = updated;
      } else {
        _bookmarks.insert(0, updated);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Remove bookmark
  Future<bool> removeBookmark(String kitabId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final bookmarkId = '${user.id}_$kitabId';

      await _supabase
          .from('bookmarks')
          .delete()
          .eq('id', bookmarkId);

      // Remove from local list
      _bookmarks.removeWhere((bookmark) => bookmark.kitabId == kitabId);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Toggle bookmark (add if not exists, remove if exists)
  Future<bool> toggleBookmark({
    required String kitabId,
    required String title,
    String? description,
    required int videoPosition,
    required int pdfPage,
    required String contentType,
  }) async {
    if (isBookmarked(kitabId)) {
      return await removeBookmark(kitabId);
    } else {
      return await addBookmark(
        kitabId: kitabId,
        title: title,
        description: description,
        videoPosition: videoPosition,
        pdfPage: pdfPage,
        contentType: contentType,
      );
    }
  }

  // Get bookmarks by content type
  List<Bookmark> getBookmarksByType(String contentType) {
    return _bookmarks.where((bookmark) => bookmark.contentType == contentType).toList();
  }

  // Search bookmarks
  List<Bookmark> searchBookmarks(String query) {
    if (query.isEmpty) return _bookmarks;
    
    final lowercaseQuery = query.toLowerCase();
    return _bookmarks.where((bookmark) {
      return bookmark.title.toLowerCase().contains(lowercaseQuery) ||
             (bookmark.description?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all bookmarks (for logout)
  void clearBookmarks() {
    _bookmarks.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
