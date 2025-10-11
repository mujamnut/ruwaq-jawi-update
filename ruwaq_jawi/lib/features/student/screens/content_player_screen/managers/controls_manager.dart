import 'dart:async';
import 'package:flutter/material.dart';

/// Controls manager - manages both custom controls visibility and skip animations
class ControlsManager {
  final VoidCallback onStateChanged;

  bool showControls = true;
  bool showSkipAnimation = false;
  bool isSkipForward = false;
  bool isSkipOnLeftSide = false;

  Timer? _controlsTimer;
  Timer? _skipAnimationTimer;

  ControlsManager({required this.onStateChanged});

  void startControlsTimer({required bool isPlaying}) {
    _controlsTimer?.cancel();

    // Auto-hide controls after 3 seconds when video is playing
    if (isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        showControls = false;
        onStateChanged();
      });
    }
  }

  void showControlsTemporarily({required bool isPlaying}) {
    showControls = true;
    onStateChanged();
    startControlsTimer(isPlaying: isPlaying);
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
    _skipAnimationTimer = Timer(const Duration(milliseconds: 600), () {
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
