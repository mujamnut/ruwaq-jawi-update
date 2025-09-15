import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/video_kitab_service.dart';
import '../../../core/models/video_kitab.dart';
import '../../../core/models/category.dart';
import '../widgets/admin_bottom_nav.dart';
import 'admin_video_kitab_form_screen.dart';

class AdminContentEnhanced extends StatefulWidget {
  const AdminContentEnhanced({Key? key}) : super(key: key);

  @override
  _AdminContentEnhancedState createState() => _AdminContentEnhancedState();
}

class _AdminContentEnhancedState extends State<AdminContentEnhanced>
    with TickerProviderStateMixin {
  List<VideoKitab> _kitabList = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  
  final _searchController = TextEditingController();
  late AnimationController _fabAnimationController;
  late AnimationController _listAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _fabRotationAnimation;
  ScrollController _scrollController = ScrollController();
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
    _fabScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _fabRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));
    
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
      if (shouldShowAppBar != _isAppBarVisible) {
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
        final List<dynamic> categoriesJsonList = jsonDecode(cachedCategoriesJson);
        
        final List<VideoKitab> cachedKitabList = kitabJsonList
            .map((json) => VideoKitab.fromJson(json))
            .toList();
        final List<Category> cachedCategories = categoriesJsonList
            .map((json) => Category.fromJson(json))
            .toList();

        
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

      setState(() {
        _kitabList = kitabList;
        _categories = categories;
        _isLoading = false;
        _error = null;
      });
      
      // Start list animation after data loads
      _listAnimationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cacheData(List<VideoKitab> kitabList, List<Category> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert to JSON and cache
      final kitabJsonList = kitabList.map((kitab) => kitab.toJson()).toList();
      final categoriesJsonList = categories.map((category) => category.toJson()).toList();
      
      await prefs.setString('cached_kitab_list', jsonEncode(kitabJsonList));
      await prefs.setString('cached_categories', jsonEncode(categoriesJsonList));
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  List<VideoKitab> get _filteredKitab {
    List<VideoKitab> filtered = _kitabList.where((kitab) {
      final query = _searchQuery.toLowerCase();
      final titleMatch = kitab.title.toLowerCase().contains(query);
      final authorMatch = kitab.author?.toLowerCase().contains(query) ?? false;
      final descriptionMatch = kitab.description?.toLowerCase().contains(query) ?? false;
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
      appBar: _buildModernAppBar(),
      extendBodyBehindAppBar: false,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryColor,
        backgroundColor: Colors.white,
        strokeWidth: 3.0,
        child: Column(
          children: [
            // Modern Search and Filter Section
            _buildSearchAndFilterSection(),

            // Enhanced Content List
            Expanded(
              child: _isLoading
                  ? _buildModernLoadingState()
                  : _error != null
                      ? _buildModernErrorState()
                      : _filteredKitab.isEmpty
                          ? _buildModernEmptyState()
                          : _buildModernContentList(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildModernFAB(),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
    );
  }


  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      title: const Text(
        'Kandungan',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 24,
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryLightColor,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      actions: const [],
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Search Bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppTheme.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Cari kitab, pengarang, atau kategori...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondaryColor.withOpacity(0.6),
                  fontSize: 16,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    color: AppTheme.textSecondaryColor.withOpacity(0.7),
                    size: 20,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Filter Label
          Text(
            'Filter Kandungan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Modern Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildModernFilterChip('all', 'Semua', HugeIcons.strokeRoundedGridView),
                _buildModernFilterChip('active', 'Aktif', HugeIcons.strokeRoundedCheckmarkCircle02),
                _buildModernFilterChip('inactive', 'Tidak Aktif', HugeIcons.strokeRoundedCancel01),
                _buildModernFilterChip('premium', 'Premium', HugeIcons.strokeRoundedStar),
                _buildModernFilterChip('free', 'Percuma', HugeIcons.strokeRoundedGift),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilterChip(String value, String label, IconData icon) {
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
          },
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppTheme.primaryColor 
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected 
                    ? AppTheme.primaryColor 
                    : AppTheme.borderColor,
                width: isSelected ? 0 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: icon,
                  size: 16,
                  color: isSelected 
                      ? Colors.white 
                      : AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected 
                        ? Colors.white 
                        : AppTheme.textSecondaryColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Memuat kandungan...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
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
              color: Colors.black.withOpacity(0.08),
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
                color: AppTheme.errorColor.withOpacity(0.1),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
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
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedInbox,
                  size: 60,
                  color: AppTheme.textSecondaryColor.withOpacity(0.6),
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
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
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
          controller: _scrollController,
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
      orElse: () => Category(
        id: '',
        name: 'Tiada Kategori',
        sortOrder: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _editKitab(kitab);
          },
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Thumbnail Header
              Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.primaryLightColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Stack(
                  children: [
                    if (kitab.thumbnailUrl != null)
                      Hero(
                        tag: 'kitab_${kitab.id}',
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          child: Image.network(
                            kitab.thumbnailUrl!,
                            width: double.infinity,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildEnhancedPlaceholder();
                            },
                          ),
                        ),
                      )
                    else
                      _buildEnhancedPlaceholder(),
                    
                    // Status Badges with Better Styling
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!kitab.isActive)
                            _buildStatusBadge(
                              'Tidak Aktif',
                              AppTheme.errorColor,
                              HugeIcons.strokeRoundedCancel01,
                            ),
                        ],
                      ),
                    ),
                    
                    // Gradient Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Enhanced Content Info
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
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
                    
                    // Author
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedUser,
                          size: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            kitab.author ?? 'Tiada Pengarang',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
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
                    const SizedBox(height: 16),
                    
                    // Status Row
                    Row(
                      children: [
                        // Active Status
                        _buildInfoChip(
                          icon: kitab.isActive 
                              ? HugeIcons.strokeRoundedCheckmarkCircle02 
                              : HugeIcons.strokeRoundedCancel01,
                          label: kitab.isActive ? 'Aktif' : 'Tidak Aktif',
                          color: kitab.isActive 
                              ? AppTheme.successColor 
                              : AppTheme.errorColor,
                        ),
                        const Spacer(),
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
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: 12,
            color: Colors.white,
          ),
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: icon,
          size: 16,
          color: color,
        ),
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
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryLightColor.withOpacity(0.05),
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
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedVideo01,
              size: 40,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Video Kitab',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primaryColor.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFAB() {
    return FloatingActionButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        _createNewKitab();
      },
      backgroundColor: const Color(0xFF00BF6D),
      foregroundColor: Colors.white,
      child: const HugeIcon(
        icon: HugeIcons.strokeRoundedPlusSign,
        color: Colors.white,
        size: 24.0,
      ),
    );
  }

  void _createNewKitab() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminVideoKitabFormScreen(),
      ),
    ).then((result) {
      if (result != null) {
        _refreshData();
      }
    });
  }

  void _editKitab(VideoKitab kitab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminVideoKitabFormScreen(
          videoKitabId: kitab.id,
          videoKitab: kitab,
        ),
      ),
    ).then((result) {
      if (result != null) {
        _refreshData();
      }
    });
  }
}
