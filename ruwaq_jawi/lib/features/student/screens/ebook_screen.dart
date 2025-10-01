import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/student_bottom_nav.dart';
import 'ebook_screen/managers/ebook_filter_manager.dart';
import 'ebook_screen/widgets/ebook_app_bar_widget.dart';
import 'ebook_screen/widgets/ebook_search_bar_widget.dart';
import 'ebook_screen/widgets/ebook_category_chips_widget.dart';
import 'ebook_screen/widgets/ebook_list_widget.dart';
import 'ebook_screen/widgets/ebook_empty_state_widget.dart';
import 'ebook_screen/widgets/ebook_loading_state_widget.dart';

class EbookScreen extends StatefulWidget {
  const EbookScreen({super.key});

  @override
  State<EbookScreen> createState() => _EbookScreenState();
}

class _EbookScreenState extends State<EbookScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late EbookFilterManager _filterManager;
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _searchAnimationController;

  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();

    // Initialize filter manager
    _filterManager = EbookFilterManager(onStateChanged: () => setState(() {}));

    // Initialize animation controllers
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Load ebooks after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kitabProvider = context.read<KitabProvider>();
      if (kitabProvider.ebookList.isEmpty) {
        kitabProvider.initialize().then((_) {
          if (mounted) {
            _fadeAnimationController.forward();
            _slideAnimationController.forward();
          }
        });
      } else {
        _fadeAnimationController.forward();
        _slideAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: const EbookAppBarWidget(),
          body: kitabProvider.isLoading
              ? const EbookLoadingStateWidget()
              : kitabProvider.errorMessage != null
              ? _buildErrorState(kitabProvider.errorMessage!)
              : _buildContent(kitabProvider),
          bottomNavigationBar: const StudentBottomNav(currentIndex: 2),
        );
      },
    );
  }

  Widget _buildContent(KitabProvider kitabProvider) {
    // Filter and sort ebooks
    final filteredEbooks = _filterManager.sortByNewest(
      _filterManager.filterEbooks(kitabProvider.activeEbooks),
    );

    if (filteredEbooks.isEmpty) {
      return _buildEmptyContent(kitabProvider);
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
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
            // Header with spacing
            SliverToBoxAdapter(
              child: Container(
                color: AppTheme.backgroundColor,
                padding: const EdgeInsets.only(top: 20),
              ),
            ),

            // Search and filters
            SliverToBoxAdapter(
              child: Container(
                color: AppTheme.backgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    EbookSearchBarWidget(
                      controller: _searchController,
                      searchQuery: _filterManager.searchQuery,
                      isSearchFocused: _isSearchFocused,
                      animationController: _searchAnimationController,
                      onFocusChanged: (focused) {
                        setState(() => _isSearchFocused = focused);
                      },
                      onChanged: (value) {
                        _filterManager.updateSearch(value);
                      },
                      onClear: () {
                        _searchController.clear();
                        _filterManager.clearSearch();
                      },
                    ),
                    EbookCategoryChipsWidget(
                      categories: kitabProvider.categories,
                      selectedCategoryId: _filterManager.selectedCategoryId,
                      onCategorySelected: (categoryId) {
                        _filterManager.updateCategory(categoryId);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // List
            EbookListWidget(
              ebooks: filteredEbooks,
              fadeController: _fadeAnimationController,
              slideController: _slideAnimationController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyContent(KitabProvider kitabProvider) {
    return FadeTransition(
      opacity: _fadeAnimationController,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header with spacing
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundColor,
              padding: const EdgeInsets.only(top: 20),
            ),
          ),

          // Search and filters
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  EbookSearchBarWidget(
                    controller: _searchController,
                    searchQuery: _filterManager.searchQuery,
                    isSearchFocused: _isSearchFocused,
                    animationController: _searchAnimationController,
                    onFocusChanged: (focused) {
                      setState(() => _isSearchFocused = focused);
                    },
                    onChanged: (value) {
                      _filterManager.updateSearch(value);
                    },
                    onClear: () {
                      _searchController.clear();
                      _filterManager.clearSearch();
                    },
                  ),
                  EbookCategoryChipsWidget(
                    categories: kitabProvider.categories,
                    selectedCategoryId: _filterManager.selectedCategoryId,
                    onCategorySelected: (categoryId) {
                      _filterManager.updateCategory(categoryId);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Empty state
          SliverFillRemaining(
            child: EbookEmptyStateWidget(
              searchQuery: _filterManager.searchQuery,
              hasCategory: _filterManager.selectedCategoryId != null,
              onClearSearch: () {
                _searchController.clear();
                _filterManager.clearSearch();
              },
              onResetCategory: () {
                _filterManager.updateCategory(null);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Ralat',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
