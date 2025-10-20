import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auto_generated_form.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/shimmer_loading.dart';
import 'form_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminAccess();
    });
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
              // Navigate to add category form
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AdminAddCategoryScreen(),
                ),
              );
              _loadCategories(); // Refresh after adding
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 3),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ShimmerList(
        itemCount: 8,
        shimmerItem: const CategoryShimmerCard(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCategories,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return const Center(
        child: Text('No categories found'),
      );
    }

    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return ListTile(
          title: Text(category['name'] ?? ''),
          subtitle: Text(category['description'] ?? ''),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AdminAddCategoryScreen(
                        categoryId: category['id'],
                      ),
                    ),
                  );
                  _loadCategories(); // Refresh after editing
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteCategory(category),
              ),
            ],
          ),
        );
      },
    );
  }

}
