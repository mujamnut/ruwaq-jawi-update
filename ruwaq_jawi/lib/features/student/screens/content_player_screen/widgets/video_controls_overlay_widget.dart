import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'video_bottom_controls_widget.dart';

/// Custom controls overlay - hybrid approach
/// Shows minimal controls that work WITH YouTube player
class VideoControlsOverlayWidget extends StatefulWidget {
  final YoutubePlayerController? controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onBack;
  final bool showControls;
  final VoidCallback onShowControls;
  final VoidCallback onHideControls;

  const VideoControlsOverlayWidget({
    super.key,
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.showControls,
    required this.onShowControls,
    required this.onHideControls,
    this.onBack,
  });

  @override
  State<VideoControlsOverlayWidget> createState() =>
      _VideoControlsOverlayWidgetState();
}

class _VideoControlsOverlayWidgetState
    extends State<VideoControlsOverlayWidget> {
  void _togglePlayPause() {
    if (widget.controller == null) return;

    if (widget.controller!.value.isPlaying) {
      widget.controller!.pause();
    } else {
      widget.controller!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showControls) return const SizedBox.shrink();

    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onHideControls,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Stack(
            children: [
              // Center Play/Pause Button
              Center(
                child: GestureDetector(
                  onTap: () {
                    _togglePlayPause();
                    // Don't hide controls immediately after play/pause
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (widget.controller?.value.isPlaying ?? false)
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),

              // Top bar - Back button only
              if (widget.onBack != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onBack,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: PhosphorIcon(
                            PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
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
                  onTap: () {}, // Prevent taps from hiding controls
                  child: VideoBottomControlsWidget(
                    controller: widget.controller,
                    isFullscreen: widget.isFullscreen,
                    onToggleFullscreen: widget.onToggleFullscreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
