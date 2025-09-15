import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_bottom_nav.dart';
import 'admin_ebook_form_screen.dart';
import 'admin_ebook_detail_screen.dart';

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

  // Local storage keys
  static const String _ebooksKey = 'cached_ebooks';
  static const String _categoriesKey = 'cached_categories';
  static const String _lastUpdateKey = 'last_update_timestamp';

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached data first for instant display
      final cachedEbooks = prefs.getString(_ebooksKey);
      final cachedCategories = prefs.getString(_categoriesKey);
      final lastUpdate = prefs.getInt(_lastUpdateKey) ?? 0;

      if (cachedEbooks != null && cachedCategories != null) {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Penapis E-book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kategori:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String?>(
              value: _selectedCategoryFilter,
              hint: const Text('Semua kategori'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Semua kategori'),
                ),
                ..._categories.map(
                  (cat) => DropdownMenuItem<String?>(
                    value: cat['id'],
                    child: Text(cat['name']),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategoryFilter = value;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('Jenis:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<bool?>(
              value: _premiumFilter,
              hint: const Text('Semua jenis'),
              isExpanded: true,
              items: const [
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text('Semua jenis'),
                ),
                DropdownMenuItem<bool?>(
                  value: true,
                  child: Text('Premium sahaja'),
                ),
                DropdownMenuItem<bool?>(
                  value: false,
                  child: Text('Percuma sahaja'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _premiumFilter = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategoryFilter = null;
                _premiumFilter = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pengurusan E-book',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedFilterMailCircle,
              color: Colors.white,
            ),
            onPressed: _showFilterDialog,
            tooltip: 'Penapis',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            _buildSearchBar(),
            _buildStatsCard(),
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
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Jumlah',
            totalEbooks.toString(),
            HugeIcons.strokeRoundedBook02,
          ),
          _buildStatItem(
            'Aktif',
            activeEbooks.toString(),
            HugeIcons.strokeRoundedCheckmarkCircle02,
          ),
          _buildStatItem(
            'Premium',
            premiumEbooks.toString(),
            HugeIcons.strokeRoundedStar,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        HugeIcon(icon: icon, color: AppTheme.primaryColor, size: 24.0),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
        ),
      ],
    );
  }

  Widget _buildEbookList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminEbookDetailScreen(ebookId: ebook['id']),
          ),
        );
      },
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],

                    if (category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Kategori: ${category['name']}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    if (ebook['total_pages'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${ebook['total_pages']} muka surat',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
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

              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminEbookFormScreen(
                            ebookId: ebook['id'],
                            ebookData: ebook,
                          ),
                        ),
                      ).then((_) => _refreshData());
                      break;
                    case 'toggle':
                      _toggleEbookStatus(ebook['id'], isActive);
                      break;
                    case 'delete':
                      _deleteEbook(
                        ebook['id'],
                        ebook['title'] ?? 'Tanpa Tajuk',
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedEdit01,
                          size: 16,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: isActive
                              ? HugeIcons.strokeRoundedViewOff
                              : HugeIcons.strokeRoundedView,
                          size: 16.0,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(isActive ? 'Nyahaktif' : 'Aktifkan'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete01,
                          size: 16.0,
                          color: Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text('Padam', style: TextStyle(color: Colors.red)),
                      ],
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
