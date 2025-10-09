import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../../core/models/video_episode.dart';
import '../../../../../core/services/video_progress_service.dart';

class VideoPlayerManager {
  final VoidCallback onStateChanged;

  YoutubePlayerController? controller;
  VideoEpisode? currentEpisode;

  VideoPlayerManager({required this.onStateChanged});

  Timer? _initializationTimer;
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
      onStateChanged();
      return;
    }

    // Validate YouTube video ID format
    if (!_isValidYouTubeId(videoId)) {
      debugPrint('❌ Invalid YouTube video ID format: $videoId');
      currentEpisode = null;
      controller = null;
      onStateChanged();
      return;
    }

    // Cancel any pending initialization
    _initializationTimer?.cancel();
    _isDisposing = false;

    // Properly dispose old controller
    final oldController = controller;
    if (oldController != null) {
      try {
        oldController.removeListener(_onPlayerStateChange);
        oldController.pause();
        oldController.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing old controller: $e');
      }
    }

    // Set to null first to trigger rebuild
    controller = null;
    currentEpisode = episode;
    onStateChanged();

    // Create new controller with proper timing
    _initializationTimer = Timer(const Duration(milliseconds: 150), () {
      if (_isDisposing) {
        debugPrint('⚠️ Initialization cancelled - disposing');
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
            hideControls: true,
            disableDragSeek: true,
            loop: false,
            useHybridComposition: true,
          ),
        );

        newController.addListener(_onPlayerStateChange);

        controller = newController;
        onStateChanged();

        debugPrint('✅ Player initialized successfully for: ${episode.title}');

        // Restore saved position with better error handling
        try {
          final savedPosition = VideoProgressService.getVideoPosition(
            episode.id,
          );
          if (savedPosition > 10) {
            Timer(const Duration(milliseconds: 800), () {
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
    _initializationTimer?.cancel();

    try {
      controller?.removeListener(_onPlayerStateChange);
      controller?.pause();
      controller?.dispose();
    } catch (e) {
      debugPrint('⚠️ Error during dispose: $e');
    }

    controller = null;
    currentEpisode = null;
  }
}
