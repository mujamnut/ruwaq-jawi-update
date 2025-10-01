import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'fullscreen_video_widget.dart';

class ContentPlayerScaffoldWidget extends StatelessWidget {
  final bool isFullscreen;
  final PreferredSizeWidget appBar;
  final Widget normalView;
  final Widget? player;
  final YoutubePlayerController? videoController;
  final bool showControls;
  final bool showSkipAnimation;
  final bool isSkipForward;
  final bool isSkipOnLeftSide;
  final VoidCallback onToggleControls;
  final VoidCallback onStartControlsTimer;
  final Function(bool, int, bool) onShowSkipFeedback;
  final VoidCallback onToggleFullscreen;
  final Future<bool> Function()? onWillPop;

  const ContentPlayerScaffoldWidget({
    super.key,
    required this.isFullscreen,
    required this.appBar,
    required this.normalView,
    required this.player,
    required this.videoController,
    required this.showControls,
    required this.showSkipAnimation,
    required this.isSkipForward,
    required this.isSkipOnLeftSide,
    required this.onToggleControls,
    required this.onStartControlsTimer,
    required this.onShowSkipFeedback,
    required this.onToggleFullscreen,
    this.onWillPop,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('🎬 ContentPlayerScaffoldWidget build - isFullscreen=$isFullscreen, showControls=$showControls');

    // Fullscreen mode - hide AppBar and take full screen
    if (isFullscreen) {
      return PopScope(
        canPop: false, // Handle back button manually
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (!didPop) {
            // Exit fullscreen instead of popping
            onToggleFullscreen();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: FullscreenVideoWidget(
            player: player,
            videoController: videoController,
            showControls: showControls,
            showSkipAnimation: showSkipAnimation,
            isSkipForward: isSkipForward,
            isSkipOnLeftSide: isSkipOnLeftSide,
            onToggleControls: onToggleControls,
            onStartControlsTimer: onStartControlsTimer,
            onShowSkipFeedback: onShowSkipFeedback,
            onToggleFullscreen: onToggleFullscreen,
          ),
        ),
      );
    }

    // Normal mode - show AppBar and tabs
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBar,
      body: PopScope(
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop && onWillPop != null) {
            await onWillPop!();
          }
        },
        child: normalView,
      ),
    );
  }
}
