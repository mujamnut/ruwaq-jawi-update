import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YoutubePlayerConfigWidget extends StatelessWidget {
  final YoutubePlayerController controller;
  final VoidCallback? onReady;
  final Function(YoutubeMetaData)? onEnded;
  final Widget Function(BuildContext, Widget) builder;

  const YoutubePlayerConfigWidget({
    super.key,
    required this.controller,
    required this.builder,
    this.onReady,
    this.onEnded,
  });

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      builder: builder,
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: false, // We use custom progress
        topActions: const [], // Remove top controls
        bottomActions: const [], // Remove all bottom controls (including fullscreen)
        progressColors: const ProgressBarColors(
          playedColor: Colors.transparent,
          handleColor: Colors.transparent,
          bufferedColor: Colors.transparent,
          backgroundColor: Colors.transparent,
        ),
        aspectRatio: 16 / 9,
        onReady: onReady,
        onEnded: onEnded,
      ),
    );
  }
}