import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../../../../core/models/video_kitab.dart';
import '../../../../core/services/admin_category_service.dart';
import '../../../../core/services/video_kitab_service.dart';
import '../../../../core/services/video_episode_service.dart';
import '../../../../core/models/video_episode.dart';
import '../../../../core/models/preview_models.dart';
import 'episode_form_screen.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/preview_service.dart';
import '../../../../core/theme/app_theme.dart';

class AdminVideoKitabFormScreen extends StatefulWidget {
  final String? videoKitabId; // null untuk tambah baru
  final VideoKitab? videoKitab; // data untuk edit

  const AdminVideoKitabFormScreen({
    super.key,
    this.videoKitabId,
    this.videoKitab,
  });

  @override
  State<AdminVideoKitabFormScreen> createState() =>
      _AdminVideoKitabFormScreenState();
}

class _AdminVideoKitabFormScreenState extends State<AdminVideoKitabFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalPagesController = TextEditingController();

  late AdminCategoryService _categoryService;
  late TabController _tabController;

  bool _isPremium = true;
  bool _isActive = true;
  bool _isLoading = false;
  String? _selectedCategoryId;
  String? _thumbnailUrl;
  String? _pdfUrl;
  File? _selectedThumbnail;
  File? _selectedPdf;

  List<Map<String, dynamic>> _categories = [];
  List<VideoEpisode> _episodes = [];

  // Preview tracking
  Map<String, bool> _episodePreviewStatus =
      {}; // Track which episodes have previews
  final Set<String> _episodesWithPreviewChanges =
      {}; // Track which episodes had preview changes

  // Track the current video kitab ID (can be updated when creating new kitab)
  String? _currentVideoKitabId;

  bool get _isEditing => widget.videoKitabId != null;
  String? get _effectiveVideoKitabId =>
      _currentVideoKitabId ?? widget.videoKitabId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _categoryService = AdminCategoryService(SupabaseService.client);

    // Initialize current video kitab ID
    _currentVideoKitabId = widget.videoKitabId;

    _checkAdminAccess();
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
    await Future.wait([
      _loadCategories(),
      if (_isEditing) _loadVideoKitabData(),
    ]);
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

  Future<void> _loadVideoKitabData() async {
    if (widget.videoKitab != null) {
      final data = widget.videoKitab!;
      _titleController.text = data.title;
      _authorController.text = data.author ?? '';
      _descriptionController.text = data.description ?? '';
      _totalPagesController.text = data.totalPages?.toString() ?? '';
      _selectedCategoryId = data.categoryId;
      _isPremium = data.isPremium;
      _isActive = data.isActive;
      _thumbnailUrl = data.thumbnailUrl;
      _pdfUrl = data.pdfUrl;

      // Load episodes jika ada
      if (widget.videoKitabId != null) {
        await _loadEpisodes();
      }
    }
  }

  Future<void> _loadEpisodes() async {
    final videoKitabId = _effectiveVideoKitabId;
    if (videoKitabId == null) {
      setState(() {
        _episodes = [];
      });
      return;
    }

    try {
      final episodes = await VideoEpisodeService.getEpisodesForVideoKitab(
        videoKitabId,
        orderBy: 'part_number',
        ascending: true,
      );

      // Load preview status for each episode
      final Map<String, bool> previewStatus = {};
      for (final episode in episodes) {
        try {
          final hasPreview = await PreviewService.hasPreview(
            contentType: PreviewContentType.videoEpisode,
            contentId: episode.id,
          );
          previewStatus[episode.id] = hasPreview;
        } catch (e) {
          previewStatus[episode.id] = false;
        }
      }

      setState(() {
        _episodes = episodes;
        _episodePreviewStatus = previewStatus;
      });
    } catch (e) {
      // Don't show error for episodes - just log it
      setState(() {
        _episodes = [];
        _episodePreviewStatus.clear();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _totalPagesController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // =====================================================
  // PREVIEW MANAGEMENT METHODS
  // =====================================================

  /// Toggle preview status for an episode
  Future<void> _toggleEpisodePreview(
    VideoEpisode episode,
    bool isPreview,
  ) async {
    try {
      if (isPreview) {
        // Create preview
        await PreviewService.createPreview(
          PreviewConfig(
            contentType: PreviewContentType.videoEpisode,
            contentId: episode.id,
            previewType: PreviewType.freeTrial,
            previewDescription: 'Preview episode for ${episode.title}',
            isActive: true,
          ),
        );
        _showSnackBar('Preview diaktifkan untuk ${episode.title}');
      } else {
        // Remove preview - get existing preview and delete it
        final previews = await PreviewService.getPreviewForContent(
          contentType: PreviewContentType.videoEpisode,
          contentId: episode.id,
          onlyActive: false,
        );

        for (final preview in previews) {
          await PreviewService.deletePreview(preview.id);
        }
        _showSnackBar('Preview dinyahaktifkan untuk ${episode.title}');
      }

      // Update local state
      setState(() {
        _episodePreviewStatus[episode.id] = isPreview;
        _episodesWithPreviewChanges.add(episode.id);
      });
    } catch (e) {
      _showSnackBar('Ralat mengemas kini preview: $e', isError: true);
    }
  }

  // =====================================================
  // HELPER METHODS
  // =====================================================

  // PDF helper methods
  Future<void> _detectPdfPageCount(File pdfFile) async {
    try {
      // Use pdfx package to read PDF and get page count
      final document = await pdfx.PdfDocument.openFile(pdfFile.path);
      final pageCount = document.pagesCount;

      setState(() {
        _totalPagesController.text = pageCount.toString();
      });

      _showSnackBar('Jumlah halaman PDF: $pageCount', isError: false);

      // Close the document to free memory
      await document.close();
    } catch (e) {
      _showSnackBar(
        'Tidak dapat mengira halaman PDF secara automatik. Sila masukkan secara manual.',
        isError: false,
      );
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
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppTheme.textPrimaryColor,
            size: 24.0,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Video Kitab' : 'Tambah Video Kitab Baru',
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textPrimaryColor),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _currentVideoKitabId != null && !_isEditing
                  ? () => Navigator.of(context).pop(true)
                  : _saveVideoKitab,
              child: Text(
                _currentVideoKitabId != null && !_isEditing
                    ? 'Selesai'
                    : (_isEditing ? 'Kemaskini' : 'Simpan'),
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              text: 'Maklumat Asas',
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                color: Colors.grey,
              ),
            ),
            Tab(
              text: 'Media',
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                color: Colors.grey,
              ),
            ),
            Tab(
              text: 'Episode',
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedVideo01,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildBasicInfoTab(), _buildMediaTab(), _buildEpisodeTab()],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Field
            _buildSectionTitle('Maklumat Asas'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tajuk Video Kitab *',
                border: OutlineInputBorder(),
                prefixIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedAlignLeft,
                  color: Colors.grey,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tajuk tidak boleh kosong';
                }
                return null;
              },
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Author Field
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

            // Category Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Kategori *',
                border: OutlineInputBorder(),
                prefixIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedGrid,
                  color: Colors.grey,
                ),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category['id'] as String,
                  child: Text(category['name'] as String),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Sila pilih kategori';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description Field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Penerangan',
                border: OutlineInputBorder(),
                prefixIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedFile01,
                  color: Colors.grey,
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Settings Section
            _buildSectionTitle('Tetapan'),
            const SizedBox(height: 16),

            // Premium Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedStar,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Premium',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _isPremium
                              ? 'Video kitab premium'
                              : 'Video kitab percuma',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPremium,
                    onChanged: (value) {
                      setState(() {
                        _isPremium = value;
                      });
                    },
                    activeThumbColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isActive
                        ? HugeIcons.strokeRoundedView
                        : HugeIcons.strokeRoundedViewOff,
                    color: _isActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Aktif',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _isActive
                              ? 'Ditunjukkan kepada pengguna'
                              : 'Tersembunyi dari pengguna',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                    activeThumbColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail Section
          _buildSectionTitle('Gambar Kecil'),
          const SizedBox(height: 16),
          _buildThumbnailSection(),
          const SizedBox(height: 24),

          // PDF Section
          _buildSectionTitle('Dokumen PDF'),
          const SizedBox(height: 16),
          _buildPdfSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEpisodeTab() {
    return Column(
      children: [
        // Episode List Header with Preview Summary
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Episode Video (${_episodes.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _effectiveVideoKitabId != null
                        ? _addNewEpisode
                        : null,
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
              if (_episodes.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildPreviewSummary(),
              ],
            ],
          ),
        ),

        // Episodes List
        Expanded(
          child: _episodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        HugeIcons.strokeRoundedVideo01,
                        size: 64.0,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _effectiveVideoKitabId != null
                            ? 'Belum ada episode video.\nTambah episode untuk video kitab ini.'
                            : 'Simpan video kitab terlebih dahulu\nuntuk menambah episode.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _episodes.length,
                  itemBuilder: (context, index) {
                    final episode = _episodes[index];
                    return _buildEpisodeCard(episode, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildThumbnailSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                'Gambar Kecil Video Kitab',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current thumbnail preview
          if (_selectedThumbnail != null || _thumbnailUrl != null) ...[
            Container(
              height: 120,
              width: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _selectedThumbnail != null
                    ? Image.file(_selectedThumbnail!, fit: BoxFit.cover)
                    : (_thumbnailUrl != null
                          ? Image.network(_thumbnailUrl!, fit: BoxFit.cover)
                          : const HugeIcon(
                              icon: HugeIcons.strokeRoundedImage01,
                              size: 48,
                              color: Colors.grey,
                            )),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Upload buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickThumbnailImage,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedUpload01,
                  color: Colors.white,
                ),
                label: const Text('Pilih Gambar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_selectedThumbnail != null || _thumbnailUrl != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _removeThumbnail,
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete01,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Buang',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPdfSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedPdf01,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'Dokumen PDF',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_selectedPdf != null || _pdfUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedPdf01,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPdf?.path.split('/').last ?? 'PDF tersedia',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_totalPagesController.text.isNotEmpty)
                          Text('${_totalPagesController.text} halaman'),
                      ],
                    ),
                  ),
                  if (_pdfUrl != null)
                    TextButton(onPressed: _openPdf, child: const Text('Lihat')),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Total Pages Field
          TextFormField(
            controller: _totalPagesController,
            decoration: const InputDecoration(
              labelText: 'Jumlah Halaman PDF',
              border: OutlineInputBorder(),
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedFile01,
                color: Colors.grey,
              ),
              hintText: 'Auto-dikesan apabila PDF dipilih',
              helperText:
                  'Akan cuba mengesan bilangan halaman secara automatik',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final intValue = int.tryParse(value);
                if (intValue == null) {
                  return 'Sila masukkan nombor yang sah';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Upload buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickPdfFile,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedUpload01,
                  color: Colors.white,
                ),
                label: const Text('Pilih PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_selectedPdf != null || _pdfUrl != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _removePdf,
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete01,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Buang',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(VideoEpisode episode, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: episode.isActive
              ? AppTheme.primaryColor
              : Colors.grey,
          child: Text(
            episode.partNumber.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          episode.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: episode.isActive
                ? AppTheme.textPrimaryColor
                : AppTheme.textSecondaryColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${episode.durationMinutes} minit${episode.isActive ? '' : ' • Tidak aktif'}',
            ),
            const SizedBox(height: 8),
            // Preview Toggle Row
            Row(
              children: [
                Switch(
                  value: _episodePreviewStatus[episode.id] ?? false,
                  onChanged: (value) => _toggleEpisodePreview(episode, value),
                  activeThumbColor: AppTheme.primaryColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Text(
                  'Preview Episode',
                  style: TextStyle(
                    fontSize: 13,
                    color: (_episodePreviewStatus[episode.id] ?? false)
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                    fontWeight: (_episodePreviewStatus[episode.id] ?? false)
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                if (_episodePreviewStatus[episode.id] ?? false) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PREVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedPlayCircle,
                color: Colors.blue,
              ),
              onPressed: () => _previewEpisode(episode),
              tooltip: 'Preview video',
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleEpisodeAction(episode, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedEdit01,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: episode.isActive ? 'deactivate' : 'activate',
                  child: Row(
                    children: [
                      Icon(
                        episode.isActive
                            ? HugeIcons.strokeRoundedViewOff
                            : HugeIcons.strokeRoundedView,
                      ),
                      SizedBox(width: 8),
                      Text(episode.isActive ? 'Nyahaktif' : 'Aktifkan'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
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
    );
  }

  void _previewEpisode(VideoEpisode episode) async {
    final youtubeUrl = VideoEpisodeService.getYouTubeWatchUrl(
      episode.youtubeVideoId,
    );
    final uri = Uri.parse(youtubeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Tidak dapat membuka video YouTube', isError: true);
    }
  }

  // =====================================================
  // FILE PICKER METHODS
  // =====================================================

  Future<void> _pickThumbnailImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 600,
      );

      if (image != null) {
        setState(() {
          _selectedThumbnail = File(image.path);
          _thumbnailUrl = null; // Clear existing URL when new file is selected
        });
      }
    } catch (e) {
      _showSnackBar('Ralat memilih gambar: $e', isError: true);
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final pdfFile = File(result.files.single.path!);
        setState(() {
          _selectedPdf = pdfFile;
          _pdfUrl = null; // Clear existing URL when new file is selected
        });

        // Auto-detect PDF page count
        await _detectPdfPageCount(pdfFile);
      }
    } catch (e) {
      _showSnackBar('Ralat memilih PDF: ${e.toString()}', isError: true);
    }
  }

  void _removeThumbnail() {
    setState(() {
      _selectedThumbnail = null;
      _thumbnailUrl = null;
    });
  }

  void _removePdf() {
    setState(() {
      _selectedPdf = null;
      _pdfUrl = null;
    });
  }

  Future<void> _openPdf() async {
    if (_pdfUrl != null) {
      final uri = Uri.parse(_pdfUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  // =====================================================
  // EPISODE MANAGEMENT METHODS
  // =====================================================

  void _addNewEpisode() {
    final videoKitabId = _effectiveVideoKitabId;
    if (videoKitabId == null) {
      _showSnackBar(
        'Sila simpan video kitab terlebih dahulu sebelum menambah episode',
        isError: true,
      );
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => AdminEpisodeFormScreen(
              videoKitabId: videoKitabId,
              videoKitabTitle: _titleController.text.trim().isEmpty
                  ? 'Video Kitab'
                  : _titleController.text.trim(),
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            _loadEpisodes(); // Refresh episodes list
          }
        });
  }

  void _handleEpisodeAction(VideoEpisode episode, String action) async {
    switch (action) {
      case 'edit':
        final videoKitabId = _effectiveVideoKitabId;
        if (videoKitabId == null) return;

        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => AdminEpisodeFormScreen(
                  videoKitabId: videoKitabId,
                  episode: episode,
                  videoKitabTitle: _titleController.text.trim().isEmpty
                      ? 'Video Kitab'
                      : _titleController.text.trim(),
                ),
              ),
            )
            .then((result) {
              if (result == true) {
                _loadEpisodes();
              }
            });
        break;
      case 'activate':
      case 'deactivate':
        try {
          await VideoEpisodeService.toggleEpisodeStatus(
            episode.id,
            !episode.isActive,
          );
          _showSnackBar('Status episode berjaya dikemaskini');
          _loadEpisodes();
        } catch (e) {
          _showSnackBar('Ralat mengemas kini status: $e', isError: true);
        }
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Padam Episode'),
            content: Text(
              'Adakah anda pasti untuk memadam episode "${episode.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Padam'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            await VideoEpisodeService.deleteEpisode(episode.id);
            _showSnackBar('Episode berjaya dipadam');
            _loadEpisodes();
          } catch (e) {
            _showSnackBar('Ralat memadam episode: $e', isError: true);
          }
        }
        break;
    }
  }

  // =====================================================
  // SAVE METHODS
  // =====================================================

  Future<void> _saveVideoKitab() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0); // Go to basic info tab
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload files if selected
      String? uploadedThumbnailUrl = _thumbnailUrl;
      String? uploadedPdfUrl = _pdfUrl;
      String? uploadedPdfStoragePath;
      int? uploadedPdfFileSize;


      // Upload thumbnail if new file selected
      if (_selectedThumbnail != null) {
        try {
          final fileName =
              'video_kitab_thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final storagePath = 'thumbnails/$fileName';

          await SupabaseService.client.storage
              .from('video-kitab-files')
              .upload(storagePath, _selectedThumbnail!);

          uploadedThumbnailUrl = SupabaseService.client.storage
              .from('video-kitab-files')
              .getPublicUrl(storagePath);
        } catch (e) {
          _showSnackBar('Ralat upload thumbnail: $e', isError: true);
          // Don't stop execution - continue with PDF upload
        }
      }

      // Upload PDF if new file selected
      if (_selectedPdf != null) {
        try {
          final fileName =
              'video_kitab_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final storagePath = 'pdfs/$fileName';

          await SupabaseService.client.storage
              .from('video-kitab-files')
              .upload(storagePath, _selectedPdf!);

          uploadedPdfUrl = SupabaseService.client.storage
              .from('video-kitab-files')
              .getPublicUrl(storagePath);
          uploadedPdfStoragePath = storagePath;
          uploadedPdfFileSize = await _selectedPdf!.length();
        } catch (e) {
          _showSnackBar('Ralat upload PDF: $e', isError: true);
          // Don't stop execution - continue with save
        }
      }

      final videoKitabData = {
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'category_id': _selectedCategoryId,
        'thumbnail_url': uploadedThumbnailUrl,
        'pdf_url': uploadedPdfUrl,
        'pdf_storage_path': uploadedPdfStoragePath,
        'pdf_file_size': uploadedPdfFileSize,
        'total_pages': _totalPagesController.text.trim().isEmpty
            ? null
            : int.tryParse(_totalPagesController.text.trim()),
        'is_premium': _isPremium,
        'is_active': _isActive,
      };

      if (_isEditing) {
        // Update existing video kitab
        await VideoKitabService.updateVideoKitabAdmin(
          widget.videoKitabId!,
          videoKitabData,
        );
        _showSnackBar('Video Kitab berjaya dikemaskini!');
      } else {
        // Create new video kitab
        final createdVideoKitab = await VideoKitabService.createVideoKitab(
          videoKitabData,
        );

        // Update our state with the new video kitab ID so episodes can be managed
        setState(() {
          _currentVideoKitabId = createdVideoKitab.id;
        });

        _showSnackBar(
          'Video Kitab baru berjaya ditambah! Anda kini boleh menambah episode.',
        );

        // Don't pop immediately for new video kitabs - allow user to add episodes
        return;
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      _showSnackBar(
        'Ralat menyimpan video kitab: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildPreviewSummary() {
    final totalEpisodes = _episodes.length;
    final previewEpisodes = _episodePreviewStatus.values
        .where((hasPreview) => hasPreview)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedEye,
            color: AppTheme.primaryColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Pratonton: $previewEpisodes/$totalEpisodes episode',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (previewEpisodes > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$previewEpisodes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
