import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../../../../core/services/admin_category_service.dart';
import '../../../../core/services/video_kitab_service.dart';
import '../../../../core/services/video_episode_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';

class AdminKitabFormScreen extends StatefulWidget {
  final String? kitabId; // null untuk tambah baru
  final Map<String, dynamic>? kitabData; // data untuk edit

  const AdminKitabFormScreen({super.key, this.kitabId, this.kitabData});

  @override
  State<AdminKitabFormScreen> createState() => _AdminKitabFormScreenState();
}

class _AdminKitabFormScreenState extends State<AdminKitabFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalPagesController = TextEditingController();
  // final _sortOrderController = TextEditingController(); // removed

  late AdminCategoryService _categoryService;
  // Use VideoKitabService instead of AdminKitabService
  late TabController _tabController;

  bool _isPremium = true;
  bool _isActive = true;
  // bool _isEbookAvailable = false; // field removed
  bool _isLoading = false;
  String? _selectedCategoryId;
  String? _thumbnailUrl;
  String? _pdfUrl;
  File? _selectedThumbnail;
  File? _selectedPdf;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _episodes = [];
  bool _isLoadingEpisodes = false;

  bool get _isEditing => widget.kitabId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _categoryService = AdminCategoryService(SupabaseService.client);
    // Using VideoKitabService and VideoEpisodeService instead

    // Defer loading to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminAccess();
    });
  }

  Future<void> _checkAdminAccess() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      final profile = await SupabaseService.from(
        'profiles',
      ).select('role').eq('id', user.id).maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      _loadInitialData();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadCategories(), if (_isEditing) _loadKitabData()]);
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getAllCategories(
        isActive: true,
      );
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      _showSnackBar('Ralat memuatkan kategori: ${e.toString()}', isError: true);
    }
  }

  Future<void> _loadKitabData() async {
    if (widget.kitabData != null) {
      final data = widget.kitabData!;
      _titleController.text = data['title'] ?? '';
      _authorController.text = data['author'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _totalPagesController.text = (data['total_pages'] ?? '').toString();
      // _sortOrderController.text = (data['sort_order'] ?? '').toString(); // removed
      _selectedCategoryId = data['category_id'];
      _isPremium = data['is_premium'] ?? true;
      _isActive = data['is_active'] ?? true;
      // _isEbookAvailable field doesn't exist in ebooks table
      _thumbnailUrl = data['thumbnail_url'];
      _pdfUrl = data['pdf_url'];

      // Load episodes jika ada
      if (widget.kitabId != null) {
        await _loadEpisodes();
      }
    }
  }

  Future<void> _loadEpisodes() async {
    if (widget.kitabId == null) return;

    setState(() {
      _isLoadingEpisodes = true;
    });

    try {
      final episodes = await VideoEpisodeService.getEpisodesForVideoKitab(
        widget.kitabId!,
        orderBy: 'part_number',
        ascending: true,
      );

      setState(() {
        _episodes = episodes.map((e) => e.toJson()).toList();
        _isLoadingEpisodes = false;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Ralat memuatkan episodes: ${e.toString()}',
          isError: true,
        );
      }
      setState(() {
        _isLoadingEpisodes = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _totalPagesController.dispose();
    // _sortOrderController.dispose(); // removed
    _tabController.dispose();
    super.dispose();
  }

  /// Generate default YouTube thumbnail URL
  String _defaultThumbnailFor(String id) =>
      VideoEpisodeService.getYouTubeThumbnailUrl(id);

  /// Get next episode number for auto-increment
  int _getNextEpisodeNumber() {
    if (_episodes.isEmpty) return 1;

    final partNumbers =
        _episodes
            .map((e) => e['part_number'] as int? ?? 0)
            .where((partNum) => partNum > 0)
            .toList()
          ..sort();

    return partNumbers.isEmpty ? 1 : partNumbers.last + 1;
  }

  Future<void> _pickThumbnail() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedThumbnail = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar('Ralat memilih thumbnail: ${e.toString()}', isError: true);
    }
  }

  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        setState(() {
          _selectedPdf = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _showSnackBar('Ralat memilih PDF: ${e.toString()}', isError: true);
    }
  }

  Future<void> _previewPdfFile(File pdfFile) async {
    try {
      // Show in-app PDF viewer dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => _PdfViewerDialog(
            file: pdfFile,
            title: 'Pratonton PDF',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar('Ralat membuka PDF: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _previewPdfUrl(String pdfUrl) async {
    try {
      // Show in-app PDF viewer dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => _PdfViewerDialog(
            url: pdfUrl,
            title: 'Pratonton PDF',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar('Ralat membuka PDF: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _downloadPdf(String pdfUrl) async {
    try {
      final uri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          _showSnackBar('Tidak dapat memuat turun PDF', isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar('Ralat memuat turun PDF: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _submitForm() async {
    print('=== SUBMIT FORM DEBUG START ===');
    print('Form validation: ${_formKey.currentState?.validate()}');

    if (!_formKey.currentState!.validate()) {
      print('Form validation failed, returning early');
      return;
    }

    print('Setting loading state to true');
    setState(() => _isLoading = true);

    try {
      String? thumbnailUrl = _thumbnailUrl;
      print('Thumbnail URL: $thumbnailUrl');

      Map<String, dynamic> result;

      if (_isEditing) {
        print('=== EDITING MODE ===');
        print('Kitab ID: ${widget.kitabId}');

        // Update existing video kitab
        final videoKitabData = {
          'title': _titleController.text.trim(),
          'author': _authorController.text.trim().isEmpty
              ? null
              : _authorController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'category_id': _selectedCategoryId,
          'thumbnail_url': thumbnailUrl,
          'is_premium': _isPremium,
          'is_active': _isActive,
          'total_pages': int.tryParse(_totalPagesController.text),
        };

        print('Update data: $videoKitabData');
        print('Calling VideoKitabService.updateVideoKitabAdmin...');

        final updatedKitab = await VideoKitabService.updateVideoKitabAdmin(
          widget.kitabId!,
          videoKitabData,
        );

        print('Update successful! Result: ${updatedKitab.toJson()}');
        result = updatedKitab.toJson();

        _showSnackBar('Kitab berjaya dikemaskini!');
      } else {
        print('=== CREATE MODE ===');

        // Create new video kitab
        final videoKitabData = {
          'title': _titleController.text.trim(),
          'author': _authorController.text.trim().isEmpty
              ? null
              : _authorController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'category_id': _selectedCategoryId,
          'thumbnail_url': thumbnailUrl,
          'is_premium': _isPremium,
          'is_active': _isActive,
          'total_pages': int.tryParse(_totalPagesController.text),
        };

        print('Create data: $videoKitabData');
        print('Calling VideoKitabService.createVideoKitab...');

        final createdKitab = await VideoKitabService.createVideoKitab(
          videoKitabData,
        );

        print('Create successful! Result: ${createdKitab.toJson()}');
        result = createdKitab.toJson();

        _showSnackBar('Kitab berjaya ditambah!');
      }

      // kitabId available in result['id'] if needed for future file uploads

      // File upload functionality
      String? finalThumbnailUrl = thumbnailUrl;
      String? finalPdfUrl = _pdfUrl;

      // Upload thumbnail if selected
      if (_selectedThumbnail != null) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final thumbnailPath = 'thumbnails/video_kitab_${timestamp}_${_selectedThumbnail!.path.split('/').last}';

          final thumbnailBytes = await _selectedThumbnail!.readAsBytes();
          await Supabase.instance.client.storage
              .from('video-kitab-files')
              .uploadBinary(thumbnailPath, thumbnailBytes);

          finalThumbnailUrl = Supabase.instance.client.storage
              .from('video-kitab-files')
              .getPublicUrl(thumbnailPath);
        } catch (e) {
          print('Error uploading thumbnail: $e');
          _showSnackBar('Ralat upload thumbnail: $e', isError: true);
        }
      }

      // Upload PDF if selected
      if (_selectedPdf != null) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final pdfPath = 'pdfs/video_kitab_${timestamp}_${_selectedPdf!.path.split('/').last}';

          final pdfBytes = await _selectedPdf!.readAsBytes();
          await Supabase.instance.client.storage
              .from('video-kitab-files')
              .uploadBinary(pdfPath, pdfBytes);

          finalPdfUrl = Supabase.instance.client.storage
              .from('video-kitab-files')
              .getPublicUrl(pdfPath);

          final fileSize = await _selectedPdf!.length();

          // Update kitab with PDF info
          if (_isEditing && widget.kitabId != null) {
            await VideoKitabService.updateVideoKitabAdmin(widget.kitabId!, {
              'pdf_url': finalPdfUrl,
              'pdf_storage_path': pdfPath,
              'pdf_file_size': fileSize,
            });
          } else if (result['id'] != null) {
            await VideoKitabService.updateVideoKitabAdmin(result['id'], {
              'pdf_url': finalPdfUrl,
              'pdf_storage_path': pdfPath,
              'pdf_file_size': fileSize,
            });
          }
        } catch (e) {
          print('Error uploading PDF: $e');
          _showSnackBar('Ralat upload PDF: $e', isError: true);
        }
      }

      print('Navigating back with result: $result');
      // Navigate back with success result
      Navigator.pop(context, result);

      print('=== SUBMIT FORM SUCCESS ===');
    } catch (e, stackTrace) {
      print('=== ERROR IN SUBMIT FORM ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      _showSnackBar('Ralat: ${e.toString()}', isError: true);
    } finally {
      print('Setting loading state to false');
      setState(() => _isLoading = false);
      print('=== SUBMIT FORM DEBUG END ===');
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
        title: Text(_isEditing ? 'Edit Kitab' : 'Tambah Kitab'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.textLightColor,
          labelColor: AppTheme.textLightColor,
          unselectedLabelColor: AppTheme.textLightColor.withValues(alpha: 0.7),
          tabs: const [
            Tab(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                color: Colors.grey,
              ),
              text: 'Maklumat',
            ),
            Tab(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedPdf01,
                color: Colors.grey,
              ),
              text: 'Fail',
            ),
            Tab(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedVideo01,
                color: Colors.grey,
              ),
              text: 'Episode',
            ),
          ],
        ),
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
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInfoTab(),
                  _buildFilesTab(),
                  _buildEpisodesTab(),
                ],
              ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          _buildTextFormField(
            controller: _titleController,
            label: 'Tajuk Kitab',
            hint: 'Nama kitab',
            icon: HugeIcons.strokeRoundedBook02,
            isRequired: true,
          ),
          const SizedBox(height: 16),

          // Author
          _buildTextFormField(
            controller: _authorController,
            label: 'Pengarang',
            hint: 'Nama pengarang kitab',
            icon: HugeIcons.strokeRoundedUser,
          ),
          const SizedBox(height: 16),

          // Category Dropdown
          _buildCategoryDropdown(),
          const SizedBox(height: 16),

          // Description
          _buildTextFormField(
            controller: _descriptionController,
            label: 'Deskripsi',
            hint: 'Penerangan ringkas tentang kitab',
            icon: HugeIcons.strokeRoundedFile01,
            maxLines: 4,
          ),
          const SizedBox(height: 16),

          // Total Pages
          _buildTextFormField(
            controller: _totalPagesController,
            label: 'Jumlah Halaman',
            hint: 'Bilangan halaman (untuk e-book)',
            icon: HugeIcons.strokeRoundedFile01,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // Sort Order field removed - doesn't exist in video_kitab table
          const SizedBox(height: 24),

          // Status toggles
          _buildStatusToggles(),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail section
          _buildFileSection(
            title: 'Thumbnail Kitab',
            description:
                'Gambar cover yang akan dipaparkan (JPG/PNG, max 10MB)',
            currentFile: _thumbnailUrl,
            selectedFile: _selectedThumbnail,
            onPickFile: _pickThumbnail,
            isImage: true,
          ),
          const SizedBox(height: 32),

          // PDF section
          _buildFileSection(
            title: 'Fail PDF',
            description: 'Fail e-book dalam format PDF (max 50MB)',
            currentFile: _pdfUrl,
            selectedFile: _selectedPdf,
            onPickFile: _pickPdf,
            isImage: false,
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesTab() {
    return Column(
      children: [
        // Episodes header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceColor,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Episode Video (${_episodes.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEpisodeDialog(),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedPlusSign,
                  color: Colors.white,
                ),
                label: const Text('Tambah Episode'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Episodes list
        Expanded(
          child: _isLoadingEpisodes
              ? const Center(child: CircularProgressIndicator())
              : _episodes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        HugeIcons.strokeRoundedVideo01,
                        size: 64.0,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada episode video',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tekan "Tambah Episode" untuk mula',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _episodes.length,
                  onReorder: _reorderEpisodes,
                  itemBuilder: (context, index) {
                    final episode = _episodes[index];
                    return _buildEpisodeCard(
                      episode,
                      index,
                      key: ValueKey(episode['id']),
                    );
                  },
                ),
        ),
      ],
    );
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
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label + (isRequired ? ' *' : ''),
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppTheme.surfaceColor,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label adalah wajib';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      decoration: InputDecoration(
        labelText: 'Kategori',
        prefixIcon: const HugeIcon(
          icon: HugeIcons.strokeRoundedGrid,
          color: Colors.grey,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppTheme.surfaceColor,
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
      hint: const Text('Pilih kategori'),
    );
  }

  Widget _buildStatusToggles() {
    return Column(
      children: [
        _buildToggle(
          title: 'Kitab Premium',
          subtitle: _isPremium
              ? 'Perlu langganan untuk akses'
              : 'Percuma untuk semua pengguna',
          value: _isPremium,
          onChanged: (value) => setState(() => _isPremium = value),
          icon: _isPremium
              ? HugeIcons.strokeRoundedLockPassword
              : HugeIcons.strokeRoundedLock,
        ),
        const SizedBox(height: 16),
        // E-book toggle removed as field doesn't exist in ebooks table
        _buildToggle(
          title: 'Status Aktif',
          subtitle: _isActive
              ? 'Aktif - Boleh dilihat pengguna'
              : 'Tidak Aktif - Tersembunyi',
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
          icon: _isActive
              ? HugeIcons.strokeRoundedView
              : HugeIcons.strokeRoundedViewOff,
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? AppTheme.primaryColor : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildFileSection({
    required String title,
    required String description,
    String? currentFile,
    File? selectedFile,
    required VoidCallback onPickFile,
    required bool isImage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 12),

        GestureDetector(
          onTap: onPickFile,
          child: Container(
            height: isImage ? 160 : 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: _buildFileDisplay(currentFile, selectedFile, isImage),
          ),
        ),
        const SizedBox(height: 8),

        // Action buttons for existing files
        if (!isImage && (currentFile != null && currentFile.isNotEmpty || selectedFile != null))
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  if (selectedFile != null) {
                    await _previewPdfFile(selectedFile);
                  } else if (currentFile != null && currentFile.isNotEmpty) {
                    await _previewPdfUrl(currentFile);
                  }
                },
                icon: const Icon(
                  HugeIcons.strokeRoundedEye,
                  size: 14,
                ),
                label: const Text(
                  'Pratonton',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              if (currentFile != null && currentFile.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    await _downloadPdf(currentFile);
                  },
                  icon: const Icon(
                    HugeIcons.strokeRoundedDownload01,
                    size: 14,
                  ),
                  label: const Text(
                    'Muat Turun',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildFileDisplay(
    String? currentFile,
    File? selectedFile,
    bool isImage,
  ) {
    if (selectedFile != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                selectedFile,
                height: 80,
                width: 80,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    HugeIcons.strokeRoundedPdf01,
                    size: 32.0,
                    color: Colors.red,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'PDF Baru',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            selectedFile.path.split('/').last,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (currentFile != null && currentFile.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                currentFile,
                height: 80,
                width: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    HugeIcons.strokeRoundedImageNotFound01,
                    size: 32.0,
                  );
                },
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    HugeIcons.strokeRoundedPdf01,
                    size: 32.0,
                    color: Colors.green,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'PDF Sedia Ada',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            isImage ? 'Thumbnail sedia ada' : 'PDF sedia ada',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isImage
                ? HugeIcons.strokeRoundedImage01
                : HugeIcons.strokeRoundedUpload01,
            size: 32.0,
            color: Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            isImage ? 'Ketuk untuk pilih thumbnail' : 'Ketuk untuk pilih PDF',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }

  Widget _buildEpisodeCard(
    Map<String, dynamic> episode,
    int index, {
    required Key key,
  }) {
    final youtubeVideoId = episode['youtube_video_id'] as String?;
    final thumbnailUrl =
        episode['thumbnail_url'] as String? ??
        (youtubeVideoId != null ? _defaultThumbnailFor(youtubeVideoId) : null);

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // YouTube Thumbnail
            Container(
              width: 100,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[300],
              ),
              child: thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        thumbnailUrl,
                        width: 100,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              HugeIcons.strokeRoundedImageNotFound01,
                            ),
                          );
                        },
                      ),
                    )
                  : const HugeIcon(
                      icon: HugeIcons.strokeRoundedVideo01,
                      size: 40,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(width: 12),

            // Episode Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Episode Number Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Episode ${episode['part_number']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    episode['title'] ?? 'Untitled Episode',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Duration
                  Text(
                    'Tempoh: ${episode['duration_minutes'] ?? 0} minit',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (episode['is_active'] == true
                                  ? Colors.green
                                  : Colors.grey)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color:
                            (episode['is_active'] == true
                                    ? Colors.green
                                    : Colors.grey)
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      episode['is_active'] == true
                          ? 'AKTIF'
                          : 'TIDAK AKTIF',
                      style: TextStyle(
                        fontSize: 9,
                        color: episode['is_active'] == true
                            ? Colors.green
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Icon(
                  HugeIcons.strokeRoundedDrag01,
                  color: Colors.grey[400],
                  size: 20.0,
                ),
                const SizedBox(height: 8),

                // Options Menu
                PopupMenuButton(
                  iconSize: 20,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'play',
                      child: ListTile(
                        leading: Icon(
                          HugeIcons.strokeRoundedPlay,
                          color: Colors.green,
                        ),
                        title: Text('Tonton di YouTube'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: HugeIcon(
                          icon: HugeIcons.strokeRoundedEdit01,
                          color: Colors.blue,
                        ),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          HugeIcons.strokeRoundedDelete01,
                          color: Colors.red,
                        ),
                        title: Text('Padam'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'play') {
                      final videoId = episode['youtube_video_id'];
                      if (videoId != null) {
                        final url = 'https://www.youtube.com/watch?v=$videoId';
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url));
                        }
                      }
                    } else if (value == 'edit') {
                      _showEditEpisodeDialog(episode);
                    } else if (value == 'delete') {
                      _deleteEpisode(episode['id']);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.textLightColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
                _isEditing ? 'Kemaskini Kitab' : 'Simpan Kitab',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _showAddEpisodeDialog() {
    _showEpisodeDialog();
  }

  void _showEditEpisodeDialog(Map<String, dynamic> episode) {
    _showEpisodeDialog(episode: episode);
  }

  void _showEpisodeDialog({Map<String, dynamic>? episode}) {
    showDialog(
      context: context,
      builder: (context) => _EpisodeDialog(
        episode: episode,
        onSave: _saveEpisodeFromDialog,
        getNextEpisodeNumber: _getNextEpisodeNumber,
        defaultThumbnailFor: _defaultThumbnailFor,
        extractYouTubeVideoId: VideoEpisodeService.extractYouTubeVideoId,
      ),
    );
  }

  Future<void> _saveEpisodeFromDialog({
    String? episodeId,
    required String title,
    required String youtubeVideoId,
    required int episodeNumber,
    String? thumbnailUrl,
    required bool isActive,
  }) async {
    if (title.isEmpty || youtubeVideoId.isEmpty) {
      _showSnackBar('Tajuk dan YouTube ID adalah wajib', isError: true);
      return;
    }

    try {
      if (widget.kitabId == null) {
        _showSnackBar('Sila simpan kitab terlebih dahulu', isError: true);
        return;
      }

      final youtubeUrl = 'https://www.youtube.com/watch?v=$youtubeVideoId';
      final finalThumbnailUrl =
          thumbnailUrl ?? _defaultThumbnailFor(youtubeVideoId);

      if (episodeId == null) {
        // Add new episode
        await VideoEpisodeService.createEpisode({
          'video_kitab_id': widget.kitabId!,
          'title': title,
          'youtube_video_id': youtubeVideoId,
          'part_number': episodeNumber,
          'youtube_video_url': youtubeUrl,
          'thumbnail_url': finalThumbnailUrl,
          'is_active': isActive,
        });
        _showSnackBar('Episode berjaya ditambah!');
      } else {
        // Update existing episode
        await VideoEpisodeService.updateEpisode(episodeId, {
          'title': title,
          'youtube_video_id': youtubeVideoId,
          'youtube_video_url': youtubeUrl,
          'thumbnail_url': finalThumbnailUrl,
          'part_number': episodeNumber,
          'is_active': isActive,
        });
        _showSnackBar('Episode berjaya dikemaskini!');
      }

      await _loadEpisodes(); // Refresh episodes list
    } catch (e) {
      _showSnackBar('Ralat menyimpan episode: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteEpisode(String episodeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Episode'),
        content: const Text('Adakah anda pasti untuk memadam episode ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await VideoEpisodeService.deleteEpisode(episodeId);
        _showSnackBar('Episode berjaya dipadam!');
        await _loadEpisodes();
      } catch (e) {
        _showSnackBar('Ralat memadam episode: ${e.toString()}', isError: true);
      }
    }
  }

  void _reorderEpisodes(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final episode = _episodes.removeAt(oldIndex);
      _episodes.insert(newIndex, episode);
    });

    // Update episode order in database
    if (widget.kitabId != null) {
      // Note: VideoEpisodeService doesn't have reorderEpisodes method
      // Episodes are ordered by part_number, so reordering updates part numbers
      _updateEpisodePartNumbers();
    }
  }

  Future<void> _updateEpisodePartNumbers() async {
    try {
      // Update part numbers based on current order
      for (int i = 0; i < _episodes.length; i++) {
        final episode = _episodes[i];
        final episodeId = episode['id'] as String;
        final newPartNumber = i + 1;

        if (episode['part_number'] != newPartNumber) {
          await VideoEpisodeService.updateEpisode(episodeId, {
            'part_number': newPartNumber,
          });
          // Update local data to reflect changes
          _episodes[i]['part_number'] = newPartNumber;
        }
      }
    } catch (e) {
      _showSnackBar(
        'Ralat mengemas kini susunan episode: ${e.toString()}',
        isError: true,
      );
    }
  }
}

// =====================================================
// PDF VIEWER DIALOG WIDGET
// =====================================================

class _PdfViewerDialog extends StatefulWidget {
  final File? file;
  final String? url;
  final String title;

  const _PdfViewerDialog({
    this.file,
    this.url,
    required this.title,
  });

  @override
  State<_PdfViewerDialog> createState() => _PdfViewerDialogState();
}

class _PdfViewerDialogState extends State<_PdfViewerDialog> {
  pdfx.PdfController? _pdfController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      pdfx.PdfController? controller;

      if (widget.file != null) {
        // Load from local file
        controller = pdfx.PdfController(
          document: pdfx.PdfDocument.openFile(widget.file!.path),
        );
      } else if (widget.url != null) {
        // For URL, just show a message and open in browser
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'URL PDF akan dibuka dalam browser';
        });
        return;
      }

      if (controller != null) {
        _pdfController = controller;

        // Get total pages
        final pageCount = await controller.pagesCount;
        setState(() {
          _totalPages = pageCount ?? 1;
          _isLoading = false;
        });
      } else {
        throw Exception('No PDF source provided');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _openInBrowser() async {
    String? pdfUrl;
    if (widget.file != null) {
      // For local files, we'll show a message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fail tempatan tidak boleh dibuka di browser. Sila gunakan aplikasi PDF viewer.'),
          ),
        );
      }
      return;
    } else if (widget.url != null) {
      pdfUrl = widget.url;
    }

    if (pdfUrl != null) {
      try {
        final uri = Uri.parse(pdfUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ralat membuka PDF: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedPdf01,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_isLoading && !_hasError && _totalPages > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_currentPage/$_totalPages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _buildContent(),
            ),

            // Footer with controls
            if (!_isLoading && !_hasError && _totalPages > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _currentPage > 1
                          ? () {
                              setState(() {
                                _currentPage--;
                              });
                              _pdfController?.jumpToPage(_currentPage - 1);
                            }
                          : null,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Halaman $_currentPage dari $_totalPages',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _currentPage < _totalPages
                          ? () {
                              setState(() {
                                _currentPage++;
                              });
                              _pdfController?.jumpToPage(_currentPage - 1);
                            }
                          : null,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: _openInBrowser,
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedDownload01,
                        color: Colors.black,
                        size: 20,
                      ),
                      tooltip: 'Buka di Browser',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuatkan PDF...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ralat memuatkan PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Ralat tidak diketahui',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openInBrowser,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDownload01,
                color: Colors.white,
                size: 16,
              ),
              label: const Text('Buka di Browser'),
            ),
          ],
        ),
      );
    }

    if (_pdfController == null) {
      return const Center(
        child: Text('Tiada PDF untuk dipaparkan'),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: pdfx.PdfView(
        controller: _pdfController!,
        scrollDirection: Axis.vertical,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page + 1;
          });
        },
      ),
    );
  }
}

// =====================================================
// EPISODE DIALOG WIDGET
// =====================================================

class _EpisodeDialog extends StatefulWidget {
  final Map<String, dynamic>? episode;
  final Function({
    String? episodeId,
    required String title,
    required String youtubeVideoId,
    required int episodeNumber,
    String? thumbnailUrl,
    required bool isActive,
  })
  onSave;
  final int Function() getNextEpisodeNumber;
  final String Function(String) defaultThumbnailFor;
  final String? Function(String) extractYouTubeVideoId;

  const _EpisodeDialog({
    this.episode,
    required this.onSave,
    required this.getNextEpisodeNumber,
    required this.defaultThumbnailFor,
    required this.extractYouTubeVideoId,
  });

  @override
  State<_EpisodeDialog> createState() => _EpisodeDialogState();
}

class _EpisodeDialogState extends State<_EpisodeDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _youtubeUrlController;
  late final TextEditingController _thumbnailUrlController;

  String? _youtubeVideoId;
  // String? _previewTitle; // Not used in current implementation
  String? _previewThumbnailUrl;
  bool _isFetchingPreview = false;
  String? _urlErrorMessage;
  bool _useCustomThumbnail = false;
  Timer? _urlDebounce;

  late bool _isActive;
  late final bool _isEditMode;
  late final int _episodeNumber;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController();
    _youtubeUrlController = TextEditingController();
    _thumbnailUrlController = TextEditingController();

    _isActive = widget.episode?['is_active'] ?? true;
    _isEditMode = widget.episode != null;
    _episodeNumber = _isEditMode
        ? (widget.episode!['part_number'] as int? ?? 1)
        : widget.getNextEpisodeNumber();

    // Initialize for edit mode
    if (_isEditMode) {
      _titleController.text = widget.episode!['title'] ?? '';
      if (widget.episode!['youtube_video_id'] != null) {
        _youtubeVideoId = widget.episode!['youtube_video_id'];
        _youtubeUrlController.text =
            'https://www.youtube.com/watch?v=$_youtubeVideoId';

        final existingThumbnailUrl = widget.episode!['thumbnail_url'];
        final defaultThumbnailUrl = widget.defaultThumbnailFor(
          _youtubeVideoId!,
        );

        if (existingThumbnailUrl != null &&
            existingThumbnailUrl != defaultThumbnailUrl) {
          _useCustomThumbnail = true;
          _thumbnailUrlController.text = existingThumbnailUrl;
          _previewThumbnailUrl = existingThumbnailUrl;
        } else {
          _previewThumbnailUrl = defaultThumbnailUrl;
        }
      }
    }
  }

  @override
  void dispose() {
    _urlDebounce?.cancel();
    _titleController.dispose();
    _youtubeUrlController.dispose();
    _thumbnailUrlController.dispose();
    super.dispose();
  }

  void _fetchPreview() {
    _urlDebounce?.cancel();
    _urlDebounce = Timer(const Duration(milliseconds: 600), () async {
      final url = _youtubeUrlController.text.trim();
      if (url.isEmpty) return;

      setState(() {
        _urlErrorMessage = null;
        _isFetchingPreview = true;
      });

      final id = widget.extractYouTubeVideoId(url);
      if (id == null) {
        setState(() {
          _urlErrorMessage = 'Sila masukkan URL YouTube yang sah';
          _isFetchingPreview = false;
          _youtubeVideoId = null;
          _previewThumbnailUrl = null;
        });
        return;
      }

      setState(() {
        _youtubeVideoId = id;
        // _previewTitle = 'Video YouTube'; // Not used in current UI

        // Use custom thumbnail if provided, otherwise use default
        if (_useCustomThumbnail &&
            _thumbnailUrlController.text.trim().isNotEmpty) {
          _previewThumbnailUrl = _thumbnailUrlController.text.trim();
        } else {
          _previewThumbnailUrl = widget.defaultThumbnailFor(id);
        }

        _isFetchingPreview = false;
        _urlErrorMessage = null;
      });
    });
  }

  void _onThumbnailUrlChanged() {
    if (!_useCustomThumbnail) return;

    final url = _thumbnailUrlController.text.trim();
    setState(() {
      if (url.isNotEmpty && _youtubeVideoId != null) {
        _previewThumbnailUrl = url;
      } else if (_youtubeVideoId != null) {
        _previewThumbnailUrl = widget.defaultThumbnailFor(_youtubeVideoId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Edit Episode' : 'Tambah Episode'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Episode Number Display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedTextNumberSign,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Episode $_episodeNumber',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // YouTube URL Field
              TextFormField(
                controller: _youtubeUrlController,
                decoration: InputDecoration(
                  labelText: 'URL Video YouTube *',
                  hintText:
                      'Tampal URL penuh, contoh: https://www.youtube.com/watch?v=...',
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedLink01,
                    color: Colors.grey,
                  ),
                  border: const OutlineInputBorder(),
                  errorText: _urlErrorMessage,
                ),
                maxLines: 2,
                onChanged: (value) => _fetchPreview(),
                onFieldSubmitted: (value) {
                  _urlDebounce?.cancel();
                  _fetchPreview();
                },
              ),
              const SizedBox(height: 16),

              // Preview Section
              if (_isFetchingPreview) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Mendapatkan maklumat video...'),
                    ],
                  ),
                ),
              ] else if (_youtubeVideoId != null &&
                  _previewThumbnailUrl != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          _previewThumbnailUrl!,
                          width: 80,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(
                                HugeIcons.strokeRoundedImageNotFound01,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Video ID: $_youtubeVideoId',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Episode $_episodeNumber',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final url =
                              'https://www.youtube.com/watch?v=$_youtubeVideoId';
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url));
                          }
                        },
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowUpRight01,
                          color: Colors.blue,
                        ),
                        tooltip: 'Buka di YouTube',
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tajuk Episode *',
                  hintText: 'Contoh: Bab 1 - Pengenalan Fiqh',
                  prefixIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedAlignLeft,
                    color: Colors.grey,
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Thumbnail URL Section
              SwitchListTile(
                title: const Text('Gunakan URL Thumbnail Sendiri'),
                subtitle: const Text(
                  'Jika tidak, akan guna thumbnail default YouTube',
                ),
                value: _useCustomThumbnail,
                onChanged: (value) {
                  setState(() {
                    _useCustomThumbnail = value;
                    if (!value) {
                      _thumbnailUrlController.clear();
                      if (_youtubeVideoId != null) {
                        _previewThumbnailUrl = widget.defaultThumbnailFor(
                          _youtubeVideoId!,
                        );
                      }
                    } else {
                      _onThumbnailUrlChanged();
                    }
                  });
                },
              ),
              if (_useCustomThumbnail) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _thumbnailUrlController,
                  decoration: const InputDecoration(
                    labelText: 'URL Thumbnail',
                    hintText: 'https://example.com/thumbnail.jpg',
                    prefixIcon: HugeIcon(
                      icon: HugeIcons.strokeRoundedImage01,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _onThumbnailUrlChanged(),
                ),
              ],
              const SizedBox(height: 16),

              // Settings
              SwitchListTile(
                title: const Text('Episode Aktif'),
                subtitle: const Text('Boleh dilihat oleh pengguna'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed:
              (_youtubeVideoId != null &&
                  _titleController.text.trim().isNotEmpty &&
                  !_isFetchingPreview)
              ? () {
                  final finalThumbnailUrl =
                      _useCustomThumbnail &&
                          _thumbnailUrlController.text.trim().isNotEmpty
                      ? _thumbnailUrlController.text.trim()
                      : _previewThumbnailUrl;

                  widget.onSave(
                    episodeId: widget.episode?['id'],
                    title: _titleController.text.trim(),
                    youtubeVideoId: _youtubeVideoId!,
                    episodeNumber: _episodeNumber,
                    thumbnailUrl: finalThumbnailUrl,
                    isActive: _isActive,
                  );
                  Navigator.pop(context);
                }
              : null,
          child: Text(_isEditMode ? 'Kemaskini' : 'Tambah'),
        ),
      ],
    );
  }
}
