import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../../core/theme/app_theme.dart';

class VideoPlayerControlsWidget extends StatelessWidget {
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

  const VideoPlayerControlsWidget({
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
    if (player == null) {
      return Container(
        height: 200,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

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
          // Video player
          player!,

          // Skip animation feedback
          if (showSkipAnimation) _buildSkipAnimation(),

          // Controls overlay
          if (showControls) _buildControlsOverlay(context),
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
                        ? HugeIcons.strokeRoundedForward02
                        : HugeIcons.strokeRoundedGoBackward15Sec,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSkipForward ? '+10s' : '-10s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Column(
            children: [
              // Top controls
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildControlButton(
                      icon: HugeIcons.strokeRoundedFullScreen,
                      onPressed: onToggleFullscreen,
                      tooltip: 'Skrin Penuh',
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Center play/pause button
              Center(child: _buildPlayPauseButton()),

              const Spacer(),

              // Bottom controls
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildProgressBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: HugeIcon(icon: icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    if (videoController == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return GestureDetector(
      onTap: () {
        try {
          if (videoController!.value.isPlaying) {
            videoController!.pause();
          } else {
            videoController!.play();
            onStartControlsTimer();
          }
        } catch (e) {
          debugPrint('Error toggling play/pause: $e');
        }
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Icon(
          videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (videoController == null) return const SizedBox.shrink();

    return StreamBuilder<YoutubePlayerValue>(
      stream: videoController!.value.isReady
          ? Stream.periodic(
              const Duration(milliseconds: 100),
              (_) => videoController!.value,
            )
          : null,
      builder: (context, snapshot) {
        final value = snapshot.data ?? videoController!.value;
        final position = value.position;
        final duration = value.metaData.duration;

        return Column(
          children: [
            // Progress bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primaryColor,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                thumbColor: AppTheme.primaryColor,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                trackHeight: 3,
              ),
              child: Slider(
                value: position.inMilliseconds.toDouble().clamp(
                  0.0,
                  duration.inMilliseconds.toDouble(),
                ),
                max: duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  videoController!.seekTo(
                    Duration(milliseconds: value.toInt()),
                  );
                },
              ),
            ),

            // Time indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
