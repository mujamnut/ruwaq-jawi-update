import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/models/video_episode.dart';
import 'video_controls_overlay_widget.dart';
import 'skip_animation_widget.dart';

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
  final VoidCallback onTogglePlayPause;
  final Function(TapDownDetails) onDoubleTap;
  final Function(bool isFullscreen, bool isPlaying) onStartControlsTimer;

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
    required this.onTogglePlayPause,
    required this.onDoubleTap,
    required this.onStartControlsTimer,
  });

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
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
                  Text(
                    currentEpisode!.title,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          // Player
          Positioned.fill(child: player),

          // Skip animation feedback
          SkipAnimationWidget(
            showSkipAnimation: showSkipAnimation,
            isSkipForward: isSkipForward,
            isSkipOnLeftSide: isSkipOnLeftSide,
          ),

          // Controls overlay
          VideoControlsOverlayWidget(
            controller: controller,
            showControls: showControls,
            isFullscreen: false,
            onToggleFullscreen: onToggleFullscreen,
            onHideControls: onHideControls,
            onTogglePlayPause: onTogglePlayPause,
            onStartControlsTimer: onStartControlsTimer,
          ),

          // Gesture detector for showing controls when hidden
          if (!showControls)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onShowControls,
                onDoubleTap: () {},
                onDoubleTapDown: onDoubleTap,
                child: Container(color: Colors.transparent),
              ),
            ),

          // Persistent fullscreen button in portrait mode (render last = on top)
          Positioned(
            top: 8,
            right: 8,
            child: IgnorePointer(
              ignoring: false,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    debugPrint('🎬 Fullscreen button tapped!');
                    onToggleFullscreen();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: PhosphorIcon(
                      PhosphorIcons.arrowsOut(PhosphorIconsStyle.bold),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
