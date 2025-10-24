import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/kitab.dart';
import '../models/video_kitab.dart';
import '../models/ebook.dart';
import '../models/category.dart';
import '../models/reading_progress.dart';
import '../models/video_episode.dart';
import '../models/preview_models.dart';
import '../services/supabase_service.dart';
import '../services/preview_service.dart';

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

      // Use timeout and individual error handling for better resilience
      await Future.wait([
        loadCategories().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Categories loading timeout'),
        ),
        loadVideoKitabList().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Video kitab loading timeout'),
        ),
        loadEbookList().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Ebook loading timeout'),
        ),
      ], eagerError: false); // Continue loading even if some fail

      // Check if any operations failed
      bool hasAnyData = _categories.isNotEmpty ||
                       _videoKitabList.isNotEmpty ||
                       _ebookList.isNotEmpty;

      if (!hasAnyData) {
        _setError('Tidak dapat memuat data. Sila semak sambungan internet.');
      }
    } catch (e) {
      // Provide user-friendly error messages
      String errorMessage = 'Tidak dapat memuat data';
      if (e.toString().contains('timeout')) {
        errorMessage = 'Sambungan internet terlalu perlahan. Sila cuba lagi.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Tiada sambungan internet. Sila semak sambungan anda.';
      } else if (e.toString().contains('Failed to initialize')) {
        errorMessage = e.toString().replaceFirst('Failed to initialize: ', '');
      }

      _setError(errorMessage);
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
      // Debug logging removed
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
    } on SocketException {
      // Debug logging removed
      rethrow; // Let caller handle network error
    } on TimeoutException {
      // Debug logging removed
      rethrow; // Let caller handle timeout
    } catch (e) {
      // Debug logging removed
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

  /// Load preview videos for a specific video kitab using unified preview system
  Future<List<VideoEpisode>> loadPreviewVideos(String videoKitabId) async {
    try {
      // Get preview content for this video kitab
      final previews = await PreviewService.getPreviewForContent(
        contentType: PreviewContentType.videoKitab,
        contentId: videoKitabId,
        onlyActive: true,
      );

      if (previews.isEmpty) {
        // Fallback: check for video episode previews
        return await loadVideoEpisodePreviews(videoKitabId);
      }

      // For video kitab previews, return the full video episodes
      final allVideos = await loadKitabVideos(videoKitabId);
      return allVideos; // Return all videos as preview for video kitab type previews
    } catch (e) {
      // Debug logging removed
      return [];
    }
  }

  /// Load preview video episodes for a specific video kitab
  Future<List<VideoEpisode>> loadVideoEpisodePreviews(String videoKitabId) async {
    try {
      // Get all video episodes for this kitab
      final allEpisodes = await loadKitabVideos(videoKitabId);
      final previewEpisodes = <VideoEpisode>[];

      for (final episode in allEpisodes) {
        // Check if this episode has preview content
        final hasPreview = await PreviewService.hasPreview(
          contentType: PreviewContentType.videoEpisode,
          contentId: episode.id,
        );

        if (hasPreview) {
          previewEpisodes.add(episode);
        }
      }

      return previewEpisodes;
    } catch (e) {
      // Debug logging removed
      return [];
    }
  }

  /// Get preview videos from cache using unified preview system
  Future<List<VideoEpisode>> getPreviewVideosFromCache(String videoKitabId) async {
    final allVideos = _kitabVideosCache[videoKitabId] ?? [];
    final previewVideos = <VideoEpisode>[];

    for (final video in allVideos) {
      // Check if this video has preview content using the unified system
      final hasPreview = await PreviewService.hasPreview(
        contentType: PreviewContentType.videoEpisode,
        contentId: video.id,
      );

      if (hasPreview) {
        previewVideos.add(video);
      }
    }

    return previewVideos;
  }

  /// Check if video kitab has any preview content using unified preview system
  Future<bool> hasPreviewVideos(String videoKitabId) async {
    try {
      // Debug logging removed

      // First check if video kitab itself has preview content
      final hasVideoKitabPreview = await PreviewService.hasPreview(
        contentType: PreviewContentType.videoKitab,
        contentId: videoKitabId,
      );

      if (hasVideoKitabPreview) {
        // Debug logging removed
        return true;
      }

      // Check if any episodes have preview content
      final allEpisodes = await loadKitabVideos(videoKitabId);
      for (final episode in allEpisodes) {
        final hasEpisodePreview = await PreviewService.hasPreview(
          contentType: PreviewContentType.videoEpisode,
          contentId: episode.id,
        );

        if (hasEpisodePreview) {
          // Debug logging removed
          return true;
        }
      }

      // Debug logging removed
      return false;
    } catch (e) {
      // Debug logging removed
      return false;
    }
  }

  /// Load all available preview videos using unified preview system
  Future<List<VideoEpisode>> loadAllPreviewVideos({int limit = 20}) async {
    try {
      // Get all video episode preview content
      final episodePreviews = await PreviewService.getPreviewContent(
        filter: PreviewQueryFilter(
          contentType: PreviewContentType.videoEpisode,
          isActive: true,
        ),
        includeContentDetails: true,
      );

      // Convert preview content to video episodes
      final previewVideos = <VideoEpisode>[];

      for (final preview in episodePreviews.take(limit)) {
        try {
          // Get the actual video episode data
          final response = await SupabaseService.from('video_episodes')
              .select('''
                *,
                video_kitab:video_kitab_id (
                  id, title, author, thumbnail_url, category_id
                )
              ''')
              .eq('id', preview.contentId)
              .eq('is_active', true)
              .single();

          final videoEpisode = VideoEpisode.fromJson(response);
          previewVideos.add(videoEpisode);
        } catch (e) {
          // Debug logging removed
          // Skip this preview if episode not found or inactive
          continue;
        }
      }

      // Sort by creation date (newest first)
      previewVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return previewVideos;
    } catch (e) {
      // Debug logging removed
      return [];
    }
  }

  /// Get preview content for ebooks using unified preview system
  Future<List<PreviewContent>> getEbookPreviews({int limit = 20}) async {
    try {
      return await PreviewService.getPreviewContent(
        filter: PreviewQueryFilter(
          contentType: PreviewContentType.ebook,
          isActive: true,
        ),
        includeContentDetails: true,
      );
    } catch (e) {
      // Debug logging removed
      return [];
    }
  }

  /// Get preview content for video kitab using unified preview system
  Future<List<PreviewContent>> getVideoKitabPreviews({int limit = 20}) async {
    try {
      return await PreviewService.getPreviewContent(
        filter: PreviewQueryFilter(
          contentType: PreviewContentType.videoKitab,
          isActive: true,
        ),
        includeContentDetails: true,
      );
    } catch (e) {
      // Debug logging removed
      return [];
    }
  }
}
