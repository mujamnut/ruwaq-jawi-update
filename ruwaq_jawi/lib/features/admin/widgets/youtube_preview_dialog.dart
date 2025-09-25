import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';

class YouTubePreviewDialog extends StatelessWidget {
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

  const YouTubePreviewDialog({
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
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.withValues(alpha: 0.1),
                    Colors.green.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Success icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        color: Colors.green,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Sync Successful!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Review the playlist details before approval',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Playlist Info
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
                            icon: PhosphorIcons.textT(),
                          ),
                          if (channelTitle != null)
                            _buildInfoRow(
                              context,
                              label: 'Channel',
                              value: channelTitle!,
                              icon: PhosphorIcons.youtubeLogo(),
                            ),
                          _buildInfoRow(
                            context,
                            label: 'Category',
                            value: categoryName,
                            icon: PhosphorIcons.tag(),
                          ),
                          if (playlistDescription != null &&
                              playlistDescription!.isNotEmpty)
                            _buildInfoRow(
                              context,
                              label: 'Description',
                              value: _truncateText(playlistDescription!, 100),
                              icon: PhosphorIcons.textAlignLeft(),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Stats
                    _buildInfoSection(
                      context,
                      title: 'Statistics',
                      icon: PhosphorIcons.chartBar(),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: PhosphorIcons.videoCamera(),
                              label: 'Videos',
                              value: totalVideos.toString(),
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: PhosphorIcons.clock(),
                              label: 'Duration',
                              value: _formatDuration(totalDurationMinutes),
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Settings
                    _buildInfoSection(
                      context,
                      title: 'Settings',
                      icon: PhosphorIcons.gear(),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSettingCard(
                                  context,
                                  icon: PhosphorIcons.crown(
                                    PhosphorIconsStyle.fill,
                                  ),
                                  label: 'Access Type',
                                  value: isPremium ? 'Premium' : 'Free',
                                  color: isPremium
                                      ? Colors.amber
                                      : Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSettingCard(
                                  context,
                                  icon: isActive
                                      ? PhosphorIcons.eye()
                                      : PhosphorIcons.eyeSlash(),
                                  label: 'Status',
                                  value: isActive ? 'Active' : 'Inactive',
                                  color: isActive ? Colors.green : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (episodes != null && episodes!.isNotEmpty) ...[
                      const SizedBox(height: 20),

                      // Episodes Preview
                      _buildInfoSection(
                        context,
                        title: 'Episodes Preview',
                        icon: PhosphorIcons.playCircle(),
                        child: Column(
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: episodes!.take(5).length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final episode = episodes![index];
                                  return _buildEpisodePreviewCard(
                                    context,
                                    episode,
                                    index + 1,
                                  );
                                },
                              ),
                            ),
                            if (episodes!.length > 5) ...[
                              const SizedBox(height: 8),
                              Text(
                                'and ${episodes!.length - 5} more episodes...',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(24),
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
                      icon: PhosphorIcon(
                        PhosphorIcons.x(),
                        size: 18,
                        color: Colors.red,
                      ),
                      label: Text(
                        'Reject & Edit',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: PhosphorIcon(
                        PhosphorIcons.check(),
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
          PhosphorIcon(icon, size: 16, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required PhosphorIconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          PhosphorIcon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required PhosphorIconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          PhosphorIcon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: color, fontSize: 10),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodePreviewCard(
    BuildContext context,
    VideoEpisodePreview episode,
    int number,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Episode number
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Episode info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (episode.duration != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(episode.duration!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Preview badge if applicable
          if (false) // Preview status now managed via preview_content table
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PREVIEW',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0
        ? '${hours}h ${remainingMinutes}m'
        : '${hours}h';
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

class VideoEpisodePreview {
  final String title;
  final int? duration; // in minutes
  final bool isPreview;

  const VideoEpisodePreview({
    required this.title,
    this.duration,
    this.isPreview = false,
  });
}
