import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../../core/models/video_episode.dart';
import '../../../../../core/theme/app_theme.dart';

class EpisodeCardWidget extends StatelessWidget {
  final VideoEpisode episode;
  final int index;
  final bool isCurrentEpisode;
  final bool isPlaying;
  final bool isPremium;
  final bool isBlocked;
  final VoidCallback onEpisodeTap;

  const EpisodeCardWidget({
    super.key,
    required this.episode,
    required this.index,
    required this.isCurrentEpisode,
    required this.isPlaying,
    required this.isPremium,
    required this.isBlocked,
    required this.onEpisodeTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnail =
        'https://img.youtube.com/vi/${episode.youtubeVideoId}/mqdefault.jpg';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isCurrentEpisode
                    ? AppTheme.primaryColor.withValues(alpha: 0.08)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20), // xl rounded corners
                border: Border.all(
                  color: isCurrentEpisode
                      ? AppTheme.primaryColor.withValues(alpha: 0.3)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isBlocked ? null : onEpisodeTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Episode thumbnail with overlay
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 120,
                                height: 67,
                                color: Colors.black12,
                                child: Image.network(
                                  thumbnail,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          color: Colors.grey,
                                          size: 32,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Play overlay or premium lock
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isBlocked
                                      ? Colors.black.withValues(alpha: 0.35)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: isBlocked
                                      ? null
                                      : isCurrentEpisode && isPlaying
                                          ? Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor,
                                                shape: BoxShape.circle,
                                          ),
                                          child: PhosphorIcon(
                                            PhosphorIcons.pause(
                                              PhosphorIconsStyle.fill,
                                            ),
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        )
                                      : Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.6,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: PhosphorIcon(
                                            PhosphorIcons.play(
                                              PhosphorIconsStyle.fill,
                                            ),
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            // Small premium badge (top-left) when blocked
                            if (isBlocked)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PhosphorIcon(
                                        PhosphorIcons.crown(PhosphorIconsStyle.fill),
                                        color: Colors.amber,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'PREMIUM',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (episode.duration != null)
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _formatDuration(episode.duration!),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Episode details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Episode title with prefix "ep n"
                              RichText(
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontSize: 14,
                                        fontWeight: isCurrentEpisode
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isBlocked
                                            ? AppTheme.textSecondaryColor
                                            : AppTheme.textPrimaryColor,
                                      ),
                                  children: [
                                    TextSpan(
                                      text: 'Ep ${episode.partNumber} • ',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontSize: 14,
                                            color: AppTheme.textSecondaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    TextSpan(text: episode.title),
                                  ],
                                ),
                              ),
                              if (isPremium) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PhosphorIcon(
                                            PhosphorIcons.crown(),
                                            color: Colors.amber[700],
                                            size: 10,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            'PREMIUM',
                                            style: TextStyle(
                                              color: Colors.amber[700],
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              // Episode metadata
                              Row(
                                children: [
                                  // Simplified; no extra labels
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Action indicator
                        if (isBlocked)
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: PhosphorIcon(
                              PhosphorIcons.lock(),
                              color: Colors.amber[700],
                              size: 16,
                            ),
                          )
                        else if (isCurrentEpisode)
                          Container(
                            width: 8,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        else
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowRight01,
                            color: AppTheme.textSecondaryColor,
                            size: 16,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}
