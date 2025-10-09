import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../utils/video_helpers.dart';

class VideoBottomControlsWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: isFullscreen ? 16 : 12,
        right: isFullscreen ? 16 : 12,
        top: 20,
        bottom: isFullscreen ? 16 : 12,
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
      child: StreamBuilder<Map<String, Duration>>(
        stream: Stream.periodic(
          const Duration(milliseconds: 250),
          (_) => {
            'position': controller?.value.position ?? Duration.zero,
            'duration': controller?.metadata.duration ?? Duration.zero,
          },
        ),
        builder: (context, snapshot) {
          final data =
              snapshot.data ??
              {'position': Duration.zero, 'duration': Duration.zero};
          final position = data['position']!;
          final duration = data['duration']!;
          final value = VideoHelpers.calculateProgress(position, duration);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress Bar
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: isFullscreen ? 4 : 3,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: isFullscreen ? 7 : 6,
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
                    if (controller != null) {
                      final newPosition =
                          VideoHelpers.calculatePositionFromValue(
                            newValue,
                            duration,
                          );
                      controller!.seekTo(newPosition);
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
                        fontSize: isFullscreen ? 13 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Exit fullscreen button (only in fullscreen)
                    if (isFullscreen)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onToggleFullscreen,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: PhosphorIcon(
                              PhosphorIcons.arrowsIn(PhosphorIconsStyle.bold),
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
          );
        },
      ),
    );
  }
}
