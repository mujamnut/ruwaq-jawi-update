import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/kitab.dart';
import '../models/video_kitab.dart';
import '../models/ebook.dart';
import '../models/category.dart';
import '../models/reading_progress.dart';
import '../models/video_episode.dart';
import '../services/supabase_service.dart';

class KitabProvider extends ChangeNotifier {
  final List<Kitab> _kitabList = [];
  List<VideoKitab> _videoKitabList = [];
  List<Ebook> _ebookList = [];
  List<Category> _categories = [];
  Map<String, ReadingProgress> _userProgress = {};
  final Map<String, List<VideoEpisode>> _kitabVideosCache = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Kitab> get kitabList => _kitabList;
  List<VideoKitab> get videoKitabList => _videoKitabList;
  List<Ebook> get ebookList => _ebookList;
  List<Category> get categories => _categories;
  Map<String, ReadingProgress> get userProgress => _userProgress;
  Map<String, List<VideoEpisode>> get kitabVideosCache => _kitabVideosCache;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Filtered lists
  List<Kitab> get premiumKitab => _kitabList.where((k) => k.isPremium).toList();
  List<Kitab> get freeKitab => _kitabList.where((k) => !k.isPremium).toList();
  List<Kitab> get availableEbooks =>
      _kitabList.where((k) => k.isEbookAvailable).toList();

  // Video Kitab filtered lists
  List<VideoKitab> get activeVideoKitab =>
      _videoKitabList.where((vk) => vk.isActive).toList();
  List<VideoKitab> get premiumVideoKitab =>
      _videoKitabList.where((vk) => vk.isPremium && vk.isActive).toList();
  List<VideoKitab> get freeVideoKitab =>
      _videoKitabList.where((vk) => !vk.isPremium && vk.isActive).toList();

  // Ebook filtered lists
  List<Ebook> get activeEbooks => _ebookList.where((e) => e.isActive).toList();
  List<Ebook> get premiumEbooks =>
      _ebookList.where((e) => e.isPremium && e.isActive).toList();
  List<Ebook> get freeEbooks =>
      _ebookList.where((e) => !e.isPremium && e.isActive).toList();

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Initialize the provider by loading categories and kitab list
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _setError(null);

      await Future.wait([
        loadCategories(),
        loadVideoKitabList(),
        loadEbookList(),
      ]);
    } catch (e) {
      _setError('Failed to initialize: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Load all categories from database
  Future<void> loadCategories() async {
    try {
      final response = await SupabaseService.from(
        'categories',
      ).select().order('name');

      _categories = (response as List)
          .map((json) => Category.fromJson(json))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load categories: ${e.toString()}');
    }
  }

  /// Load all kitab from database - DEPRECATED: Use loadVideoKitabList() and loadEbookList() instead
  // Future<void> loadKitabList({String? categoryId}) async {
  //   try {
  //     var query = SupabaseService.from('kitab').select('''
  //       *,
  //       categories(*),
  //       pdf_storage_path,
  //       pdf_file_size,
  //       pdf_upload_date,
  //       is_ebook_available,
  //       has_multiple_videos,
  //       total_videos,
  //       total_duration_minutes
  //     ''');

  //     if (categoryId != null) {
  //       query = query.eq('category_id', categoryId);
  //     }

  //     final response = await query.order('title');

  //     _kitabList = (response as List)
  //         .map((json) => Kitab.fromJson(json))
  //         .toList();

  //     notifyListeners();
  //   } catch (e) {
  //     _setError('Failed to load kitab list: ${e.toString()}');
  //   }
  // }

  /// Load all video kitab from video_kitab table
  Future<void> loadVideoKitabList({String? categoryId}) async {
    try {
      var query = SupabaseService.from('video_kitab').select('''
        *, 
        categories(*)
      ''');

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query.eq('is_active', true).order('title');

      _videoKitabList = (response as List)
          .map((json) => VideoKitab.fromJson(json))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load video kitab list: ${e.toString()}');
    }
  }

  /// Load all ebooks from ebooks table
  Future<void> loadEbookList({String? categoryId}) async {
    try {
      var query = SupabaseService.from('ebooks').select('''
        *, 
        categories(*)
      ''');

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query.eq('is_active', true).order('title');

      _ebookList = (response as List)
          .map((json) => Ebook.fromJson(json))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load ebook list: ${e.toString()}');
    }
  }

  /// Get kitab by ID
  Kitab? getKitabById(String id) {
    try {
      return _kitabList.firstWhere((kitab) => kitab.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get kitab by category
  List<Kitab> getKitabByCategory(String categoryId) {
    return _kitabList.where((kitab) => kitab.categoryId == categoryId).toList();
  }

  /// Search kitab by title or author
  List<Kitab> searchKitab(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _kitabList.where((kitab) {
      return kitab.title.toLowerCase().contains(lowercaseQuery) ||
          (kitab.author?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  /// Get video kitab by ID
  VideoKitab? getVideoKitabById(String id) {
    try {
      return _videoKitabList.firstWhere((videoKitab) => videoKitab.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get video kitab by category
  List<VideoKitab> getVideoKitabByCategory(String categoryId) {
    return _videoKitabList
        .where((videoKitab) => videoKitab.categoryId == categoryId)
        .toList();
  }

  /// Search video kitab by title or author
  List<VideoKitab> searchVideoKitab(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _videoKitabList.where((videoKitab) {
      return videoKitab.title.toLowerCase().contains(lowercaseQuery) ||
          (videoKitab.author?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  /// Get ebook by ID
  Ebook? getEbookById(String id) {
    try {
      return _ebookList.firstWhere((ebook) => ebook.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get ebooks by category
  List<Ebook> getEbooksByCategory(String categoryId) {
    return _ebookList.where((ebook) => ebook.categoryId == categoryId).toList();
  }

  /// Search ebooks by title or author
  List<Ebook> searchEbooks(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _ebookList.where((ebook) {
      return ebook.title.toLowerCase().contains(lowercaseQuery) ||
          (ebook.author?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  /// Load user's reading progress
  Future<void> loadUserProgress(String userId) async {
    try {
      final response = await SupabaseService.from(
        'reading_progress',
      ).select().eq('user_id', userId);

      _userProgress = {};
      for (final json in response as List) {
        final progress = ReadingProgress.fromJson(json);
        _userProgress[progress.kitabId] = progress;
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load user progress: ${e.toString()}');
    }
  }

  /// Update reading progress
  Future<void> updateProgress({
    required String userId,
    required String kitabId,
    int? videoProgress,
    int? pdfPage,
  }) async {
    try {
      final existingProgress = _userProgress[kitabId];

      if (existingProgress != null) {
        // Update existing progress
        final updatedData = <String, dynamic>{
          'last_accessed': DateTime.now().toIso8601String(),
        };

        if (videoProgress != null) {
          updatedData['video_progress'] = videoProgress;
        }
        if (pdfPage != null) {
          updatedData['pdf_page'] = pdfPage;
        }

        await SupabaseService.from(
          'reading_progress',
        ).update(updatedData).eq('user_id', userId).eq('kitab_id', kitabId);

        // Update local state
        _userProgress[kitabId] = existingProgress.copyWith(
          videoProgress: videoProgress ?? existingProgress.videoProgress,
          pdfPage: pdfPage ?? existingProgress.pdfPage,
          lastAccessed: DateTime.now(),
        );
      } else {
        // Create new progress entry
        final newProgressData = {
          'user_id': userId,
          'kitab_id': kitabId,
          'video_progress': videoProgress ?? 0,
          'pdf_page': pdfPage ?? 1,
          'last_accessed': DateTime.now().toIso8601String(),
        };

        await SupabaseService.from('reading_progress').insert(newProgressData);

        // Update local state
        _userProgress[kitabId] = ReadingProgress(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: userId,
          kitabId: kitabId,
          videoProgress: videoProgress ?? 0,
          pdfPage: pdfPage ?? 1,
          lastAccessed: DateTime.now(),
          videoDuration: 0,
          completionPercentage: 0.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to update progress: ${e.toString()}');
    }
  }

  /// Get progress for specific kitab
  ReadingProgress? getProgressForKitab(String kitabId) {
    return _userProgress[kitabId];
  }

  /// Get recently accessed kitab
  List<Kitab> getRecentlyAccessedKitab({int limit = 10}) {
    final recentKitabIds = _userProgress.values.toList()
      ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

    final recentKitab = <Kitab>[];
    for (final progress in recentKitabIds.take(limit)) {
      final kitab = getKitabById(progress.kitabId);
      if (kitab != null) {
        recentKitab.add(kitab);
      }
    }

    return recentKitab;
  }

  /// Load continue reading data - TEMPORARILY DISABLED until reading_progress table is updated
  Future<List<dynamic>> loadContinueReading({int limit = 1}) async {
    try {
      // TODO: Update this method to work with new video_kitab and ebooks tables
      // For now, return empty list to prevent errors
      return [];

      // final user = SupabaseService.currentUser;
      // if (user == null) return [];

      // final response = await SupabaseService.from('reading_progress')
      //     .select('''
      //       *,
      //       kitab:kitab_id (
      //         id, title, author, description, thumbnail_url, is_premium,
      //         category_id, duration_minutes, total_pages, created_at,
      //         has_multiple_videos, total_videos, total_duration_minutes
      //       )
      //     ''')
      //     .eq('user_id', user.id)
      //     .gt('progress_percentage', 0) // Only show items with some progress
      //     .order('last_accessed', ascending: false)
      //     .limit(limit);

      // final results = <dynamic>[];
      // for (final item in response as List) {
      //   if (item['kitab'] != null) {
      //     results.add({
      //       'kitab': Kitab.fromJson(item['kitab']),
      //       'progress': {
      //         'progress_percentage': item['progress_percentage'] ?? 0,
      //         'current_page': item['current_page'] ?? 1,
      //         'last_accessed': item['last_accessed'],
      //         'video_progress': item['video_progress'] ?? 0,
      //       }
      //     });
      //   }
      // }

      // return results;
    } catch (e) {
      print('Error loading continue reading: $e');
      return [];
    }
  }

  /// Clear all data (useful for logout)
  void clear() {
    _kitabList.clear();
    _videoKitabList.clear();
    _ebookList.clear();
    _categories.clear();
    _userProgress.clear();
    _kitabVideosCache.clear();
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Refresh all data
  Future<void> refresh() async {
    await initialize();
  }

  /// Load videos for a specific kitab
  Future<List<VideoEpisode>> loadKitabVideos(String kitabId) async {
    try {
      // Check cache first
      if (_kitabVideosCache.containsKey(kitabId)) {
        return _kitabVideosCache[kitabId]!;
      }

      // Load ALL episodes (including inactive ones) to fix missing 4th episode issue
      final response = await SupabaseService.from(
        'video_episodes',
      ).select().eq('video_kitab_id', kitabId).order('part_number');

      final videos = (response as List)
          .map((json) => VideoEpisode.fromJson(json))
          .toList();

      // Cache the result
      _kitabVideosCache[kitabId] = videos;
      notifyListeners();

      return videos;
    } catch (e) {
      print('Error loading kitab videos: $e');
      return [];
    }
  }

  /// Get cached videos for a kitab (returns empty list if not cached)
  List<VideoEpisode> getCachedVideos(String kitabId) {
    return _kitabVideosCache[kitabId] ?? [];
  }

  /// Get video by ID from cache
  VideoEpisode? getVideoById(String videoId) {
    for (final videos in _kitabVideosCache.values) {
      for (final video in videos) {
        if (video.id == videoId) {
          return video;
        }
      }
    }
    return null;
  }

  /// Load preview videos for a specific kitab
  Future<List<VideoEpisode>> loadPreviewVideos(String kitabId) async {
    try {
      final response = await SupabaseService.from('video_episodes')
          .select()
          .eq('video_kitab_id', kitabId)
          .eq('is_active', true) // Only show active preview videos
          .eq('is_preview', true)
          .order('part_number');

      final previewVideos = (response as List)
          .map((json) => VideoEpisode.fromJson(json))
          .toList();

      return previewVideos;
    } catch (e) {
      print('Error loading preview videos: $e');
      return [];
    }
  }

  /// Get preview videos from cache (filter from already loaded videos)
  List<VideoEpisode> getPreviewVideosFromCache(String kitabId) {
    final allVideos = _kitabVideosCache[kitabId] ?? [];
    return allVideos.where((video) => video.isPreview).toList();
  }

  /// Check if kitab has any preview videos
  Future<bool> hasPreviewVideos(String kitabId) async {
    try {
      print('DEBUG: Checking preview videos for kitab: $kitabId');
      final previews = await loadPreviewVideos(kitabId);
      print('DEBUG: Found ${previews.length} preview videos');
      return previews.isNotEmpty;
    } catch (e) {
      print('Error checking preview videos: $e');
      return false;
    }
  }

  /// Load all available preview videos across all kitab (for general preview browsing)
  Future<List<VideoEpisode>> loadAllPreviewVideos({int limit = 20}) async {
    try {
      final response = await SupabaseService.from('video_episodes')
          .select('''
            *,
            video_kitab:video_kitab_id (
              id, title, author, thumbnail_url, category_id
            )
          ''')
          .eq('is_active', true)
          .eq('is_preview', true)
          .order('created_at', ascending: false)
          .limit(limit);

      final previewVideos = (response as List)
          .map((json) => VideoEpisode.fromJson(json))
          .toList();

      return previewVideos;
    } catch (e) {
      print('Error loading all preview videos: $e');
      return [];
    }
  }
}
