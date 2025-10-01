import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../../core/models/video_episode.dart';
import '../../../../../core/services/video_progress_service.dart';
import '../../../../../core/theme/app_theme.dart';
import 'progress_bar_widget.dart';

class VideoSectionWidget extends StatelessWidget {
  final Widget? player;
  final bool hidePlayer;
  final YoutubePlayerController? videoController;
  final bool isVideoLoading;
  final VideoEpisode? currentEpisode;
  final int tabControllerIndex;
  final bool showControls;
  final bool showSkipAnimation;
  final bool isSkipForward;
  final bool isSkipOnLeftSide;
  final bool isFullscreen;

  // Callbacks
  final VoidCallback onToggleControls;
  final VoidCallback onStartControlsTimer;
  final Function(bool, int, bool) onShowSkipFeedback;
  final Widget Function(int) buildResumeBanner;
  final VoidCallback onToggleFullscreen;

  const VideoSectionWidget({
    super.key,
    required this.player,
    required this.hidePlayer,
    required this.videoController,
    required this.isVideoLoading,
    required this.currentEpisode,
    required this.tabControllerIndex,
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
  });

  @override
  Widget build(BuildContext context) {
    if (hidePlayer) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(color: Colors.black),
      );
    }

    // Show a clean placeholder if there is no controller
    if (videoController == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  PhosphorIcons.videoCamera(),
                  size: 48,
                  color: Colors.white70,
                ),
                const SizedBox(height: 12),
                Text(
                  'Video tidak tersedia',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: isVideoLoading
                ? Stack(
                    children: [
                      player ?? Container(color: Colors.black),
                      if (!(videoController?.value.isFullScreen ?? false))
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 16),
                                Text(
                                  'Memuat video...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : _buildPlayerWithDoubleTap(context, player) ??
                    Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PhosphorIcon(
                              PhosphorIcons.videoCamera(),
                              size: 32,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Video tidak tersedia',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          ),
        ),
        // Resume banner for saved video progress
        if (currentEpisode != null && tabControllerIndex == 0) ...[
          Builder(
            builder: (context) {
              final savedPosition = VideoProgressService.getVideoPosition(
                currentEpisode!.id,
              );

              // Show saved position banner if we have saved progress > 10 seconds
              if (savedPosition > 10) {
                return buildResumeBanner(savedPosition);
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ],
    );
  }

  Widget? _buildPlayerWithDoubleTap(BuildContext context, Widget? player) {
    if (player == null) return null;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            // Single tap to toggle controls
            onToggleControls();
          },
          onDoubleTap: () {
            // This will be handled by onDoubleTapDown, but we need this to enable double tap detection
          },
          onDoubleTapDown: (details) {
            // Only handle double tap here if controls are hidden
            if (showControls || videoController == null) return;

            // Get tap position relative to the player
            final size = MediaQuery.of(context).size;
            final position = details.localPosition;

            // Calculate if tap is on left or right side
            final isLeftSide = position.dx < size.width / 2;
            final skipSeconds = isLeftSide ? -10 : 10; // Skip backward or forward

            try {
              // Get current position and calculate new position
              final currentPosition = videoController!.value.position.inSeconds;
              final videoDuration = videoController!.metadata.duration.inSeconds;
              final newPosition = (currentPosition + skipSeconds).clamp(0, videoDuration);

              // Custom seek to new position
              videoController!.seekTo(Duration(seconds: newPosition.toInt()));

              // Show feedback with visual indicator
              onShowSkipFeedback(isLeftSide, skipSeconds.abs(), isLeftSide);
            } catch (e) {
              debugPrint('Error in custom double tap seek: $e');
            }
          },
          child: player,
        ),
        // Custom Controls Overlay
        if (showControls)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // Single tap on overlay (not on buttons) should toggle controls
                onToggleControls();
                // Start auto-hide timer if controls are now visible and video is playing
                if (showControls && videoController?.value.isPlaying == true) {
                  onStartControlsTimer();
                }
              },
              onDoubleTap: () {
                // Enable double tap detection
              },
              onDoubleTapDown: (details) {
                if (videoController == null) return;

                // Get tap position relative to the overlay
                final size = MediaQuery.of(context).size;
                final position = details.localPosition;

                // Calculate if tap is on left or right side
                final isLeftSide = position.dx < size.width / 2;
                final skipSeconds = isLeftSide ? -10 : 10; // Skip backward or forward

                try {
                  // Get current position and calculate new position
                  final currentPosition = videoController!.value.position.inSeconds;
                  final videoDuration = videoController!.metadata.duration.inSeconds;
                  final newPosition = (currentPosition + skipSeconds).clamp(0, videoDuration);

                  // Custom seek to new position
                  videoController!.seekTo(Duration(seconds: newPosition.toInt()));

                  // Show feedback with visual indicator
                  onShowSkipFeedback(isLeftSide, skipSeconds.abs(), isLeftSide);

                  // Reset auto-hide timer after skip (works in both normal and fullscreen)
                  if (videoController!.value.isPlaying) {
                    onStartControlsTimer();
                  }
                } catch (e) {
                  debugPrint('Error in custom double tap seek: $e');
                }
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Stack(
                  children: [
                    // Center Play/Pause Button
                    Center(
                      child: StreamBuilder<Duration>(
                        stream: Stream.periodic(
                          const Duration(milliseconds: 100),
                          (_) => videoController?.value.position ?? Duration.zero,
                        ),
                        builder: (context, snapshot) {
                          final isPlaying = videoController?.value.isPlaying ?? false;
                          return GestureDetector(
                            onTap: () {
                              if (videoController != null) {
                                if (videoController!.value.isPlaying) {
                                  videoController!.pause();
                                } else {
                                  videoController!.play();
                                  // Start auto-hide timer after play
                                  onStartControlsTimer();
                                }
                              }
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isPlaying
                                    ? PhosphorIcons.pause()
                                    : PhosphorIcons.play(),
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Custom Seekable Progress Bar
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: GestureDetector(
                        onTap: null, // Prevent tap on progress bar from hiding controls
                        child: ProgressBarWidget(
                          videoController: videoController,
                          isFullscreen: isFullscreen,
                          onToggleFullscreen: onToggleFullscreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // YouTube-style skip animation overlay
        if (showSkipAnimation)
          Positioned(
            left: isSkipOnLeftSide ? 40 : null,
            right: !isSkipOnLeftSide ? 40 : null,
            top: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: showSkipAnimation ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSkipForward ? Icons.fast_forward : Icons.fast_rewind,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '10s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }


}