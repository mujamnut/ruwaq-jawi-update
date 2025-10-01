import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoControlsManager {
  // Control visibility state
  bool _showControls = true;
  Timer? _controlsTimer;

  // Video controller reference
  YoutubePlayerController? _videoController;

  // Callbacks
  late VoidCallback _updateUI;

  VideoControlsManager({
    required VoidCallback updateUI,
  }) {
    _updateUI = updateUI;
  }

  bool get showControls => _showControls;

  void setVideoController(YoutubePlayerController? controller) {
    _videoController = controller;
  }

  // Toggle controls visibility
  void toggleControls() {
    _controlsTimer?.cancel();

    _showControls = !_showControls;
    _updateUI();

    // Start appropriate timer based on mode and playback state
    if (_showControls && _videoController?.value.isPlaying == true) {
      startControlsTimerForMode();
    }
  }

  // Show controls permanently (until next timer)
  void showControlsForever() {
    _controlsTimer?.cancel();
    _showControls = true;
    _updateUI();
  }

  // Hide controls immediately
  void hideControls() {
    _controlsTimer?.cancel();
    _showControls = false;
    _updateUI();
  }

  // Start controls auto-hide timer
  void startControlsTimer() {
    // Fallback method - use the optimized version instead
    startControlsTimerForMode();
  }

  // Start controls timer based on current mode
  void startControlsTimerForMode() {
    _controlsTimer?.cancel();

    // Normal timer for portrait mode
    const duration = Duration(seconds: 4);

    debugPrint('Starting controls timer for ${duration.inSeconds}s');

    _controlsTimer = Timer(duration, () {
      if (_videoController?.value.isPlaying == true) {
        debugPrint('Timer expired - hiding controls');
        _showControls = false;
        _updateUI();
      }
    });
  }

  // Handle video playback state changes
  void handleVideoPlaybackStateChange(bool isPlaying) {
    if (isPlaying && _showControls) {
      startControlsTimerForMode();
    } else if (!isPlaying) {
      showControlsForever();
    }
  }

  // Show controls when transitioning fullscreen states
  void handleFullscreenTransition() {
    showControlsForever();

    // Start auto-hide timer if video is playing
    if (_videoController?.value.isPlaying == true) {
      startControlsTimerForMode();
    }
  }

  // Handle tap gestures for controls
  void handleTapToToggle() {
    toggleControls();
  }

  // Handle double tap gestures for skip
  void handleDoubleTapSkip() {
    // Show controls briefly after skip
    if (_videoController?.value.isPlaying == true) {
      startControlsTimerForMode();
    }
  }

  // Force show controls (for UI interactions)
  void forceShowControls() {
    _showControls = true;
    _updateUI();
  }

  // Check if controls should be visible for current state
  bool shouldShowControls() {
    return _showControls;
  }

  // Get controls opacity for smooth transitions
  double getControlsOpacity() {
    return _showControls ? 1.0 : 0.0;
  }

  // Dispose timer and cleanup
  void dispose() {
    _controlsTimer?.cancel();
  }
}