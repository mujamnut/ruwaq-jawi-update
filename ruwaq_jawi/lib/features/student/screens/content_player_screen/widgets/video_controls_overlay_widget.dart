import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'video_bottom_controls_widget.dart';

class VideoControlsOverlayWidget extends StatelessWidget {
  final YoutubePlayerController? controller;
  final bool showControls;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onHideControls;
  final VoidCallback onTogglePlayPause;
  final Function(bool isFullscreen, bool isPlaying) onStartControlsTimer;

  const VideoControlsOverlayWidget({
    super.key,
    required this.controller,
    required this.showControls,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onHideControls,
    required this.onTogglePlayPause,
    required this.onStartControlsTimer,
  });

  @override
  Widget build(BuildContext context) {
    if (!showControls) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Stack(
          children: [
            // Tap to hide controls (background layer)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onHideControls,
                child: Container(color: Colors.transparent),
              ),
            ),

            // Center Play/Pause (on top of gesture detector)
            Center(
              child: GestureDetector(
                onTap: () {
                  onTogglePlayPause();
                  if (controller != null && controller!.value.isPlaying) {
                    onStartControlsTimer(isFullscreen, true);
                  }
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: StreamBuilder<bool>(
                    stream: Stream.periodic(
                      const Duration(milliseconds: 500),
                      (_) => controller?.value.isPlaying ?? false,
                    ),
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return Icon(
                        isPlaying
                            ? PhosphorIcons.pause()
                            : PhosphorIcons.play(),
                        color: Colors.white,
                        size: 28,
                      );
                    },
                  ),
                ),
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  // Prevent tap from hiding controls when interacting with bottom controls
                },
                child: VideoBottomControlsWidget(
                  controller: controller,
                  isFullscreen: isFullscreen,
                  onToggleFullscreen: onToggleFullscreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
