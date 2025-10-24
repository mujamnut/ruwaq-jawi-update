import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/models/kitab.dart';
import '../../../../core/services/video_kitab_service.dart';
import '../../../../core/services/video_episode_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../shared/pdf_viewer_screen.dart';

class AdminKitabDetailScreen extends StatefulWidget {
  final String kitabId;

  const AdminKitabDetailScreen({super.key, required this.kitabId});

  @override
  State<AdminKitabDetailScreen> createState() => _AdminKitabDetailScreenState();
}

class _AdminKitabDetailScreenState extends State<AdminKitabDetailScreen> {
  // Using static methods from VideoKitabService and VideoEpisodeService

  Kitab? _kitab;
  List<Map<String, dynamic>> _episodes = [];

  bool _isLoading = true;

  // Controllers untuk preview video
  final _previewUrlController = TextEditingController();

  // Controllers untuk episodes (dynamic list)
  final List<TextEditingController> _episodeControllers = [];
  YoutubePlayerController? _ytController;
  int? _playingEpisodeIndex;

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
    _ytController?.dispose();
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

    // Create controllers for existing episodes
    for (final episode in _episodes) {
      final controller = TextEditingController();
      if (episode['youtube_video_url'] != null) {
        controller.text = episode['youtube_video_url'];
      }
      _episodeControllers.add(controller);
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
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textPrimaryColor,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            size: 22,
            color: AppTheme.textPrimaryColor,
          ),
          tooltip: 'Kembali',
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            _kitab?.title ?? 'Detail Kitab',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      // Buang FAB supaya lebih bersih
    );
  }

  Widget _buildContent() {
    if (_kitab == null) {
      return const Center(child: Text('Kitab tidak dijumpai'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_ytController != null) {
          // Auto-pause when user scrolls the page
          try {
            if (_ytController!.value.isPlaying) {
              _ytController!.pause();
            }
          } catch (_) {}
        }
        return false;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKitabInfo(),
            const SizedBox(height: 24),
            _buildEpisodesSection(),
            const SizedBox(height: 100), // Space for FAB
          ],
        ),
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
            Row(
              children: [
                Text(
                  'Maklumat Kitab',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _showKitabActionsBottomSheet,
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  tooltip: 'Tindakan',
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_kitab!.thumbnailUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    _kitab!.thumbnailUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(color: Colors.grey[300]),
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 40),
                        ),
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

            // PDF Action (if available)
            if (_kitab!.pdfUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final url = _kitab!.pdfUrl!.trim();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PdfViewerScreen(
                          pdfUrl: url,
                          title: _kitab!.title,
                          kitabId: _kitab!.id,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Lihat PDF'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showKitabActionsBottomSheet() {
    if (_kitab == null) return;
    final bool isActive = _kitab!.isActive;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  isActive ? Icons.visibility_off : Icons.visibility,
                  color: Colors.blue,
                ),
                title: Text(isActive ? 'Nyahaktif' : 'Aktifkan'),
                onTap: () async {
                  Navigator.pop(context);
                  await _toggleKitabActive(isActive);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Padam', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteKitabConfirm();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleKitabActive(bool current) async {
    if (_kitab == null) return;
    try {
      await VideoKitabService.toggleVideoKitabStatusAdmin(_kitab!.id, !current);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!current ? 'Diaktifkan' : 'Dinonaktifkan'),
          backgroundColor: !current ? Colors.green : Colors.orange,
        ),
      );
      await _loadKitabDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat mengubah status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteKitabConfirm() async {
    if (_kitab == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengesahan Padam'),
        content: Text('Padam "${_kitab!.title}"? Tindakan ini tidak boleh dibuat asal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await VideoKitabService.deleteVideoKitab(_kitab!.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berjaya dipadam'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Keluar dari halaman detail selepas padam
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ralat memadam: $e'), backgroundColor: Colors.red),
        );
      }
    }
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


  Widget _buildEpisodesSection() {
    final episodes = _episodes;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.video_library, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Episode (${episodes.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (episodes.isEmpty)
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
                ],
              ),
            )
          else
            ...List.generate(episodes.length, (index) {
              final e = episodes[index];
              return Column(
                children: [
                  _buildEpisodeDisplayCard(e, index),
                  if (index != episodes.length - 1) ...[
                    const SizedBox(height: 12),
                    Divider(color: AppTheme.borderColor),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEpisodeDisplayCard(Map<String, dynamic> episode, int index) {
    final bool isActive = episode['is_active'] ?? true;
    final String? videoId = episode['youtube_video_id'] as String?;
    final String? url = episode['youtube_video_url'] as String?;
    final String title = episode['title'] ?? 'Episode ${index + 1}';
    final int? part = episode['part_number'] as int?;
    final int? duration = episode['duration_minutes'] as int?;
    final String? thumb = episode['thumbnail_url'] as String?;

    // Check if video ID is valid (11 characters for YouTube)
    final bool hasValidVideoId = videoId != null && videoId.length == 11;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: (_playingEpisodeIndex == index && _ytController != null)
              ? Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: YoutubePlayer(
                        controller: _ytController!,
                        showVideoProgressIndicator: true,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _ytController?.pause();
                              _ytController?.dispose();
                              _ytController = null;
                              _playingEpisodeIndex = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: InkWell(
                        onTap: () {
                          final id = videoId ?? (url != null
                              ? VideoEpisodeService.extractYouTubeVideoId(url)
                              : null);
                          if (id == null || id.isEmpty) return;

                          try {
                            setState(() {
                              _ytController?.dispose();
                              _ytController = YoutubePlayerController(
                                initialVideoId: id,
                                flags: const YoutubePlayerFlags(
                                  autoPlay: true,
                                  mute: false,
                                ),
                              );
                              _playingEpisodeIndex = index;
                            });
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Ralat memuat video: Video mungkin private atau tidak tersedia'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        child: thumb != null && thumb.isNotEmpty
                            ? Image.network(
                                thumb,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.warning_rounded,
                                          size: 32,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Video Private/Tidak Tersedia',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : (videoId != null
                                ? Image.network(
                                    VideoEpisodeService.getYouTubeThumbnailUrl(
                                      videoId,
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.warning_rounded,
                                              size: 32,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Video Private/Tidak Tersedia',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(color: Colors.grey[200])),
                      ),
                    ),
                    // Warning badge for invalid/private videos
                    if (!hasValidVideoId)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Invalid/Private',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if ((episode['is_premium'] as bool?) == true && hasValidVideoId)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCrown,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    if (part != null)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: _buildOverlayBadge('Ep $part'),
                      ),
                    if (duration != null && duration > 0)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _buildOverlayBadge('${duration}m'),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (!hasValidVideoId) ...[
                          Icon(
                            Icons.warning_rounded,
                            size: 18,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: hasValidVideoId
                                  ? AppTheme.textPrimaryColor
                                  : Colors.red,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isActive ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: isActive
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showEpisodeActionsBottomSheet(episode),
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    tooltip: 'Tindakan',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (videoId != null)
                Row(
                  children: [
                    Icon(
                      Icons.ondemand_video,
                      size: 14,
                      color: hasValidVideoId ? Colors.grey : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        hasValidVideoId
                            ? 'YouTube ID: $videoId'
                            : 'YouTube ID: $videoId (Invalid/Private)',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasValidVideoId ? Colors.grey : Colors.red,
                          fontWeight: hasValidVideoId
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEpisodeActionsBottomSheet(Map<String, dynamic> episode) {
    final bool isActive = episode['is_active'] ?? true;
    final String? videoId = episode['youtube_video_id'] as String?;
    final String? url = episode['youtube_video_url'] as String?;
    final String id = episode['id'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Episode'),
                onTap: () async {
                  Navigator.pop(context);
                  await _showEditEpisodeDialog(episode);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.blue),
                title: const Text('Buka di YouTube'),
                onTap: () async {
                  Navigator.pop(context);
                  final link = videoId != null
                      ? 'https://www.youtube.com/watch?v=$videoId'
                      : (url ?? '');
                  if (link.isNotEmpty && await canLaunchUrl(Uri.parse(link))) {
                    await launchUrl(Uri.parse(link));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('Salin URL'),
                onTap: () async {
                  Navigator.pop(context);
                  final link = videoId != null
                      ? 'https://www.youtube.com/watch?v=$videoId'
                      : (url ?? '');
                  if (link.isNotEmpty) {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL disalin')),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  isActive ? Icons.visibility_off : Icons.visibility,
                  color: Colors.blue,
                ),
                title: Text(isActive ? 'Nyahaktif' : 'Aktifkan'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await VideoEpisodeService.toggleEpisodeStatus(
                      id,
                      !isActive,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          !isActive ? 'Diaktifkan' : 'Dinonaktifkan',
                        ),
                        backgroundColor: !isActive
                            ? Colors.green
                            : Colors.orange,
                      ),
                    );
                    _loadKitabDetail();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ralat: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Padam', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Pengesahan Padam'),
                      content: const Text(
                        'Padam episode ini? Tindakan tidak boleh dibuat asal.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Padam'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await VideoEpisodeService.deleteEpisode(id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Episode dipadam'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadKitabDetail();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ralat: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditEpisodeDialog(Map<String, dynamic> episode) async {
    final id = episode['id'] as String;
    final title = episode['title']?.toString() ?? '';
    final url = episode['youtube_video_url']?.toString() ?? '';
    final titleController = TextEditingController(text: title);
    final urlController = TextEditingController(text: url);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Episode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Tajuk'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL YouTube',
                  hintText: 'https://www.youtube.com/watch?v=... atau VIDEO_ID',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      try {
        final newTitle = titleController.text.trim();
        final rawUrl = urlController.text.trim();
        final newId = VideoEpisodeService.extractYouTubeVideoId(rawUrl);
        if (newId == null || newId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL YouTube tidak sah'), backgroundColor: Colors.red),
          );
          return;
        }
        await VideoEpisodeService.updateEpisode(id, {
          'title': newTitle.isEmpty ? 'Episode' : newTitle,
          'youtube_video_id': newId,
          'youtube_video_url': rawUrl.isEmpty ? 'https://www.youtube.com/watch?v=$newId' : rawUrl,
          'thumbnail_url': VideoEpisodeService.getYouTubeThumbnailUrl(newId),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Episode dikemas kini'), backgroundColor: Colors.green),
        );
        await _loadKitabDetail();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ralat mengemas kini: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Small dark badge used over thumbnails (e.g., Ep number, duration)
  Widget _buildOverlayBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

}
