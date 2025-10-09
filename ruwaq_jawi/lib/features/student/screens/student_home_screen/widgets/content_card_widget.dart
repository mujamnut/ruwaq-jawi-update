import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../utils/home_helpers.dart';

class ContentCardWidget extends StatelessWidget {
  final dynamic content;

  const ContentCardWidget({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isEbook = content.runtimeType.toString().contains('Ebook');
    final route = isEbook ? '/ebook/${content.id}' : '/kitab/${content.id}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(route),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail section
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: isEbook
                      ? Center(
                          child: PhosphorIcon(
                            PhosphorIcons.filePdf(),
                            size: 48,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: _buildVideoThumbnail(content),
                        ),
                ),
              ),
              // Content section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        content.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content.author ?? 'Unknown Author',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          PhosphorIcon(
                            isEbook
                                ? PhosphorIcons.filePdf()
                                : PhosphorIcons.videoCamera(),
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isEbook
                                  ? (content.totalPages != null
                                      ? '${content.totalPages} hal'
                                      : 'E-book')
                                  : (content.totalVideos > 0
                                      ? '${content.totalVideos} episod'
                                      : '1 episod'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(dynamic content) {
    String thumbnailUrl = '';

    if (content.thumbnailUrl != null && content.thumbnailUrl.isNotEmpty) {
      thumbnailUrl = content.thumbnailUrl;
    } else if (content.runtimeType.toString().contains('VideoEpisode') &&
        content.youtubeWatchUrl != null) {
      thumbnailUrl = HomeHelpers.getYouTubeThumbnailUrl(content.youtubeWatchUrl);
    }

    if (thumbnailUrl.isNotEmpty) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.videoCamera(),
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: Center(
          child: PhosphorIcon(
            PhosphorIcons.videoCamera(),
            size: 48,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }
  }
}
