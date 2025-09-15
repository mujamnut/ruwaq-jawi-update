import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/models/video_kitab.dart';
import '../../../core/models/kitab_video.dart';
import '../../../core/models/video_episode.dart';

class PreviewVideoSelectionDialog extends StatefulWidget {
  final String kitabId;
  final VideoKitab kitab;

  const PreviewVideoSelectionDialog({
    super.key,
    required this.kitabId,
    required this.kitab,
  });

  @override
  State<PreviewVideoSelectionDialog> createState() => _PreviewVideoSelectionDialogState();
}

class _PreviewVideoSelectionDialogState extends State<PreviewVideoSelectionDialog> {
  List<VideoEpisode> _previewVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreviewVideos();
  }

  Future<void> _loadPreviewVideos() async {
    try {
      final kitabProvider = context.read<KitabProvider>();
      final previewVideos = await kitabProvider.loadPreviewVideos(widget.kitabId);
      
      if (mounted) {
        setState(() {
          _previewVideos = previewVideos;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading preview videos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _playPreview([VideoEpisode? video]) {
    Navigator.of(context).pop();
    
    if (video != null) {
      // Play specific preview video
      context.push('/preview/${widget.kitabId}?video=${video.id}');
    } else if (_previewVideos.isNotEmpty) {
      // Play first available preview video
      context.push('/preview/${widget.kitabId}');
    }
  }

  void _showSubscriptionDialog() {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Langganan Diperlukan'),
        content: const Text(
          'Kitab ini memerlukan langganan premium untuk diakses. Ingin melanggan sekarang?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.textLightColor,
            ),
            child: const Text('Langgan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'PRATONTON',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: PhosphorIcon(PhosphorIcons.x()),
                        color: AppTheme.textLightColor,
                        iconSize: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.kitab.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textLightColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.kitab.author?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.kitab.author!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textLightColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _previewVideos.isEmpty
                      ? _buildNoPreviewsContent()
                      : _buildPreviewsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPreviewsContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIcons.eyeSlash(),
            size: 48,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Tiada Pratonton Tersedia',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kitab ini tidak mempunyai video pratonton. Untuk menonton video penuh, sila langgan premium.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimaryColor,
                    side: BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _showSubscriptionDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textLightColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Langgan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewsList() {
    return Column(
      children: [
        // Info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppTheme.secondaryColor.withOpacity(0.1),
          child: Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.info(),
                size: 16,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pilih video pratonton untuk ditonton.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Preview videos list
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            itemCount: _previewVideos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final video = _previewVideos[index];
              return _buildPreviewVideoTile(video);
            },
          ),
        ),
        
        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.borderColor),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimaryColor,
                    side: BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _playPreview(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textLightColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Tonton Pratonton'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewVideoTile(VideoEpisode video) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: InkWell(
        onTap: () => _playPreview(video),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Video icon/number
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${video.partNumber}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primaryColor,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            video.title,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PREVIEW',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIcons.clock(),
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          video.formattedDuration,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Play icon
              PhosphorIcon(
                PhosphorIcons.play(),
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
