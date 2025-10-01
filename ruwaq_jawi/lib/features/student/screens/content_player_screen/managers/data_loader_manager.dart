import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../../core/models/video_kitab.dart';
import '../../../../../core/models/video_episode.dart';
import '../../../../../core/providers/kitab_provider.dart';
import '../../../../../core/services/video_progress_service.dart';
import '../services/notification_helper.dart';

class DataLoaderManager {
  // Data state
  VideoKitab? _kitab;
  List<VideoEpisode> _episodes = [];
  VideoEpisode? _currentEpisode;
  bool _isDataLoading = true;
  int _currentEpisodeIndex = 0;
  final Map<String, int> _episodePositions = {}; // episodeId -> seconds

  // Controllers
  YoutubePlayerController? _videoController;
  PdfViewerController? _pdfController;
  bool _isVideoLoading = true;

  // Callbacks
  final VoidCallback? onStateChanged;
  final Function(String)? onShowNotification;

  DataLoaderManager({this.onStateChanged, this.onShowNotification});

  // Getters
  VideoKitab? get kitab => _kitab;
  List<VideoEpisode> get episodes => _episodes;
  VideoEpisode? get currentEpisode => _currentEpisode;
  bool get isDataLoading => _isDataLoading;
  int get currentEpisodeIndex => _currentEpisodeIndex;
  YoutubePlayerController? get videoController => _videoController;
  PdfViewerController? get pdfController => _pdfController;
  bool get isVideoLoading => _isVideoLoading;

  Future<void> loadRealData(BuildContext context, String kitabId, String? episodeId) async {
    try {
      final kitabProvider = context.read<KitabProvider>();

      // Get VideoKitab data from Supabase
      final videoKitabList = kitabProvider.activeVideoKitab;
      try {
        _kitab = videoKitabList.firstWhere((vk) => vk.id == kitabId);
      } catch (e) {
        debugPrint('VideoKitab not found: $e');
        _isDataLoading = false;
        onStateChanged?.call();
        return;
      }

      // Load episodes from video_kitab table
      if (_kitab?.hasVideos == true) {
        _episodes = await kitabProvider.loadKitabVideos(kitabId);

        // Sort episodes by part number in ascending order (1, 2, 3, 4...)
        _episodes.sort((a, b) => a.partNumber.compareTo(b.partNumber));

        // Debug: Print episode order after sorting
        debugPrint('📝 Loaded and sorted episodes:');
        for (int i = 0; i < _episodes.length; i++) {
          debugPrint('📝 Index $i: Part ${_episodes[i].partNumber} - ${_episodes[i].title}');
        }

        // Find current episode
        if (episodeId != null) {
          final episodeIndex = _episodes.indexWhere((ep) => ep.id == episodeId);
          if (episodeIndex != -1) {
            _currentEpisodeIndex = episodeIndex;
            _currentEpisode = _episodes[episodeIndex];
          } else {
            _currentEpisode = _episodes.isNotEmpty ? _episodes.first : null;
            _currentEpisodeIndex = 0;
          }
        } else {
          _currentEpisode = _episodes.isNotEmpty ? _episodes.first : null;
          _currentEpisodeIndex = 0;
        }
      }

      // Initialize players
      await _initializePlayers();

      _isDataLoading = false;
      onStateChanged?.call();
    } on SocketException catch (e) {
      debugPrint('Network error loading data: $e');
      _isDataLoading = false;
      onStateChanged?.call();
      onShowNotification?.call('Tiada sambungan internet. Sila semak sambungan anda.');
    } on TimeoutException catch (e) {
      debugPrint('Timeout loading data: $e');
      _isDataLoading = false;
      onStateChanged?.call();
      onShowNotification?.call('Sambungan terlalu lambat. Sila cuba lagi.');
    } catch (e) {
      debugPrint('Error loading Supabase data: $e');
      _isDataLoading = false;
      onStateChanged?.call();
      onShowNotification?.call('Ralat memuat kandungan. Sila cuba lagi.');
    }
  }

  Future<void> _initializePlayers() async {
    // Determine video ID from real Supabase data
    String? videoId;
    if (_kitab?.hasVideos == true && _currentEpisode != null) {
      videoId = _currentEpisode!.youtubeVideoId;
    }

    // Initialize YouTube player with real data
    if (videoId != null && videoId.isNotEmpty) {
      _videoController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: true,
          controlsVisibleAtStart: false,
          forceHD: false,
          hideControls: true, // Hide in normal view (we use custom controls)
          disableDragSeek: true,
          showLiveFullscreenButton: true, // Allow native fullscreen
          loop: false,
          useHybridComposition: true,
        ),
      );

      _videoController!.addListener(() {
        // Notify state change when fullscreen changes
        onStateChanged?.call();

        // Track video position for progress tracking
        try {
          if (_videoController != null && _videoController!.value.isReady) {
            final lastVideoPosition = _videoController!.value.position.inSeconds;
            if (_currentEpisode != null) {
              _episodePositions[_currentEpisode!.id] = lastVideoPosition;
            }
          }
        } catch (e) {
          debugPrint('Error in video controller listener: $e');
        }
      });

      // Restore saved video position
      if (_currentEpisode != null) {
        final savedPosition = VideoProgressService.getVideoPosition(_currentEpisode!.id);
        if (savedPosition > 10) {
          // Only restore if more than 10 seconds
          _videoController!.seekTo(Duration(seconds: savedPosition));
        }
      }

      _isVideoLoading = false;
    } else {
      _isVideoLoading = false;
    }

    // Initialize PDF controller for real PDF data
    _pdfController = PdfViewerController();
    onStateChanged?.call();
  }

  void switchToEpisode(int index) {
    debugPrint('🔄 switchToEpisode called with index: $index');
    debugPrint('🔄 Current index: $_currentEpisodeIndex');
    debugPrint('🔄 Episodes length: ${_episodes.length}');

    if (index < 0 || index >= _episodes.length || index == _currentEpisodeIndex) {
      debugPrint('🔄 Invalid index, returning early');
      return;
    }

    // Save current episode position
    try {
      final currentPos = _videoController?.value.position.inSeconds ?? 0;
      if (_currentEpisode != null) {
        _episodePositions[_currentEpisode!.id] = currentPos;
      }
    } catch (_) {}

    _currentEpisodeIndex = index;
    _currentEpisode = _episodes[index];
    onStateChanged?.call();

    debugPrint('🔄 Switched to episode index: $index');
    debugPrint('🔄 New episode part number: ${_currentEpisode?.partNumber}');
    debugPrint('🔄 New episode title: ${_currentEpisode?.title}');

    final newVideoId = _currentEpisode!.youtubeVideoId;

    if (_videoController != null) {
      try {
        _videoController!.load(newVideoId);

        // Check for saved position first, then fall back to episode position
        final savedPos = VideoProgressService.getVideoPosition(_currentEpisode!.id);
        final resumePos = savedPos > 10 ? savedPos : (_episodePositions[_currentEpisode!.id] ?? 0);

        if (resumePos > 0) {
          // Wait for controller to be ready before seeking
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (_videoController != null) {
              try {
                _videoController!.seekTo(Duration(seconds: resumePos));
              } catch (e) {
                debugPrint('Error seeking to position: $e');
              }
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading video: $e');
        onShowNotification?.call('Ralat memuat video: $e');
      }
    }
  }

  void dispose() {
    _videoController?.dispose();
  }
}