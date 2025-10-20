import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/video_kitab_service.dart';
import '../../../../core/models/video_kitab.dart';
import '../../../../core/models/category.dart' as CategoryModel;
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/shimmer_loading.dart';
import 'kitab_manual_form_screen.dart';
import 'kitab_auto_form_screen.dart';
import 'kitab_detail_screen.dart';

class AdminVideoListScreen extends StatefulWidget {
  const AdminVideoListScreen({super.key});

  @override
  _AdminVideoListScreenState createState() => _AdminVideoListScreenState();
}

class _AdminVideoListScreenState extends State<AdminVideoListScreen>
    with TickerProviderStateMixin {
  List<VideoKitab> _kitabList = [];
  List<CategoryModel.Category> _categories = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';
  String _searchQuery = '';

  final _searchController = TextEditingController();
  late AnimationController _fabAnimationController;
  late AnimationController _listAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _fabRotationAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isAppBarVisible = true;

  @override
  void initState() {
    super.initState();
    _searchController.text = _searchQuery;

    // Initialize animation controllers
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Setup FAB animations
    _fabScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _fabRotationAnimation =
        Tween<double>(
          begin: 0.0,
          end: 0.125, // 45 degrees
        ).animate(
          CurvedAnimation(
            parent: _fabAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    // Setup scroll listener for app bar visibility
    _scrollController.addListener(_onScroll);

    _refreshData();
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    _listAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final bool shouldShowAppBar = _scrollController.offset <= 50;
      if (shouldShowAppBar != _isAppBarVisible && mounted) {
        setState(() {
          _isAppBarVisible = shouldShowAppBar;
        });
      }
    }
  }

  // Load data with caching
  Future<void> _refreshData() async {
    // Load from cache first for instant display
    await _loadFromCache();

    // Then load fresh data from database
    await _loadDataFromDB();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached kitab list
      final cachedKitabJson = prefs.getString('cached_kitab_list');
      final cachedCategoriesJson = prefs.getString('cached_categories');

      if (cachedKitabJson != null && cachedCategoriesJson != null) {
        final List<dynamic> kitabJsonList = jsonDecode(cachedKitabJson);
        final List<dynamic> categoriesJsonList = jsonDecode(
          cachedCategoriesJson,
        );

        final List<VideoKitab> cachedKitabList = kitabJsonList
            .map((json) => VideoKitab.fromJson(json))
            .toList();
        final List<CategoryModel.Category> cachedCategories = categoriesJsonList
            .map((json) => CategoryModel.Category.fromJson(json))
            .toList();

        if (!mounted) return;
        setState(() {
          _kitabList = cachedKitabList;
          _categories = cachedCategories;
          _isLoading = false;
        });
      }
    } catch (e) {
      // If cache fails, continue to load from database
      debugPrint('Cache load error: $e');
    }
  }

  Future<void> _loadDataFromDB() async {
    try {
      // Load fresh data from database
      final categories = await SupabaseService.getActiveCategories();
      final kitabList = await VideoKitabService.getVideoKitabs();

      // Cache the fresh data
      await _cacheData(kitabList, categories);

      if (!mounted) return;
      setState(() {
        _kitabList = kitabList;
        _categories = categories;
        _isLoading = false;
        _error = null;
      });

      // Start list animation after data loads
      _listAnimationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cacheData(
    List<VideoKitab> kitabList,
    List<CategoryModel.Category> categories,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert to JSON and cache
      final kitabJsonList = kitabList.map((kitab) => kitab.toJson()).toList();
      final categoriesJsonList = categories
          .map((category) => category.toJson())
          .toList();

      await prefs.setString('cached_kitab_list', jsonEncode(kitabJsonList));
      await prefs.setString(
        'cached_categories',
        jsonEncode(categoriesJsonList),
      );
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  List<VideoKitab> get _filteredKitab {
    List<VideoKitab> filtered = _kitabList.where((kitab) {
      final query = _searchQuery.toLowerCase();
      final titleMatch = kitab.title.toLowerCase().contains(query);
      final authorMatch = kitab.author?.toLowerCase().contains(query) ?? false;
      final descriptionMatch =
          kitab.description?.toLowerCase().contains(query) ?? false;
      return titleMatch || authorMatch || descriptionMatch;
    }).toList();

    // Status filter
    switch (_selectedFilter) {
      case 'active':
        return filtered.where((k) => k.isActive).toList();
      case 'inactive':
        return filtered.where((k) => !k.isActive).toList();
      case 'premium':
        return filtered.where((k) => k.isPremium).toList();
      case 'free':
        return filtered.where((k) => !k.isPremium).toList();
      default:
        return filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildTitleSliverAppBar(innerBoxIsScrolled),
        ],
        body: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppTheme.primaryColor,
          backgroundColor: Colors.white,
          strokeWidth: 3.0,
          child: _isLoading
              ? _buildModernLoadingState()
              : _error != null
              ? _buildModernErrorState()
              : _filteredKitab.isEmpty
              ? _buildModernEmptyState()
              : _buildModernContentList(),
        ),
      ),
      floatingActionButton: _buildModernFAB(),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
    );
  }

  SliverAppBar _buildTitleSliverAppBar(bool innerBoxIsScrolled) {
    final bool filterActive = _selectedFilter != 'all';
    return SliverAppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.textPrimaryColor,
      elevation: 0,
      pinned: true,
      forceElevated: innerBoxIsScrolled,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 0,
      centerTitle: false,
      title: const Padding(
        padding: EdgeInsets.only(left: 16),
        child: Text(
          'Video Kitab',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.2,
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.transparent,
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Cari kitab, pengarang, atau kategori...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
                filled: true,
                fillColor: AppTheme.neutralGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Tapis',
          onPressed: _openFilterSheet,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSettings04,
                color: filterActive
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
                size: 22,
              ),
              if (filterActive)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // Nota: Bar carian kini diletakkan pada bahagian bawah SliverAppBar tajuk
  // supaya ia berada lebih rapat di bahagian atas dan kelihatan lebih kemas.

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Tapis Kandungan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (_selectedFilter != 'all')
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedFilter = 'all');
                            setModalState(() {});
                            Navigator.pop(context);
                          },
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildModernFilterChip(
                          'all',
                          'Semua',
                          HugeIcons.strokeRoundedGridView,
                          onChanged: () => setModalState(() {}),
                        ),
                        _buildModernFilterChip(
                          'active',
                          'Aktif',
                          HugeIcons.strokeRoundedCheckmarkCircle02,
                          onChanged: () => setModalState(() {}),
                        ),
                        _buildModernFilterChip(
                          'inactive',
                          'Tidak Aktif',
                          HugeIcons.strokeRoundedCancel01,
                          onChanged: () => setModalState(() {}),
                        ),
                        _buildModernFilterChip(
                          'premium',
                          'Premium',
                          HugeIcons.strokeRoundedStar,
                          onChanged: () => setModalState(() {}),
                        ),
                        _buildModernFilterChip(
                          'free',
                          'Percuma',
                          HugeIcons.strokeRoundedGift,
                          onChanged: () => setModalState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Search Bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.transparent,
              border: Border.all(color: AppTheme.borderColor, width: 1),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Cari kitab, pengarang, atau kategori...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
                filled: true,
                fillColor: AppTheme.neutralGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
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

          const SizedBox(height: 12),

          // Modern Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildModernFilterChip(
                  'all',
                  'Semua',
                  HugeIcons.strokeRoundedGridView,
                ),
                _buildModernFilterChip(
                  'active',
                  'Aktif',
                  HugeIcons.strokeRoundedCheckmarkCircle02,
                ),
                _buildModernFilterChip(
                  'inactive',
                  'Tidak Aktif',
                  HugeIcons.strokeRoundedCancel01,
                ),
                _buildModernFilterChip(
                  'premium',
                  'Premium',
                  HugeIcons.strokeRoundedStar,
                ),
                _buildModernFilterChip(
                  'free',
                  'Percuma',
                  HugeIcons.strokeRoundedGift,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilterChip(String value, String label, IconData icon, {VoidCallback? onChanged}) {
    final isSelected = _selectedFilter == value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedFilter = isSelected ? 'all' : value;
            });
            if (onChanged != null) onChanged();
          },
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor,
                width: 1,
              ),
              boxShadow: const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: icon,
                  size: 16,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernLoadingState() {
    return ShimmerList(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: 6,
      shimmerItem: const VideoKitabShimmerCard(),
    );
  }

  Widget _buildModernErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 40,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ops! Terdapat ralat',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    size: 18,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Cuba Lagi',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedInbox,
                  size: 60,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tiada kitab dijumpai',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuba ubah carian atau filter anda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedFilter = 'all';
                  _searchController.clear();
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Kosongkan Penapis',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernContentList() {
    return AnimatedBuilder(
      animation: _listAnimationController,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          itemCount: _filteredKitab.length,
          itemBuilder: (context, index) {
            final kitab = _filteredKitab[index];
            final animationDelay = index * 0.1;
            return TweenAnimationBuilder(
              duration: Duration(milliseconds: 600 + (index * 100)),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, double value, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - value) * 30),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildModernKitabCard(kitab),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildModernKitabCard(VideoKitab kitab) {
    final category = _categories.firstWhere(
      (c) => c.id == kitab.categoryId,
      orElse: () => CategoryModel.Category(
        id: '',
        name: 'Tiada Kategori',
        sortOrder: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return Container(
      // Remove card look (no color/shadow/border)
      decoration: const BoxDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _openKitabDetail(kitab.id);
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail at top (YouTube style)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: (kitab.thumbnailUrl != null && kitab.thumbnailUrl!.isNotEmpty)
                          ? Hero(
                              tag: 'kitab_${kitab.id}',
                              child: Image.network(
                                kitab.thumbnailUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildCardBackgroundPlaceholder();
                                },
                              ),
                            )
                          : _buildCardBackgroundPlaceholder(),
                    ),

                    // (Status icon moved next to author text below)

                    // Total videos (bottom-right)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _buildOverlayBadge('${kitab.totalVideos} video'),
                    ),
                  ],
                ),
              ),

              // Text below thumbnail
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kitab.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedUser,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  kitab.author ?? 'Tiada Pengarang',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              HugeIcon(
                                icon: kitab.isActive
                                    ? HugeIcons.strokeRoundedCheckmarkCircle02
                                    : HugeIcons.strokeRoundedCancel01,
                                size: 16,
                                color: kitab.isActive
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedTag01,
                                size: 12,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _showVideoActionsBottomSheet(kitab),
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedMoreVertical,
                            size: 20.0,
                            color: Colors.grey,
                          ),
                          tooltip: 'Tindakan',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    String label,
    Color color,
    IconData icon, {
    EdgeInsets? margin,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Small dark badge used over thumbnails (duration, count)
  Widget _buildOverlayBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedPlaceholder() {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.primaryLightColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedVideo01,
              size: 40,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Video Kitab',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primaryColor.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Full-card background placeholder (used when thumbnail missing or fails)
  Widget _buildCardBackgroundPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.10),
            AppTheme.primaryLightColor.withValues(alpha: 0.06),
          ],
        ),
      ),
    );
  }

  Widget _buildModernFAB() {
    return FloatingActionButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        _showAddOptionsDialog();
      },
      shape: const CircleBorder(),
      backgroundColor: const Color(0xFF00BF6D),
      foregroundColor: Colors.white,
      elevation: 6,
      child: const Icon(Icons.add, size: 24, color: Colors.white),
    );
  }

  void _showAddOptionsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: bottom + 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedPlusSign,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tambah Video Kitab',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        Text(
                          'Pilih kaedah untuk menambah kandungan',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Quick Setup Option
              _buildDialogOption(
                icon: PhosphorIcons.youtubeLogo(PhosphorIconsStyle.fill),
                title: 'Quick Setup',
                subtitle: 'Auto import dari YouTube playlist',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _navigateToQuickSetup();
                },
              ),

              const SizedBox(height: 16),

              // Manual Setup Option
              _buildDialogOption(
                icon: HugeIcons.strokeRoundedEdit01,
                title: 'Manual Setup',
                subtitle: 'Buat secara manual dengan form',
                color: AppTheme.primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  _navigateToManualSetup();
                },
              ),

              const SizedBox(height: 20),

              // Cancel Button
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openKitabDetail(String kitabId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminKitabDetailScreen(kitabId: kitabId),
      ),
    );
    if (mounted) {
      _refreshData(); // Refresh list when returning from detail
    }
  }

  Future<void> _toggleKitabStatus(String id, bool currentStatus) async {
    try {
      await VideoKitabService.toggleVideoKitabStatusAdmin(id, !currentStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!currentStatus ? 'Diaktifkan' : 'Dinonaktifkan'),
          backgroundColor: !currentStatus ? Colors.green : Colors.orange,
        ),
      );
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat mengubah status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteKitab(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengesahan Padam'),
        content: Text('Padam "$title"? Tindakan ini tidak boleh dibuat asal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await VideoKitabService.deleteVideoKitab(id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berjaya dipadam'), backgroundColor: Colors.green),
        );
        _refreshData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ralat memadam: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showVideoActionsBottomSheet(VideoKitab kitab) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedEdit01,
                    size: 20,
                    color: Colors.blue,
                  ),
                  title: const Text('Edit'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    _editKitab(kitab);
                  },
                ),
                ListTile(
                  leading: HugeIcon(
                    icon: kitab.isActive
                        ? HugeIcons.strokeRoundedViewOff
                        : HugeIcons.strokeRoundedView,
                    size: 20,
                    color: Colors.blue,
                  ),
                  title: Text(kitab.isActive ? 'Nyahaktif' : 'Aktifkan'),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    await _toggleKitabStatus(kitab.id, kitab.isActive);
                  },
                ),
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete01,
                    size: 20,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Padam',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    await _deleteKitab(kitab.id, kitab.title);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogOption({
    required dynamic icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTheme.borderColor.withValues(alpha: 0.5),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: icon is PhosphorIconData
                      ? PhosphorIcon(icon, color: color, size: 24)
                      : HugeIcon(icon: icon, color: color, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppTheme.textSecondaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToQuickSetup() async {
    // Navigate using GoRouter for consistency
    final result = await context.push('/admin/kitabs/add-auto');
    if (result != null) {
      _refreshData();
    }
  }

  void _navigateToManualSetup() async {
    // Navigate using GoRouter for consistency
    final result = await context.push('/admin/kitabs/add-manual');
    if (result != null) {
      _refreshData();
    }
  }

  void _editKitab(VideoKitab kitab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AdminKitabFormScreen(kitabId: kitab.id, kitabData: kitab.toJson()),
      ),
    ).then((result) {
      if (result != null) {
        _refreshData();
      }
    });
  }
}
