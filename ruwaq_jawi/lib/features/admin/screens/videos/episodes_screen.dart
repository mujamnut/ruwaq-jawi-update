import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/kitab.dart';
import '../../../../core/models/kitab_video.dart';
import '../../../../core/theme/app_theme.dart';

class AdminVideoEpisodesScreen extends StatefulWidget {
  final Kitab kitab;

  const AdminVideoEpisodesScreen({super.key, required this.kitab});

  @override
  State<AdminVideoEpisodesScreen> createState() =>
      _AdminVideoEpisodesScreenState();
}

class _AdminVideoEpisodesScreenState extends State<AdminVideoEpisodesScreen> {
  List<KitabVideo> _videos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await SupabaseService.from(
        'kitab_videos',
      ).select().eq('kitab_id', widget.kitab.id).order('part_number');

      final videos = (response as List)
          .map((json) => KitabVideo.fromJson(json))
          .toList();

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ralat memuatkan video: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Video Episodes'),
            Text(
              widget.kitab.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addVideo,
            tooltip: 'Tambah Episode',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVideos,
            tooltip: 'Muat Semula',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVideo,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Episode'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuatkan video...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
            ElevatedButton(
              onPressed: _loadVideos,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textLightColor,
              ),
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildStatsHeader(),
        Expanded(child: _buildVideosList()),
      ],
    );
  }

  Widget _buildStatsHeader() {
    final totalDuration = _videos.fold<int>(
      0,
      (sum, video) => sum + (video.durationMinutes ?? 0),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          _buildStatCard(
            'Total Episodes',
            _videos.length.toString(),
            Icons.play_circle_outline,
            Colors.blue,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Total Duration',
            _formatDuration(totalDuration),
            Icons.schedule,
            Colors.green,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Published',
            _videos.where((v) => v.isActive).length.toString(),
            Icons.visibility,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosList() {
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Tiada Episode',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambah episode video untuk kitab ini',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addVideo,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Episode Pertama'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textLightColor,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _videos.length,
      onReorder: _reorderVideos,
      itemBuilder: (context, index) {
        return _buildVideoCard(_videos[index], index);
      },
    );
  }

  Widget _buildVideoCard(KitabVideo video, int index) {
    return Container(
      key: ValueKey(video.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: video.isActive ? AppTheme.borderColor : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _editVideo(video),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Episode number
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: video.isActive
                          ? AppTheme.primaryColor
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        video.partNumber.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Video info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: video.isActive
                                    ? AppTheme.textPrimaryColor
                                    : AppTheme.textSecondaryColor,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (video.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            video.description!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondaryColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Actions menu
                  PopupMenuButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppTheme.textSecondaryColor,
                    ),
                    onSelected: (value) => _handleVideoAction(video, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy),
                            SizedBox(width: 8),
                            Text('Duplikasi'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: video.isActive ? 'deactivate' : 'activate',
                        child: Row(
                          children: [
                            Icon(
                              video.isActive
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            const SizedBox(width: 8),
                            Text(video.isActive ? 'Nyahaktif' : 'Aktifkan'),
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
                  // Reorder handle
                  Icon(Icons.drag_handle, color: AppTheme.textSecondaryColor),
                ],
              ),
              const SizedBox(height: 12),
              // Video details
              Row(
                children: [
                  ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            color: Colors.red,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'YouTube',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDuration(video.durationMinutes),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!video.isActive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Tidak Aktif',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'Dikemaskini ${_formatDate(video.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes == 0) return '0m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minit lalu';
    } else {
      return 'Baru sahaja';
    }
  }

  void _addVideo() {
    _showVideoForm();
  }

  void _editVideo(KitabVideo video) {
    _showVideoForm(video: video);
  }

  void _showVideoForm({KitabVideo? video}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VideoFormDialog(
        kitab: widget.kitab,
        video: video,
        existingVideos: _videos,
        onSaved: () {
          Navigator.pop(context);
          _loadVideos();
        },
      ),
    );
  }

  Future<void> _reorderVideos(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    try {
      final video = _videos.removeAt(oldIndex);
      _videos.insert(newIndex, video);

      // Update episode numbers
      for (int i = 0; i < _videos.length; i++) {
        if (_videos[i].partNumber != i + 1) {
          await SupabaseService.from(
            'kitab_videos',
          ).update({'part_number': i + 1}).eq('id', _videos[i].id);

          _videos[i] = _videos[i].copyWith(partNumber: i + 1);
        }
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Urutan episode berjaya dikemas kini'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ralat mengubah urutan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      _loadVideos(); // Reload to get correct order
    }
  }

  void _handleVideoAction(KitabVideo video, String action) async {
    switch (action) {
      case 'edit':
        _editVideo(video);
        break;
      case 'duplicate':
        await _duplicateVideo(video);
        break;
      case 'activate':
      case 'deactivate':
        await _toggleVideoStatus(video);
        break;
      case 'delete':
        await _deleteVideo(video);
        break;
    }
  }

  Future<void> _duplicateVideo(KitabVideo video) async {
    try {
      final duplicateData = video.toJson();
      duplicateData.remove('id');
      duplicateData['title'] = '${video.title} (Salinan)';
      duplicateData['part_number'] = _videos.length + 1;
      duplicateData['created_at'] = DateTime.now().toIso8601String();
      duplicateData['updated_at'] = DateTime.now().toIso8601String();
      duplicateData['is_active'] = false;

      await SupabaseService.from('kitab_videos').insert(duplicateData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Episode berjaya diduplikasi'),
          backgroundColor: Colors.green,
        ),
      );

      _loadVideos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ralat menduplikasi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleVideoStatus(KitabVideo video) async {
    try {
      await SupabaseService.from(
        'kitab_videos',
      ).update({'is_active': !video.isActive}).eq('id', video.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Episode ${video.isActive ? 'dinyahaktifkan' : 'diaktifkan'}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _loadVideos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ralat: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteVideo(KitabVideo video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Episode'),
        content: Text(
          'Adakah anda pasti untuk memadam episode "${video.title}"?',
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
        await SupabaseService.from('kitab_videos').delete().eq('id', video.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Episode berjaya dipadam'),
            backgroundColor: Colors.green,
          ),
        );

        _loadVideos();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memadam episode: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _VideoFormDialog extends StatefulWidget {
  final Kitab kitab;
  final KitabVideo? video;
  final List<KitabVideo> existingVideos;
  final VoidCallback onSaved;

  const _VideoFormDialog({
    required this.kitab,
    this.video,
    required this.existingVideos,
    required this.onSaved,
  });

  @override
  State<_VideoFormDialog> createState() => _VideoFormDialogState();
}

class _VideoFormDialogState extends State<_VideoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _videoIdController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _durationController = TextEditingController();
  final _episodeController = TextEditingController();

  bool _isActive = true;
  bool _isSubmitting = false;

  bool get _isEditMode => widget.video != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _populateForm();
    } else {
      // Set next episode number
      final nextEpisode = widget.existingVideos.length + 1;
      _episodeController.text = nextEpisode.toString();
    }
  }

  void _populateForm() {
    final video = widget.video!;
    _titleController.text = video.title;
    _descriptionController.text = video.description ?? '';
    _videoIdController.text = video.youtubeVideoId ?? '';
    _videoUrlController.text = video.youtubeVideoUrl ?? '';
    _durationController.text = video.durationMinutes.toString() ?? '';
    _episodeController.text = video.partNumber.toString();
    _isActive = video.isActive;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditMode ? 'Edit Episode' : 'Tambah Episode Baru',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          // Form
          Expanded(child: _buildForm()),
          // Actions
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditMode ? 'Kemaskini' : 'Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _episodeController,
                    decoration: const InputDecoration(
                      labelText: 'Nombor Episode',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty == true) {
                        return 'Nombor episode diperlukan';
                      }
                      final episode = int.tryParse(value!);
                      if (episode == null || episode < 1) {
                        return 'Nombor episode tidak sah';
                      }
                      // Check for duplicates (exclude current video if editing)
                      final existing = widget.existingVideos.where(
                        (v) =>
                            v.partNumber == episode &&
                            (_isEditMode ? v.id != widget.video!.id : true),
                      );
                      if (existing.isNotEmpty) {
                        return 'Nombor episode sudah digunakan';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SwitchListTile(
                  title: const Text('Aktif'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tajuk Episode',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty == true ? 'Tajuk episode diperlukan' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Penerangan Episode',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _videoIdController,
              decoration: const InputDecoration(
                labelText: 'YouTube Video ID',
                hintText: 'cth: dQw4w9WgXcQ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _videoUrlController,
              decoration: const InputDecoration(
                labelText: 'YouTube Video URL',
                hintText: 'cth: https://www.youtube.com/watch?v=dQw4w9WgXcQ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Tempoh (minit)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isNotEmpty == true) {
                  final duration = int.tryParse(value!);
                  if (duration == null || duration < 0) {
                    return 'Tempoh tidak sah';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final videoData = {
        'kitab_id': widget.kitab.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'youtube_video_id': _videoIdController.text.trim().isEmpty
            ? null
            : _videoIdController.text.trim(),
        'youtube_video_url': _videoUrlController.text.trim().isEmpty
            ? null
            : _videoUrlController.text.trim(),
        'duration_minutes': _durationController.text.trim().isEmpty
            ? null
            : int.tryParse(_durationController.text.trim()),
        'part_number': int.parse(_episodeController.text.trim()),
        'is_active': _isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isEditMode) {
        await SupabaseService.from(
          'kitab_videos',
        ).update(videoData).eq('id', widget.video!.id);
      } else {
        await SupabaseService.from('kitab_videos').insert(videoData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Episode berjaya dikemaskini'
                : 'Episode berjaya ditambah',
          ),
          backgroundColor: Colors.green,
        ),
      );

      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ralat menyimpan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoIdController.dispose();
    _videoUrlController.dispose();
    _durationController.dispose();
    _episodeController.dispose();
    super.dispose();
  }
}
