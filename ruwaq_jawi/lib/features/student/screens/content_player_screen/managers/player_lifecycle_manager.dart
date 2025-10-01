import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class PlayerLifecycleManager {
  // Progress tracking
  Timer? _progressTimer;
  bool _hidePlayer = false;

  // Callbacks
  final VoidCallback? onStateChanged;

  PlayerLifecycleManager({this.onStateChanged});

  // Getters
  bool get hidePlayer => _hidePlayer;

  void initializeProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {});
  }

  Future<bool> onWillPop(
    BuildContext context,
    YoutubePlayerController? videoController,
  ) async {
    // Detach player from widget tree before pop to avoid WebView teardown crash
    detachPlayer(videoController);
    // Allow a frame so UI can paint the hidden state, then manually pop
    await Future<void>.delayed(const Duration(milliseconds: 32));
    if (context.mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      }
    }
    return false; // we handled the pop manually
  }

  void detachPlayer(YoutubePlayerController? videoController) {
    try {
      if (videoController?.value.isFullScreen ?? false) {
        videoController?.toggleFullScreenMode();
      }
    } catch (_) {}
    try {
      videoController?.pause();
    } catch (_) {}

    _hidePlayer = true;
    onStateChanged?.call();
  }

  void deactivate(YoutubePlayerController? videoController) {
    // Ensure video is paused when screen is transitioning away
    try {
      videoController?.pause();
    } catch (_) {}
  }

  void dispose(YoutubePlayerController? videoController) {
    _progressTimer?.cancel();
    videoController?.dispose();
  }
}
