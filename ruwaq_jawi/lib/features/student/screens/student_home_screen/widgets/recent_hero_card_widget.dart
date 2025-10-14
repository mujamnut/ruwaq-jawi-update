import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../utils/home_helpers.dart';

class RecentHeroCardWidget extends StatelessWidget {
  final dynamic content;

  const RecentHeroCardWidget({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final bool isEbook = content.runtimeType.toString().contains('Ebook');
    final String route = isEbook ? '/ebook/${content.id}' : '/kitab/${content.id}';

    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background (image for video, soft gradient for ebook)
              Positioned.fill(
                child: isEbook
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.gradientStart.withValues(alpha: 0.12),
                              AppTheme.gradientEnd.withValues(alpha: 0.12),
                            ],
                          ),
                        ),
                      )
                    : _buildVideoBackground(content),
              ),
              // Scrim for text readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  isEbook ? PhosphorIcons.filePdf() : PhosphorIcons.videoCamera(),
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isEbook ? 'E-Book' : 'Video',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        content.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
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

  Widget _buildVideoBackground(dynamic content) {
    String thumbnailUrl = '';
    if (content.thumbnailUrl != null && content.thumbnailUrl.isNotEmpty) {
      thumbnailUrl = content.thumbnailUrl;
    } else if (content.runtimeType.toString().contains('VideoEpisode') &&
        content.youtubeWatchUrl != null) {
      thumbnailUrl = HomeHelpers.getYouTubeThumbnailUrl(content.youtubeWatchUrl);
    }

    if (thumbnailUrl.isNotEmpty) {
      return Image.network(
        thumbnailUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(color: AppTheme.primaryColor.withValues(alpha: 0.08));
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(color: AppTheme.primaryColor.withValues(alpha: 0.08));
        },
      );
    }
    return Container(color: AppTheme.primaryColor.withValues(alpha: 0.08));
  }
}

