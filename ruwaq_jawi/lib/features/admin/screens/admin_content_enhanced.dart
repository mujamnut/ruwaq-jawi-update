import 'package:flutter/material.dart';
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

class _AdminContentEnhancedState extends State<AdminContentEnhanced> {
  List<VideoKitab> _kitabList = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  
  final _searchController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _searchController.text = _searchQuery;
    _refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      appBar: AppBar(
        title: const Text('Kandungan'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [

            // Search and Filter
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari kitab...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Filter Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'Semua'),
                        _buildFilterChip('active', 'Aktif'),
                        _buildFilterChip('inactive', 'Tidak Aktif'),
                        _buildFilterChip('premium', 'Premium'),
                        _buildFilterChip('free', 'Percuma'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Ralat: $_error'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _refreshData,
                                child: const Text('Cuba Lagi'),
                              ),
                            ],
                          ),
                        )
                      : _filteredKitab.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('Tiada kitab dijumpai'),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredKitab.length,
                              itemBuilder: (context, index) {
                                final kitab = _filteredKitab[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildKitabCard(kitab),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewKitab,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
    );
  }


  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? value : 'all';
          });
        },
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        backgroundColor: Colors.grey[100],
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildKitabCard(VideoKitab kitab) {
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editKitab(kitab),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail header
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    if (kitab.thumbnailUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: Image.network(
                          kitab.thumbnailUrl!,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildModernPlaceholder();
                          },
                        ),
                      )
                    else
                      _buildModernPlaceholder(),
                    
                    // Status badges
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!kitab.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Tidak Aktif',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (kitab.isPremium)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kitab.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Oleh: ${kitab.author ?? 'Tiada Pengarang'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          kitab.isActive ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: kitab.isActive ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          kitab.isActive ? 'Aktif' : 'Tidak Aktif',
                          style: TextStyle(
                            fontSize: 12,
                            color: kitab.isActive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          kitab.isPremium ? Icons.star : Icons.lock_open,
                          size: 16,
                          color: kitab.isPremium ? Colors.amber : Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          kitab.isPremium ? 'Premium' : 'Percuma',
                          style: TextStyle(
                            fontSize: 12,
                            color: kitab.isPremium ? Colors.amber : Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
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

  Widget _buildModernPlaceholder() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library,
            size: 32,
            color: AppTheme.primaryColor.withOpacity(0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'Video Kitab',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
