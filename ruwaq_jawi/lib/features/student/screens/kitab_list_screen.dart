import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/models/video_kitab.dart';
import '../widgets/student_bottom_nav.dart';

class KitabListScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialSort;

  const KitabListScreen({super.key, this.initialCategory, this.initialSort});

  @override
  State<KitabListScreen> createState() => _KitabListScreenState();
}

class _KitabListScreenState extends State<KitabListScreen> {
  String? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      bool scrolled = _scrollController.offset > 10;
      if (scrolled != _isScrolled) {
        setState(() {
          _isScrolled = scrolled;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kitabProvider = context.read<KitabProvider>();
      if (kitabProvider.videoKitabList.isEmpty) {
        kitabProvider.initialize();
      }

      // Set initial category filter if provided
      if (widget.initialCategory != null &&
          widget.initialCategory!.isNotEmpty) {
        _setInitialCategoryFilter(kitabProvider);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setInitialCategoryFilter(KitabProvider kitabProvider) {
    final categoryName = Uri.decodeComponent(widget.initialCategory!);
    if (categoryName != 'Semua') {
      try {
        final category = kitabProvider.categories.firstWhere(
          (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
        );
        setState(() {
          _selectedCategoryId = category.id;
        });
      } catch (e) {
        // Category not found, keep default selection
        debugPrint('Category "$categoryName" not found');
        debugPrint(
          'Available categories: ${kitabProvider.categories.map((c) => c.name).join(', ')}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: Text(
              'Pengajian Kitab',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: _isScrolled ? Colors.white : AppTheme.backgroundColor,
            iconTheme: IconThemeData(color: Colors.black),
            elevation: _isScrolled ? 2 : 0,
            centerTitle: false,
            titleSpacing: 20,
          ),
          body: kitabProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : kitabProvider.errorMessage != null
              ? _buildErrorState(kitabProvider.errorMessage!)
              : _buildScrollableContent(kitabProvider),
          bottomNavigationBar: const StudentBottomNav(currentIndex: 1),
        );
      },
    );
  }

  Widget _buildScrollableContent(KitabProvider kitabProvider) {
    List<VideoKitab> filteredKitab = kitabProvider.activeVideoKitab.where((
      videoKitab,
    ) {
      bool categoryMatch =
          _selectedCategoryId == null ||
          videoKitab.categoryId == _selectedCategoryId;

      bool searchMatch =
          _searchQuery.isEmpty ||
          videoKitab.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (videoKitab.author?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false);

      return categoryMatch && searchMatch;
    }).toList();

    // Sort by newest by default
    filteredKitab.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (filteredKitab.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSearchAndFilters(kitabProvider)),
          SliverFillRemaining(child: _buildEmptyState()),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await kitabProvider.refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search and Filters
          SliverToBoxAdapter(child: _buildSearchAndFilters(kitabProvider)),

          // List Content (Changed from grid to list for better card layout)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final kitab = filteredKitab[index];
                return AnimatedContainer(
                  duration: Duration(milliseconds: 200 + (index * 50)),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: _buildKitabCard(kitab),
                );
              }, childCount: filteredKitab.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(KitabProvider kitabProvider) {
    final categories = [
      'Semua',
      ...kitabProvider.categories.map((c) => c.name),
    ];
    final selectedCategory = _selectedCategoryId == null
        ? 'Semua'
        : kitabProvider.categories
              .firstWhere((c) => c.id == _selectedCategoryId)
              .name;

    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _searchController,
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
                  borderSide: BorderSide(
                    color: Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Category Filters
          Container(
            height: 40,
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;

                return Container(
                  margin: EdgeInsets.only(right: 12, bottom: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (category == 'Semua') {
                          _selectedCategoryId = null;
                        } else {
                          _selectedCategoryId = kitabProvider.categories
                              .firstWhere((c) => c.name == category)
                              .id;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE8E8E8)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                        category,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.textPrimaryColor
                              : AppTheme.textSecondaryColor,
                          fontSize: 13,
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
        ],
      ),
    );
  }

  Widget _buildKitabCard(VideoKitab kitab) {
    final hasVideo = kitab.totalVideos > 0;
    final hasEbook = kitab.pdfUrl != null && kitab.pdfUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/kitab/${kitab.id}'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: PhosphorIcon(
                PhosphorIcons.chalkboardTeacher(),
                size: 64,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tiada Kitab Video Ditemui',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Cuba ubah penapis kategori atau periksa semula untuk melihat kitab video yang tersedia',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCategoryId = null;
                });
              },
              icon: PhosphorIcon(
                PhosphorIcons.arrowClockwise(),
                color: AppTheme.textLightColor,
                size: 18,
              ),
              label: const Text('Reset Penapis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textLightColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: PhosphorIcon(
              PhosphorIcons.warning(),
              size: 64,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ralat Memuat Data',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              context.read<KitabProvider>().refresh();
            },
            icon: PhosphorIcon(
              PhosphorIcons.arrowClockwise(),
              color: AppTheme.textLightColor,
              size: 18,
            ),
            label: const Text('Cuba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.textLightColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }
}
