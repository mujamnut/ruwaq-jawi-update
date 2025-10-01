import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoControlsWidget extends StatelessWidget {
  final YoutubePlayerController? videoController;
  final bool showControls;
  final VoidCallback onToggleControls;
  final VoidCallback onStartControlsTimer;
  final Function(bool, int, bool) onShowSkipFeedback;

  const VideoControlsWidget({
    super.key,
    required this.videoController,
    required this.showControls,
    required this.onToggleControls,
    required this.onStartControlsTimer,
    required this.onShowSkipFeedback,
  });

  @override
  Widget build(BuildContext context) {
    // Debug logging untuk track state
    debugPrint('VideoControlsWidget called - showControls: $showControls');

    if (!showControls) {
      debugPrint('Controls hidden - returning SizedBox.shrink()');
      return const SizedBox.shrink();
    }

    debugPrint('Rendering control overlay');
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // Single tap on overlay (not on buttons) should toggle controls
          onToggleControls();
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
          final skipSeconds = isLeftSide
              ? -10
              : 10; // Skip backward or forward

          try {
            // Get current position and calculate new position
            final currentPosition =
                videoController!.value.position.inSeconds;
            final videoDuration =
                videoController!.metadata.duration.inSeconds;
            final newPosition = (currentPosition + skipSeconds).clamp(
              0,
              videoDuration,
            );

            // Custom seek to new position
            videoController!.seekTo(
              Duration(seconds: newPosition.toInt()),
            );

            // Show feedback with visual indicator
            onShowSkipFeedback(isLeftSide, skipSeconds.abs(), isLeftSide);

            // Reset auto-hide timer after skip
            if (videoController!.value.isPlaying) {
              onStartControlsTimer();
            }
          } catch (e) {
            debugPrint('Error in custom double tap seek: $e');
          }
        },
        child: Container(
          color: Colors.black.withValues(alpha:0.3),
          child: Stack(
            children: [
              // Center Play/Pause Button
              Center(
                child: StreamBuilder<Duration>(
                  stream: Stream.periodic(
                    const Duration(milliseconds: 100),
                    (_) =>
                        videoController?.value.position ?? Duration.zero,
                  ),
                  builder: (context, snapshot) {
                    final isPlaying =
                        videoController?.value.isPlaying ?? false;
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
                          color: Colors.black.withValues(alpha:0.7),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.5),
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
              // Custom Seekable Progress Bar - responsive positioning
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: GestureDetector(
                  onTap:
                      null, // Prevent tap on progress bar from hiding controls
                  child: _buildCustomProgressBar(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomProgressBar(BuildContext context) {
    if (videoController == null) {
      return Container(
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: Stream.periodic(
        const Duration(milliseconds: 100),
        (_) => videoController!.value.position,
      ),
      builder: (context, snapshot) {
        final position = videoController!.value.position.inSeconds.toDouble();
        final duration = videoController!.metadata.duration.inSeconds.toDouble();

        if (duration <= 0) {
          return Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(Duration(seconds: position.toInt())),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(Duration(seconds: duration.toInt())),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Seekable progress bar
            GestureDetector(
              onTapDown: (details) {
                final RenderBox renderBox = context.findRenderObject() as RenderBox;
                final tapPosition = details.localPosition.dx;
                final width = renderBox.size.width;
                final seekPercent = (tapPosition / width).clamp(0.0, 1.0);
                final seekTime = duration * seekPercent;

                videoController!.seekTo(Duration(seconds: seekTime.toInt()));
                onStartControlsTimer();
              },
              child: Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Stack(
                  children: [
                    // Progress indicator
                    FractionallySizedBox(
                      widthFactor: (position / duration).clamp(0.0, 1.0),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Seek thumb
                    Positioned(
                      left: ((position / duration).clamp(0.0, 1.0) *
                            ((context.findRenderObject() as RenderBox?)?.size.width ?? 0.0)) - 6,
                      top: -4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }
}