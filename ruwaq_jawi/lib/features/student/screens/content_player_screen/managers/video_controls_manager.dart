import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VideoControlsManager {
  // Control visibility state
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isFullscreen = false;

  // Skip animation state
  bool _showSkipAnimation = false;
  bool _isSkipForward = false;
  bool _isSkipOnLeftSide = false;
  Timer? _skipAnimationTimer;

  // Callbacks
  final VoidCallback? onStateChanged;

  VideoControlsManager({this.onStateChanged});

  // Getters
  bool get showControls => _showControls;
  bool get isFullscreen => _isFullscreen;
  bool get showSkipAnimation => _showSkipAnimation;
  bool get isSkipForward => _isSkipForward;
  bool get isSkipOnLeftSide => _isSkipOnLeftSide;

  void showSkipFeedback(bool isBackward, int seconds, bool isLeftSide) {
    _showSkipAnimation = true;
    _isSkipForward = !isBackward;
    _isSkipOnLeftSide = isLeftSide;
    onStateChanged?.call();

    // Hide animation after 800ms
    _skipAnimationTimer?.cancel();
    _skipAnimationTimer = Timer(const Duration(milliseconds: 800), () {
      _showSkipAnimation = false;
      onStateChanged?.call();
    });
  }

  void startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      _showControls = false;
      onStateChanged?.call();
    });
  }

  void showControlsForever() {
    _controlsTimer?.cancel();
    _showControls = true;
    onStateChanged?.call();
  }

  void toggleControls() {
    _showControls = !_showControls;
    onStateChanged?.call();
  }

  void toggleFullscreen() {
    _isFullscreen = !_isFullscreen;
    debugPrint('🎬 toggleFullscreen: isFullscreen=$_isFullscreen');

    if (_isFullscreen) {
      // Enter fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // ALWAYS show controls when entering fullscreen
      _showControls = true;
      _controlsTimer?.cancel();
      debugPrint('🎬 Fullscreen entered - showControls=$_showControls');
      // Start timer to hide controls after 3 seconds
      startControlsTimer();
    } else {
      // Exit fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      _showControls = true;
      _controlsTimer?.cancel();
      debugPrint('🎬 Fullscreen exited - showControls=$_showControls');
    }

    onStateChanged?.call();
  }

  void dispose() {
    _skipAnimationTimer?.cancel();
    _controlsTimer?.cancel();

    // Reset system UI and orientation on dispose
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }
}
