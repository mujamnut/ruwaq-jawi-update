import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/models/category.dart';
import 'student_home_screen/widgets/category_icon_card_widget.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  _CategoryFilter _filter = _CategoryFilter.all;

  // (Removed filter state after reverting to simple layout)

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _scrollController.addListener(() {
      bool scrolled = _scrollController.offset > 10;
      if (scrolled != _isScrolled) {
        setState(() => _isScrolled = scrolled);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Get category image path (PNG with transparent background)
  String? _getCategoryImagePath(String categoryName) {
    final category = categoryName.toLowerCase().trim();

    if (category.contains('fiqh')) {
      return 'assets/images/categories/fiqh.png';
    } else if (category.contains('akidah')) {
      return 'assets/images/categories/akidah.png';
    } else if (category.contains('quran & tafsir')) {
      return 'assets/images/categories/quran.png';
    } else if (category.contains('hadith')) {
      return 'assets/images/categories/hadith.png';
    } else if (category.contains('sirah')) {
      return 'assets/images/categories/sirah.png';
    } else if (category.contains('akhlak & tasawuf')) {
      return 'assets/images/categories/akhlak.png';
    } else if (category.contains('usul fiqh')) {
      return 'assets/images/categories/usul_fiqh.png';
    } else if (category.contains('bahasa arab')) {
      return 'assets/images/categories/bahasa_arab.png';
    }
    return null;
  }

  /// Get Arabic text for category (fallback)
  String _getArabicTextForCategory(String categoryName) {
    final category = categoryName.toLowerCase().trim();

    if (category.contains('fiqh')) {
      return 'الفقه';
    } else if (category.contains('akidah')) {
      return 'العقيدة';
    } else if (category.contains('quran & tafsir')) {
      return 'القران و التفسير';
    } else if (category.contains('hadith')) {
      return 'الحديث';
    } else if (category.contains('sirah')) {
      return 'السيرة';
    } else if (category.contains('akhlak & tasawuf')) {
      return 'التصوف';
    } else if (category.contains('usul fiqh')) {
      return 'أصول الفقه';
    } else if (category.contains('bahasa arab')) {
      return 'لغة العربية';
    } else {
      return 'كتاب';
    }
  }

  /// Build category Arabic display (image with color tint or fallback to text)
  Widget _buildCategoryArabicDisplay(String categoryName) {
    final imagePath = _getCategoryImagePath(categoryName);

    if (imagePath != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 20.0),
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            AppTheme.primaryColor,
            BlendMode.srcIn,
          ),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Text(
                _getArabicTextForCategory(categoryName),
                style: const TextStyle(
                  fontFamily: 'ArefRuqaa',
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      );
    } else {
      return Text(
        _getArabicTextForCategory(categoryName),
        style: const TextStyle(
          fontFamily: 'ArefRuqaa',
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
        textAlign: TextAlign.center,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: Consumer<KitabProvider>(
        builder: (context, kitabProvider, child) {
          if (kitabProvider.isLoading) {
            return _buildLoadingState();
          }

          final categories = kitabProvider.categories;

          return RefreshIndicator(
            onRefresh: () async {
              await kitabProvider.refresh();
              if (mounted) {
                _animationController.reset();
                _animationController.forward();
              }
            },
            color: AppTheme.primaryColor,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.86,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];

                    // Count total items (video kitab + ebooks)
                    final videoKitabCount = kitabProvider.activeVideoKitab
                        .where((k) => k.categoryId == category.id)
                        .length;
                    final ebookCount = kitabProvider.activeEbooks
                        .where((e) => e.categoryId == category.id)
                        .length;
                    final totalCount = videoKitabCount + ebookCount;

                    return CategoryIconCardWidget(
                      category: category,
                      totalCount: totalCount,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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
      leading: IconButton(
        icon: PhosphorIcon(
          PhosphorIcons.arrowLeft(),
          color: AppTheme.textPrimaryColor,
          size: 24,
        ),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'Semua Kategori',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimaryColor,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildCategoryCard(Category category, int totalCount, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: RepaintBoundary(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/category/${category.id}');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Top section with Arabic image/text and accent bar
                        Expanded(
                          flex: 3,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.14),
                                  AppTheme.primaryColor.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: _buildCategoryArabicDisplay(category.name),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Bottom section with category name and count
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 10.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    category.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimaryColor,
                                          fontSize: 14,
                                          height: 1.2,
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.borderColor,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PhosphorIcon(
                                        PhosphorIcons.books(),
                                        color: AppTheme.primaryColor,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$totalCount item${totalCount != 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.86,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // circular icon skeleton
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.borderColor.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 60,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Sticky filter/search header content
  Widget _buildFilterHeader(BuildContext context) {
    return const SizedBox.shrink();
    return Material(
      color: AppTheme.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar to global search for now
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                splashColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                highlightColor: AppTheme.primaryColor.withValues(alpha: 0.04),
                onTap: () => context.push('/search'),
                child: Ink(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.magnifyingGlass(),
                          color: AppTheme.textSecondaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cari kategori…',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Text(
                            'Cari',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip('Semua', _CategoryFilter.all),
                _buildChoiceChip('Video', _CategoryFilter.video),
                _buildChoiceChip('E-book', _CategoryFilter.ebook),
                _buildChoiceChip('Popular', _CategoryFilter.popular),
                _buildChoiceChip('A–Z', _CategoryFilter.az),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, _CategoryFilter value) {
    return const SizedBox.shrink();
    final bool selected = _filter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppTheme.textSecondaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.backgroundColor,
      shape: StadiumBorder(side: BorderSide(color: AppTheme.borderColor)),
      onSelected: (_) {
        setState(() {
          _filter = value;
          _animationController.reset();
          _animationController.forward();
        });
      },
    );
  }

  int _countItemsForCategory(KitabProvider provider, String categoryId) {
    return _countVideoForCategory(provider, categoryId) +
        _countEbookForCategory(provider, categoryId);
  }

  int _countVideoForCategory(KitabProvider provider, String categoryId) {
    return provider.activeVideoKitab.where((k) => k.categoryId == categoryId).length;
  }

  int _countEbookForCategory(KitabProvider provider, String categoryId) {
    return provider.activeEbooks.where((e) => e.categoryId == categoryId).length;
  }

  // Loading state with slivers for visual consistency
  Widget _buildSliverLoadingState() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          backgroundColor: AppTheme.surfaceColor.withValues(alpha: 0.96),
          elevation: _isScrolled ? 1 : 0,
          pinned: true,
          floating: true,
          snap: true,
          expandedHeight: 120,
          leading: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.arrowLeft(),
              color: AppTheme.textPrimaryColor,
              size: 24,
            ),
            onPressed: () => context.pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
            title: Text(
              'Semua Kategori',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                  ),
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyFilterHeader(
            child: _buildFilterHeader(context),
            height: 88,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                );
              },
              childCount: 8,
            ),
          ),
        ),
      ],
    );
  }
}

// Filter options
enum _CategoryFilter { all, video, ebook, popular, az }

// Simple sticky header for search + chips
class _StickyFilterHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyFilterHeader({required this.child, this.height = 88});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        boxShadow: [
          if (overlapsContent || shrinkOffset > 0)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFilterHeader oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
