import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/models/video_kitab.dart';
import '../../../core/models/ebook.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _searchResults = [];
  final List<String> _recentSearches =
      []; // Will be loaded from storage in future
  final List<String> _popularSearches =
      []; // Will be loaded from analytics in future
  bool _isSearching = false;
  String _selectedFilter = 'Semua';
  Timer? _debounceTimer;
  bool _showFilter = true;

  final List<String> _filterOptions = ['Semua', 'Pengajian', 'E-Book'];

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

    // Add scroll listener for filter visibility
    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _showFilter) {
        setState(() {
          _showFilter = false;
        });
      } else if (_scrollController.offset <= 10 && !_showFilter) {
        setState(() {
          _showFilter = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.arrowLeft(),
            color: Colors.black,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            children: [
              Expanded(child: _buildSearchField()),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (_searchController.text.isNotEmpty) {
                    _performSearch(_searchController.text);
                  }
                },
                child: Text(
                  'Search',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        titleSpacing: 0,
      ),
      body: Stack(
        children: [
          // Main content dengan padding top untuk filter
          Padding(
            padding: EdgeInsets.only(top: _showFilter ? 45 : 0),
            child: _searchController.text.isEmpty
                ? _buildSearchSuggestions()
                : _buildSearchResults(),
          ),
          // Filter sticky di atas dengan animation
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showFilter ? 0 : -45,
            left: 0,
            right: 0,
            child: _buildFilterChips(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFEEEEEE),
          hintText: 'Cari kitab yang anda inginkan...',
          hintStyle: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: PhosphorIcon(
              PhosphorIcons.magnifyingGlass(),
              color: AppTheme.textSecondaryColor,
              size: 20,
            ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: _clearSearch,
                  icon: PhosphorIcon(
                    PhosphorIcons.x(),
                    color: AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) {
          setState(() {}); // Update to show/hide X button
          _performSearch(value);
        },
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
      color: AppTheme.backgroundColor,
      child: Container(
        height: 45,
        padding: const EdgeInsets.only(left: 16, top: 6, bottom: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _filterOptions.length,
          itemBuilder: (context, index) {
            final filter = _filterOptions[index];
            final isSelected = _selectedFilter == filter;

            return Container(
              margin: EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter;
                  });
                  // Trigger search if there's text, otherwise just update the list
                  if (_searchController.text.isNotEmpty) {
                    _performSearch(_searchController.text);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE8E8E8) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? Colors.grey.shade300
                          : Colors.grey.shade200,
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textPrimaryColor
                          : AppTheme.textSecondaryColor,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        // Filter items based on selected filter
        final allItems = <dynamic>[];

        if (_selectedFilter == 'Semua') {
          allItems.addAll(kitabProvider.activeVideoKitab);
          allItems.addAll(kitabProvider.activeEbooks);
        } else if (_selectedFilter == 'Pengajian') {
          allItems.addAll(kitabProvider.activeVideoKitab);
        } else if (_selectedFilter == 'E-Book') {
          allItems.addAll(kitabProvider.activeEbooks);
        }

        if (allItems.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Recent searches (if any)
            if (_recentSearches.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: AppTheme.backgroundColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        'Carian Terkini',
                        PhosphorIcons.clockCounterClockwise(),
                      ),
                      const SizedBox(height: 12),
                      _buildSearchChips(_recentSearches, true),
                    ],
                  ),
                ),
              ),

            // Filtered items list
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = allItems[index];
                  if (item is VideoKitab) {
                    return _buildKitabCard(item);
                  } else {
                    return _buildEbookCard(item);
                  }
                }, childCount: allItems.length),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, dynamic icon) {
    return Row(
      children: [
        PhosphorIcon(icon, color: AppTheme.primaryColor, size: 20),
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
              ? PhosphorIcon(
                  PhosphorIcons.clockCounterClockwise(),
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                )
              : PhosphorIcon(
                  PhosphorIcons.trendUp(),
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
          deleteIcon: isRecent
              ? PhosphorIcon(PhosphorIcons.x(), size: 16)
              : null,
          onDeleted: isRecent ? () => _removeRecentSearch(search) : null,
        );
      }).toList(),
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
      controller: _scrollController,
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
          PhosphorIcon(
            PhosphorIcons.magnifyingGlassMinus(),
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
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
                child: PhosphorIcon(
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
              PhosphorIcon(
                PhosphorIcons.caretRight(),
                color: Colors.black54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  dynamic _getResultIcon(String type) {
    switch (type) {
      case 'kitab':
        return PhosphorIcons.book();
      case 'video':
        return PhosphorIcons.videoCamera();
      case 'author':
        return PhosphorIcons.user();
      default:
        return PhosphorIcons.magnifyingGlass();
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
      if (kitabProvider.videoKitabList.isEmpty &&
          kitabProvider.ebookList.isEmpty) {
        await Future.wait([
          kitabProvider.loadVideoKitabList(),
          kitabProvider.loadEbookList(),
        ]);
        // Double check if still empty after loading
        if (kitabProvider.videoKitabList.isEmpty &&
            kitabProvider.ebookList.isEmpty) {
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
      final videoKitabList = kitabProvider.activeVideoKitab;
      final ebookList = kitabProvider.activeEbooks;

      print(
        '🔍 Searching for: "$q" in ${videoKitabList.length} video kitab and ${ebookList.length} ebooks',
      );
      print('📋 Selected filter: $_selectedFilter');

      // Filter by title or author
      List<Map<String, dynamic>> results = [];

      bool filterSemua = _selectedFilter == 'Semua';
      bool filterPengajian = _selectedFilter == 'Pengajian';
      bool filterEbook = _selectedFilter == 'E-Book';

      // Search in video kitab and ebooks
      List<Map<String, dynamic>> allResults = [];

      // Search in video kitab if filter allows
      if (filterSemua || filterPengajian) {
        final filteredVideoKitab = videoKitabList.where((vk) {
          final title = (vk.title ?? '').toLowerCase().trim();
          final author = (vk.author ?? '').toLowerCase().trim();
          final description = (vk.description ?? '').toLowerCase().trim();

          // Check if query matches title, author, or description
          final titleMatches = title.contains(q);
          final authorMatches = author.contains(q);
          final descMatches = description.contains(q);
          return titleMatches || authorMatches || descMatches;
        }).toList();

        final videoKitabResults = filteredVideoKitab.map((vk) {
          String? categoryName;

          // Get category name
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
            'title': vk.title ?? 'Tidak Berjudul',
            'author': (vk.author ?? '').trim().isNotEmpty ? vk.author : null,
            'type': 'kitab',
            'category': categoryName,
            'description':
                vk.description?.length != null && vk.description!.length > 100
                ? '${vk.description!.substring(0, 100)}...'
                : vk.description,
            'isPremium': vk.isPremium,
          };
        }).toList();

        allResults.addAll(videoKitabResults);
      }

      // Search in ebooks if filter allows
      if (filterSemua || filterEbook) {
        final filteredEbooks = ebookList.where((eb) {
          final title = (eb.title ?? '').toLowerCase().trim();
          final author = (eb.author ?? '').toLowerCase().trim();
          final description = (eb.description ?? '').toLowerCase().trim();

          // Check if query matches title, author, or description
          final titleMatches = title.contains(q);
          final authorMatches = author.contains(q);
          final descMatches = description.contains(q);
          return titleMatches || authorMatches || descMatches;
        }).toList();

        final ebookResults = filteredEbooks.map((eb) {
          String? categoryName;

          // Get category name
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
            'title': eb.title ?? 'Tidak Berjudul',
            'author': (eb.author ?? '').trim().isNotEmpty ? eb.author : null,
            'type': 'ebook',
            'category': categoryName,
            'description':
                eb.description?.length != null && eb.description!.length > 100
                ? '${eb.description!.substring(0, 100)}...'
                : eb.description,
            'isPremium': eb.isPremium,
          };
        }).toList();

        allResults.addAll(ebookResults);
      }

      results = allResults;

      print(
        '📚 Found ${results.length} items matching "$q" with filter "$_selectedFilter"',
      );

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

  Widget _buildKitabCard(VideoKitab kitab) {
    final hasVideo = kitab.totalVideos > 0;
    final hasEbook = kitab.pdfUrl != null && kitab.pdfUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/kitab/${kitab.id}'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Video camera icon with circular background
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.videoCamera(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 35,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title with crown
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              kitab.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (kitab.isPremium) ...[
                            const SizedBox(width: 6),
                            PhosphorIcon(
                              PhosphorIcons.crown(PhosphorIconsStyle.fill),
                              color: const Color(0xFFFFD700),
                              size: 16,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 2),

                      // Category
                      Text(
                        kitab.categoryName ?? 'Kategori Umum',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 2),

                      // Episode info
                      Text(
                        hasVideo && kitab.totalVideos > 0
                            ? '${kitab.totalVideos} episod'
                            : hasEbook
                            ? 'PDF tersedia'
                            : '1 episod',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // Arrow icon
              PhosphorIcon(
                PhosphorIcons.caretRight(),
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEbookCard(Ebook ebook) {
    return GestureDetector(
      onTap: () => context.push('/ebook/${ebook.id}'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Book icon with circular background
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.book(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 35,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title with crown
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              ebook.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ebook.isPremium) ...[
                            const SizedBox(width: 6),
                            PhosphorIcon(
                              PhosphorIcons.crown(PhosphorIconsStyle.fill),
                              color: const Color(0xFFFFD700),
                              size: 16,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 2),

                      // Category
                      Text(
                        ebook.categoryName ?? 'Kategori Umum',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 2),

                      // Page info
                      Text(
                        ebook.totalPages != null && ebook.totalPages! > 0
                            ? '${ebook.totalPages} muka surat'
                            : 'E-Book tersedia',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // Arrow icon
              PhosphorIcon(
                PhosphorIcons.caretRight(),
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openResult(Map<String, dynamic> result) {
    switch (result['type']) {
      case 'kitab':
      case 'video':
        context.push('/kitab/${result['id']}');
        break;
      case 'ebook':
        context.push('/ebook/${result['id']}');
        break;
      case 'author':
        context.push('/kitab?author=${result['title']}');
        break;
    }
  }
}
