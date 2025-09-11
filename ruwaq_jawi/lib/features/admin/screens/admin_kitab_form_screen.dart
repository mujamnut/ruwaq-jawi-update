import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/admin_category_service.dart';
import '../../../core/services/admin_kitab_service.dart';
import '../../../core/services/admin_video_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

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
  final _sortOrderController = TextEditingController();

  late AdminCategoryService _categoryService;
  late AdminKitabService _kitabService;
  late AdminVideoService _videoService;
  late TabController _tabController;

  bool _isPremium = true;
  bool _isActive = true;
  bool _isEbookAvailable = false;
  bool _isLoading = false;
  String? _selectedCategoryId;
  String? _thumbnailUrl;
  String? _pdfUrl;
  File? _selectedThumbnail;
  File? _selectedPdf;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _episodes = [];

  bool get _isEditing => widget.kitabId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _categoryService = AdminCategoryService(SupabaseService.client);
    _kitabService = AdminKitabService(SupabaseService.client);
    _videoService = AdminVideoService(SupabaseService.client);

    _loadInitialData();
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
      _sortOrderController.text = (data['sort_order'] ?? '').toString();
      _selectedCategoryId = data['category_id'];
      _isPremium = data['is_premium'] ?? true;
      _isActive = data['is_active'] ?? true;
      _isEbookAvailable = data['is_ebook_available'] ?? false;
      _thumbnailUrl = data['thumbnail_url'];
      _pdfUrl = data['pdf_url'];

      // Load episodes jika ada
      if (widget.kitabId != null) {
        await _loadEpisodes();
      }
    }
  }

  Future<void> _loadEpisodes() async {
    try {
      final episodes = await _videoService.getKitabEpisodes(
        kitabId: widget.kitabId!,
        orderBy: 'part_number',
        ascending: true,
      );
      setState(() {
        _episodes = episodes;
      });
    } catch (e) {
      _showSnackBar('Ralat memuatkan episodes: ${e.toString()}', isError: true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _totalPagesController.dispose();
    _sortOrderController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // =====================================================
  // YOUTUBE URL PARSING HELPERS
  // =====================================================

  /// Extract YouTube video ID from various URL formats
  String? _extractYouTubeVideoId(String input) {
    final trimmed = input.trim();

    // Check if already a video ID (11 characters, alphanumeric + - and _)
    final idRegex = RegExp(r'^[0-9A-Za-z_-]{11}$');
    if (idRegex.hasMatch(trimmed)) return trimmed;

    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return null;
    }

    if (uri == null || uri.host.isEmpty) return null;

    final host = uri.host.replaceFirst('www.', '');
    final segs = uri.pathSegments;

    // youtu.be/VIDEO_ID format
    if (host == 'youtu.be') {
      return segs.isNotEmpty ? segs.first : null;
    }

    // youtube.com formats
    if (host.endsWith('youtube.com') || host.endsWith('youtube-nocookie.com')) {
      // Watch URL: /watch?v=VIDEO_ID
      if (uri.path == '/watch' && uri.queryParameters.containsKey('v')) {
        return uri.queryParameters['v'];
      }

      // Embed/shorts/live: /embed/VIDEO_ID, /shorts/VIDEO_ID, /live/VIDEO_ID
      if (segs.length >= 2 &&
          (segs[0] == 'embed' ||
              segs[0] == 'shorts' ||
              segs[0] == 'live' ||
              segs[0] == 'v')) {
        return segs[1];
      }
    }

    return null;
  }

  /// Check if input looks like a YouTube URL or ID
  bool _isLikelyYouTubeUrl(String input) {
    final id = _extractYouTubeVideoId(input);
    return id != null;
  }

  /// Generate default YouTube thumbnail URL
  String _defaultThumbnailFor(String id) =>
      'https://img.youtube.com/vi/$id/hqdefault.jpg';

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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? thumbnailUrl = _thumbnailUrl;
      String? pdfUrl = _pdfUrl;
      String? pdfStoragePath;
      int? pdfFileSize;

      Map<String, dynamic> result;

      if (_isEditing) {
        // Update existing kitab
        result = await _kitabService.updateKitab(
          kitabId: widget.kitabId!,
          title: _titleController.text.trim(),
          author: _authorController.text.trim().isEmpty
              ? null
              : _authorController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          categoryId: _selectedCategoryId,
          thumbnailUrl: thumbnailUrl,
          isPremium: _isPremium,
          isActive: _isActive,
          isEbookAvailable: _isEbookAvailable,
          totalPages: int.tryParse(_totalPagesController.text),
          sortOrder: int.tryParse(_sortOrderController.text),
        );

        _showSnackBar('Kitab berjaya dikemaskini!');
      } else {
        // Create new kitab
        result = await _kitabService.createKitab(
          title: _titleController.text.trim(),
          author: _authorController.text.trim().isEmpty
              ? null
              : _authorController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          categoryId: _selectedCategoryId,
          thumbnailUrl: thumbnailUrl,
          isPremium: _isPremium,
          isActive: _isActive,
          isEbookAvailable: _isEbookAvailable,
          totalPages: int.tryParse(_totalPagesController.text),
          sortOrder: int.tryParse(_sortOrderController.text),
        );

        _showSnackBar('Kitab berjaya ditambah!');
      }

      final kitabId = result['id'] as String;

      // Upload files if selected
      if (_selectedThumbnail != null) {
        thumbnailUrl = await _kitabService.uploadKitabThumbnail(
          _selectedThumbnail!,
          kitabId,
        );
        await _kitabService.updateKitab(
          kitabId: kitabId,
          thumbnailUrl: thumbnailUrl,
        );
      }

      if (_selectedPdf != null) {
        pdfUrl = await _kitabService.uploadKitabPDF(_selectedPdf!, kitabId);
      }

      // Navigate back with success result
      Navigator.pop(context, result);
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
        title: Text(_isEditing ? 'Edit Kitab' : 'Tambah Kitab'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.textLightColor,
          labelColor: AppTheme.textLightColor,
          unselectedLabelColor: AppTheme.textLightColor.withOpacity(0.7),
          tabs: const [
            Tab(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: Colors.grey),
              text: 'Maklumat',
            ),
            Tab(icon: HugeIcon(icon: HugeIcons.strokeRoundedPdf01, color: Colors.grey), text: 'Fail'),
            Tab(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedVideo01, color: Colors.grey),
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

          // Sort Order
          _buildTextFormField(
            controller: _sortOrderController,
            label: 'Susunan',
            hint: 'Nombor untuk urutan paparan',
            icon: HugeIcons.strokeRoundedSortingAZ01,
            keyboardType: TextInputType.number,
          ),
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
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedPlusSign, color: Colors.white),
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
          child: _episodes.isEmpty
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
      value: _selectedCategoryId,
      decoration: InputDecoration(
        labelText: 'Kategori',
        prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedGrid, color: Colors.grey),
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
        _buildToggle(
          title: 'E-book Tersedia',
          subtitle: _isEbookAvailable
              ? 'Kitab boleh dibaca dalam format PDF'
              : 'Hanya video tersedia',
          value: _isEbookAvailable,
          onChanged: (value) => setState(() => _isEbookAvailable = value),
          icon: _isEbookAvailable
              ? HugeIcons.strokeRoundedPdf01
              : HugeIcons.strokeRoundedVideo01,
        ),
        const SizedBox(height: 16),
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
            activeColor: AppTheme.primaryColor,
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
            height: isImage ? 200 : 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: _buildFileDisplay(currentFile, selectedFile, isImage),
          ),
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
                height: 120,
                width: 120,
                fit: BoxFit.cover,
              ),
            )
          else
            const Icon(
              HugeIcons.strokeRoundedPdf01,
              size: 48.0,
              color: Colors.red,
            ),
          const SizedBox(height: 8),
          Text(
            selectedFile.path.split('/').last,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
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
                height: 120,
                width: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    HugeIcons.strokeRoundedImageNotFound01,
                    size: 48.0,
                  );
                },
              ),
            )
          else
            const Icon(
              HugeIcons.strokeRoundedPdf01,
              size: 48.0,
              color: Colors.red,
            ),
          const SizedBox(height: 8),
          Text(
            isImage ? 'Thumbnail sedia ada' : 'PDF sedia ada',
            style: Theme.of(context).textTheme.bodySmall,
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
            size: 48.0,
            color: Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            isImage ? 'Ketuk untuk pilih thumbnail' : 'Ketuk untuk pilih PDF',
            style: const TextStyle(color: Colors.grey),
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
                  : const HugeIcon(icon: HugeIcons.strokeRoundedVideo01, size: 40, color: Colors.grey),
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

                  // Status Badges
                  Wrap(
                    spacing: 8,
                    children: [
                      if (episode['is_preview'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            'PREVIEW',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color:
                                (episode['is_active'] == true
                                        ? Colors.green
                                        : Colors.grey)
                                    .withOpacity(0.3),
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
                        leading: HugeIcon(icon: HugeIcons.strokeRoundedEdit01, color: Colors.blue),
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
        extractYouTubeVideoId: _extractYouTubeVideoId,
      ),
    );
  }

  Future<void> _saveEpisodeFromDialog({
    String? episodeId,
    required String title,
    required String youtubeVideoId,
    required int episodeNumber,
    String? thumbnailUrl,
    required bool isPreview,
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
        await _videoService.addEpisode(
          kitabId: widget.kitabId!,
          title: title,
          youtubeVideoId: youtubeVideoId,
          partNumber: episodeNumber,
          youtubeVideoUrl: youtubeUrl,
          thumbnailUrl: finalThumbnailUrl,
          isPreview: isPreview,
          isActive: isActive,
        );
        _showSnackBar('Episode berjaya ditambah!');
      } else {
        // Update existing episode
        await _videoService.updateEpisode(
          episodeId: episodeId,
          title: title,
          youtubeVideoId: youtubeVideoId,
          youtubeVideoUrl: youtubeUrl,
          thumbnailUrl: finalThumbnailUrl,
          partNumber: episodeNumber,
          isPreview: isPreview,
          isActive: isActive,
        );
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
        await _videoService.deleteEpisode(episodeId);
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
      final episodeIds = _episodes.map((e) => e['id'] as String).toList();
      _videoService.reorderEpisodes(widget.kitabId!, episodeIds);
    }
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
    required bool isPreview,
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
  String? _previewTitle;
  String? _previewThumbnailUrl;
  bool _isFetchingPreview = false;
  String? _urlErrorMessage;
  bool _useCustomThumbnail = false;
  Timer? _urlDebounce;

  late bool _isPreview;
  late bool _isActive;
  late final bool _isEditMode;
  late final int _episodeNumber;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController();
    _youtubeUrlController = TextEditingController();
    _thumbnailUrlController = TextEditingController();

    _isPreview = widget.episode?['is_preview'] ?? false;
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
          _previewTitle = null;
          _previewThumbnailUrl = null;
        });
        return;
      }

      setState(() {
        _youtubeVideoId = id;
        _previewTitle = 'Video YouTube';

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
                  prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedLink01, color: Colors.grey),
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
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
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
                        icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowUpRight01, color: Colors.blue),
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
                  prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedAlignLeft, color: Colors.grey),
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
                    prefixIcon: HugeIcon(icon: HugeIcons.strokeRoundedImage01, color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _onThumbnailUrlChanged(),
                ),
              ],
              const SizedBox(height: 16),

              // Settings
              SwitchListTile(
                title: const Text('Episode Preview'),
                subtitle: const Text('Boleh ditonton tanpa langganan'),
                value: _isPreview,
                onChanged: (value) => setState(() => _isPreview = value),
              ),
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
                    isPreview: _isPreview,
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
