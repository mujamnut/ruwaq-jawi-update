import 'dart:async';
import 'package:flutter/material.dart';

class ControlsManager {
  final VoidCallback onStateChanged;

  bool showControls = true;
  bool showSkipAnimation = false;
  bool isSkipForward = false;
  bool isSkipOnLeftSide = false;

  Timer? _controlsTimer;
  Timer? _skipAnimationTimer;

  ControlsManager({required this.onStateChanged});

  void startControlsTimer({required bool isFullscreen, required bool isPlaying}) {
    _controlsTimer?.cancel();

    // Only auto-hide in fullscreen and when video is playing
    if (isFullscreen && isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 5), () {
        showControls = false;
        onStateChanged();
      });
    }
  }

  void toggleControls({required bool isFullscreen, required bool isPlaying}) {
    showControls = !showControls;
    onStateChanged();

    if (showControls) {
      startControlsTimer(isFullscreen: isFullscreen, isPlaying: isPlaying);
    } else {
      _controlsTimer?.cancel();
    }
  }

  void showControlsTemporarily({required bool isFullscreen, required bool isPlaying}) {
    showControls = true;
    onStateChanged();
    startControlsTimer(isFullscreen: isFullscreen, isPlaying: isPlaying);
  }

  void hideControls() {
    showControls = false;
    _controlsTimer?.cancel();
    onStateChanged();
  }

  void showSkipFeedback(bool isBackward, int seconds, bool isLeftSide) {
    showSkipAnimation = true;
    isSkipForward = !isBackward;
    isSkipOnLeftSide = isLeftSide;
    onStateChanged();

    _skipAnimationTimer?.cancel();
    _skipAnimationTimer = Timer(const Duration(milliseconds: 800), () {
      showSkipAnimation = false;
      onStateChanged();
    });
  }

  void cancelTimers() {
    _controlsTimer?.cancel();
    _skipAnimationTimer?.cancel();
  }

  void dispose() {
    cancelTimers();
  }
}
