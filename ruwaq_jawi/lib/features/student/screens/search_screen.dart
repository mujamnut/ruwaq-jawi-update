import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/models/kitab.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  final List<String> _recentSearches =
      []; // Will be loaded from storage in future
  final List<String> _popularSearches =
      []; // Will be loaded from analytics in future
  bool _isSearching = false;
  String _selectedFilter = 'Semua';
  Timer? _debounceTimer;

  final List<String> _filterOptions = ['Semua', 'Kitab', 'Video', 'Pengarang'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });

    // Add listener to update UI when text changes
    _searchController.addListener(() {
      setState(() {}); // Rebuild to update clear button visibility
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        elevation: 0,
        title: _buildSearchField(),
        actions: [
          if (_searchController.text.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white, size: 20),
                onPressed: _clearSearch,
                tooltip: 'Kosongkan carian',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildSearchSuggestions()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Cari kitab, video, atau pengarang...',
          hintStyle: const TextStyle(color: Colors.black45, fontSize: 16),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Colors.black54, size: 22),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
        ),
        onChanged: _performSearch,
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            _addToRecentSearches(value);
          }
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final filter = _filterOptions[index];
          final isSelected = _selectedFilter == filter;

          return Container(
            margin: EdgeInsets.only(
              right: index < _filterOptions.length - 1 ? 8 : 0,
            ),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
                if (_searchController.text.isNotEmpty) {
                  _performSearch(_searchController.text);
                }
              },
              backgroundColor: AppTheme.surfaceColor,
              selectedColor: AppTheme.primaryColor,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            _buildSectionHeader('Carian Terkini', Icons.history),
            const SizedBox(height: 12),
            _buildSearchChips(_recentSearches, true),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('Carian Popular', Icons.trending_up),
          const SizedBox(height: 12),
          _buildSearchChips(_popularSearches, false),
          const SizedBox(height: 24),
          _buildQuickCategories(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchChips(List<String> searches, bool isRecent) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: searches.map((search) {
        return InputChip(
          label: Text(search),
          onPressed: () => _selectSuggestion(search),
          backgroundColor: AppTheme.surfaceColor,
          side: BorderSide(color: AppTheme.borderColor),
          labelStyle: const TextStyle(color: Colors.black),
          avatar: isRecent
              ? Icon(
                  Icons.history,
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                )
              : Icon(Icons.trending_up, size: 16, color: AppTheme.primaryColor),
          deleteIcon: isRecent ? const Icon(Icons.close, size: 16) : null,
          onDeleted: isRecent ? () => _removeRecentSearch(search) : null,
        );
      }).toList(),
    );
  }

  Widget _buildQuickCategories() {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        final categories = kitabProvider.categories.take(4).map((category) {
          final kitabCount = kitabProvider.kitabList
              .where((k) => k.categoryId == category.id)
              .length;
          return {
            'name': category.name,
            'icon': Icons.book, // Default icon, could be made dynamic
            'count': kitabCount,
          };
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Kategori Popular', Icons.category),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return GestureDetector(
                  onTap: () => _selectSuggestion(category['name'] as String),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            category['icon'] as IconData,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                category['name'] as String,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                              ),
                              Text(
                                '${category['count']} kitab',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return _buildNoResults();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildResultCard(_searchResults[index]);
      },
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppTheme.textSecondaryColor),
          const SizedBox(height: 16),
          Text(
            'Tiada hasil ditemui',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuba gunakan kata kunci yang berbeza',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: InkWell(
        onTap: () => _openResult(result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getResultIcon(result['type']),
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            result['title'],
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                          ),
                        ),
                        if (result['isPremium'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PREMIUM',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result['author'] ?? result['category'] ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    if (result['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        result['description'],
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.black54, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getResultIcon(String type) {
    switch (type) {
      case 'kitab':
        return Icons.book;
      case 'video':
        return Icons.play_circle_outline;
      case 'author':
        return Icons.person;
      default:
        return Icons.search;
    }
  }

  void _performSearch(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Don't search if query is too short (less than 2 characters)
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Set loading state immediately for better UX
    setState(() {
      _isSearching = true;
    });

    // Start debounce timer
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performActualSearch(query);
    });
  }

  void _performActualSearch(String query) async {
    try {
      final kitabProvider = Provider.of<KitabProvider>(context, listen: false);

      // Ensure data is loaded - wait for it properly
      if (kitabProvider.kitabList.isEmpty) {
        await kitabProvider.loadKitabList();
        // Double check if still empty after loading
        if (kitabProvider.kitabList.isEmpty) {
          if (mounted) {
            setState(() {
              _searchResults = [];
              _isSearching = false;
            });
          }
          return;
        }
      }

      final q = query.toLowerCase().trim();
      final List<Kitab> all = List<Kitab>.from(kitabProvider.kitabList);

      print('🔍 Searching for: "$q" in ${all.length} kitab');
      print('📋 Selected filter: $_selectedFilter');

      // Filter by title or author
      List<Map<String, dynamic>> results = [];

      bool filterSemua = _selectedFilter == 'Semua';
      bool filterKitab = _selectedFilter == 'Kitab';
      bool filterVideo = _selectedFilter == 'Video';
      bool filterPengarang = _selectedFilter == 'Pengarang';

      if (filterPengarang) {
        // Search for authors only
        final authorsSet = <String>{};
        for (final k in all) {
          final author = (k.author ?? '').trim();
          if (author.isNotEmpty && author.toLowerCase().contains(q)) {
            authorsSet.add(author);
          }
        }

        results = authorsSet
            .map(
              (author) => {
                'id': author.hashCode.toString(),
                'title': author,
                'author': null,
                'type': 'author',
                'description': 'Pengarang',
                'isPremium': null,
              },
            )
            .toList();

        print('👤 Found ${results.length} authors matching "$q"');
      } else {
        // Search in kitab titles and authors
        final filteredKitab = all.where((k) {
          final title = (k.title ?? '').toLowerCase().trim();
          final author = (k.author ?? '').toLowerCase().trim();
          final description = (k.description ?? '').toLowerCase().trim();

          // Check if query matches title, author, or description
          final titleMatches = title.contains(q);
          final authorMatches = author.contains(q);
          final descMatches = description.contains(q);
          final matches = titleMatches || authorMatches || descMatches;

          if (!matches) return false;

          // Apply type filter
          if (filterKitab) {
            return true; // All kitab that match query
          } else if (filterVideo) {
            return (k.youtubeVideoId?.isNotEmpty ??
                false); // Only kitab with videos
          } else {
            return true; // Semua - all matching results
          }
        }).toList();

        results = filteredKitab.map((k) {
          final hasVideo = (k.youtubeVideoId?.isNotEmpty ?? false);
          String? categoryName;

          // Get category name
          if (k.categoryId != null) {
            try {
              final category = kitabProvider.categories.firstWhere(
                (c) => c.id == k.categoryId,
              );
              categoryName = category.name;
            } catch (e) {
              categoryName = null;
            }
          }

          return {
            'id': k.id,
            'title': k.title ?? 'Tidak Berjudul',
            'author': (k.author ?? '').trim().isNotEmpty ? k.author : null,
            'type': filterVideo ? 'video' : (hasVideo ? 'video' : 'kitab'),
            'category': categoryName,
            'description':
                k.description?.length != null && k.description!.length > 100
                ? '${k.description!.substring(0, 100)}...'
                : k.description,
            'isPremium': k.isPremium,
            'youtubeVideoId': k.youtubeVideoId,
          };
        }).toList();

        print(
          '📚 Found ${results.length} kitab matching "$q" with filter "$_selectedFilter"',
        );
      }

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('❌ Search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _mockSearch(String query) {
    final allResults = [
      {
        'id': '1',
        'title': 'Tafsir Ibn Kathir',
        'author': 'Ibn Kathir',
        'type': 'kitab',
        'category': 'Tafsir',
        'description': 'Tafsir Al-Quran yang terkenal dan komprehensif',
        'isPremium': true,
      },
      {
        'id': '2',
        'title': 'Sahih Bukhari',
        'author': 'Imam Bukhari',
        'type': 'kitab',
        'category': 'Hadis',
        'description': 'Koleksi hadis sahih yang paling otentik',
        'isPremium': false,
      },
      {
        'id': '3',
        'title': 'Adab Menuntut Ilmu',
        'author': 'Ustaz Ahmad',
        'type': 'video',
        'category': 'Akhlak',
        'description': 'Video pembelajaran tentang adab dalam menuntut ilmu',
        'isPremium': false,
      },
      {
        'id': '4',
        'title': 'Ibn Kathir',
        'type': 'author',
        'description': 'Ulama besar ahli tafsir dari Damaskus',
        'isPremium': null,
      },
    ];

    final q = query.toLowerCase();
    return allResults.where((result) {
      final title = (result['title'] as String?)?.toLowerCase() ?? '';
      final author = (result['author'] as String?)?.toLowerCase() ?? '';
      final desc = (result['description'] as String?)?.toLowerCase() ?? '';

      final matchesQuery =
          title.contains(q) || author.contains(q) || desc.contains(q);

      final type = result['type'] as String?;
      final matchesFilter =
          _selectedFilter == 'Semua' ||
          (_selectedFilter == 'Kitab' && type == 'kitab') ||
          (_selectedFilter == 'Video' && type == 'video') ||
          (_selectedFilter == 'Pengarang' && type == 'author');

      return matchesQuery && matchesFilter;
    }).toList();
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _performSearch(suggestion);
    _addToRecentSearches(suggestion);
  }

  void _addToRecentSearches(String search) {
    setState(() {
      _recentSearches.remove(search);
      _recentSearches.insert(0, search);
      if (_recentSearches.length > 5) {
        _recentSearches.removeLast();
      }
    });
  }

  void _removeRecentSearch(String search) {
    setState(() {
      _recentSearches.remove(search);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }

  void _openResult(Map<String, dynamic> result) {
    switch (result['type']) {
      case 'kitab':
      case 'video':
        context.push('/kitab/${result['id']}');
        break;
      case 'author':
        context.push('/kitab?author=${result['title']}');
        break;
    }
  }
}
