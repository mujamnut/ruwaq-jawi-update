import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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
        child: Stack(children: [
          // YouTube Player fills entire screen with native controls; topActions carries the back
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
    );
  }
}
