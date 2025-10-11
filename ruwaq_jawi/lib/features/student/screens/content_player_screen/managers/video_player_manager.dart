import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../../core/models/video_episode.dart';
import '../../../../../core/services/video_progress_service.dart';

class VideoPlayerManager {
  final VoidCallback onStateChanged;

  YoutubePlayerController? controller;
  VideoEpisode? currentEpisode;
  bool isInitializing = false;

  VideoPlayerManager({required this.onStateChanged});

  Timer? _initializationTimer;
  Timer? _positionRestoreTimer;
  bool _isDisposing = false;

  void initializePlayer(VideoEpisode episode) {
    final videoId = episode.youtubeVideoId;

    debugPrint(
      '🎬 Initializing player for episode: ${episode.title} (ID: $videoId)',
    );

    if (videoId.isEmpty) {
      debugPrint('❌ Empty video ID, cannot initialize player');
      currentEpisode = null;
      controller = null;
      isInitializing = false;
      onStateChanged();
      return;
    }

    // Validate YouTube video ID format
    if (!_isValidYouTubeId(videoId)) {
      debugPrint('❌ Invalid YouTube video ID format: $videoId');
      currentEpisode = null;
      controller = null;
      isInitializing = false;
      onStateChanged();
      return;
    }

    // Cancel any pending timers to prevent memory leaks
    _initializationTimer?.cancel();
    _positionRestoreTimer?.cancel();
    _isDisposing = false;

    // Properly dispose old controller
    final oldController = controller;
    if (oldController != null) {
      try {
        // IMPORTANT: Remove listener first to prevent memory leak
        oldController.removeListener(_onPlayerStateChange);
      } catch (e) {
        debugPrint('⚠️ Error removing listener: $e');
      } finally {
        // Always dispose controller even if removeListener fails
        try {
          oldController.pause();
          oldController.dispose();
        } catch (e) {
          debugPrint('⚠️ Error disposing old controller: $e');
        }
      }
    }

    // Set initialization flag and null controller
    isInitializing = true;
    controller = null;
    currentEpisode = episode;
    onStateChanged();

    // Create new controller with proper timing
    _initializationTimer = Timer(const Duration(milliseconds: 150), () {
      if (_isDisposing) {
        debugPrint('⚠️ Initialization cancelled - disposing');
        isInitializing = false;
        return;
      }

      try {
        final newController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
            enableCaption: true,
            controlsVisibleAtStart: false,
            hideControls: true, // Hide YouTube's controls, use our custom
            disableDragSeek: false, // Allow our custom seekbar
            loop: false,
            useHybridComposition: true,
          ),
        );

        newController.addListener(_onPlayerStateChange);

        controller = newController;
        isInitializing = false;
        onStateChanged();

        debugPrint('✅ Player initialized successfully for: ${episode.title}');

        // Restore saved position with better error handling
        try {
          final savedPosition = VideoProgressService.getVideoPosition(
            episode.id,
          );
          if (savedPosition > 10) {
            // FIXED: Store timer reference to prevent memory leak
            _positionRestoreTimer?.cancel();
            _positionRestoreTimer = Timer(const Duration(milliseconds: 800), () {
              if (controller == newController && !_isDisposing) {
                controller?.seekTo(Duration(seconds: savedPosition));
              }
            });
          }
        } catch (e) {
          debugPrint('⚠️ Error restoring position: $e');
        }
      } catch (e) {
        debugPrint('❌ Error creating controller: $e');
        currentEpisode = null;
        controller = null;
        isInitializing = false;
        onStateChanged();
      }
    });
  }

  void _onPlayerStateChange() {
    try {
      if (controller != null &&
          controller!.value.isReady &&
          currentEpisode != null) {
        final position = controller!.value.position.inSeconds;

        VideoProgressService.saveVideoPosition(currentEpisode!.id, position);

        // Notify parent to check if video ended
        onStateChanged();
      }
    } catch (e) {
      debugPrint('⚠️ Error in player state change: $e');
    }
  }

  bool get isVideoEnded {
    try {
      if (controller == null || currentEpisode == null) return false;
      if (!controller!.value.isReady) return false;

      final position = controller!.value.position.inSeconds;
      final duration = controller!.metadata.duration.inSeconds;

      return position > 0 && duration > 0 && (duration - position) < 2;
    } catch (e) {
      debugPrint('⚠️ Error checking video ended: $e');
      return false;
    }
  }

  void play() {
    controller?.play();
  }

  void pause() {
    controller?.pause();
  }

  void seekTo(Duration position) {
    controller?.seekTo(position);
  }

  bool get isPlaying => controller?.value.isPlaying ?? false;

  Duration get currentPosition {
    try {
      return controller?.value.position ?? Duration.zero;
    } catch (e) {
      return Duration.zero;
    }
  }

  Duration get duration {
    try {
      if (controller == null || !controller!.value.isReady) {
        return Duration.zero;
      }
      return controller!.metadata.duration;
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Validate YouTube video ID format
  bool _isValidYouTubeId(String videoId) {
    // YouTube video IDs are typically 11 characters long and contain alphanumeric characters, hyphens, and underscores
    final regex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return regex.hasMatch(videoId);
  }

  void dispose() {
    _isDisposing = true;

    // Cancel all timers to prevent memory leaks
    _initializationTimer?.cancel();
    _positionRestoreTimer?.cancel();

    try {
      // Remove listener first to break reference loop
      controller?.removeListener(_onPlayerStateChange);
    } catch (e) {
      debugPrint('⚠️ Error removing listener during dispose: $e');
    } finally {
      // Always dispose controller and clear references
      try {
        controller?.pause();
        controller?.dispose();
      } catch (e) {
        debugPrint('⚠️ Error during controller dispose: $e');
      }

      controller = null;
      currentEpisode = null;
      isInitializing = false;
    }
  }
}
