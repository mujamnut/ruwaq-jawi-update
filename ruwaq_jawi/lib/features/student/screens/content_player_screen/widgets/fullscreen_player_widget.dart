import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'video_controls_overlay_widget.dart';
import 'skip_animation_widget.dart';

class FullscreenPlayerWidget extends StatelessWidget {
  final Widget player;
  final YoutubePlayerController? controller;
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

  const FullscreenPlayerWidget({
    super.key,
    required this.player,
    required this.controller,
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
    return SafeArea(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Player fills entire screen
            Positioned.fill(child: player),

            // Skip animation feedback
            SkipAnimationWidget(
              showSkipAnimation: showSkipAnimation,
              isSkipForward: isSkipForward,
              isSkipOnLeftSide: isSkipOnLeftSide,
              isFullscreen: true,
            ),

            // Controls overlay
            VideoControlsOverlayWidget(
              controller: controller,
              showControls: showControls,
              isFullscreen: true,
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
          ],
        ),
      ),
    );
  }
}
