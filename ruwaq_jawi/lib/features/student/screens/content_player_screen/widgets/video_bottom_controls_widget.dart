import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../utils/video_helpers.dart';

class VideoBottomControlsWidget extends StatefulWidget {
  final YoutubePlayerController? controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  const VideoBottomControlsWidget({
    super.key,
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  @override
  State<VideoBottomControlsWidget> createState() =>
      _VideoBottomControlsWidgetState();
}

class _VideoBottomControlsWidgetState
    extends State<VideoBottomControlsWidget> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _startUpdateTimer();
  }

  @override
  void didUpdateWidget(VideoBottomControlsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _startUpdateTimer();
    }
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    if (widget.controller != null) {
      _updateTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) {
          if (mounted) setState(() {});
        },
      );
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.controller?.value.position ?? Duration.zero;
    final duration = widget.controller?.metadata.duration ?? Duration.zero;
    final value = VideoHelpers.calculateProgress(position, duration);

    return Container(
      padding: EdgeInsets.only(
        left: widget.isFullscreen ? 16 : 12,
        right: widget.isFullscreen ? 16 : 12,
        top: 20,
        bottom: widget.isFullscreen ? 16 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Bar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: widget.isFullscreen ? 4 : 3,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: widget.isFullscreen ? 7 : 6,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 14,
              ),
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
              thumbColor: AppTheme.primaryColor,
              overlayColor: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            child: Slider(
              value: value,
              onChanged: (newValue) {
                if (widget.controller != null) {
                  final newPosition = VideoHelpers.calculatePositionFromValue(
                    newValue,
                    duration,
                  );
                  widget.controller!.seekTo(newPosition);
                }
              },
            ),
          ),

          // Time display and fullscreen button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Time display
                Text(
                  '${VideoHelpers.formatDuration(position)} / ${VideoHelpers.formatDuration(duration)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.isFullscreen ? 13 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // Fullscreen toggle button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onToggleFullscreen,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: PhosphorIcon(
                        widget.isFullscreen
                            ? PhosphorIcons.arrowsIn(PhosphorIconsStyle.bold)
                            : PhosphorIcons.arrowsOut(PhosphorIconsStyle.bold),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
