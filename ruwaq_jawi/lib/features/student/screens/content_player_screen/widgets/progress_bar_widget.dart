import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../../core/theme/app_theme.dart';

class ProgressBarWidget extends StatelessWidget {
  final YoutubePlayerController? videoController;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  const ProgressBarWidget({
    super.key,
    required this.videoController,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    if (videoController == null) {
      return Container(
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
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
        final position = snapshot.data ?? Duration.zero;
        final duration = videoController!.metadata.duration;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        return Column(
          children: [
            // Time display and fullscreen button
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Combined duration display on left
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Fullscreen button on right
                  GestureDetector(
                    onTap: onToggleFullscreen,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: HugeIcon(
                        icon: isFullscreen
                            ? HugeIcons.strokeRoundedCancelSquare
                            : HugeIcons.strokeRoundedFullScreen,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Custom draggable progress bar
            GestureDetector(
              onTapDown: (details) =>
                  _onProgressBarTap(context, details, duration),
              onPanUpdate: (details) =>
                  _onProgressBarPan(context, details, duration),
              child: SizedBox(
                height: 20, // Larger touch area
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background track
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Progress track
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Seek handle
                    Positioned(
                      left:
                          (MediaQuery.of(context).size.width - 48) *
                              progress.clamp(0.0, 1.0) -
                          8, // Account for handle width and padding
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
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

  void _onProgressBarTap(
    BuildContext context,
    TapDownDetails details,
    Duration duration,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final progress = (localPosition.dx / renderBox.size.width).clamp(0.0, 1.0);
    final newPosition = Duration(
      milliseconds: (duration.inMilliseconds * progress).toInt(),
    );

    videoController?.seekTo(newPosition);
  }

  void _onProgressBarPan(
    BuildContext context,
    DragUpdateDetails details,
    Duration duration,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final progress = (localPosition.dx / renderBox.size.width).clamp(0.0, 1.0);
    final newPosition = Duration(
      milliseconds: (duration.inMilliseconds * progress).toInt(),
    );

    videoController?.seekTo(newPosition);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}
