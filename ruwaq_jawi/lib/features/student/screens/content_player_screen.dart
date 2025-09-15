import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/models/video_kitab.dart';
import '../../../core/models/kitab_video.dart';
import '../../../core/models/video_episode.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
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
  late TabController _tabController;
  YoutubePlayerController? _videoController;
  PdfViewerController? _pdfController;

  bool _isVideoLoading = true;
  // ignore: unused_field
  bool _isPdfLoading = true;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load real data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRealData();
    });


    // Start progress tracking timer
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  void _checkSaveStatus() {
    if (_currentEpisode != null) {
      setState(() {
        _isSaved = LocalFavoritesService.isVideoEpisodeFavorite(_currentEpisode!.id);
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        _kitab = videoKitabList.firstWhere(
          (vk) => vk.id == widget.kitabId,
        );
      } catch (e) {
        print('VideoKitab not found: $e');
        setState(() {
          _isDataLoading = false;
        });
        return;
      }

      // Load episodes from video_kitab table
      if (_kitab?.hasVideos == true) {
        _episodes = await kitabProvider.loadKitabVideos(widget.kitabId);

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
      }
    } catch (e) {
      print('Error loading Supabase data: $e');
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
    if (index < 0 || index >= _episodes.length || index == _currentEpisodeIndex)
      return;

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

    // Check save status for new episode
    _checkSaveStatus();

    final newVideoId = _currentEpisode!.youtubeVideoId;

    if (_videoController != null) {
      try {
        _videoController!.load(newVideoId);
        
        // Check for saved position first, then fall back to episode position
        final savedPos = VideoProgressService.getVideoPosition(_currentEpisode!.id);
        final resumePos = savedPos > 10 ? savedPos : (_episodePositions[_currentEpisode!.id] ?? 0);
        
        if (resumePos > 0) {
          _videoController!.seekTo(Duration(seconds: resumePos));
        }
      } catch (_) {}
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
          controlsVisibleAtStart: true,
          forceHD: false,
          useHybridComposition: true,
        ),
      );

      _videoController!.addListener(() {
        // Track video position for progress tracking
        if (_videoController!.value.isReady) {
          _lastVideoPosition = _videoController!.value.position.inSeconds;
          if (_currentEpisode != null) {
            _episodePositions[_currentEpisode!.id] = _lastVideoPosition;
          }
        }
      });

      // Restore saved video position
      if (_currentEpisode != null) {
        final savedPosition = VideoProgressService.getVideoPosition(_currentEpisode!.id);
        if (savedPosition > 10) { // Only restore if more than 10 seconds
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
      _isPdfLoading = false;
    });
  }

  void _saveProgress() async {
    try {
      // Save video progress for current episode
      if (_currentEpisode != null && _videoController != null) {
        final currentPosition = _videoController!.value.position.inSeconds;
        if (currentPosition > 0) {
          await VideoProgressService.saveVideoPosition(
            _currentEpisode!.id, 
            currentPosition
          );
        }
      }
      
      if (kDebugMode) {
        print(
          'Progress saved: Video ${_lastVideoPosition}s, PDF page $_currentPdfPage',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving video progress: $e');
      }
    }
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

  Future<void> _navigateToKitab(String kitabId) async {
    _detachPlayer();
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    context.pushReplacement('/player/$kitabId');
  }

  // Clean resume banner with modern design
  Widget _buildResumeBanner(int seconds) {
    final label = 'Sambung dari ${VideoProgressService.formatDuration(seconds)}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
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
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
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
            PhosphorIcon(
              PhosphorIcons.play(),
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text('Meneruskan dari ${VideoProgressService.formatDuration(seconds)}'),
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
    _saveProgress();
    _videoController?.dispose();
    _tabController.dispose();
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
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.caretLeft(),
              color: AppTheme.textPrimaryColor,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Memuat...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text(
                'Memuat kandungan dari Supabase...',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                PhosphorIcons.warning(),
                size: 64,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Kitab tidak ditemui',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kitab yang anda cari tidak wujud dalam pangkalan data',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: PhosphorIcon(
                  PhosphorIcons.caretLeft(),
                  color: Colors.white,
                ),
                label: const Text('Kembali'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build main content with YouTube player
    if (_videoController == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _buildAppBar(),
        body: WillPopScope(
          onWillPop: _onWillPop,
          child: _buildNormalView(null),
        ),
      );
    }

    return YoutubePlayerBuilder(
      builder: (context, player) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: _buildAppBar(),
          body: WillPopScope(
            onWillPop: _onWillPop,
            child: _buildNormalView(player),
          ),
        );
      },
      player: YoutubePlayer(
        controller: _videoController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppTheme.primaryColor,
        bottomActions: const [
          CurrentPosition(),
          ProgressBar(isExpanded: true),
          RemainingDuration(),
          FullScreenButton(),
        ],
        onReady: () {
          if (mounted) {
            setState(() {
              _isVideoLoading = false;
            });
          }
        },
        onEnded: (metaData) {
          // Auto play next episode if available
          if (_currentEpisodeIndex < _episodes.length - 1) {
            _switchToEpisode(_currentEpisodeIndex + 1);
          }
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.backgroundColor,
      foregroundColor: AppTheme.textPrimaryColor,
      elevation: 0,
      leading: IconButton(
        icon: PhosphorIcon(
          PhosphorIcons.caretLeft(),
          color: AppTheme.textPrimaryColor,
        ),
        onPressed: () => context.pop(),
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
        IconButton(
          icon: _isSaveLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                )
              : PhosphorIcon(
                  _isSaved 
                      ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                      : PhosphorIcons.heart(),
                  color: _isSaved ? Colors.red : AppTheme.textSecondaryColor,
                ),
          onPressed: _isSaveLoading ? null : _toggleSaved,
          tooltip: _isSaved ? 'Buang Video dari Simpan' : 'Simpan Video',
        ),
      ],
    );
  }


  Widget _buildNormalView(Widget? player) {
    return Column(
      children: [
        // Video player always on top
        _buildVideoSection(player),

        // Clean tab bar design
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondaryColor,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(PhosphorIcons.videoCamera(), size: 16),
                    const SizedBox(width: 6),
                    const Text('Video'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(PhosphorIcons.filePdf(), size: 16),
                    const SizedBox(width: 6),
                    const Text('E-Book'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Content (only the content below the video)
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildVideoTabContent(), _buildPdfTab()],
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
                : player ??
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
              final savedPosition = VideoProgressService.getVideoPosition(_currentEpisode!.id);
              
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
          // Clean video info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and premium badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (_kitab?.hasVideos ?? false && _currentEpisode != null)
                            ? _currentEpisode!.title
                            : _kitab?.title ?? 'Kitab',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                      ),
                    ),
                    if (_kitab?.isPremium == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PhosphorIcon(
                              PhosphorIcons.crown(),
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'PREMIUM',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                      ),
                  ],
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
              if (_cachedPdfPath != null && _cachedPdfPath != 'ONLINE_VIEW') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
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
                      backgroundColor: AppTheme.backgroundColor,
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
                      backgroundColor: AppTheme.backgroundColor,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // PDF Viewer with caching support
        Expanded(
          child: _buildPdfViewer(),
        ),

        // Modern PDF navigation controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
            ? AppTheme.primaryColor.withOpacity(0.1)
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
              _isPdfLoading = false;
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
              _isPdfLoading = false;
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
          _isPdfLoading = false;
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
                color: AppTheme.primaryColor.withOpacity(0.1),
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
                color: AppTheme.primaryColor.withOpacity(0.1),
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
                color: Colors.orange.withOpacity(0.1),
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
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed unused _buildChapterList() to resolve lint warning


  void _shareContent() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.shareNetwork(),
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text('Pautan dikongsi'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _toggleSaved() async {
    if (_currentEpisode == null || _isSaveLoading) return;

    setState(() {
      _isSaveLoading = true;
    });

    try {
      bool success;
      if (_isSaved) {
        success = await LocalFavoritesService.removeVideoEpisodeFromFavorites(_currentEpisode!.id);
      } else {
        success = await LocalFavoritesService.addVideoEpisodeToFavorites(_currentEpisode!.id);
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
                  Text(_isSaved ? 'Video episod disimpan' : 'Video episod dibuang dari senarai simpan'),
                ],
              ),
              backgroundColor: _isSaved ? AppTheme.primaryColor : Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  const Icon(Icons.error_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Text('Ralat menyimpan video episod'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
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
                  'Senarai Episod',
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
                    color: AppTheme.primaryColor.withOpacity(0.1),
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
            ..._episodes
                .asMap()
                .entries
                .map((entry) => _buildEpisodeCard(entry.value, entry.key))
                .toList(),
          ],
        ),
      ),
    ];
  }

  Widget _buildEpisodeCard(VideoEpisode episode, int index) {
    final isCurrentEpisode = index == _currentEpisodeIndex;
    final thumbnail =
        'https://img.youtube.com/vi/${episode.youtubeVideoId}/mqdefault.jpg';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentEpisode
              ? AppTheme.primaryColor
              : AppTheme.borderColor,
          width: isCurrentEpisode ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _switchToEpisode(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Modern thumbnail with play overlay
              Container(
                width: 100,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        thumbnail,
                        width: 100,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: PhosphorIcon(
                                PhosphorIcons.videoCamera(),
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Play overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black.withOpacity(0.3),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrentEpisode
                                  ? AppTheme.primaryColor
                                  : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: PhosphorIcon(
                              PhosphorIcons.play(PhosphorIconsStyle.fill),
                              color: isCurrentEpisode
                                  ? Colors.white
                                  : AppTheme.textPrimaryColor,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Duration badge
                    if (episode.durationMinutes > 0)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${episode.formattedDuration}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Episode info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrentEpisode
                                ? AppTheme.primaryColor
                                : AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Ep ${episode.partNumber}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isCurrentEpisode
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                          ),
                        ),
                        const Spacer(),
                        if (isCurrentEpisode)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SEMASA',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      episode.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (episode.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        episode.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
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
    );
  }
}
