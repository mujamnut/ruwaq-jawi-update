import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

class FullscreenVideoWidget extends StatelessWidget {
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

  const FullscreenVideoWidget({
    super.key,
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
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('🎬 FullscreenVideoWidget build - showControls=$showControls');

    if (player == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // In fullscreen mode, always show controls by default
    return GestureDetector(
      onTap: onToggleControls,
      onDoubleTapDown: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        final tapPosition = details.globalPosition.dx;
        final isLeftSide = tapPosition < screenWidth / 2;

        if (videoController != null) {
          try {
            final currentPosition = videoController!.value.position.inSeconds;
            final skipSeconds = 10;

            if (isLeftSide) {
              // Skip backward
              final newPosition = (currentPosition - skipSeconds).clamp(
                0,
                double.infinity,
              );
              videoController!.seekTo(Duration(seconds: newPosition.toInt()));
              onShowSkipFeedback(true, skipSeconds, true);
            } else {
              // Skip forward
              final newPosition = currentPosition + skipSeconds;
              videoController!.seekTo(Duration(seconds: newPosition.toInt()));
              onShowSkipFeedback(false, skipSeconds, false);
            }
          } catch (e) {
            debugPrint('Error during double tap seek: $e');
          }
        }
      },
      child: Stack(
        children: [
          // Video player taking full screen with proper fit
          Positioned.fill(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: player!,
              ),
            ),
          ),

          // Skip animation feedback
          if (showSkipAnimation) _buildSkipAnimation(),

          // Always show controls in fullscreen - directly control visibility
          if (showControls)
            Positioned.fill(
              child: _buildControlsOverlay(context),
            ),
        ],
      ),
    );
  }

  Widget _buildSkipAnimation() {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: showSkipAnimation ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: isSkipForward
                        ? HugeIcons.strokeRoundedArrowRight01
                        : HugeIcons.strokeRoundedArrowLeft01,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '10s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(BuildContext context) {
    debugPrint('🎬 _buildControlsOverlay called - showControls=$showControls');
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Exit fullscreen button (top-right)
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: onToggleFullscreen,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancelSquare,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Center play/pause button
          Center(
            child: GestureDetector(
              onTap: () {
                if (videoController != null) {
                  if (videoController!.value.isPlaying) {
                    videoController!.pause();
                  } else {
                    videoController!.play();
                    onStartControlsTimer();
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: videoController?.value.isPlaying == true
                      ? HugeIcons.strokeRoundedPause
                      : HugeIcons.strokeRoundedPlay,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),

          // Bottom controls with seek bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    if (videoController == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          StreamBuilder(
            stream: Stream.periodic(const Duration(milliseconds: 500)),
            builder: (context, snapshot) {
              final position = videoController!.value.position;
              final duration = videoController!.metadata.duration;

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: position.inSeconds.toDouble(),
                      min: 0,
                      max: duration.inSeconds.toDouble(),
                      activeColor: Colors.red,
                      inactiveColor: Colors.white.withValues(alpha: 0.3),
                      onChanged: (value) {
                        videoController!.seekTo(Duration(seconds: value.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}