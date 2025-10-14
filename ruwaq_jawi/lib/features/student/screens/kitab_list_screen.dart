import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/saved_items_provider.dart';
import '../../../core/models/video_kitab.dart';
import '../../../core/utils/youtube_utils.dart';
import '../../../core/utils/thumbnail_utils.dart';
import '../widgets/student_bottom_nav.dart';
import 'package:hugeicons/hugeicons.dart';

class KitabListScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialSort;

  const KitabListScreen({super.key, this.initialCategory, this.initialSort});

  @override
  State<KitabListScreen> createState() => _KitabListScreenState();
}

class _KitabListScreenState extends State<KitabListScreen>
    with TickerProviderStateMixin {
  String? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  late AnimationController _animationController;
  late AnimationController _searchAnimationController;
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scrollController.addListener(() {
      bool scrolled = _scrollController.offset > 10;
      if (scrolled != _isScrolled) {
        setState(() {
          _isScrolled = scrolled;
        });
      }
    });

    // Start entrance animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      _fadeAnimationController.forward();
      _slideAnimationController.forward();
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
    _animationController.dispose();
    _searchAnimationController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
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
          appBar: _buildAppBar(),
          body: kitabProvider.isLoading
              ? _buildLoadingState(kitabProvider)
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
        if (mounted) {
          _fadeAnimationController.reset();
          _slideAnimationController.reset();
          _fadeAnimationController.forward();
          _slideAnimationController.forward();
        }
      },
      color: AppTheme.primaryColor,
      child: FadeTransition(
        opacity: _fadeAnimationController,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Search and Filters
            SliverToBoxAdapter(child: _buildSearchAndFilters(kitabProvider)),

            // Enhanced List Content with staggered animations
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final kitab = filteredKitab[index];
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _slideAnimationController,
                            curve: Interval(
                              (index * 0.1).clamp(0.0, 1.0),
                              1.0,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                        ),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _fadeAnimationController,
                        curve: Interval(
                          (index * 0.1).clamp(0.0, 1.0),
                          1.0,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: _buildKitabCard(kitab),
                    ),
                  );
                }, childCount: filteredKitab.length),
              ),
            ),
          ],
        ),
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
          // Add top padding consistent with ebook screen
          const SizedBox(height: 20),

          // Enhanced Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: AnimatedBuilder(
              animation: _searchAnimationController,
              builder: (context, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isSearchFocused
                          ? AppTheme.primaryColor.withValues(alpha: 0.3)
                          : AppTheme.borderColor,
                      width: _isSearchFocused ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isSearchFocused
                            ? AppTheme.primaryColor.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: _isSearchFocused ? 12 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onTap: () {
                      setState(() => _isSearchFocused = true);
                      _searchAnimationController.forward();
                    },
                    onEditingComplete: () {
                      setState(() => _isSearchFocused = false);
                      _searchAnimationController.reverse();
                      FocusScope.of(context).unfocus();
                    },
                    decoration: InputDecoration(
                      filled: false,
                      hintText: 'Cari kitab yang anda inginkan...',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: PhosphorIcon(
                          PhosphorIcons.magnifyingGlass(),
                          color: _isSearchFocused
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondaryColor,
                          size: 20,
                        ),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: PhosphorIcon(
                                PhosphorIcons.x(),
                                color: AppTheme.textSecondaryColor,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // Enhanced Category Filters
          Container(
            height: 50,
            padding: const EdgeInsets.only(left: 20, bottom: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;

                return Container(
                  margin: const EdgeInsets.only(right: 5),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.lightImpact();
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
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.95 + (0.05 * value),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.borderColor,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: PhosphorIcon(
                                        PhosphorIcons.check(),
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textSecondaryColor,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

  Widget _buildVideoThumbnail(VideoKitab kitab) {
    // Use ThumbnailUtils for auto-fallback to YouTube thumbnail
    String? thumbnailUrl = ThumbnailUtils.getThumbnailUrlWithFallback(
      thumbnailUrl: kitab.thumbnailUrl,
      youtubeVideoId: null, // VideoKitab doesn't have direct YouTube video ID
      quality: YouTubeThumbnailQuality.hqdefault,
    );

    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return Container(
        width: 140,
        height: 85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.backgroundColor,
        ),
        child: Image.network(
          thumbnailUrl,
          width: 140,
          height: 85,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultThumbnail();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 140,
              height: 85,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else {
      return _buildDefaultThumbnail();
    }
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: 140,
      height: 85,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.12),
            AppTheme.primaryColor.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              PhosphorIcons.videoCamera(),
              size: 32,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 4),
            Text(
              'Video',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitabCard(VideoKitab kitab) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/kitab/${kitab.id}');
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Thumbnail
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildVideoThumbnail(kitab),
                            ),
                          ),
                          // Duration badge (bottom right)
                          if (kitab.totalDurationMinutes > 0)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  kitab.formattedDuration,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          // Premium badge (top left)
                          if (kitab.isPremium)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFB8860B),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFFD700,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIcons.crown(
                                        PhosphorIconsStyle.fill,
                                      ),
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 3),
                                    const Text(
                                      'PREMIUM',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Play button overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.center,
                                  end: Alignment.center,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.05),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: PhosphorIcon(
                                    PhosphorIcons.play(PhosphorIconsStyle.fill),
                                    color: AppTheme.primaryColor,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 16),

                      // Enhanced Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              kitab.title,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimaryColor,
                                    height: 1.3,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 6),

                            // Author/Category with icon
                            Row(
                              children: [
                                PhosphorIcon(
                                  PhosphorIcons.user(),
                                  color: AppTheme.textSecondaryColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    kitab.author ??
                                        kitab.categoryName ??
                                        'Kategori Umum',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontSize: 13,
                                          color: AppTheme.textSecondaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Category display only
                            if (kitab.categoryName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  kitab.categoryName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                            const SizedBox(height: 8),

                            // Video count badge
                            if (kitab.totalVideos > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIcons.videoCamera(),
                                      color: AppTheme.primaryColor,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${kitab.totalVideos} episod',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Action button with bottom sheet
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.borderColor,
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showKitabOptionsBottomSheet(kitab);
                            },
                            child: Center(
                              child: PhosphorIcon(
                                PhosphorIcons.dotsThreeVertical(),
                                color: AppTheme.textSecondaryColor,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Fixed app bar with better visibility
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _isScrolled
          ? AppTheme.surfaceColor.withValues(alpha: 0.95)
          : Colors.transparent,
      elevation: _isScrolled ? 1 : 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      automaticallyImplyLeading: false,
      title: Text(
        'Pengajian Kitab',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimaryColor,
        ),
      ),
      centerTitle: false,
      titleSpacing: 20,
    );
  }

  // Loading state: keep search + filters visible, skeleton only for list
  Widget _buildLoadingState(KitabProvider kitabProvider) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        // Keep real search and filters visible during refresh
        SliverToBoxAdapter(child: _buildSearchAndFilters(kitabProvider)),

        // Skeleton cards for list content only
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 85,
                        decoration: BoxDecoration(
                          color: AppTheme.borderColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 16,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.borderColor.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 14,
                              width: 120,
                              decoration: BoxDecoration(
                                color: AppTheme.borderColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  height: 12,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: AppTheme.borderColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  height: 12,
                                  width: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.borderColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }

  /// Show bottom sheet with kitab options
  void _showKitabOptionsBottomSheet(VideoKitab kitab) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header with kitab info
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      // Thumbnail
                      Container(
                        width: 60,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppTheme.backgroundColor,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kitab.thumbnailUrl?.isNotEmpty == true
                              ? Image.network(
                                  kitab.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: Center(
                                        child: PhosphorIcon(
                                          PhosphorIcons.videoCamera(),
                                          size: 16,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Center(
                                    child: PhosphorIcon(
                                      PhosphorIcons.videoCamera(),
                                      size: 16,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title and author
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kitab.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (kitab.author?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                kitab.author!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  height: 1,
                  color: AppTheme.borderColor.withValues(alpha: 0.5),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      // Save option
                      FutureBuilder<bool>(
                        future: _isVideoKitabSaved(kitab.id),
                        builder: (context, snapshot) {
                          final isSaved = snapshot.data ?? false;
                          return _buildBottomSheetOption(
                            icon: isSaved
                                ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                                : PhosphorIcons.heart(),
                            title: isSaved
                                ? 'Buang dari Simpanan'
                                : 'Simpan ke Koleksi',
                            subtitle: isSaved
                                ? 'Alih keluar dari senarai simpanan'
                                : 'Simpan untuk tontonnan kemudian',
                            iconColor: isSaved
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondaryColor,
                            onTap: () {
                              Navigator.of(context).pop();
                              _handleMenuAction('save', kitab);
                            },
                          );
                        },
                      ),

                      // Share option
                      _buildBottomSheetOption(
                        icon: HugeIcons.strokeRoundedShare08,
                        title: 'Kongsi',
                        subtitle: 'Kongsi dengan rakan dan keluarga',
                        iconColor: AppTheme.textSecondaryColor,
                        onTap: () {
                          Navigator.of(context).pop();
                          _handleMenuAction('share', kitab);
                        },
                      ),

                      // View details option
                      _buildBottomSheetOption(
                        icon: HugeIcons.strokeRoundedEye,
                        title: 'Lihat Detail',
                        subtitle: 'Buka halaman detail kitab',
                        iconColor: AppTheme.textSecondaryColor,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/kitab/${kitab.id}');
                        },
                      ),
                    ],
                  ),
                ),

                // Bottom padding for safe area
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build individual option in bottom sheet
  Widget _buildBottomSheetOption({
    required dynamic icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor == AppTheme.primaryColor
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: iconColor == AppTheme.primaryColor
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : AppTheme.borderColor,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: icon is IconData
                      ? HugeIcon(icon: icon, color: iconColor, size: 20)
                      : icon is PhosphorIconData
                      ? PhosphorIcon(icon, color: iconColor, size: 20)
                      : icon,
                ),
              ),
              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              PhosphorIcon(
                PhosphorIcons.caretRight(),
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check if a video kitab is saved by the user
  Future<bool> _isVideoKitabSaved(String videoKitabId) async {
    try {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      return await savedItemsProvider.isKitabSaved(videoKitabId);
    } catch (e) {
      debugPrint('Error checking if video kitab is saved: $e');
      return false;
    }
  }

  /// Handle menu action selection
  Future<void> _handleMenuAction(String action, VideoKitab kitab) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sila log masuk terlebih dahulu'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      switch (action) {
        case 'save':
          await _handleSaveAction(userId, kitab);
          break;
        case 'share':
          await _handleShareAction(kitab);
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ralat: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Handle save/unsave action
  Future<void> _handleSaveAction(String userId, VideoKitab kitab) async {
    HapticFeedback.lightImpact();

    final isSaved = await _isVideoKitabSaved(kitab.id);

    if (isSaved) {
      // Remove from saved (Supabase)
      final savedItemsProvider = context.read<SavedItemsProvider>();
      await savedItemsProvider.removeFromSaved(kitab.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.heartBreak(PhosphorIconsStyle.fill),
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text('Dibuang dari simpanan'),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Add to saved (Supabase)
      final savedItemsProvider = context.read<SavedItemsProvider>();
      await savedItemsProvider.addToSaved(kitab.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.heart(PhosphorIconsStyle.fill),
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text('Disimpan ke koleksi anda'),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Lihat',
              textColor: Colors.white,
              onPressed: () {
                context.push('/saved');
              },
            ),
          ),
        );
      }
    }

    // Trigger rebuild to update the UI
    if (mounted) {
      setState(() {});
    }
  }

  /// Handle share action
  Future<void> _handleShareAction(VideoKitab kitab) async {
    HapticFeedback.lightImpact();

    // For now, show a simple dialog
    // In a real app, you'd use share_plus package or similar
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppTheme.surfaceColor,
        title: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedShare08,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              'Kongsi Kitab',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kongsi "${kitab.title}" dengan rakan-rakan anda!',
              style: TextStyle(color: AppTheme.textSecondaryColor, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'https://ruwaqjawi.app/kitab/${kitab.id}',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        // Copy to clipboard functionality would go here
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Pautan disalin!'),
                            backgroundColor: AppTheme.primaryColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCopy01,
                          color: AppTheme.primaryColor,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Tutup',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 120),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor.withValues(alpha: 0.12),
                                AppTheme.primaryColor.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.2,
                              ),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: PhosphorIcon(
                            PhosphorIcons.chalkboardTeacher(),
                            size: 80,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Column(
                            children: [
                              Text(
                                'Tiada Kitab Video Ditemui',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: AppTheme.textPrimaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Text(
                                  'Cuba ubah penapis kategori atau kata kunci pencarian untuk melihat kitab video yang tersedia',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                        height: 1.5,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _selectedCategoryId = null;
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        PhosphorIcon(
                                          PhosphorIcons.arrowClockwise(),
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Reset Penapis',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 120),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.errorColor.withValues(alpha: 0.12),
                                AppTheme.errorColor.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppTheme.errorColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.errorColor.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: PhosphorIcon(
                            PhosphorIcons.warning(),
                            size: 72,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Column(
                            children: [
                              Text(
                                'Ralat Memuat Data',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: AppTheme.textPrimaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Text(
                                  errorMessage,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                        height: 1.5,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    context.read<KitabProvider>().refresh();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        PhosphorIcon(
                                          PhosphorIcons.arrowClockwise(),
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Cuba Lagi',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
