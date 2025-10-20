import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class YouTubePreviewSheet extends StatelessWidget {
  final String playlistTitle;
  final String? playlistDescription;
  final String? channelTitle;
  final int totalVideos;
  final int totalDurationMinutes;
  final bool isPremium;
  final bool isActive;
  final String categoryName;
  final List<VideoEpisodePreview>? episodes;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool pdfUploaded;
  final bool pdfSelected;
  final String? pdfUrl;
  final int? pdfSizeBytes;

  const YouTubePreviewSheet({
    super.key,
    required this.playlistTitle,
    this.playlistDescription,
    this.channelTitle,
    required this.totalVideos,
    this.totalDurationMinutes = 0,
    required this.isPremium,
    required this.isActive,
    required this.categoryName,
    this.episodes,
    required this.onApprove,
    required this.onReject,
    this.pdfUploaded = false,
    this.pdfSelected = false,
    this.pdfUrl,
    this.pdfSizeBytes,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double handleWidth = 36;
    final double handleHeight = 4;
    final double initialHeight = size.height * 0.85;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        height: initialHeight,
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Drag handle
            Container(
              width: handleWidth,
              height: handleHeight,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(Icons.check_circle, color: Colors.green, size: 32),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sync Successful!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Review the playlist details before approval',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.textSecondaryColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Content scroll
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection(
                      context,
                      title: 'Playlist Information',
                      icon: PhosphorIcons.info(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            context,
                            label: 'Title',
                            value: playlistTitle,
                            icon: PhosphorIcons.playlist(),
                          ),
                          if (channelTitle != null && channelTitle!.isNotEmpty)
                            _buildInfoRow(
                              context,
                              label: 'Channel',
                              value: channelTitle!,
                              icon: PhosphorIcons.youtubeLogo(),
                            ),
                          _buildInfoRow(
                            context,
                            label: 'Total Videos',
                            value: '$totalVideos',
                            icon: PhosphorIcons.listNumbers(),
                          ),
                          if (totalDurationMinutes > 0)
                            _buildInfoRow(
                              context,
                              label: 'Total Duration',
                              value: '${totalDurationMinutes} min',
                              icon: PhosphorIcons.timer(),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // PDF Section (if any)
                    _buildInfoSection(
                      context,
                      title: 'PDF Document',
                      icon: PhosphorIcons.filePdf(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pdfUploaded
                                      ? 'Attached to playlist'
                                      : pdfSelected
                                          ? 'Selected but not uploaded'
                                          : 'No PDF',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              if (pdfUrl != null)
                                OutlinedButton(
                                  onPressed: () => _openPdf(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    side: BorderSide(color: AppTheme.borderColor),
                                  ),
                                  child: const Text('Open PDF'),
                                ),
                            ],
                          ),
                          if (pdfSizeBytes != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Size: ${(pdfSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.textSecondaryColor),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildInfoSection(
                      context,
                      title: 'Publishing Options',
                      icon: PhosphorIcons.sliders(),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(context, isPremium ? 'Premium' : 'Free',
                              isPremium ? Colors.amber : Colors.green),
                          _chip(context, isActive ? 'Active' : 'Hidden',
                              isActive ? Colors.green : Colors.grey),
                          _chip(context, 'Category: $categoryName', Colors.blue),
                        ],
                      ),
                    ),

                    if (episodes != null && episodes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoSection(
                        context,
                        title: 'Episodes',
                        icon: PhosphorIcons.video(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${episodes!.length} episodes',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            ...episodes!.take(5).map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.play_circle_outline, size: 18,
                                          color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          e.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            if (episodes!.length > 5)
                              Text(
                                '+ ${episodes!.length - 5} more...'
                                    .toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.textSecondaryColor),
                              )
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.borderColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      label: const Text(
                        'Reject & Edit',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18, color: Colors.white),
                      label: const Text(
                        'Approve & Publish',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPdf(BuildContext context) async {
    if (pdfUrl == null) return;
    final uri = Uri.parse(pdfUrl!);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka PDF')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ralat membuka PDF')),
      );
    }
  }

  Widget _chip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required PhosphorIconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                PhosphorIcon(icon, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    required PhosphorIconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                PhosphorIcon(icon, color: AppTheme.textSecondaryColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

// Keep the same episode preview model used in dialog
class VideoEpisodePreview {
  final String title;
  final int? duration;
  final bool isPreview;

  VideoEpisodePreview({
    required this.title,
    this.duration,
    this.isPreview = false,
  });
}
