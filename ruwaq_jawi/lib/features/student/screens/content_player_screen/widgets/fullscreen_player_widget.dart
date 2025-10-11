import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'skip_animation_widget.dart';
import 'video_controls_overlay_widget.dart';

/// Fullscreen player with custom controls
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
  final Function(TapDownDetails) onDoubleTap;

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
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // YouTube Player fills entire screen
            Positioned.fill(child: player),

            // Skip animation feedback
            SkipAnimationWidget(
              showSkipAnimation: showSkipAnimation,
              isSkipForward: isSkipForward,
              isSkipOnLeftSide: isSkipOnLeftSide,
              isFullscreen: true,
            ),

            // Custom controls overlay with back button
            VideoControlsOverlayWidget(
              controller: controller,
              isFullscreen: true,
              onToggleFullscreen: onToggleFullscreen,
              showControls: showControls,
              onShowControls: onShowControls,
              onHideControls: onHideControls,
              onBack: onToggleFullscreen, // Exit fullscreen on back
            ),

            // Gesture detector for showing controls when hidden
            if (!showControls)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: onShowControls,
                  onDoubleTap: () {}, // Empty to avoid conflict
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
