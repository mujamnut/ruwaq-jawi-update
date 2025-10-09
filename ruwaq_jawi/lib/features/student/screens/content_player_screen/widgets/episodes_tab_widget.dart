import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/models/video_episode.dart';
import '../../../../../core/theme/app_theme.dart';
import 'episode_card_widget.dart';

class EpisodesTabWidget extends StatelessWidget {
  final List<VideoEpisode> episodes;
  final int currentEpisodeIndex;
  final bool isPlaying;
  final bool isPremiumUser;
  final Function(int index, VideoEpisode episode) onEpisodeTap;

  const EpisodesTabWidget({
    super.key,
    required this.episodes,
    required this.currentEpisodeIndex,
    required this.isPlaying,
    required this.isPremiumUser,
    required this.onEpisodeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                PhosphorIcons.videoCamera(),
                size: 48,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Tiada episod tersedia',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final isCurrentEpisode = index == currentEpisodeIndex;
        final isPremium = episode.isPremium == true;
        final isBlocked = isPremium && !isPremiumUser;

        return EpisodeCardWidget(
          episode: episode,
          index: index,
          isCurrentEpisode: isCurrentEpisode,
          isPlaying: isPlaying && isCurrentEpisode,
          isPremium: isPremium,
          isBlocked: isBlocked,
          onEpisodeTap: () => onEpisodeTap(index, episode),
        );
      },
    );
  }
}
