import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
  final _sortOrderController = TextEditingController();

  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingData = false;
  String? _error;

  bool get _isEditing => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('DEBUG: AdminAddCategoryScreen initState called');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) {
        print('DEBUG: Starting postFrameCallback operations');
      }
      _checkAdminAccess().then((_) {
        if (_isEditing && mounted) {
          _loadCategoryData();
        }
      }).catchError((e) {
        if (kDebugMode) {
          print('DEBUG: Error in postFrameCallback: $e');
        }
        if (mounted) {
          setState(() {
            _error = 'Error initializing: $e';
            _isLoadingData = false;
          });
        }
      });
    });
  }

  Future<void> _checkAdminAccess() async {
    if (kDebugMode) {
      print('DEBUG: Checking admin access...');
    }

    final user = SupabaseService.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('DEBUG: No user found, redirecting to login');
      }
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      // Add timeout to prevent infinite waiting
      final profile = await SupabaseService.from(
        'profiles',
      ).select('role').eq('id', user.id).maybeSingle().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Admin check timeout');
        },
      );

      if (kDebugMode) {
        print('DEBUG: User profile: $profile');
      }

      if (profile == null || profile['role'] != 'admin') {
        if (kDebugMode) {
          print('DEBUG: User is not admin, redirecting to home');
        }
        if (mounted) {
          context.go('/home');
        }
        return;
      }

      if (kDebugMode) {
        print('DEBUG: Admin access confirmed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Admin check error: $e');
      }
      if (mounted) {
        setState(() {
          _error = 'Akses ditolak. Anda tidak mempunyai kebenaran admin.';
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _loadCategoryData() async {
    setState(() {
      _isLoadingData = true;
      _error = null;
    });

    try {
      final response = await SupabaseService.from(
        'categories',
      ).select('*').eq('id', widget.categoryId!).maybeSingle();

      if (response == null) {
        setState(() {
          _error = 'Kategori tidak dijumpai';
          _isLoadingData = false;
        });
        return;
      }

      setState(() {
        _nameController.text = response['name'] ?? '';
        _descriptionController.text = response['description'] ?? '';
        _sortOrderController.text = (response['sort_order'] ?? 0).toString();
        _isActive = response['is_active'] ?? true;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuatkan data kategori: $e';
        _isLoadingData = false;
      });
    }
  }

  Future<void> _saveCategory() async {
    if (kDebugMode) {
      print('DEBUG: _saveCategory called');
    }

    if (!_formKey.currentState!.validate()) {
      if (kDebugMode) {
        print('DEBUG: Form validation failed');
      }
      return;
    }

    if (kDebugMode) {
      print('DEBUG: Form validation passed, setting loading state');
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

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

      if (kDebugMode) {
        print('DEBUG: Saving category data: $data');
        print('DEBUG: User ID: ${SupabaseService.currentUser?.id}');
      }

      if (_isEditing) {
        // Update existing category
        final result = await SupabaseService.from(
          'categories',
        ).update(data).eq('id', widget.categoryId!);

        if (kDebugMode) {
          print('DEBUG: Update result: $result');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Kategori "${_nameController.text}" berjaya dikemas kini',
              ),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      } else {
        // Create new category
        // Check for duplicate name (friendly error)
        final existing = await SupabaseService.from('categories')
            .select('id')
            .eq('name', _nameController.text.trim())
            .maybeSingle();
        if (existing != null) {
          if (mounted) {
            setState(() {
              _error = 'Nama kategori sudah wujud';
              _isLoading = false;
            });
          }
          return;
        }

        final insertData = {
          ...data,
          'created_at': DateTime.now().toIso8601String(),
        };

        final result = await SupabaseService.from('categories')
            .insert(insertData)
            .select()
            .single();

        if (kDebugMode) {
          print('DEBUG: Insert result: $result');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Kategori "${_nameController.text}" berjaya ditambah',
              ),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      }

      if (mounted) {
        if (kDebugMode) {
          print('DEBUG: Save successful, returning to previous screen');
        }
        context.pop(true); // Return success result
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Error saving category: $e');
        print('DEBUG: Error type: ${e.runtimeType}');
      }
      if (mounted) {
        setState(() {
          _error = 'Gagal menyimpan kategori: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('DEBUG: Building AdminAddCategoryScreen widget');
      print('DEBUG: _isLoadingData: $_isLoadingData, _error: $_error, _isEditing: $_isEditing');
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Edit Kategori' : 'Tambah Kategori'),
        elevation: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
            size: 20.0,
          ),
          onPressed: () {
            if (kDebugMode) {
              print('DEBUG: Back button pressed');
            }
            context.pop();
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (kDebugMode) {
      print('DEBUG: Building _buildBody');
    }

    if (_isLoadingData) {
      if (kDebugMode) {
        print('DEBUG: Showing loading indicator');
      }
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuatkan data kategori...'),
          ],
        ),
      );
    }

    if (_error != null && _isEditing) {
      if (kDebugMode) {
        print('DEBUG: Showing error screen for editing: $_error');
      }
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
              'Ralat',
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
              onPressed: _loadCategoryData,
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    AppTheme.primaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(
                      icon: _isEditing
                          ? HugeIcons.strokeRoundedEdit02
                          : HugeIcons.strokeRoundedPlusSignCircle,
                      color: AppTheme.primaryColor,
                      size: 24.0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Kategori' : 'Kategori Baharu',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEditing
                              ? 'Kemas kini maklumat kategori'
                              : 'Tambah kategori baharu untuk mengorganisasi kandungan',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Error message
            if (_error != null && !_isEditing) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedAlert02,
                      size: 20.0,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Form fields
            _buildFormSection('Maklumat Asas', [
              _buildTextField(
                controller: _nameController,
                label: 'Nama Kategori',
                hint: 'Masukkan nama kategori',
                icon: HugeIcons.strokeRoundedFolder02,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Nama kategori adalah wajib';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Penerangan (Pilihan)',
                hint: 'Masukkan penerangan kategori',
                icon: HugeIcons.strokeRoundedNote,
                maxLines: 3,
              ),
            ]),

            const SizedBox(height: 24),

            _buildFormSection('Tetapan', [
              _buildTextField(
                controller: _sortOrderController,
                label: 'Susunan',
                hint: 'Nombor susunan (0 = pertama)',
                icon: HugeIcons.strokeRoundedSortingAZ01,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isNotEmpty == true) {
                    final num = int.tryParse(value!);
                    if (num == null || num < 0) {
                      return 'Susunan mestilah nombor positif atau 0';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedToggleOn,
                        color: AppTheme.primaryColor,
                        size: 20.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Kategori',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kategori yang tidak aktif tidak akan dipaparkan kepada pengguna',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                      activeThumbColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: Builder(
                builder: (context) {
                  try {
                    return ShadButton(
                      onPressed: _isLoading ? null : _saveCategory,
                      child: _isLoading
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Menyimpan...'),
                              ],
                            )
                          : Text(
                              _isEditing ? 'Kemas Kini Kategori' : 'Tambah Kategori',
                            ),
                    );
                  } catch (e) {
                    if (kDebugMode) {
                      print('DEBUG: Error building ShadButton: $e');
                    }
                    // Fallback ElevatedButton
                    return ElevatedButton(
                      onPressed: _isLoading ? null : _saveCategory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Menyimpan...'),
                              ],
                            )
                          : Text(
                              _isEditing ? 'Kemas Kini Kategori' : 'Tambah Kategori',
                            ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    try {
      return TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: HugeIcon(
            icon: icon,
            size: 20.0,
            color: Colors.grey.shade600,
          ),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
      );
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Error building text field for $label: $e');
      }
      // Fallback basic text field
      return TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }
}
