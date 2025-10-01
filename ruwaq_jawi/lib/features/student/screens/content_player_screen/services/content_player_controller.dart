import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:provider/provider.dart';
import '../../../../../core/models/video_kitab.dart';
import '../../../../../core/models/video_episode.dart';
import '../../../../../core/providers/kitab_provider.dart';
import '../../../../../core/providers/auth_provider.dart';
import '../../../../../core/services/local_favorites_service.dart';
import '../../../../../core/services/video_progress_service.dart';
import '../../../../../core/services/pdf_cache_service.dart';

class ContentPlayerController {
  // State management
  late BuildContext _context;
  late VoidCallback _updateUI;

  // Data
  VideoKitab? kitab;
  List<VideoEpisode> episodes = [];
  VideoEpisode? currentEpisode;
  int currentEpisodeIndex = 0;
  final Map<String, int> episodePositions = {};
  int lastVideoPosition = 0;

  // Controllers
  YoutubePlayerController? videoController;
  PdfViewerController? pdfController;

  // PDF state
  String? cachedPdfPath;
  bool isPdfDownloading = false;
  double downloadProgress = 0.0;
  int currentPdfPage = 1;
  int totalPdfPages = 0;

  // Save state
  bool isSaved = false;
  bool isSaveLoading = false;

  // Loading state
  bool isDataLoading = true;
  bool isVideoLoading = true;

  ContentPlayerController({
    required BuildContext context,
    required VoidCallback updateUI,
  }) {
    _context = context;
    _updateUI = updateUI;
  }

  void dispose() {
    videoController?.dispose();
    pdfController?.dispose();
  }

  // Main data loading
  Future<void> loadRealData(String kitabId, String? episodeId) async {
    try {
      final kitabProvider = _context.read<KitabProvider>();

      // Get VideoKitab data from Supabase
      final videoKitabList = kitabProvider.activeVideoKitab;
      try {
        kitab = videoKitabList.firstWhere((vk) => vk.id == kitabId);
      } catch (e) {
        debugPrint('VideoKitab not found: $e');
        isDataLoading = false;
        _updateUI();
        return;
      }

      // Load episodes from video_kitab table
      if (kitab?.hasVideos == true) {
        episodes = await kitabProvider.loadKitabVideos(kitabId);

        // Sort episodes by part number in ascending order
        episodes.sort((a, b) => a.partNumber.compareTo(b.partNumber));

        // Debug: Print episode order after sorting
        debugPrint('📝 Loaded and sorted episodes:');
        for (int i = 0; i < episodes.length; i++) {
          debugPrint(
            '📝 Index $i: Part ${episodes[i].partNumber} - ${episodes[i].title}',
          );
        }

        // Find current episode
        if (episodeId != null) {
          final episodeIndex = episodes.indexWhere(
            (ep) => ep.id == episodeId,
          );
          if (episodeIndex != -1) {
            currentEpisodeIndex = episodeIndex;
            currentEpisode = episodes[episodeIndex];
          } else {
            currentEpisode = episodes.isNotEmpty ? episodes.first : null;
            currentEpisodeIndex = 0;
          }
        } else {
          currentEpisode = episodes.isNotEmpty ? episodes.first : null;
          currentEpisodeIndex = 0;
        }
      }

      // Initialize players
      await initializePlayers();

      // Check save status after episode is loaded
      checkSaveStatus();

      // Check PDF cache
      await checkPdfCache();

      isDataLoading = false;
      _updateUI();

    } catch (e) {
      debugPrint('Error loading Supabase data: $e');
      isDataLoading = false;
      _updateUI();

      if (_context.mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuat kandungan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Episode management
  void switchToEpisode(int index) {
    debugPrint('🔄 switchToEpisode called with index: $index');
    debugPrint('🔄 Current index: $currentEpisodeIndex');
    debugPrint('🔄 Episodes length: ${episodes.length}');

    if (index < 0 || index >= episodes.length || index == currentEpisodeIndex) {
      debugPrint('🔄 Invalid index, returning early');
      return;
    }

    // Check episode access before switching
    final targetEpisode = episodes[index];
    if (!canAccessEpisode(targetEpisode)) {
      debugPrint('🔒 Episode ${targetEpisode.partNumber} is locked (premium)');
      return;
    }

    // Save current episode position
    try {
      final currentPos = videoController?.value.position.inSeconds ?? 0;
      if (currentEpisode != null) {
        episodePositions[currentEpisode!.id] = currentPos;
      }
    } catch (_) {}

    currentEpisodeIndex = index;
    currentEpisode = episodes[index];
    _updateUI();

    debugPrint('🔄 Switched to episode index: $index');
    debugPrint('🔄 New episode part number: ${currentEpisode?.partNumber}');
    debugPrint('🔄 New episode title: ${currentEpisode?.title}');

    // Check save status for new episode
    checkSaveStatus();

    final newVideoId = currentEpisode!.youtubeVideoId;

    if (videoController != null) {
      try {
        videoController!.load(newVideoId);

        // Check for saved position first, then fall back to episode position
        final savedPos = VideoProgressService.getVideoPosition(
          currentEpisode!.id,
        );
        final resumePos = savedPos > 10
            ? savedPos
            : (episodePositions[currentEpisode!.id] ?? 0);

        if (resumePos > 0) {
          // Wait for controller to be ready before seeking
          Future.delayed(const Duration(milliseconds: 1000), () {
            try {
              videoController?.seekTo(Duration(seconds: resumePos));
            } catch (e) {
              debugPrint('Error seeking to position: $e');
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading video: $e');
        if (_context.mounted) {
          ScaffoldMessenger.of(_context).showSnackBar(
            SnackBar(
              content: Text('Ralat memuat video: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Player initialization
  Future<void> initializePlayers() async {
    // Determine video ID from real Supabase data
    String? videoId;
    if (kitab?.hasVideos == true && currentEpisode != null) {
      videoId = currentEpisode!.youtubeVideoId;
    }

    // Initialize YouTube player with real data
    if (videoId != null && videoId.isNotEmpty) {
      videoController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: false,
          controlsVisibleAtStart: false,
          forceHD: false,
          hideControls: true,
          disableDragSeek: true,
          showLiveFullscreenButton: true,
          loop: false,
          useHybridComposition: true,
          hideThumbnail: false,
        ),
      );

      videoController!.addListener(() {
        // Track video position for progress tracking
        try {
          if (videoController != null &&
              videoController!.value.isReady) {
            lastVideoPosition = videoController!.value.position.inSeconds;
            if (currentEpisode != null) {
              episodePositions[currentEpisode!.id] = lastVideoPosition;
            }
          }
        } catch (e) {
          debugPrint('Error in video controller listener: $e');
        }
      });

      // Restore saved video position
      if (currentEpisode != null) {
        final savedPosition = VideoProgressService.getVideoPosition(
          currentEpisode!.id,
        );
        if (savedPosition > 10) {
          // Only restore if more than 10 seconds
          videoController!.seekTo(Duration(seconds: savedPosition));
        }
      }

      isVideoLoading = false;
      _updateUI();
    } else {
      isVideoLoading = false;
      _updateUI();
    }

    // Initialize PDF controller for real PDF data
    pdfController = PdfViewerController();
    _updateUI();
  }

  // PDF handling
  Future<void> checkPdfCache() async {
    if (kitab?.pdfUrl != null && kitab!.pdfUrl!.isNotEmpty) {
      final cachedPath = PdfCacheService.getCachedPdfPath(kitab!.pdfUrl!);
      if (cachedPath != null) {
        cachedPdfPath = cachedPath;
        _updateUI();

        // Update access time
        await PdfCacheService.updateLastAccessed(kitab!.pdfUrl!);
      }
    }
  }

  Future<void> downloadPdfIfNeeded() async {
    if (kitab?.pdfUrl == null || kitab!.pdfUrl!.isEmpty) return;

    // Check if already cached
    if (PdfCacheService.isPdfCached(kitab!.pdfUrl!)) {
      cachedPdfPath = PdfCacheService.getCachedPdfPath(kitab!.pdfUrl!);
      _updateUI();
      return;
    }

    // Download and cache PDF
    isPdfDownloading = true;
    downloadProgress = 0.0;
    _updateUI();

    try {
      final success = await PdfCacheService.cachePdf(
        kitab!.pdfUrl!,
        onProgress: (progress) {
          downloadProgress = progress;
          _updateUI();
        },
      );

      if (success) {
        cachedPdfPath = PdfCacheService.getCachedPdfPath(kitab!.pdfUrl!);

        if (_context.mounted) {
          ScaffoldMessenger.of(_context).showSnackBar(
            const SnackBar(
              content: Text('PDF disimpan untuk akses offline'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (_context.mounted) {
          ScaffoldMessenger.of(_context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memuat turun PDF. Sila cuba lagi.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (_context.mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuat turun PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      isPdfDownloading = false;
      _updateUI();
    }
  }

  // Save/unsave functionality
  void checkSaveStatus() {
    if (currentEpisode != null) {
      isSaved = LocalFavoritesService.isVideoEpisodeFavorite(
        currentEpisode!.id,
        kitab?.id ?? '',
      );
      _updateUI();
    }
  }

  Future<void> toggleSaved() async {
    if (currentEpisode == null || isSaveLoading) return;

    isSaveLoading = true;
    _updateUI();

    try {
      bool success;
      if (isSaved) {
        success = await LocalFavoritesService.removeVideoEpisodeFromFavorites(
          currentEpisode!.id,
        );
      } else {
        success = await LocalFavoritesService.addVideoEpisodeToFavorites(
          currentEpisode!.id,
          kitab?.id ?? '',
        );
      }

      if (success) {
        isSaved = !isSaved;

        if (_context.mounted) {
          ScaffoldMessenger.of(_context).showSnackBar(
            SnackBar(
              content: Text(
                isSaved ? 'Video disimpan' : 'Video dibuang dari simpan',
              ),
              backgroundColor: isSaved ? Colors.green : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling save status: $e');
      if (_context.mounted) {
        ScaffoldMessenger.of(_context).showSnackBar(
          SnackBar(
            content: Text('Ralat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      isSaveLoading = false;
      _updateUI();
    }
  }

  // Progress tracking
  void resumeFromBookmark(int seconds) {
    if (videoController != null) {
      try {
        videoController!.seekTo(Duration(seconds: seconds));

        if (currentEpisode != null) {
          VideoProgressService.saveVideoPosition(
            currentEpisode!.id,
            seconds,
          );
          episodePositions[currentEpisode!.id] = seconds;
        }
      } catch (e) {
        debugPrint('Error resuming from bookmark: $e');
      }
    }
  }

  // Premium access control
  bool canAccessEpisode(VideoEpisode episode) {
    final authProvider = _context.read<AuthProvider>();
    final hasActiveSubscription = authProvider.hasActiveSubscription;

    // Episode can be accessed if:
    // 1. Episode is not premium (free)
    // 2. Episode is premium but user has active subscription
    return !episode.isPremium || hasActiveSubscription;
  }

  bool isEpisodeLocked(VideoEpisode episode) {
    return !canAccessEpisode(episode);
  }

  // PDF callbacks
  void onPdfPageChanged(int pageNumber) {
    currentPdfPage = pageNumber;
    _updateUI();
  }

  void onPdfDocumentLoaded(int totalPages) {
    totalPdfPages = totalPages;
    _updateUI();
  }

  void onViewOnline() {
    cachedPdfPath = 'ONLINE_VIEW';
    _updateUI();
  }

  // Auto play next episode
  bool canPlayNextEpisode() {
    if (currentEpisodeIndex + 1 < episodes.length) {
      final nextEpisode = episodes[currentEpisodeIndex + 1];
      return canAccessEpisode(nextEpisode);
    }
    return false;
  }

  void playNextEpisode() {
    if (canPlayNextEpisode()) {
      switchToEpisode(currentEpisodeIndex + 1);
    }
  }
}