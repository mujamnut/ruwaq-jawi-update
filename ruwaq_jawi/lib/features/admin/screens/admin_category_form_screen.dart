import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/services/admin_category_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminCategoryFormScreen extends StatefulWidget {
  final String? categoryId; // null untuk tambah baru
  final Map<String, dynamic>? categoryData; // data untuk edit

  const AdminCategoryFormScreen({
    super.key,
    this.categoryId,
    this.categoryData,
  });

  @override
  State<AdminCategoryFormScreen> createState() => _AdminCategoryFormScreenState();
}

class _AdminCategoryFormScreenState extends State<AdminCategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController();
  
  late AdminCategoryService _categoryService;
  
  bool _isActive = true;
  bool _isLoading = false;
  String? _iconUrl;
  File? _selectedIcon;
  
  bool get _isEditing => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    _categoryService = AdminCategoryService(SupabaseService.client);
    
    if (_isEditing && widget.categoryData != null) {
      _initializeFormData();
    }
  }

  void _initializeFormData() {
    final data = widget.categoryData!;
    _nameController.text = data['name'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _sortOrderController.text = (data['sort_order'] ?? '').toString();
    _isActive = data['is_active'] ?? true;
    _iconUrl = data['icon_url'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedIcon = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar('Ralat memilih gambar: ${e.toString()}', isError: true);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? iconUrl = _iconUrl;

      // Upload icon baru jika dipilih
      if (_selectedIcon != null) {
        final tempCategoryId = widget.categoryId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
        iconUrl = await _categoryService.uploadCategoryIcon(_selectedIcon!, tempCategoryId);
        
        // Padam icon lama jika editing
        if (_isEditing && _iconUrl != null) {
          await _categoryService.deleteOldIcon(_iconUrl);
        }
      }

      if (_isEditing) {
        // Update kategori
        await _categoryService.updateCategory(
          categoryId: widget.categoryId!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null : _descriptionController.text.trim(),
          iconUrl: iconUrl,
          sortOrder: int.tryParse(_sortOrderController.text),
          isActive: _isActive,
        );
        
        _showSnackBar('Kategori berjaya dikemaskini!');
      } else {
        // Tambah kategori baru
        await _categoryService.createCategory(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null : _descriptionController.text.trim(),
          iconUrl: iconUrl,
          sortOrder: int.tryParse(_sortOrderController.text),
          isActive: _isActive,
        );
        
        _showSnackBar('Kategori berjaya ditambah!');
      }

      // Kembali ke screen sebelum
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Ralat: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Kategori' : 'Tambah Kategori'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Selector
                    _buildIconSelector(),
                    const SizedBox(height: 24),

                    // Nama Kategori
                    _buildTextFormField(
                      controller: _nameController,
                      label: 'Nama Kategori',
                      hint: 'Contoh: Akidah, Fiqh, Sejarah',
                      icon: HugeIcons.strokeRoundedGrid,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    // Deskripsi
                    _buildTextFormField(
                      controller: _descriptionController,
                      label: 'Deskripsi (Opsional)',
                      hint: 'Penerangan ringkas tentang kategori ini',
                      icon: HugeIcons.strokeRoundedFile01,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Sort Order
                    _buildTextFormField(
                      controller: _sortOrderController,
                      label: 'Susunan (Opsional)',
                      hint: 'Nombor untuk urutan paparan',
                      icon: HugeIcons.strokeRoundedSortingAZ01,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),

                    // Status Toggle
                    _buildStatusToggle(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Save Button
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Icon Kategori',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        GestureDetector(
          onTap: _pickIcon,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderColor,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: _buildIconDisplay(),
          ),
        ),
        
        const SizedBox(height: 8),
        Text(
          'Ketuk untuk pilih icon (opsional)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildIconDisplay() {
    if (_selectedIcon != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedIcon!,
              height: 60,
              width: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Icon dipilih',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    } else if (_iconUrl != null && _iconUrl!.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _iconUrl!,
              height: 60,
              width: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const HugeIcon(icon: HugeIcons.strokeRoundedImageNotFound01, size: 60.0, color: Colors.grey);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Icon sedia ada',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    } else {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: 40.0, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'Tiada icon dipilih',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: HugeIcon(icon: icon, size: 20.0, color: Colors.grey),
            border: const OutlineInputBorder(),
          ),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: isRequired ? (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label adalah wajib';
            }
            return null;
          } : null,
        ),
      ],
    );
  }

  Widget _buildStatusToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_isActive ? Colors.green : Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: HugeIcon(
              icon: _isActive ? HugeIcons.strokeRoundedView : HugeIcons.strokeRoundedViewOff,
              color: _isActive ? Colors.green : Colors.grey,
              size: 20.0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Kategori',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isActive ? 'Aktif - Boleh dilihat pengguna' : 'Tidak Aktif - Tersembunyi',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ShadSwitch(
            value: _isActive,
            onChanged: (value) {
              setState(() => _isActive = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: ShadButton(
        onPressed: _isLoading ? null : _submitForm,
        size: ShadButtonSize.lg,
        child: _isLoading 
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              _isEditing ? 'Kemaskini Kategori' : 'Simpan Kategori',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
      ),
    );
  }
}
