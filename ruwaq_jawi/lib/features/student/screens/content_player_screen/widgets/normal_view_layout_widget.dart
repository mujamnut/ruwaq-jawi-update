import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../../core/models/video_episode.dart';
import 'video_section_widget.dart';
import 'enhanced_tab_bar_widget.dart';

class NormalViewLayoutWidget extends StatelessWidget {
  final Widget? player;
  final bool hidePlayer;
  final YoutubePlayerController? videoController;
  final bool isVideoLoading;
  final VideoEpisode? currentEpisode;
  final TabController tabController;
  final bool showControls;
  final bool showSkipAnimation;
  final bool isSkipForward;
  final bool isSkipOnLeftSide;
  final bool isFullscreen;
  final VoidCallback onToggleControls;
  final VoidCallback onStartControlsTimer;
  final Function(bool, int, bool) onShowSkipFeedback;
  final Widget Function(int) buildResumeBanner;
  final VoidCallback onToggleFullscreen;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final Widget videoTabContent;
  final Widget pdfTabContent;

  const NormalViewLayoutWidget({
    super.key,
    required this.player,
    required this.hidePlayer,
    required this.videoController,
    required this.isVideoLoading,
    required this.currentEpisode,
    required this.tabController,
    required this.showControls,
    required this.showSkipAnimation,
    required this.isSkipForward,
    required this.isSkipOnLeftSide,
    required this.isFullscreen,
    required this.onToggleControls,
    required this.onStartControlsTimer,
    required this.onShowSkipFeedback,
    required this.buildResumeBanner,
    required this.onToggleFullscreen,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.videoTabContent,
    required this.pdfTabContent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Video player always on top
        VideoSectionWidget(
          player: player,
          hidePlayer: hidePlayer,
          videoController: videoController,
          isVideoLoading: isVideoLoading,
          currentEpisode: currentEpisode,
          tabControllerIndex: tabController.index,
          showControls: showControls,
          showSkipAnimation: showSkipAnimation,
          isSkipForward: isSkipForward,
          isSkipOnLeftSide: isSkipOnLeftSide,
          isFullscreen: isFullscreen,
          onToggleControls: onToggleControls,
          onStartControlsTimer: onStartControlsTimer,
          onShowSkipFeedback: onShowSkipFeedback,
          buildResumeBanner: buildResumeBanner,
          onToggleFullscreen: onToggleFullscreen,
        ),

        // Enhanced tab bar
        EnhancedTabBarWidget(tabController: tabController),

        // Tab Content with animations
        Expanded(
          child: AnimatedBuilder(
            animation: fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: fadeAnimation.value.clamp(0.0, 1.0),
                child: SlideTransition(
                  position: slideAnimation,
                  child: TabBarView(
                    controller: tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [videoTabContent, pdfTabContent],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}