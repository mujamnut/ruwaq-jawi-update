import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullscreenHandler {
  // Fullscreen state tracking
  bool _isFullScreen = false;

  // Callbacks
  late VoidCallback _updateUI;
  late VoidCallback _showControls;
  late VoidCallback _startControlsTimer;

  FullscreenHandler({
    required VoidCallback updateUI,
    required VoidCallback showControls,
    required VoidCallback startControlsTimer,
  }) {
    _updateUI = updateUI;
    _showControls = showControls;
    _startControlsTimer = startControlsTimer;
  }

  bool get isFullScreen => _isFullScreen;

  // Initialize system UI for fullscreen readiness
  void initializeSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Handle fullscreen state changes
  void handleFullScreenStateChange(bool isFullScreen) {
    debugPrint('Fullscreen state changed: $isFullScreen');

    _isFullScreen = isFullScreen;

    if (isFullScreen) {
      // Entering fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      // Allow all orientations in fullscreen
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Exiting fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Return to portrait for normal viewing
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // Show controls when transitioning fullscreen states
    _showControls();
    _updateUI();

    // Start auto-hide timer if video is playing (handled by caller)
    _startControlsTimer();
  }

  // Cleanup when disposing
  void dispose() {
    // Reset system UI and orientation on dispose
    // Ensure we exit fullscreen if still in fullscreen
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    // Reset to portrait orientation only
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Restore system UI bars
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  // Check if current state should show AppBar and tabs
  bool shouldShowNormalUI() {
    return !_isFullScreen;
  }

  // Get appropriate system UI overlay style for current state
  SystemUiOverlayStyle getSystemUIOverlayStyle() {
    if (_isFullScreen) {
      return const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      );
    } else {
      return const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      );
    }
  }
}