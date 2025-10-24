import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';

class AdminAddCategoryScreen extends StatefulWidget {
  final String? categoryId;

  const AdminAddCategoryScreen({super.key, this.categoryId});

  @override
  State<AdminAddCategoryScreen> createState() => _AdminAddCategoryScreenState();
}

class _AdminAddCategoryScreenState extends State<AdminAddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');

  bool _isActive = true;
  bool _isLoading = false;

  bool get _isEditing => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadCategory();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _loadCategory() async {
    setState(() => _isLoading = true);

    try {
      final data = await SupabaseService.from(
        'categories',
      ).select().eq('id', widget.categoryId!).single();

      setState(() {
        _nameController.text = data['name'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _sortOrderController.text = (data['sort_order'] ?? 0).toString();
        _isActive = data['is_active'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'sort_order': int.tryParse(_sortOrderController.text) ?? 0,
        'is_active': _isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isEditing) {
        await SupabaseService.from(
          'categories',
        ).update(data).eq('id', widget.categoryId!);
      } else {
        // Check duplicate
        final existing = await SupabaseService.from(
          'categories',
        ).select('id').eq('name', _nameController.text.trim()).maybeSingle();

        if (existing != null) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nama kategori sudah wujud')),
            );
          }
          return;
        }

        await SupabaseService.from('categories').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Berjaya dikemas kini' : 'Berjaya ditambah',
            ),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppTheme.textPrimaryColor,
            size: 24.0,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Kategori' : 'Tambah Kategori',
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nama Kategori *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v?.trim().isEmpty ?? true
                                  ? 'Wajib diisi'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Penerangan',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _sortOrderController,
                              decoration: const InputDecoration(
                                labelText: 'Susunan',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Aktif'),
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                ),
                                child: Text(_isEditing ? 'Simpan' : 'Tambah'),
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
    );
  }
}
