import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import '../../../core/models/video_kitab.dart';
import '../../../core/models/video_episode.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/local_favorites_service.dart';
import '../../../core/services/video_progress_service.dart';
import '../../../core/services/pdf_cache_service.dart';

class ContentPlayerScreen extends StatefulWidget {
  final String kitabId;
  final String? episodeId; // Episode ID for multi-episode kitab
  final String? pdfUrl;

  const ContentPlayerScreen({
    super.key,
    required this.kitabId,
    this.episodeId,
    this.pdfUrl,
  });

  @override
  State<ContentPlayerScreen> createState() => _ContentPlayerScreenState();
}

class _ContentPlayerScreenState extends State<ContentPlayerScreen>
    with TickerProviderStateMixin {
  // Animation controllers for smooth animations
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;
  YoutubePlayerController? _videoController;
  PdfViewerController? _pdfController;

  bool _isVideoLoading = true;

  // Real data from Supabase
  VideoKitab? _kitab;
  List<VideoEpisode> _episodes = [];
  VideoEpisode? _currentEpisode;
  bool _isDataLoading = true;
  int _currentEpisodeIndex = 0;
  final Map<String, int> _episodePositions = {}; // episodeId -> seconds

  // Progress tracking
  int _lastVideoPosition = 0;
  int _currentPdfPage = 1;
  int _totalPdfPages = 0;
  bool _hidePlayer = false;

  Timer? _progressTimer;

  // Save/favorite state
  bool _isSaved = false;
  bool _isSaveLoading = false;

  // PDF caching state
  bool _isPdfDownloading = false;
  double _downloadProgress = 0.0;
  String? _cachedPdfPath;

  // Skip animation state
  bool _showSkipAnimation = false;
  bool _isSkipForward = false;
  bool _isSkipOnLeftSide = false;
  Timer? _skipAnimationTimer;

  // Control visibility state
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize animation controllers
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
      value: 0.0,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
      value: 0.0,
    );

    // Create animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Load real data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRealData();
    });

    // Start progress tracking timer
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {});
  }

  void _checkSaveStatus() {
    if (_currentEpisode != null) {
      setState(() {
        _isSaved = LocalFavoritesService.isVideoEpisodeFavorite(
          _currentEpisode!.id,
        );
      });
    }
  }

  Future<void> _checkPdfCache() async {
    if (_kitab?.pdfUrl != null && _kitab!.pdfUrl!.isNotEmpty) {
      final cachedPath = PdfCacheService.getCachedPdfPath(_kitab!.pdfUrl!);
      if (cachedPath != null) {
        setState(() {
          _cachedPdfPath = cachedPath;
        });
        // Update last accessed time
        await PdfCacheService.updateLastAccessed(_kitab!.pdfUrl!);
      }
    }
  }

  Future<void> _downloadPdfIfNeeded() async {
    if (_kitab?.pdfUrl == null || _kitab!.pdfUrl!.isEmpty) return;

    // Check if already cached
    if (PdfCacheService.isPdfCached(_kitab!.pdfUrl!)) {
      _cachedPdfPath = PdfCacheService.getCachedPdfPath(_kitab!.pdfUrl!);
      setState(() {});
      return;
    }

    // Download and cache PDF
    setState(() {
      _isPdfDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final cachedPath = await PdfCacheService.downloadAndCachePdf(
        _kitab!.pdfUrl!,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      if (cachedPath != null) {
        setState(() {
          _cachedPdfPath = cachedPath;
          _isPdfDownloading = false;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.downloadSimple(),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text('PDF disimpan untuk akses offline'),
                ],
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isPdfDownloading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Ralat memuat turun PDF: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadRealData() async {
    try {
      final kitabProvider = context.read<KitabProvider>();

      // Get VideoKitab data from Supabase
      final videoKitabList = kitabProvider.activeVideoKitab;
      try {
        _kitab = videoKitabList.firstWhere((vk) => vk.id == widget.kitabId);
      } catch (e) {
        debugPrint('VideoKitab not found: $e');
        setState(() {
          _isDataLoading = false;
        });
        return;
      }

      // Load episodes from video_kitab table
      if (_kitab?.hasVideos == true) {
        _episodes = await kitabProvider.loadKitabVideos(widget.kitabId);

        // Fix: Sort episodes by part number in ascending order (1, 2, 3, 4...)
        _episodes.sort((a, b) => a.partNumber.compareTo(b.partNumber));

        // Debug: Print episode order after sorting
        debugPrint('📝 Loaded and sorted episodes:');
        for (int i = 0; i < _episodes.length; i++) {
          debugPrint('📝 Index $i: Part ${_episodes[i].partNumber} - ${_episodes[i].title}');
        }

        // Find current episode
        if (widget.episodeId != null) {
          final episodeIndex = _episodes.indexWhere(
            (ep) => ep.id == widget.episodeId,
          );
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

      // Check save status after episode is loaded
      _checkSaveStatus();

      // Check PDF cache
      await _checkPdfCache();

      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
        // Start animations
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _fadeAnimationController.forward();
            _slideAnimationController.forward();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading Supabase data: $e');
      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuat kandungan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _switchToEpisode(int index) {
    debugPrint('🔄 _switchToEpisode called with index: $index');
    debugPrint('🔄 Current index: $_currentEpisodeIndex');
    debugPrint('🔄 Episodes length: ${_episodes.length}');

    if (index < 0 ||
        index >= _episodes.length ||
        index == _currentEpisodeIndex) {
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

    setState(() {
      _currentEpisodeIndex = index;
      _currentEpisode = _episodes[index];
    });

    debugPrint('🔄 Switched to episode index: $index');
    debugPrint('🔄 New episode part number: ${_currentEpisode?.partNumber}');
    debugPrint('🔄 New episode title: ${_currentEpisode?.title}');

    // Check save status for new episode
    _checkSaveStatus();

    final newVideoId = _currentEpisode!.youtubeVideoId;

    if (_videoController != null) {
      try {
        _videoController!.load(newVideoId);

        // Check for saved position first, then fall back to episode position
        final savedPos = VideoProgressService.getVideoPosition(
          _currentEpisode!.id,
        );
        final resumePos = savedPos > 10
            ? savedPos
            : (_episodePositions[_currentEpisode!.id] ?? 0);

        if (resumePos > 0) {
          // Wait for controller to be ready before seeking
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted && _videoController != null) {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ralat memuat video: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
          enableCaption: false,
          controlsVisibleAtStart: false, // Fix: Don't show controls at start
          forceHD: false,
          hideControls: true, // Hide default controls
          disableDragSeek: true, // Disable default seek
          showLiveFullscreenButton: false, // Hide fullscreen button
          loop: false,
          useHybridComposition: true,
        ),
      );

      _videoController!.addListener(() {
        // Track video position for progress tracking
        try {
          if (_videoController != null && _videoController!.value.isReady && mounted) {
            _lastVideoPosition = _videoController!.value.position.inSeconds;
            if (_currentEpisode != null) {
              _episodePositions[_currentEpisode!.id] = _lastVideoPosition;
            }

            // Handle control visibility changes (listen to YouTube player state)
            if (_videoController!.value.isPlaying && _showControls) {
              _startControlsTimer();
            } else if (!_videoController!.value.isPlaying) {
              _showControlsForever();
            }
          }
        } catch (e) {
          debugPrint('Error in video controller listener: $e');
        }
      });

      // Restore saved video position
      if (_currentEpisode != null) {
        final savedPosition = VideoProgressService.getVideoPosition(
          _currentEpisode!.id,
        );
        if (savedPosition > 10) {
          // Only restore if more than 10 seconds
          _videoController!.seekTo(Duration(seconds: savedPosition));
        }
      }

      setState(() {
        _isVideoLoading = false;
      });
    } else {
      setState(() {
        _isVideoLoading = false;
      });
    }

    // Initialize PDF controller for real PDF data
    _pdfController = PdfViewerController();

    setState(() {
      // PDF loaded
    });
  }

  Future<bool> _onWillPop() async {
    // Detach player from widget tree before pop to avoid WebView teardown crash
    _detachPlayer();
    // Allow a frame so UI can paint the hidden state, then manually pop
    await Future<void>.delayed(const Duration(milliseconds: 32));
    if (mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      }
    }
    return false; // we handled the pop manually
  }


  // Clean resume banner with modern design
  Widget _buildResumeBanner(int seconds) {
    final label =
        'Sambung dari ${VideoProgressService.formatDuration(seconds)}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PhosphorIcon(
              PhosphorIcons.clockCountdown(),
              color: Colors.orange,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _resumeFromBookmark(seconds),
            icon: PhosphorIcon(
              PhosphorIcons.play(),
              size: 16,
              color: AppTheme.primaryColor,
            ),
            label: Text(
              'Main',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resumeFromBookmark(int seconds) {
    if (_videoController == null) return;
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
    _videoController!.seekTo(Duration(seconds: seconds));

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            PhosphorIcon(PhosphorIcons.play(), color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Meneruskan dari ${VideoProgressService.formatDuration(seconds)}',
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _skipAnimationTimer?.cancel();
    _controlsTimer?.cancel();

    // Reset system UI and orientation on dispose
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    _videoController?.dispose();
    _tabController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // Ensure video is paused when screen is transitioning away
    try {
      _videoController?.pause();
    } catch (_) {}
    super.deactivate();
  }

  void _detachPlayer() {
    try {
      if (_videoController?.value.isFullScreen ?? false) {
        _videoController?.toggleFullScreenMode();
      }
    } catch (_) {}
    try {
      _videoController?.pause();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _hidePlayer = true;
        // Nullify controller so build() switches to non-YouTube path
        _videoController = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while data is loading
    if (_isDataLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: AppTheme.textPrimaryColor,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Column(
                      children: [
                        Text(
                          'Memuat Kandungan',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sila tunggu sebentar...',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // Show error if kitab not found
    if (_kitab == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _buildAppBar(),
        body: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.textSecondaryColor.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedAlert02,
                              color: AppTheme.textSecondaryColor,
                              size: 48,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Kitab Tidak Ditemui',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Kitab yang anda cari tidak wujud dalam pangkalan data',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondaryColor,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => context.pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowLeft01,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: const Text(
                              'Kembali',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // Build main content with YouTube player
    if (_videoController == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: PopScope(
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) await _onWillPop();
          },
          child: _buildNormalView(null),
        ),
      );
    }

    return YoutubePlayerBuilder(
      builder: (context, player) {
        // Fullscreen mode - hide AppBar and take full screen
        if (_isFullscreen) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: _buildFullscreenView(player),
          );
        }

        // Normal mode - show AppBar and tabs
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(),
          body: PopScope(
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) await _onWillPop();
            },
            child: _buildNormalView(player),
          ),
        );
      },
      player: YoutubePlayer(
        controller: _videoController!,
        showVideoProgressIndicator: false, // Hide default progress
        topActions: const [], // Remove all top controls
        bottomActions: const [], // Remove all bottom controls
        progressColors: const ProgressBarColors(
          playedColor: Colors.transparent,
          handleColor: Colors.transparent,
          bufferedColor: Colors.transparent,
          backgroundColor: Colors.transparent,
        ),
        onReady: () {
          if (mounted) {
            setState(() {
              _isVideoLoading = false;
            });

            // Start auto-hide timer when video is ready and playing
            if (_videoController?.value.isPlaying == true && _showControls) {
              _startControlsTimer();
            }
          }
        },
        onEnded: (metaData) {
          // Auto play next episode if available
          debugPrint('🎬 Video ended. Current episode index: $_currentEpisodeIndex');
          debugPrint('🎬 Current episode part: ${_currentEpisode?.partNumber}');
          debugPrint('🎬 Total episodes: ${_episodes.length}');
          debugPrint('🎬 Next episode index would be: ${_currentEpisodeIndex + 1}');
          if (_currentEpisodeIndex + 1 < _episodes.length) {
            debugPrint('🎬 Next episode part: ${_episodes[_currentEpisodeIndex + 1].partNumber}');
          }

          if (mounted && _currentEpisodeIndex < _episodes.length - 1) {
            // Add delay to ensure proper state transition
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                debugPrint('🎬 Switching to next episode...');
                _switchToEpisode(_currentEpisodeIndex + 1);
              }
            });
          }
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppTheme.textPrimaryColor,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      title: Text(
        _kitab?.title ?? 'Memuat...',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: _isSaveLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: HugeIcon(
                      key: ValueKey(_isSaved),
                      icon: _isSaved
                          ? HugeIcons.strokeRoundedFavourite
                          : HugeIcons.strokeRoundedHeartAdd,
                      color: _isSaved
                          ? const Color(0xFFE91E63)
                          : AppTheme.textSecondaryColor,
                      size: 20,
                    ),
                  ),
            onPressed: _isSaveLoading ? null : _toggleSaved,
            tooltip: _isSaved ? 'Buang Video dari Simpan' : 'Simpan Video',
          ),
        ),
      ],
    );
  }

  Widget _buildNormalView(Widget? player) {
    return Column(
      children: [
        // Video player always on top
        _buildVideoSection(player),

        // Enhanced tab bar design
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondaryColor,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedVideo01,
                      size: 18,
                      color: _tabController.index == 0
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Text('Video'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPdf01,
                      size: 18,
                      color: _tabController.index == 1
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Text('E-Book'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Content with animations
        Expanded(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [_buildVideoTabContent(), _buildPdfTab()],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoSection(Widget? player) {
    if (_hidePlayer) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(color: Colors.black),
      );
    }
    // Show a clean placeholder if there is no controller
    if (_videoController == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  PhosphorIcons.videoCamera(),
                  size: 48,
                  color: Colors.white70,
                ),
                const SizedBox(height: 12),
                Text(
                  'Video tidak tersedia',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: _isVideoLoading
                ? Stack(
                    children: [
                      player ?? Container(color: Colors.black),
                      if (!(_videoController?.value.isFullScreen ?? false))
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 16),
                                Text(
                                  'Memuat video...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : _buildPlayerWithDoubleTap(player) ??
                      Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PhosphorIcon(
                                PhosphorIcons.videoCamera(),
                                size: 32,
                                color: Colors.white70,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Video tidak tersedia',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ),
        // Resume banner for saved video progress
        if (_currentEpisode != null && _tabController.index == 0) ...[
          Builder(
            builder: (context) {
              final savedPosition = VideoProgressService.getVideoPosition(
                _currentEpisode!.id,
              );

              // Show saved position banner if we have saved progress > 10 seconds
              if (savedPosition > 10) {
                return _buildResumeBanner(savedPosition);
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ],
    );
  }

  Widget? _buildPlayerWithDoubleTap(Widget? player) {
    if (player == null) return null;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            // Single tap to toggle controls
            _toggleControls();
          },
          onDoubleTap: () {
            // This will be handled by onDoubleTapDown, but we need this to enable double tap detection
          },
          onDoubleTapDown: (details) {
            // Only handle double tap here if controls are hidden
            if (_showControls || _videoController == null) return;

            // Get tap position relative to the player
            final size = MediaQuery.of(context).size;
            final position = details.localPosition;

            // Calculate if tap is on left or right side
            final isLeftSide = position.dx < size.width / 2;
            final skipSeconds = isLeftSide ? -10 : 10; // Skip backward or forward

            try {
              // Get current position and calculate new position
              final currentPosition = _videoController!.value.position.inSeconds;
              final videoDuration = _videoController!.metadata.duration.inSeconds;
              final newPosition = (currentPosition + skipSeconds).clamp(0, videoDuration);

              // Custom seek to new position
              _videoController!.seekTo(Duration(seconds: newPosition.toInt()));

              // Show feedback with visual indicator
              _showSkipFeedback(isLeftSide, skipSeconds.abs(), isLeftSide);
            } catch (e) {
              debugPrint('Error in custom double tap seek: $e');
            }
          },
          child: player,
        ),
        // Custom Controls Overlay
        if (_showControls)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // Single tap on overlay (not on buttons) should toggle controls
                _toggleControls();
                // Start auto-hide timer if controls are now visible and video is playing
                if (_showControls && _videoController?.value.isPlaying == true) {
                  _startControlsTimer();
                }
              },
              onDoubleTap: () {
                // Enable double tap detection
              },
              onDoubleTapDown: (details) {
                if (_videoController == null) return;

                // Get tap position relative to the overlay
                final size = MediaQuery.of(context).size;
                final position = details.localPosition;

                // Calculate if tap is on left or right side
                final isLeftSide = position.dx < size.width / 2;
                final skipSeconds = isLeftSide ? -10 : 10; // Skip backward or forward

                try {
                  // Get current position and calculate new position
                  final currentPosition = _videoController!.value.position.inSeconds;
                  final videoDuration = _videoController!.metadata.duration.inSeconds;
                  final newPosition = (currentPosition + skipSeconds).clamp(0, videoDuration);

                  // Custom seek to new position
                  _videoController!.seekTo(Duration(seconds: newPosition.toInt()));

                  // Show feedback with visual indicator
                  _showSkipFeedback(isLeftSide, skipSeconds.abs(), isLeftSide);

                  // Reset auto-hide timer after skip (works in both normal and fullscreen)
                  if (_videoController!.value.isPlaying) {
                    _startControlsTimer();
                  }
                } catch (e) {
                  debugPrint('Error in custom double tap seek: $e');
                }
              },
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Stack(
                  children: [
                    // Center Play/Pause Button
                    Center(
                      child: StreamBuilder<Duration>(
                        stream: Stream.periodic(
                          const Duration(milliseconds: 100),
                          (_) => _videoController?.value.position ?? Duration.zero,
                        ),
                        builder: (context, snapshot) {
                          final isPlaying = _videoController?.value.isPlaying ?? false;
                          return GestureDetector(
                            onTap: () {
                              if (_videoController != null) {
                                if (_videoController!.value.isPlaying) {
                                  _videoController!.pause();
                                } else {
                                  _videoController!.play();
                                  // Start auto-hide timer after play
                                  _startControlsTimer();
                                }
                              }
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isPlaying
                                    ? PhosphorIcons.pause()
                                    : PhosphorIcons.play(),
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Custom Seekable Progress Bar
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: GestureDetector(
                        onTap: null, // Prevent tap on progress bar from hiding controls
                        child: _buildCustomProgressBar(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // YouTube-style skip animation overlay
        if (_showSkipAnimation)
          Positioned(
            left: _isSkipOnLeftSide ? 40 : null,
            right: !_isSkipOnLeftSide ? 40 : null,
            top: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _showSkipAnimation ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSkipForward ? Icons.fast_forward : Icons.fast_rewind,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '10s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showSkipFeedback(bool isBackward, int seconds, bool isLeftSide) {
    if (!mounted) return;

    setState(() {
      _showSkipAnimation = true;
      _isSkipForward = !isBackward;
      _isSkipOnLeftSide = isLeftSide;
    });

    // Hide animation after 800ms
    _skipAnimationTimer?.cancel();
    _skipAnimationTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showSkipAnimation = false;
        });
      }
    });
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _videoController?.value.isPlaying == true) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _showControlsForever() {
    _controlsTimer?.cancel();
    if (mounted) {
      setState(() {
        _showControls = true;
      });
    }
  }

  void _toggleControls() {
    if (!mounted) return;

    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls && _videoController?.value.isPlaying == true) {
      _startControlsTimer();
    }
  }

  void _toggleFullscreen() {
    if (!mounted) return;

    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      // Enter fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // Show controls when entering fullscreen
      _showControls = true;
    } else {
      // Exit fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    // Reset controls timer when toggling fullscreen
    if (_showControls && _videoController?.value.isPlaying == true) {
      _startControlsTimer();
    }
  }

  Widget _buildFullscreenView(Widget? player) {
    if (player == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        // Video player taking full screen
        Positioned.fill(
          child: _buildPlayerWithDoubleTap(player),
        ),
        // Exit fullscreen button (always visible in top-right)
        Positioned(
          top: 20,
          right: 20,
          child: GestureDetector(
            onTap: _toggleFullscreen,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancelSquare,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoTabContent() {
    if (_isDataLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clean video info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  (_kitab?.hasVideos ?? false && _currentEpisode != null)
                      ? _currentEpisode!.title
                      : _kitab?.title ?? 'Kitab',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                if (_kitab?.author != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.user(),
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _kitab?.author ?? 'Unknown Author',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_kitab?.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Tentang',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _kitab?.description ?? 'No description available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Episodes section with modern design
          if (_episodes.length > 1) ..._buildEpisodesSection(),
        ],
      ),
    );
  }

  Widget _buildPdfTab() {
    return Column(
      children: [
        // Modern PDF toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.filePdf(),
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Halaman $_currentPdfPage${_totalPdfPages > 0 ? ' / $_totalPdfPages' : ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Spacer(),
              // Cache status indicator
              if (_cachedPdfPath != null &&
                  _cachedPdfPath != 'ONLINE_VIEW') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.downloadSimple(),
                        size: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (_cachedPdfPath == 'ONLINE_VIEW') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.globe(),
                        size: 12,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: PhosphorIcon(
                      PhosphorIcons.magnifyingGlassMinus(),
                      size: 18,
                    ),
                    onPressed: () => _pdfController?.zoomLevel = 1.0,
                    tooltip: 'Zum Keluar',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: PhosphorIcon(
                      PhosphorIcons.magnifyingGlassPlus(),
                      size: 18,
                    ),
                    onPressed: () => _pdfController?.zoomLevel = 2.0,
                    tooltip: 'Zum Masuk',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // PDF Viewer with caching support
        Expanded(child: _buildPdfViewer()),

        // Modern PDF navigation controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPdfNavButton(
                icon: PhosphorIcons.skipBack(),
                onPressed: _currentPdfPage > 1
                    ? () => _pdfController?.firstPage()
                    : null,
                tooltip: 'Halaman Pertama',
              ),
              _buildPdfNavButton(
                icon: PhosphorIcons.caretLeft(),
                onPressed: _currentPdfPage > 1
                    ? () => _pdfController?.previousPage()
                    : null,
                tooltip: 'Halaman Sebelum',
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_currentPdfPage',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildPdfNavButton(
                icon: PhosphorIcons.caretRight(),
                onPressed: _currentPdfPage < _totalPdfPages
                    ? () => _pdfController?.nextPage()
                    : null,
                tooltip: 'Halaman Seterusnya',
              ),
              _buildPdfNavButton(
                icon: PhosphorIcons.skipForward(),
                onPressed: _currentPdfPage < _totalPdfPages
                    ? () => _pdfController?.lastPage()
                    : null,
                tooltip: 'Halaman Terakhir',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdfNavButton({
    required PhosphorIconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return IconButton(
      icon: PhosphorIcon(
        icon,
        size: 20,
        color: onPressed != null
            ? AppTheme.textPrimaryColor
            : AppTheme.textSecondaryColor,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: onPressed != null
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildPdfViewer() {
    // No PDF URL available
    if (_kitab?.pdfUrl == null || _kitab!.pdfUrl!.isEmpty) {
      return _buildNoPdfMessage();
    }

    // PDF is downloading
    if (_isPdfDownloading) {
      return _buildDownloadingMessage();
    }

    // Use cached PDF if available, or force online view
    if (_cachedPdfPath != null) {
      if (_cachedPdfPath == 'ONLINE_VIEW') {
        // Force online view
        return SfPdfViewer.network(
          _kitab!.pdfUrl!,
          controller: _pdfController,
          enableDoubleTapZooming: true,
          enableTextSelection: true,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onPageChanged: (PdfPageChangedDetails details) {
            setState(() {
              _currentPdfPage = details.newPageNumber;
            });
          },
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            setState(() {
              _totalPdfPages = details.document.pages.count;
            });
          },
        );
      } else {
        // Use cached file
        return SfPdfViewer.file(
          File(_cachedPdfPath!),
          controller: _pdfController,
          enableDoubleTapZooming: true,
          enableTextSelection: true,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onPageChanged: (PdfPageChangedDetails details) {
            setState(() {
              _currentPdfPage = details.newPageNumber;
            });
          },
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            setState(() {
              _totalPdfPages = details.document.pages.count;
            });
          },
        );
      }
    }

    // Check if PDF is cached, if not show download prompt
    final isCached = PdfCacheService.isPdfCached(_kitab!.pdfUrl!);
    if (!isCached) {
      return _buildDownloadPrompt();
    }

    // Fallback to network PDF viewer
    return SfPdfViewer.network(
      _kitab!.pdfUrl!,
      controller: _pdfController,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      onPageChanged: (PdfPageChangedDetails details) {
        setState(() {
          _currentPdfPage = details.newPageNumber;
        });
      },
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        setState(() {
          _totalPdfPages = details.document.pages.count;
        });
        // Auto-download PDF for caching
        _downloadPdfIfNeeded();
      },
    );
  }

  Widget _buildNoPdfMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIcons.filePdf(),
            size: 48,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'PDF tidak tersedia',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kitab ini tidak mempunyai fail PDF',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadingMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: PhosphorIcon(
                PhosphorIcons.downloadSimple(),
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Memuat turun PDF...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PDF akan disimpan untuk akses offline',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: (_downloadProgress * 100).round(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 100 - (_downloadProgress * 100).round(),
                    child: const SizedBox(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: PhosphorIcon(
                PhosphorIcons.cloudArrowDown(),
                size: 48,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Muat turun untuk akses offline',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Muat turun PDF ini untuk akses pantas tanpa internet pada masa akan datang',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _downloadPdfIfNeeded,
              icon: PhosphorIcon(
                PhosphorIcons.downloadSimple(),
                color: Colors.white,
                size: 18,
              ),
              label: const Text('Muat Turun PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                // Set a flag to show network viewer
                setState(() {
                  _cachedPdfPath = 'ONLINE_VIEW'; // Special flag
                });
              },
              icon: PhosphorIcon(
                PhosphorIcons.globe(),
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              label: Text(
                'Lihat online sahaja',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed unused _buildChapterList() to resolve lint warning


  void _toggleSaved() async {
    if (_currentEpisode == null || _isSaveLoading) return;

    setState(() {
      _isSaveLoading = true;
    });

    try {
      bool success;
      if (_isSaved) {
        success = await LocalFavoritesService.removeVideoEpisodeFromFavorites(
          _currentEpisode!.id,
        );
      } else {
        success = await LocalFavoritesService.addVideoEpisodeToFavorites(
          _currentEpisode!.id,
        );
      }

      if (success) {
        setState(() {
          _isSaved = !_isSaved;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  PhosphorIcon(
                    _isSaved
                        ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                        : PhosphorIcons.heartBreak(),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isSaved
                        ? 'Video episod disimpan'
                        : 'Video episod dibuang dari senarai simpan',
                  ),
                ],
              ),
              backgroundColor: _isSaved ? AppTheme.primaryColor : Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text('Ralat menyimpan video episod'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Ralat: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaveLoading = false;
        });
      }
    }
  }

  List<Widget> _buildEpisodesSection() {
    if (_episodes.length <= 1) return [];

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.listNumbers(),
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Senarai Episode',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_episodes.length} episod',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Episodes are already sorted by part number, so just map them directly
            ..._episodes.asMap().entries
                .map((entry) => _buildEpisodeCard(entry.value, entry.key)),
          ],
        ),
      ),
    ];
  }

  Widget _buildEpisodeCard(VideoEpisode episode, int index) {
    final isCurrentEpisode = index == _currentEpisodeIndex;
    final thumbnail =
        'https://img.youtube.com/vi/${episode.youtubeVideoId}/mqdefault.jpg';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isCurrentEpisode
                    ? AppTheme.primaryColor.withValues(alpha: 0.08)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20), // xl rounded corners
                border: Border.all(
                  color: isCurrentEpisode
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor.withValues(alpha: 0.5),
                  width: isCurrentEpisode ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isCurrentEpisode
                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: isCurrentEpisode ? 12 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _switchToEpisode(index),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Enhanced thumbnail with modern design
                        Container(
                          width: 110,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.grey[100],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  thumbnail,
                                  width: 110,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 110,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: HugeIcon(
                                          icon: HugeIcons.strokeRoundedVideo01,
                                          color: AppTheme.primaryColor,
                                          size: 28,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Enhanced duration badge
                              if (episode.durationMinutes > 0)
                                Positioned(
                                  bottom: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      episode.formattedDuration,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              // Enhanced "Now Playing" overlay
                              if (isCurrentEpisode)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: Colors.black.withValues(alpha: 0.4),
                                    ),
                                    child: Center(
                                      child: TweenAnimationBuilder<double>(
                                        duration: const Duration(milliseconds: 800),
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        curve: Curves.elasticOut,
                                        builder: (context, value, child) {
                                          return Transform.scale(
                                            scale: 0.8 + (0.2 * value),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppTheme.primaryColor,
                                                    AppTheme.primaryColor.withValues(alpha: 0.8),
                                                  ],
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: HugeIcon(
                                                icon: HugeIcons.strokeRoundedPause,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Enhanced video info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Episode badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor.withValues(alpha: 0.15),
                                      AppTheme.primaryColor.withValues(alpha: 0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedVideoReplay,
                                      size: 12,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Episode ${episode.partNumber}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Enhanced title
                              Text(
                                episode.title,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 6),

                              // Status and description
                              Row(
                                children: [
                                  if (isCurrentEpisode) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryColor,
                                            AppTheme.primaryColor.withValues(alpha: 0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'PLAYING',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedClock03,
                                    size: 14,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    episode.formattedDuration,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),

                              if (episode.description?.isNotEmpty == true) ...[
                                const SizedBox(height: 6),
                                Text(
                                  episode.description!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                    height: 1.3,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Custom Progress Bar with Seek Functionality
  Widget _buildCustomProgressBar() {
    if (_videoController == null) {
      return Container(
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: Stream.periodic(
        const Duration(milliseconds: 100),
        (_) => _videoController!.value.position,
      ),
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _videoController!.metadata.duration;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        return Column(
          children: [
            // Time display and fullscreen button
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Combined duration display on left
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Fullscreen button on right
                  GestureDetector(
                    onTap: _toggleFullscreen,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: HugeIcon(
                        icon: _isFullscreen
                            ? HugeIcons.strokeRoundedCancelSquare
                            : HugeIcons.strokeRoundedFullScreen,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Custom draggable progress bar
            GestureDetector(
              onTapDown: (details) => _onProgressBarTap(details, duration),
              onPanUpdate: (details) => _onProgressBarPan(details, duration),
              child: Container(
                height: 20, // Larger touch area
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background track
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Progress track
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Seek handle
                    Positioned(
                      left: (MediaQuery.of(context).size.width - 48) * progress.clamp(0.0, 1.0) - 8, // Account for handle width and padding
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onProgressBarTap(TapDownDetails details, Duration duration) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final progress = (localPosition.dx / renderBox.size.width).clamp(0.0, 1.0);
    final newPosition = Duration(milliseconds: (duration.inMilliseconds * progress).toInt());

    _videoController?.seekTo(newPosition);
  }

  void _onProgressBarPan(DragUpdateDetails details, Duration duration) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final progress = (localPosition.dx / renderBox.size.width).clamp(0.0, 1.0);
    final newPosition = Duration(milliseconds: (duration.inMilliseconds * progress).toInt());

    _videoController?.seekTo(newPosition);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}
