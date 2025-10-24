import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/models/video_episode.dart';

/// Portrait mode video player with custom controls
class VideoPlayerWidget extends StatelessWidget {
  final Widget player;
  final YoutubePlayerController? controller;
  final VideoEpisode? currentEpisode;
  final bool showControls;
  final bool showSkipAnimation;
  final bool isSkipForward;
  final bool isSkipOnLeftSide;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onShowControls;
  final VoidCallback onHideControls;
  final Function(TapDownDetails) onDoubleTap;

  const VideoPlayerWidget({
    super.key,
    required this.player,
    required this.controller,
    required this.currentEpisode,
    required this.showControls,
    required this.showSkipAnimation,
    required this.isSkipForward,
    required this.isSkipOnLeftSide,
    required this.onToggleFullscreen,
    required this.onShowControls,
    required this.onHideControls,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final loadingWidget = Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              currentEpisode != null
                  ? 'Memuatkan video...'
                  : 'Video tidak tersedia',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (currentEpisode != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  currentEpisode!.title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (controller == null) {
      return Container(
        color: Colors.black,
        child: SafeArea(
          top: true,
          bottom: false,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: loadingWidget,
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: SafeArea(
        top: true,
        bottom: false,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(children: [
            // YouTube Player with native controls (topActions contains back)
            Positioned.fill(child: player),
            // Double-tap gesture layer for skip (does not block single taps)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: () {},
                onDoubleTapDown: onDoubleTap,
                child: const SizedBox.expand(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
