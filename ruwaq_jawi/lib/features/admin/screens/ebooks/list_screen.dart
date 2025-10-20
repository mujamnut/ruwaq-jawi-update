import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/shimmer_loading.dart';
import 'form_screen.dart';
import 'detail_screen.dart';

class AdminEbookListScreen extends StatefulWidget {
  const AdminEbookListScreen({super.key});

  @override
  State<AdminEbookListScreen> createState() => _AdminEbookListScreenState();
}

class _AdminEbookListScreenState extends State<AdminEbookListScreen> {
  List<Map<String, dynamic>> _ebooks = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategoryFilter;
  bool? _premiumFilter;
  bool? _activeFilter;
  final _searchController = TextEditingController();

  // Local storage keys
  static const String _ebooksKey = 'cached_ebooks';
  static const String _categoriesKey = 'cached_categories';
  static const String _lastUpdateKey = 'last_update_timestamp';

  @override
  void initState() {
    super.initState();
    _searchController.text = _searchQuery;
    _loadCachedData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached data first for instant display
      final cachedEbooks = prefs.getString(_ebooksKey);
      final cachedCategories = prefs.getString(_categoriesKey);
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;

      if (cachedEbooks != null && cachedCategories != null) {
        if (!mounted) return;
        setState(() {
          _ebooks = List<Map<String, dynamic>>.from(json.decode(cachedEbooks));
          _categories = List<Map<String, dynamic>>.from(
            json.decode(cachedCategories),
          );
          _isLoading = false;
        });
      }

      // Check if data is older than 5 minutes, then refresh
      final now = DateTime.now().millisecondsSinceEpoch;
      final fiveMinutes = 5 * 60 * 1000;

      if (now - lastUpdate > fiveMinutes || cachedEbooks == null) {
        await _refreshData();
      }
    } catch (e) {
      print('Error loading cached data: $e');
      await _refreshData();
    }
  }

  Future<void> _loadCategories() async {
    try {
      // Fetch real categories from database
      final response = await SupabaseService.from(
        'categories',
      ).select('*').order('name');

      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
      });

      // Cache categories
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_categoriesKey, json.encode(_categories));
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch fresh data from database
      await Future.wait([_loadEbooksFromDB(), _loadCategories()]);

      // Update last refresh timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ralat memuatkan e-book: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEbooksFromDB() async {
    try {
      // Fetch real data from ebooks table
      var query = SupabaseService.from(
        'ebooks',
      ).select('*, categories(id, name)').order('created_at', ascending: false);

      final response = await query;
      final allEbooks = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;
      setState(() {
        _ebooks = allEbooks;
        _isLoading = false;
      });

      // Cache the raw data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ebooksKey, json.encode(allEbooks));
    } catch (e) {
      throw Exception('Error loading ebooks: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredEbooks {
    List<Map<String, dynamic>> ebooks = List.from(_ebooks);

    // Apply category filter
    if (_selectedCategoryFilter != null) {
      ebooks = ebooks
          .where((ebook) => ebook['category_id'] == _selectedCategoryFilter)
          .toList();
    }

    // Apply premium filter
    if (_premiumFilter != null) {
      ebooks = ebooks
          .where((ebook) => ebook['is_premium'] == _premiumFilter)
          .toList();
    }

    // Apply active status filter
    if (_activeFilter != null) {
      ebooks = ebooks
          .where((ebook) => (ebook['is_active'] ?? false) == _activeFilter)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      ebooks = ebooks.where((ebook) {
        final title = (ebook['title'] ?? '').toString().toLowerCase();
        final author = (ebook['author'] ?? '').toString().toLowerCase();
        final searchLower = _searchQuery.toLowerCase();
        return title.contains(searchLower) || author.contains(searchLower);
      }).toList();
    }

    return ebooks;
  }

  Future<void> _deleteEbook(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengesahan Padam'),
        content: Text(
          'Adakah anda pasti mahu memadam e-book "$title"?\n\nTindakan ini tidak boleh dibuat asal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.from('ebooks').delete().eq('id', id);
        _showSnackBar('E-book "$title" berjaya dipadam', isSuccess: true);
        _refreshData();
      } catch (e) {
        _showSnackBar(
          'Ralat memadam e-book: ${e.toString()}',
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _toggleEbookStatus(String id, bool currentStatus) async {
    try {
      await SupabaseService.from(
        'ebooks',
      ).update({'is_active': !currentStatus}).eq('id', id);
      _showSnackBar(
        'Status e-book berjaya ${!currentStatus ? 'diaktifkan' : 'dinyahaktifkan'}',
        isSuccess: true,
      );
      _refreshData();
    } catch (e) {
      _showSnackBar('Ralat mengubah status: ${e.toString()}', isSuccess: false);
    }
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  void _showFilterDialog() {
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
                        'Tapis E-book',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedCategoryFilter != null ||
                          _premiumFilter != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategoryFilter = null;
                              _premiumFilter = null;
                            });
                            setModalState(() {});
                          },
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'Semua',
                          icon: HugeIcons.strokeRoundedGridView,
                          isSelected: _selectedCategoryFilter == null,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedCategoryFilter = null);
                            setModalState(() {});
                          },
                        ),
                        ..._categories.map((cat) {
                          final String id = cat['id'];
                          final String name = cat['name'] ?? 'Kategori';
                          final bool selected = _selectedCategoryFilter == id;
                          return _buildFilterChip(
                            label: name,
                            icon: HugeIcons.strokeRoundedTag01,
                            isSelected: selected,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(
                                () => _selectedCategoryFilter = selected
                                    ? null
                                    : id,
                              );
                              setModalState(() {});
                            },
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Premium chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'Semua Jenis',
                          icon: HugeIcons.strokeRoundedGridView,
                          isSelected: _premiumFilter == null,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _premiumFilter = null);
                            setModalState(() {});
                          },
                        ),
                        _buildFilterChip(
                          label: 'Premium',
                          icon: HugeIcons.strokeRoundedStar,
                          isSelected: _premiumFilter == true,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _premiumFilter = true);
                            setModalState(() {});
                          },
                        ),
                        _buildFilterChip(
                          label: 'Percuma',
                          icon: HugeIcons.strokeRoundedGift,
                          isSelected: _premiumFilter == false,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _premiumFilter = false);
                            setModalState(() {});
                          },
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

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimaryColor,
        centerTitle: false,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Text(
            'Pengurusan E-book',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.2,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedFilterMailCircle,
              color: AppTheme.textSecondaryColor,
            ),
            onPressed: _showFilterDialog,
            tooltip: 'Penapis',
          ),
          const SizedBox(width: 8),
        ],
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari e-book mengikut tajuk atau pengarang...',
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
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            _buildCompactStatsChips(),
            Expanded(child: _buildEbookList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminEbookFormScreen(),
            ),
          ).then((_) => _refreshData()); // Reload after adding
        },
        backgroundColor: const Color(0xFF00BF6D),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const HugeIcon(
          icon: HugeIcons.strokeRoundedPlusSign,
          color: Colors.white,
          size: 24.0,
        ),
      ),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 2),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Cari e-book mengikut tajuk atau pengarang...',
          prefixIcon: const HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: Colors.grey,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildStatsCard() {
    final filteredEbooks = _filteredEbooks;
    final totalEbooks = filteredEbooks.length;
    final activeEbooks = filteredEbooks
        .where((e) => e['is_active'] == true)
        .length;
    final premiumEbooks = filteredEbooks
        .where((e) => e['is_premium'] == true)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatPill(
              label: 'Jumlah',
              value: totalEbooks.toString(),
              icon: HugeIcons.strokeRoundedBook02,
              selected:
                  _selectedCategoryFilter == null &&
                  _premiumFilter == null &&
                  _activeFilter == null,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedCategoryFilter = null;
                  _premiumFilter = null;
                  _activeFilter = null;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatPill(
              label: 'Aktif',
              value: activeEbooks.toString(),
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              selected: _activeFilter == true,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _activeFilter = _activeFilter == true ? null : true;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatPill(
              label: 'Premium',
              value: premiumEbooks.toString(),
              icon: HugeIcons.strokeRoundedStar,
              selected: _premiumFilter == true,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _premiumFilter = _premiumFilter == true ? null : true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // Compact chips below search: Jumlah, Aktif, Premium
  Widget _buildCompactStatsChips() {
    final filteredEbooks = _filteredEbooks;
    final totalEbooks = filteredEbooks.length;
    final activeEbooks = filteredEbooks
        .where((e) => e['is_active'] == true)
        .length;
    final premiumEbooks = filteredEbooks
        .where((e) => e['is_premium'] == true)
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'Jumlah $totalEbooks',
              icon: HugeIcons.strokeRoundedBook02,
              isSelected:
                  _selectedCategoryFilter == null &&
                  _premiumFilter == null &&
                  _activeFilter == null,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedCategoryFilter = null;
                  _premiumFilter = null;
                  _activeFilter = null;
                });
              },
            ),
            _buildFilterChip(
              label: 'Aktif $activeEbooks',
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              isSelected: _activeFilter == true,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _activeFilter = _activeFilter == true ? null : true;
                });
              },
            ),
            _buildFilterChip(
              label: 'Premium $premiumEbooks',
              icon: HugeIcons.strokeRoundedStar,
              isSelected: _premiumFilter == true,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _premiumFilter = _premiumFilter == true ? null : true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                color: selected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEbookList() {
    if (_isLoading) {
      return ShimmerList(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        shimmerItem: const EbookShimmerCard(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 64.0,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Ralat Memuat Data',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      );
    }

    final filteredEbooks = _filteredEbooks;

    if (filteredEbooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedBook02,
              size: 64.0,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Tiada E-book Dijumpai',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tiada e-book sepadan dengan carian anda'
                  : 'Belum ada e-book yang ditambah',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminEbookFormScreen(),
                  ),
                ).then((_) => _refreshData());
              },
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedPlusSign,
                color: Colors.white,
              ),
              label: const Text('Tambah E-book Pertama'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredEbooks.length,
      itemBuilder: (context, index) {
        final ebook = filteredEbooks[index];
        return _buildEbookCard(ebook);
      },
    );
  }

  Widget _buildEbookCard(Map<String, dynamic> ebook) {
    final isActive = ebook['is_active'] ?? true;
    final isPremium = ebook['is_premium'] ?? false;
    final category = ebook['categories'];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AdminEbookDetailScreen(ebookId: ebook['id']),
            ),
          ).then((_) => _refreshData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? Colors.grey.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Container(
                  width: 80,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                  child: ebook['thumbnail_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            ebook['thumbnail_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return HugeIcon(
                                icon: HugeIcons.strokeRoundedBook02,
                                size: 40.0,
                                color: Colors.grey.shade400,
                              );
                            },
                          ),
                        )
                      : HugeIcon(
                          icon: HugeIcons.strokeRoundedBook02,
                          size: 40.0,
                          color: Colors.grey.shade400,
                        ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ebook['title'] ?? 'Tanpa Tajuk',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? Colors.black
                                        : Colors.grey[600],
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      if (ebook['author'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Oleh: ${ebook['author']}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],

                      if (category != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Kategori: ${category['name']}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],

                      if (ebook['total_pages'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${ebook['total_pages']} muka surat',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],

                      // Views and Downloads
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedView,
                            size: 14.0,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${ebook['views_count'] ?? 0}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 16),
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedDownload01,
                            size: 14.0,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${ebook['downloads_count'] ?? 0}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'Aktif' : 'Tidak Aktif',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(ebook['created_at']),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions (3-dots opens bottom sheet)
                IconButton(
                  onPressed: () => _showEbookActionsBottomSheet(ebook),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreVertical,
                    size: 20.0,
                    color: Colors.grey,
                  ),
                  tooltip: 'Tindakan',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEbookActionsBottomSheet(Map<String, dynamic> ebook) {
    final bool isActive = ebook['is_active'] ?? true;
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
                // Handle
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
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminEbookFormScreen(
                          ebookId: ebook['id'],
                          ebookData: ebook,
                        ),
                      ),
                    );
                    if (mounted) _refreshData();
                  },
                ),
                ListTile(
                  leading: HugeIcon(
                    icon: isActive
                        ? HugeIcons.strokeRoundedViewOff
                        : HugeIcons.strokeRoundedView,
                    size: 20,
                    color: Colors.blue,
                  ),
                  title: Text(isActive ? 'Nyahaktif' : 'Aktifkan'),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    await _toggleEbookStatus(ebook['id'], isActive);
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
                    await _deleteEbook(
                      ebook['id'],
                      ebook['title'] ?? 'Tanpa Tajuk',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '-';
    }
  }
}
