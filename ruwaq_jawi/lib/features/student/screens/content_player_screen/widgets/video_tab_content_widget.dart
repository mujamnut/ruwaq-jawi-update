import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/models/video_kitab.dart';
import '../../../../../core/models/video_episode.dart';
import '../../../../../core/theme/app_theme.dart';
import 'episode_card_widget.dart';

class VideoTabContentWidget extends StatelessWidget {
  final bool isDataLoading;
  final VideoKitab? kitab;
  final VideoEpisode? currentEpisode;
  final List<VideoEpisode> episodes;
  final int currentEpisodeIndex;
  final bool isPremiumUser;
  final bool Function(int) isVideoPlaying;
  final Function(int) onEpisodeTap;

  const VideoTabContentWidget({
    super.key,
    required this.isDataLoading,
    required this.kitab,
    required this.currentEpisode,
    required this.episodes,
    required this.currentEpisodeIndex,
    required this.isPremiumUser,
    required this.isVideoPlaying,
    required this.onEpisodeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isDataLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clean video info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  (kitab?.hasVideos ?? false && currentEpisode != null)
                      ? currentEpisode!.title
                      : kitab?.title ?? 'Kitab',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                if (kitab?.author != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.user(),
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        kitab?.author ?? 'Unknown Author',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (kitab?.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Tentang',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kitab?.description ?? 'No description available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Episodes section with modern design
          if (episodes.length > 1) ..._buildEpisodesSection(context),
        ],
      ),
    );
  }

  List<Widget> _buildEpisodesSection(BuildContext context) {
    if (episodes.length <= 1) return [];

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.listNumbers(),
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Senarai Episode',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${episodes.length} episod',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Episodes are already sorted by part number, so just map them directly
            ...episodes.asMap().entries
                .map((entry) => _buildEpisodeCard(entry.value, entry.key)),
          ],
        ),
      ),
    ];
  }

  Widget _buildEpisodeCard(VideoEpisode episode, int index) {
    final isCurrentEpisode = index == currentEpisodeIndex;
    final isPlaying = isVideoPlaying(index);
    final isPremium = episode.isPremium == true;
    final isBlocked = isPremium && !isPremiumUser;

    return EpisodeCardWidget(
      episode: episode,
      index: index,
      isCurrentEpisode: isCurrentEpisode,
      isPlaying: isPlaying,
      isPremium: isPremium,
      isBlocked: isBlocked,
      onEpisodeTap: () => onEpisodeTap(index),
    );
  }
}