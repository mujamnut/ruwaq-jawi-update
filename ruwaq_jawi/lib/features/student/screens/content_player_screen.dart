import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:provider/provider.dart';
import '../../../core/models/kitab.dart';
import '../../../core/models/kitab_video.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/bookmark_provider.dart';

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

  // Real data from database
  Kitab? _kitab;
  List<KitabVideo> _episodes = [];
  KitabVideo? _currentEpisode;
  bool _isDataLoading = true;
  int _currentEpisodeIndex = 0;
  final Map<String, int> _episodePositions = {}; // episodeId -> seconds

  // Progress tracking
  int _lastVideoPosition = 0;
  int _currentPdfPage = 1;
  int _totalPdfPages = 0;
  bool _hidePlayer = false;

  Timer? _progressTimer;

  // Bookmark state
  bool _isBookmarkLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load real data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRealData();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookmarkProvider = Provider.of<BookmarkProvider>(
        context,
        listen: false,
      );
      if (!bookmarkProvider.isLoading && bookmarkProvider.bookmarks.isEmpty) {
        bookmarkProvider.loadBookmarks();
      }
    });

    // Start progress tracking timer
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  Future<void> _loadRealData() async {
    try {
      final kitabProvider = context.read<KitabProvider>();

      // Get kitab data
      _kitab = kitabProvider.getKitabById(widget.kitabId);
      if (_kitab == null) {
        await kitabProvider.initialize();
        _kitab = kitabProvider.getKitabById(widget.kitabId);
      }

      if (_kitab == null) {
        throw Exception('Kitab not found');
      }

      // Load episodes if multi-episode kitab
      if (_kitab!.hasMultipleVideos) {
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

      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading content: ${e.toString()}'),
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

    final newVideoId = _currentEpisode!.youtubeVideoId;

    if (_videoController != null) {
      try {
        _videoController!.load(newVideoId);
        final resumePos = _episodePositions[_currentEpisode!.id] ?? 0;
        if (resumePos > 0) {
          _videoController!.seekTo(Duration(seconds: resumePos));
        }
      } catch (_) {}
    }
  }

  Future<void> _initializePlayers() async {
    // Determine video ID
    String? videoId;
    if (_kitab!.hasMultipleVideos && _currentEpisode != null) {
      videoId = _currentEpisode!.youtubeVideoId;
    } else if (_kitab!.youtubeVideoId?.isNotEmpty ?? false) {
      videoId = _kitab!.youtubeVideoId;
    }

    // Initialize YouTube player
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
        // Track video position
        if (_videoController!.value.isReady) {
          _lastVideoPosition = _videoController!.value.position.inSeconds;
          // Save per-episode position as well
          if (_currentEpisode != null) {
            _episodePositions[_currentEpisode!.id] = _lastVideoPosition;
          }
        }
      });

      setState(() {
        _isVideoLoading = false;
      });
    } else {
      setState(() {
        _isVideoLoading = false;
      });
    }

    // Initialize PDF controller
    _pdfController = PdfViewerController();

    setState(() {
      _isPdfLoading = false;
    });
  }

  void _saveProgress() async {
    // TODO: Save progress to database via provider
    // This will save both video position and PDF page
    print(
      'Saving progress: Video ${_lastVideoPosition}s, PDF page $_currentPdfPage',
    );
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

  // Small banner to resume playback from saved bookmark position
  Widget _buildResumeBanner(int seconds) {
    final label = 'Sambung dari ${_formatDuration(seconds)}';
    return Container(
      width: double.infinity,
      color: AppTheme.primaryColor.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.bookmark, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _resumeFromBookmark(seconds),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Main'),
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
          // Handle video end
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.backgroundColor,
      foregroundColor: AppTheme.textPrimaryColor,
      elevation: 0,
      title: Text(
        _kitab?.title ?? 'Kitab',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        Consumer<BookmarkProvider>(
          builder: (context, bookmarkProvider, child) {
            final isBookmarked = bookmarkProvider.isBookmarked(widget.kitabId);
            return IconButton(
              icon: _isBookmarkLoading
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
                  : Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                      color: AppTheme.primaryColor,
                    ),
              onPressed: _isBookmarkLoading ? null : _toggleBookmark,
              tooltip: isBookmarked ? 'Buang Tandaan' : 'Tandai',
            );
          },
        ),
      ],
    );
  }

  Widget _buildEpisodeSelector() {
    if (!(_kitab?.hasMultipleVideos ?? false) || _episodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.surfaceColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _episodes.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    _episodes[i].partNumber > 0
                        ? 'Episod ${_episodes[i].partNumber}'
                        : _episodes[i].title.isNotEmpty
                        ? _episodes[i].title
                        : 'Episod ${i + 1}',
                  ),
                  selected: i == _currentEpisodeIndex,
                  onSelected: (selected) {
                    if (selected && i != _currentEpisodeIndex) {
                      _switchToEpisode(i);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalView(Widget? player) {
    return Column(
      children: [
        // Video player always on top
        _buildVideoSection(player),

        // Tabs under the video
        Container(
          color: AppTheme.backgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondaryColor,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Video'),
              Tab(text: 'E-Book'),
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
    // Show a placeholder box if there is no controller
    if (_videoController == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: const Center(
            child: Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.white70,
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
                                  'Memuatkan video...',
                                  style: TextStyle(color: Colors.white),
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
                        child: const Center(
                          child: Text(
                            'Video tidak tersedia',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
          ),
        ),
        // Episode selector for multi-episode kitab
        _buildEpisodeSelector(),
        // Resume banner only when Video tab is active
        Consumer<BookmarkProvider>(
          builder: (context, bookmarkProvider, _) {
            final bm = bookmarkProvider.getBookmark(widget.kitabId);
            final onVideoTab = _tabController.index == 0;
            final show =
                onVideoTab &&
                bm != null &&
                bm.contentType == 'video' &&
                bm.videoPosition > 0;
            if (!show) return const SizedBox.shrink();
            return _buildResumeBanner(bm.videoPosition);
          },
        ),
      ],
    );
  }

  Widget _buildVideoTabContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Title and Author
          Text(
            (_kitab?.hasMultipleVideos ?? false && _currentEpisode != null)
                ? _currentEpisode!.title
                : _kitab?.title ?? 'Kitab',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _kitab?.author ?? 'Penulis',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            (_kitab?.hasMultipleVideos ?? false && _currentEpisode != null)
                ? (_currentEpisode!.description ?? '')
                : (_kitab?.description ?? ''),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Episodes Section
          if (_episodes.length > 1) ..._buildEpisodesSection(),
        ],
      ),
    );
  }

  Widget _buildPdfTab() {
    return Column(
      children: [
        // PDF Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.surfaceColor,
          child: Row(
            children: [
              Text(
                'Halaman $_currentPdfPage${_totalPdfPages > 0 ? ' daripada $_totalPdfPages' : ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.zoom_out),
                onPressed: () => _pdfController?.zoomLevel = 1.0,
                tooltip: 'Zum Keluar',
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in),
                onPressed: () => _pdfController?.zoomLevel = 2.0,
                tooltip: 'Zum Masuk',
              ),
            ],
          ),
        ),

        // PDF Viewer
        Expanded(
          child: widget.pdfUrl != null && widget.pdfUrl!.isNotEmpty
              ? SfPdfViewer.network(
                  widget.pdfUrl!,
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
                )
              : const Center(
                  child: Text(
                    'PDF tidak tersedia',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
        ),

        // PDF Navigation Controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: _currentPdfPage > 1
                    ? () => _pdfController?.firstPage()
                    : null,
                tooltip: 'Halaman Pertama',
              ),
              IconButton(
                icon: const Icon(Icons.navigate_before),
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
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_currentPdfPage',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.navigate_next),
                onPressed: _currentPdfPage < _totalPdfPages
                    ? () => _pdfController?.nextPage()
                    : null,
                tooltip: 'Halaman Seterusnya',
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
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

  // Removed unused _buildChapterList() to resolve lint warning

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _toggleBookmark() async {
    if (_isBookmarkLoading) return;

    setState(() {
      _isBookmarkLoading = true;
    });

    try {
      final bookmarkProvider = Provider.of<BookmarkProvider>(
        context,
        listen: false,
      );
      final isCurrentlyBookmarked = bookmarkProvider.isBookmarked(
        widget.kitabId,
      );

      // Determine current content type based on active tab
      final currentContentType = _tabController.index == 0 ? 'video' : 'pdf';

      final success = await bookmarkProvider.toggleBookmark(
        kitabId: widget.kitabId,
        title: _kitab?.title ?? 'Kitab',
        description: _kitab?.description ?? '',
        videoPosition: _lastVideoPosition,
        pdfPage: _currentPdfPage,
        contentType: currentContentType,
      );

      if (success) {
        final message = isCurrentlyBookmarked
            ? 'Tandaan telah dibuang'
            : 'Ditandai pada kedudukan semasa';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isCurrentlyBookmarked
                        ? Icons.bookmark_remove
                        : Icons.bookmark_added,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message)),
                ],
              ),
              backgroundColor: isCurrentlyBookmarked
                  ? Colors.orange
                  : AppTheme.primaryColor,
              duration: const Duration(seconds: 2),
              action: !isCurrentlyBookmarked
                  ? SnackBarAction(
                      label: 'LIHAT',
                      textColor: Colors.white,
                      onPressed: () {
                        // Navigate to bookmarks screen
                        context.push('/saved');
                      },
                    )
                  : null,
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
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bookmarkProvider.error ?? 'Gagal mengemas kini tandaan',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
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
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Ralat: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBookmarkLoading = false;
        });
      }
    }
  }

  List<Widget> _buildEpisodesSection() {
    if (_episodes.length <= 1) return [];

    return [
      Text(
        _episodes.length > 1 ? 'Senarai Episod' : 'Video',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimaryColor,
        ),
      ),
      const SizedBox(height: 16),
      ..._episodes
          .asMap()
          .entries
          .map((entry) => _buildEpisodeCard(entry.value, entry.key))
          .toList(),
    ];
  }

  Widget _buildEpisodeCard(KitabVideo episode, int index) {
    final isCurrentEpisode = index == _currentEpisodeIndex;
    final thumbnail =
        'https://img.youtube.com/vi/${episode.youtubeVideoId}/mqdefault.jpg';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentEpisode
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentEpisode
              ? AppTheme.primaryColor.withOpacity(0.3)
              : AppTheme.borderColor,
        ),
      ),
      child: InkWell(
        onTap: () => _switchToEpisode(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 120,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[300],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        thumbnail,
                        width: 120,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 120,
                            height: 68,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.play_circle_fill,
                              color: Colors.red,
                              size: 30,
                            ),
                          );
                        },
                      ),
                    ),
                    // Duration badge
                    if (episode.durationMinutes > 0)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${episode.durationMinutes}m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    // Current episode indicator
                    if (isCurrentEpisode)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SEMASA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Episode info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Episod ${episode.partNumber}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const Spacer(),
                        if (isCurrentEpisode)
                          Icon(
                            Icons.play_arrow,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      episode.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (episode.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        episode.description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor,
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
