import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_bottom_nav.dart';

class AdminEbookFormScreen extends StatefulWidget {
  final String? ebookId;
  final Map<String, dynamic>? ebookData;

  const AdminEbookFormScreen({super.key, this.ebookId, this.ebookData});

  @override
  State<AdminEbookFormScreen> createState() => _AdminEbookFormScreenState();
}

class _AdminEbookFormScreenState extends State<AdminEbookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pagesController = TextEditingController();

  bool _isLoading = false;
  bool _isPremium = true;
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  // File handling
  PlatformFile? _selectedPdfFile;
  PlatformFile? _selectedThumbnailFile;
  String? _uploadedPdfUrl;
  String? _uploadedThumbnailUrl;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.ebookData != null) {
      _populateForm();
    }
  }

  void _populateForm() {
    final data = widget.ebookData!;
    _titleController.text = data['title'] ?? '';
    _authorController.text = data['author'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _pagesController.text = data['total_pages']?.toString() ?? '';
    _isPremium = data['is_premium'] ?? true;
    _selectedCategoryId = data['category_id'];
    _uploadedPdfUrl = data['pdf_url'];
    _uploadedThumbnailUrl = data['thumbnail_url'];
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await SupabaseService.from(
        'categories',
      ).select('id, name').eq('is_active', true).order('name');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(categories);
      });
    } catch (e) {
      _showErrorSnackBar('Ralat memuatkan kategori: ${e.toString()}');
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedPdfFile = result.files.first;
        });
        _showSuccessSnackBar('Fail PDF dipilih: ${_selectedPdfFile!.name}');

        // Auto-detect PDF page count
        await _detectPdfPageCount();
      }
    } catch (e) {
      _showErrorSnackBar('Ralat memilih fail PDF: ${e.toString()}');
    }
  }

  Future<void> _pickThumbnailFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedThumbnailFile = result.files.first;
        });
        _showSuccessSnackBar(
          'Gambar thumbnail dipilih: ${_selectedThumbnailFile!.name}',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Ralat memilih gambar: ${e.toString()}');
    }
  }

  Future<void> _detectPdfPageCount() async {
    if (_selectedPdfFile?.bytes == null) return;

    try {
      // Create a temporary file from bytes to use with pdfx
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(_selectedPdfFile!.bytes!);

      // Use pdfx to read PDF and get page count
      final document = await pdfx.PdfDocument.openFile(tempFile.path);
      final pageCount = document.pagesCount;

      setState(() {
        _pagesController.text = pageCount.toString();
      });

      _showSuccessSnackBar('Jumlah halaman PDF dikesan: $pageCount');

      // Close the document and clean up temp file
      await document.close();
      await tempFile.delete();
    } catch (e) {
      _showErrorSnackBar(
        'Tidak dapat mengesan bilangan halaman PDF secara automatik: ${e.toString()}',
      );
    }
  }

  Future<String?> _uploadFile(PlatformFile file, String folder) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final filePath = '$folder/$fileName';

      // Upload to Supabase Storage
      await SupabaseService.client.storage
          .from('ebook-pdfs')
          .uploadBinary(filePath, file.bytes!);

      // Get public URL
      final publicUrl = SupabaseService.client.storage
          .from('ebook-pdfs')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Ralat upload fail: $e');
    }
  }

  Future<void> _saveEbook() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? pdfUrl = _uploadedPdfUrl;
      String? thumbnailUrl = _uploadedThumbnailUrl;

      // Upload files in parallel for better performance
      final List<Future<String?>> uploadTasks = [];

      if (_selectedPdfFile != null) {
        uploadTasks.add(_uploadFile(_selectedPdfFile!, 'pdf'));
      }

      if (_selectedThumbnailFile != null) {
        uploadTasks.add(_uploadFile(_selectedThumbnailFile!, 'thumbnails'));
      }

      // Execute uploads in parallel
      if (uploadTasks.isNotEmpty) {
        final results = await Future.wait(uploadTasks);
        int resultIndex = 0;

        if (_selectedPdfFile != null) {
          pdfUrl = results[resultIndex++];
        }

        if (_selectedThumbnailFile != null) {
          thumbnailUrl = results[resultIndex];
        }
      }

      // Validate required fields
      if (pdfUrl == null) {
        throw Exception('Fail PDF adalah wajib');
      }

      final ebookData = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'category_id': _selectedCategoryId,
        'pdf_url': pdfUrl,
        'pdf_storage_path': _selectedPdfFile != null
            ? 'pdf/${DateTime.now().millisecondsSinceEpoch}_${_selectedPdfFile!.name}'
            : null,
        'pdf_file_size': _selectedPdfFile?.size,
        'thumbnail_url': thumbnailUrl,
        'is_premium': _isPremium,
        'total_pages': int.tryParse(_pagesController.text.trim()),
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.ebookId != null) {
        // Update existing e-book
        await SupabaseService.from(
          'ebooks',
        ).update(ebookData).eq('id', widget.ebookId!);
        _showSuccessSnackBar('E-book berjaya dikemaskini');
      } else {
        // Create new e-book
        ebookData['created_at'] = DateTime.now().toIso8601String();
        await SupabaseService.from('ebooks').insert(ebookData);
        _showSuccessSnackBar('E-book berjaya ditambah');
      }

      // Wait a moment for snackbar to show, then navigate
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate back to ebook list
      if (mounted) {
        context.go('/admin/ebooks');
      }
    } catch (e) {
      _showErrorSnackBar('Ralat menyimpan e-book: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.ebookId != null ? 'Edit E-book' : 'Tambah E-book Baru',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft02,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 24),
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildFileUploadSection(),
              const SizedBox(height: 24),
              _buildSettingsSection(),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 2),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedBook02,
                color: Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'E-book Khusus',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Form ini khusus untuk menambah e-book sahaja tanpa video. E-book akan tersedia untuk dimuat turun dan dibaca dalam aplikasi.',
            style: TextStyle(
              color: Colors.blue.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maklumat Asas E-book',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Tajuk E-book *',
            border: OutlineInputBorder(),
            prefixIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedAlignLeft,
              color: Colors.grey,
            ),
          ),
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return 'Tajuk adalah wajib';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _authorController,
          decoration: const InputDecoration(
            labelText: 'Pengarang',
            border: OutlineInputBorder(),
            prefixIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategoryId,
          decoration: const InputDecoration(
            labelText: 'Kategori',
            border: OutlineInputBorder(),
            prefixIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedGrid,
              color: Colors.grey,
            ),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem<String>(
              value: category['id'],
              child: Text(category['name']),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Penerangan',
            border: OutlineInputBorder(),
            prefixIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedFile01,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pagesController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Jumlah Muka Surat',
            border: OutlineInputBorder(),
            prefixIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedFile01,
              color: Colors.grey,
            ),
            hintText: 'Auto-dikesan apabila PDF dipilih',
            helperText: 'Akan cuba mengesan bilangan halaman secara automatik',
          ),
        ),
      ],
    );
  }

  Widget _buildFileUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Fail',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // PDF Upload
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedPdf01,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Fail PDF E-book *',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedPdfFile != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Dipilih: ${_selectedPdfFile!.name}',
                    style: TextStyle(color: Colors.green),
                  ),
                )
              else if (_uploadedPdfUrl != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PDF sedia ada telah diupload',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickPdfFile,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedUpload01,
                  color: Colors.white,
                ),
                label: Text(
                  _selectedPdfFile != null || _uploadedPdfUrl != null
                      ? 'Tukar PDF'
                      : 'Pilih PDF',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Thumbnail Upload
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedImage01,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Gambar Thumbnail (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedThumbnailFile != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Dipilih: ${_selectedThumbnailFile!.name}',
                    style: TextStyle(color: Colors.green),
                  ),
                )
              else if (_uploadedThumbnailUrl != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Thumbnail sedia ada telah diupload',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickThumbnailFile,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedImage01,
                  color: Colors.white,
                ),
                label: Text(
                  _selectedThumbnailFile != null ||
                          _uploadedThumbnailUrl != null
                      ? 'Tukar Thumbnail'
                      : 'Pilih Thumbnail',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tetapan E-book',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('E-book Premium'),
          subtitle: Text(
            _isPremium
                ? 'Memerlukan langganan untuk akses'
                : 'Boleh diakses secara percuma',
          ),
          value: _isPremium,
          activeThumbColor: AppTheme.primaryColor,
          onChanged: (value) {
            setState(() {
              _isPremium = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveEbook,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const HugeIcon(
                icon: HugeIcons.strokeRoundedFloppyDisk,
                color: Colors.white,
              ),
        label: Text(
          _isLoading
              ? 'Menyimpan...'
              : (widget.ebookId != null ? 'Kemaskini E-book' : 'Simpan E-book'),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _pagesController.dispose();
    super.dispose();
  }
}
