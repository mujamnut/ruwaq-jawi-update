import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/models/video_episode.dart';
import '../../../../../core/theme/app_theme.dart';
import 'episode_card_widget.dart';

class EpisodesListWidget extends StatelessWidget {
  final List<VideoEpisode> episodes;
  final int currentEpisodeIndex;
  final bool isPremiumUser;
  final Function(int) isVideoPlaying;
  final Function(int) onEpisodeTap;

  const EpisodesListWidget({
    super.key,
    required this.episodes,
    required this.currentEpisodeIndex,
    required this.isPremiumUser,
    required this.isVideoPlaying,
    required this.onEpisodeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (episodes.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          // Episodes are already sorted by part number, so just map them directly
          ...episodes.asMap().entries
              .map((entry) => _buildEpisodeCard(entry.value, entry.key)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
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
    );
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