import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auto_generated_form.dart';
import '../widgets/admin_bottom_nav.dart';
import 'generic_admin_form_screen.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      final profile = await SupabaseService.from(
        'profiles',
      ).select('role').eq('id', user.id).maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        if (mounted) {
          context.go('/home');
        }
        return;
      }

      _loadCategories();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Akses ditolak. Anda tidak mempunyai kebenaran admin.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _error = null;
        _isLoading = true;
      });

      final response = await SupabaseService.from(
        'categories',
      ).select('*').order('sort_order', ascending: true);

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuatkan data kategori: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCategories {
    if (_searchQuery.isEmpty) {
      return _categories;
    }
    return _categories.where((category) {
      final name = category['name']?.toString().toLowerCase() ?? '';
      final description =
          category['description']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    // Check if category is being used
    final [ebooksCount, videoKitabCount] = await Future.wait([
      SupabaseService.from('ebooks')
          .select('id')
          .eq('category_id', category['id'])
          .then((data) => (data as List).length),
      SupabaseService.from('video_kitab')
          .select('id')
          .eq('category_id', category['id'])
          .then((data) => (data as List).length),
    ]);

    if (ebooksCount > 0 || videoKitabCount > 0) {
      if (mounted) {
        _showErrorDialog(
          'Tidak Boleh Padam',
          'Kategori ini sedang digunakan oleh $ebooksCount e-book dan $videoKitabCount video kitab. Sila alihkan kandungan ke kategori lain terlebih dahulu.',
        );
      }
      return;
    }

    final confirmed = await _showConfirmDialog(
      'Padam Kategori',
      'Adakah anda pasti untuk memadam kategori "${category['name']}"?',
    );

    if (!confirmed) return;

    try {
      await SupabaseService.from(
        'categories',
      ).delete().eq('id', category['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kategori "${category['name']}" berjaya dipadam'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        _loadCategories();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Ralat', 'Gagal memadam kategori: $e');
      }
    }
  }

  Future<void> _toggleCategoryStatus(Map<String, dynamic> category) async {
    try {
      final newStatus = !(category['is_active'] ?? true);

      await SupabaseService.from('categories')
          .update({
            'is_active': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', category['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kategori "${category['name']}" ${newStatus ? 'diaktifkan' : 'dinyahaktifkan'}',
            ),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        _loadCategories();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Ralat', 'Gagal mengemas kini status kategori: $e');
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Padam'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Urus Kategori'),
        elevation: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
            size: 20.0,
          ),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedPlusSignCircle,
              color: Colors.white,
              size: 24.0,
            ),
            onPressed: () async {
              // Use auto-generated form instead of custom form
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const GenericAdminFormScreen(
                    tableName: 'categories',
                    fieldConfigs: {
                      'icon_url': FormFieldConfig(
                        label: 'Icon URL',
                        placeholder: 'https://example.com/icon.png',
                      ),
                      'sort_order': FormFieldConfig(
                        label: 'Sort Order',
                        placeholder: '0',
                      ),
                    },
                    hiddenFields: ['id', 'created_at', 'updated_at'],
                    title: 'Tambah Kategori Baru',
                  ),
                ),
              );
              _loadCategories();
            },
            tooltip: 'Tambah Kategori',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuatkan kategori...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 64.0,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Ralat Memuat Kategori',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ShadButton(
              onPressed: _loadCategories,
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Cari kategori...',
                prefixIcon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  size: 20.0,
                  color: Colors.grey,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 16.0,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          // Categories list
          Expanded(
            child: _filteredCategories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: _searchQuery.isNotEmpty
                              ? HugeIcons.strokeRoundedSearch01
                              : HugeIcons.strokeRoundedFolderAdd,
                          size: 64.0,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tiada kategori ditemui untuk "$_searchQuery"'
                              : 'Tiada kategori tersedia',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Cuba cari dengan kata kunci yang berbeza'
                              : 'Tekan butang + untuk menambah kategori baharu',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = _filteredCategories[index];
                      return _buildCategoryCard(category);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final isActive = category['is_active'] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.transparent : Colors.orange.shade200,
          width: isActive ? 0 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive ? Colors.white : Colors.orange.shade50,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedFolder02,
              color: isActive ? AppTheme.primaryColor : Colors.orange,
              size: 24.0,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  category['name'] ?? 'Tiada Nama',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isActive ? Colors.black87 : Colors.orange.shade800,
                  ),
                ),
              ),
              if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    'TIDAK AKTIF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (category['description'] != null &&
                  category['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  category['description'],
                  style: TextStyle(
                    color: isActive
                        ? Colors.grey.shade600
                        : Colors.orange.shade700,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'Susunan: ${category['sort_order'] ?? 0}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: FutureBuilder<int>(
                      future: _getCategoryUsageCount(category['id']),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Text(
                          'Kandungan: $count',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedMoreVertical,
              size: 20.0,
              color: Colors.grey,
            ),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  context.push('/admin/categories/edit/${category['id']}').then(
                    (result) {
                      if (result != null) {
                        _loadCategories();
                      }
                    },
                  );
                  break;
                case 'toggle':
                  _toggleCategoryStatus(category);
                  break;
                case 'delete':
                  _deleteCategory(category);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedEdit02,
                      size: 16.0,
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
                          ? HugeIcons.strokeRoundedEye
                          : HugeIcons.strokeRoundedEye,
                      size: 16.0,
                      color: isActive ? Colors.orange : Colors.green,
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
                      icon: HugeIcons.strokeRoundedDelete02,
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
        ),
      ),
    );
  }

  Future<int> _getCategoryUsageCount(String categoryId) async {
    try {
      final [ebooksCount, videoKitabCount] = await Future.wait([
        SupabaseService.from('ebooks')
            .select('id')
            .eq('category_id', categoryId)
            .then((data) => (data as List).length),
        SupabaseService.from('video_kitab')
            .select('id')
            .eq('category_id', categoryId)
            .then((data) => (data as List).length),
      ]);
      return ebooksCount + videoKitabCount;
    } catch (e) {
      return 0;
    }
  }
}
