import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../core/providers/kitab_provider.dart';

class SearchManager {
  // State
  List<Map<String, dynamic>> searchResults = [];
  List<String> recentSearches = [];
  bool isSearching = false;
  String selectedFilter = 'Semua';

  // Callbacks
  final VoidCallback? onStateChanged;

  // Debounce timer
  Timer? _debounceTimer;

  SearchManager({this.onStateChanged});

  // Filter options
  static const List<String> filterOptions = ['Semua', 'Pengajian', 'E-Book'];

  void dispose() {
    _debounceTimer?.cancel();
  }

  // Update filter
  void updateFilter(String filter) {
    selectedFilter = filter;
    onStateChanged?.call();
  }

  // Perform search with debounce
  void performSearch(String query, KitabProvider kitabProvider) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      searchResults = [];
      isSearching = false;
      onStateChanged?.call();
      return;
    }

    // Don't search if query is too short (less than 2 characters)
    if (query.trim().length < 2) {
      searchResults = [];
      isSearching = false;
      onStateChanged?.call();
      return;
    }

    // Set loading state immediately for better UX
    isSearching = true;
    onStateChanged?.call();

    // Start debounce timer
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performActualSearch(query, kitabProvider);
    });
  }

  // Actual search implementation
  Future<void> _performActualSearch(String query, KitabProvider kitabProvider) async {
    try {
      // Ensure data is loaded
      if (kitabProvider.videoKitabList.isEmpty && kitabProvider.ebookList.isEmpty) {
        await Future.wait([
          kitabProvider.loadVideoKitabList(),
          kitabProvider.loadEbookList(),
        ]);

        // Double check if still empty after loading
        if (kitabProvider.videoKitabList.isEmpty && kitabProvider.ebookList.isEmpty) {
          searchResults = [];
          isSearching = false;
          onStateChanged?.call();
          return;
        }
      }

      final q = query.toLowerCase().trim();
      final videoKitabList = kitabProvider.activeVideoKitab;
      final ebookList = kitabProvider.activeEbooks;

      debugPrint('🔍 Searching for: "$q" in ${videoKitabList.length} video kitab and ${ebookList.length} ebooks');
      debugPrint('📋 Selected filter: $selectedFilter');

      List<Map<String, dynamic>> allResults = [];

      bool filterSemua = selectedFilter == 'Semua';
      bool filterPengajian = selectedFilter == 'Pengajian';
      bool filterEbook = selectedFilter == 'E-Book';

      // Search in video kitab if filter allows
      if (filterSemua || filterPengajian) {
        final filteredVideoKitab = videoKitabList.where((vk) {
          final title = vk.title.toLowerCase().trim();
          final author = vk.author?.toLowerCase().trim() ?? '';
          final description = vk.description?.toLowerCase().trim() ?? '';

          return title.contains(q) || author.contains(q) || description.contains(q);
        }).toList();

        final videoKitabResults = filteredVideoKitab.map((vk) {
          String? categoryName;

          if (vk.categoryId != null) {
            try {
              final category = kitabProvider.categories.firstWhere(
                (c) => c.id == vk.categoryId,
              );
              categoryName = category.name;
            } catch (e) {
              categoryName = null;
            }
          }

          return {
            'id': vk.id,
            'title': vk.title,
            'author': vk.author?.trim().isNotEmpty == true ? vk.author : null,
            'type': 'kitab',
            'category': categoryName,
            'description': vk.description != null && vk.description!.length > 100
                ? '${vk.description!.substring(0, 100)}...'
                : vk.description,
            'isPremium': vk.isPremium,
            'totalVideos': vk.totalVideos,
            'categoryName': categoryName,
            'thumbnailUrl': vk.thumbnailUrl,
          };
        }).toList();

        allResults.addAll(videoKitabResults);
      }

      // Search in ebooks if filter allows
      if (filterSemua || filterEbook) {
        final filteredEbooks = ebookList.where((eb) {
          final title = eb.title.toLowerCase().trim();
          final author = eb.author?.toLowerCase().trim() ?? '';
          final description = eb.description?.toLowerCase().trim() ?? '';

          return title.contains(q) || author.contains(q) || description.contains(q);
        }).toList();

        final ebookResults = filteredEbooks.map((eb) {
          String? categoryName;

          if (eb.categoryId != null) {
            try {
              final category = kitabProvider.categories.firstWhere(
                (c) => c.id == eb.categoryId,
              );
              categoryName = category.name;
            } catch (e) {
              categoryName = null;
            }
          }

          return {
            'id': eb.id,
            'title': eb.title,
            'author': eb.author?.trim().isNotEmpty == true ? eb.author : null,
            'type': 'ebook',
            'category': categoryName,
            'description': eb.description != null && eb.description!.length > 100
                ? '${eb.description!.substring(0, 100)}...'
                : eb.description,
            'isPremium': eb.isPremium,
            'totalPages': eb.totalPages,
            'categoryName': categoryName,
          };
        }).toList();

        allResults.addAll(ebookResults);
      }

      searchResults = allResults;
      isSearching = false;
      onStateChanged?.call();

      debugPrint('📚 Found ${searchResults.length} items matching "$q" with filter "$selectedFilter"');
    } catch (e) {
      debugPrint('❌ Search error: $e');
      searchResults = [];
      isSearching = false;
      onStateChanged?.call();
    }
  }

  // Recent searches management
  void addToRecentSearches(String search) {
    recentSearches.remove(search);
    recentSearches.insert(0, search);
    if (recentSearches.length > 5) {
      recentSearches.removeLast();
    }
    onStateChanged?.call();
  }

  void removeRecentSearch(String search) {
    recentSearches.remove(search);
    onStateChanged?.call();
  }

  void clearSearch() {
    searchResults = [];
    isSearching = false;
    onStateChanged?.call();
  }
}
