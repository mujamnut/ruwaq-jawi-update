import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/kitab.dart';
import '../../../core/models/preview_models.dart';
import '../../../core/services/video_kitab_service.dart';
import '../../../core/services/video_episode_service.dart';
import '../../../core/services/preview_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminKitabDetailScreen extends StatefulWidget {
  final String kitabId;

  const AdminKitabDetailScreen({super.key, required this.kitabId});

  @override
  State<AdminKitabDetailScreen> createState() => _AdminKitabDetailScreenState();
}

class _AdminKitabDetailScreenState extends State<AdminKitabDetailScreen> {
  // Using static methods from VideoKitabService and VideoEpisodeService

  Kitab? _kitab;
  String? _previewVideoId;
  List<Map<String, dynamic>> _episodes = [];
  final Map<String, bool> _episodePreviewStatus =
      {}; // Track which episodes have previews

  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers untuk preview video
  final _previewUrlController = TextEditingController();

  // Controllers untuk episodes (dynamic list)
  final List<TextEditingController> _episodeControllers = [];
  final List<bool> _episodePremiumFlags = [];

  @override
  void initState() {
    super.initState();
    // Services are now static methods
    _loadKitabDetail();
  }

  @override
  void dispose() {
    _previewUrlController.dispose();
    for (final controller in _episodeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadKitabDetail() async {
    try {
      setState(() => _isLoading = true);

      // Load kitab data
      final videoKitab = await VideoKitabService.getVideoKitabById(
        widget.kitabId,
      );
      if (videoKitab == null) {
        throw Exception('Kitab tidak dijumpai');
      }
      _kitab = Kitab.fromJson(videoKitab.toJson());

      // Load preview video
      if (_kitab?.youtubeVideoUrl != null) {
        _previewUrlController.text = _kitab!.youtubeVideoUrl!;
        _previewVideoId = _kitab!.youtubeVideoId;
      }

      // Load episodes
      final episodesList = await VideoEpisodeService.getEpisodesForVideoKitab(
        widget.kitabId,
        orderBy: 'part_number',
        ascending: true,
      );
      _episodes = episodesList.map((e) => e.toJson()).toList();

      // Setup episode controllers
      await _setupEpisodeControllers();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Ralat memuat data: ${e.toString()}', isError: true);
    }
  }

  Future<void> _setupEpisodeControllers() async {
    // Clear existing controllers
    for (final controller in _episodeControllers) {
      controller.dispose();
    }
    _episodeControllers.clear();
    _episodePremiumFlags.clear();

    // Create controllers for existing episodes
    for (final episode in _episodes) {
      final controller = TextEditingController();
      if (episode['youtube_video_url'] != null) {
        controller.text = episode['youtube_video_url'];
      }
      _episodeControllers.add(controller);

      // Check preview status using unified preview system
      final episodeId = episode['id'] as String;
      try {
        final hasPreview = await PreviewService.hasPreview(
          contentType: PreviewContentType.videoEpisode,
          contentId: episodeId,
        );
        _episodePreviewStatus[episodeId] = hasPreview;
        _episodePremiumFlags.add(
          !hasPreview,
        ); // If has preview, it's not premium (accessible)
      } catch (e) {
        print('Error checking preview status for episode $episodeId: $e');
        _episodePreviewStatus[episodeId] = false;
        _episodePremiumFlags.add(true); // Default to premium if error
      }
    }
  }

  String _defaultThumbnailFor(String id) =>
      VideoEpisodeService.getYouTubeThumbnailUrl(id);

  void _addNewEpisode() {
    setState(() {
      _episodeControllers.add(TextEditingController());
      _episodePremiumFlags.add(true); // Default to premium
    });
  }

  void _removeEpisode(int index) {
    setState(() {
      _episodeControllers[index].dispose();
      _episodeControllers.removeAt(index);
      _episodePremiumFlags.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    if (_kitab == null) return;

    setState(() => _isSaving = true);

    try {
      // Save preview video
      String? previewVideoId;
      String? previewVideoUrl = _previewUrlController.text.trim();

      if (previewVideoUrl.isNotEmpty) {
        previewVideoId = VideoEpisodeService.extractYouTubeVideoId(
          previewVideoUrl,
        );
        if (previewVideoId == null) {
          throw Exception('URL preview video tidak sah');
        }
      }

      // Update kitab with preview video
      await VideoKitabService.updateVideoKitabAdmin(widget.kitabId, {
        'youtube_video_id': previewVideoId,
        'youtube_video_url': previewVideoUrl.isEmpty ? null : previewVideoUrl,
      });

      // Clear existing episodes
      for (final episode in _episodes) {
        await VideoEpisodeService.deleteEpisode(episode['id']);
      }

      // Save new episodes
      for (int i = 0; i < _episodeControllers.length; i++) {
        final url = _episodeControllers[i].text.trim();
        if (url.isNotEmpty) {
          final videoId = VideoEpisodeService.extractYouTubeVideoId(url);
          if (videoId != null) {
            // Create episode without is_preview field
            final episodeData = await VideoEpisodeService.createEpisode({
              'video_kitab_id': widget.kitabId,
              'title': '${_kitab!.title} - Episode ${i + 1}',
              'youtube_video_id': videoId,
              'youtube_video_url': url,
              'thumbnail_url': _defaultThumbnailFor(videoId),
              'part_number': i + 1,
              'is_active': true,
            });

            // Create preview content if this episode should be free preview
            if (!_episodePremiumFlags[i]) {
              try {
                await PreviewService.createPreview(
                  PreviewConfig(
                    contentType: PreviewContentType.videoEpisode,
                    contentId: episodeData.id,
                    previewType: PreviewType.freeTrial,
                    previewDescription: 'Free preview episode',
                    isActive: true,
                  ),
                );
              } catch (e) {
                print(
                  'Error creating preview for episode ${episodeData.id}: $e',
                );
              }
            }
          }
        }
      }

      _showSnackBar('Perubahan berjaya disimpan!');
      await _loadKitabDetail(); // Reload data
    } catch (e) {
      _showSnackBar('Ralat menyimpan: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isSaving = false);
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
        title: Text(_kitab?.title ?? 'Detail Kitab'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        actions: [
          IconButton(
            onPressed: () {
              context.push('/admin/content/edit', extra: _kitab?.toJson());
            },
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Kitab',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveChanges,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
      ),
    );
  }

  Widget _buildContent() {
    if (_kitab == null) {
      return const Center(child: Text('Kitab tidak dijumpai'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKitabInfo(),
          const SizedBox(height: 24),
          _buildPreviewSection(),
          const SizedBox(height: 24),
          _buildEpisodesSection(),
          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildKitabInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maklumat Kitab',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),

            if (_kitab!.thumbnailUrl != null) ...[
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _kitab!.thumbnailUrl!,
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.book, size: 40),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            _buildInfoRow('Tajuk', _kitab!.title),
            if (_kitab!.author != null)
              _buildInfoRow('Pengarang', _kitab!.author!),
            if (_kitab!.description != null)
              _buildInfoRow('Penerangan', _kitab!.description!),

            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    'Status',
                    _kitab!.isPremium ? 'Premium' : 'Percuma',
                  ),
                ),
                Expanded(
                  child: _buildInfoRow('Halaman', '${_kitab!.totalPages ?? 0}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Video Preview (Percuma)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Video preview yang boleh ditonton semua pengguna tanpa langganan',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _previewUrlController,
              decoration: InputDecoration(
                labelText: 'URL Video Preview',
                hintText: 'https://www.youtube.com/watch?v=...',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                errorText:
                    _previewUrlController.text.trim().isNotEmpty &&
                        _previewVideoId == null
                    ? 'URL YouTube tidak sah'
                    : null,
              ),
              maxLines: 2,
              onChanged: (value) {
                setState(() {
                  _previewVideoId = VideoEpisodeService.extractYouTubeVideoId(
                    value.trim(),
                  );
                });
              },
            ),

            // Debug info for invalid URLs
            if (_previewUrlController.text.trim().isNotEmpty &&
                _previewVideoId == null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'URL tidak sah. Pastikan URL YouTube valid dan video ID 11 karakter.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_previewVideoId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        _defaultThumbnailFor(_previewVideoId!),
                        width: 80,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                Text(
                                  'Error',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 80,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
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
                            'Video ID: $_previewVideoId',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Preview (Percuma)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final url =
                            'https://www.youtube.com/watch?v=$_previewVideoId';
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url));
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      tooltip: 'Buka di YouTube',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_library, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Episode (${_episodeControllers.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addNewEpisode,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Episode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Atur episode dengan status premium/percuma secara individu',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            if (_episodeControllers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.video_library, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Belum ada episode',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tekan "Episode" untuk menambah',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_episodeControllers.length, (index) {
                return _buildEpisodeCard(index);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeCard(int index) {
    final controller = _episodeControllers[index];
    final isPremium = _episodePremiumFlags[index];
    final videoId = VideoEpisodeService.extractYouTubeVideoId(controller.text);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surfaceColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Episode header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Episode ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _removeEpisode(index),
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                tooltip: 'Buang Episode',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // URL input
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'URL Video Episode',
              hintText: 'https://www.youtube.com/watch?v=...',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Premium toggle
          Row(
            children: [
              Switch(
                value: isPremium,
                onChanged: (value) {
                  setState(() {
                    _episodePremiumFlags[index] = value;
                  });
                },
                activeThumbColor: AppTheme.secondaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPremium
                      ? 'Premium (Perlu langganan)'
                      : 'Percuma (Semua pengguna)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isPremium ? AppTheme.secondaryColor : Colors.green,
                  ),
                ),
              ),
            ],
          ),

          // Video preview
          if (videoId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPremium
                    ? AppTheme.secondaryColor.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPremium
                      ? AppTheme.secondaryColor.withValues(alpha: 0.3)
                      : Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      _defaultThumbnailFor(videoId),
                      width: 60,
                      height: 45,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: Colors.grey,
                              ),
                              Text(
                                'Error',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 60,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
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
                          'Video ID: $videoId',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPremium ? 'PREMIUM' : 'PERCUMA',
                          style: TextStyle(
                            fontSize: 10,
                            color: isPremium
                                ? AppTheme.secondaryColor
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final url = 'https://www.youtube.com/watch?v=$videoId';
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url));
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    tooltip: 'Buka di YouTube',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
