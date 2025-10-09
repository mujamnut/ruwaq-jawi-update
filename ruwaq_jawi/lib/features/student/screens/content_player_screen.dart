import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// Import models
import '../../../core/models/video_kitab.dart';
import '../../../core/models/video_episode.dart';

// Import providers
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/kitab_provider.dart';

// Import theme
import '../../../core/theme/app_theme.dart';

// Import managers
import 'content_player_screen/managers/video_player_manager.dart';
import 'content_player_screen/managers/controls_manager.dart';

// Import widgets
import 'content_player_screen/widgets/video_player_widget.dart';
import 'content_player_screen/widgets/fullscreen_player_widget.dart';
import 'content_player_screen/widgets/tab_bar_widget.dart';
import 'content_player_screen/widgets/episodes_tab_widget.dart';
import 'content_player_screen/widgets/pdf_tab_widget.dart';
import 'ebook_detail_screen.dart';

// Import services
import 'content_player_screen/services/premium_dialog_helper.dart';

// Import utils
import 'content_player_screen/utils/video_helpers.dart';

class ContentPlayerScreen extends StatefulWidget {
  final String kitabId;
  final String? episodeId;
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
    with SingleTickerProviderStateMixin {
  // Data
  VideoKitab? _kitab;
  List<VideoEpisode> _episodes = [];
  bool _isLoading = true;
  int _currentEpisodeIndex = 0;

  // Managers
  late VideoPlayerManager _videoManager;
  late ControlsManager _controlsManager;

  // UI state
  bool _isFullscreen = false;
  final ScrollController _scrollController = ScrollController();

  // Tab controller
  late TabController _tabController;
  int _currentTabIndex = 0;

  bool get _isPremiumUser {
    final authProvider = context.read<AuthProvider>();
    return authProvider.hasActiveSubscription;
  }

  @override
  void initState() {
    super.initState();

    // Initialize managers
    _videoManager = VideoPlayerManager(
      onStateChanged: () {
        if (mounted) {
          setState(() {});

          // Check if video ended
          if (_videoManager.isVideoEnded) {
            _onVideoEnded();
          }
        }
      },
    );

    _controlsManager = ControlsManager(
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );

    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });

    // Allow all orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final kitabProvider = context.read<KitabProvider>();
      final videoKitabList = kitabProvider.activeVideoKitab;

      try {
        _kitab = videoKitabList.firstWhere((vk) => vk.id == widget.kitabId);
      } catch (e) {
        debugPrint('VideoKitab not found: $e');
        setState(() => _isLoading = false);
        return;
      }

      // Load episodes
      if (_kitab?.hasVideos == true) {
        _episodes = await kitabProvider.loadKitabVideos(widget.kitabId);
        _episodes.sort((a, b) => a.partNumber.compareTo(b.partNumber));

        // Find current episode
        if (widget.episodeId != null) {
          final episodeIndex = _episodes.indexWhere(
            (ep) => ep.id == widget.episodeId,
          );
          if (episodeIndex != -1) {
            _currentEpisodeIndex = episodeIndex;
          } else {
            _currentEpisodeIndex = 0;
          }
        } else {
          _currentEpisodeIndex = 0;
        }

        // Initialize video player
        if (_episodes.isNotEmpty) {
          _videoManager.initializePlayer(_episodes[_currentEpisodeIndex]);
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onVideoEnded() {
    // Auto play next episode if available
    if (_currentEpisodeIndex + 1 < _episodes.length) {
      final nextEpisode = _episodes[_currentEpisodeIndex + 1];
      if (!nextEpisode.isPremium || _isPremiumUser) {
        _switchToEpisode(_currentEpisodeIndex + 1);
      }
    }
  }

  Future<void> _toggleFullscreen() async {
    if (_videoManager.controller == null || !mounted) return;

    setState(() {
      _isFullscreen = !_isFullscreen;
      _controlsManager.showControls = true;
    });

    _controlsManager.cancelTimers();

    try {
      if (_isFullscreen) {
        // Enter fullscreen
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
        ).timeout(const Duration(seconds: 2));

        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]).timeout(const Duration(seconds: 2));

        _controlsManager.startControlsTimer(
          isFullscreen: true,
          isPlaying: _videoManager.isPlaying,
        );
      } else {
        // Exit fullscreen
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
        ).timeout(const Duration(seconds: 2));

        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]).timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('Error toggling fullscreen: $e');
      // Revert state on error
      setState(() {
        _isFullscreen = !_isFullscreen;
      });

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengubah mode layar penuh'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_videoManager.controller == null) return;

    final size = MediaQuery.of(context).size;
    final position = details.localPosition;
    final isLeftSide = VideoHelpers.isLeftSide(position.dx, size.width);
    final skipSeconds = VideoHelpers.getSkipSeconds(isLeftSide);

    try {
      final currentPosition = _videoManager.currentPosition.inSeconds;
      final videoDuration = _videoManager.duration.inSeconds;
      final newPosition = VideoHelpers.clampPosition(
        currentPosition,
        skipSeconds,
        videoDuration,
      );

      _videoManager.seekTo(Duration(seconds: newPosition));
      _controlsManager.showSkipFeedback(
        isLeftSide,
        skipSeconds.abs(),
        isLeftSide,
      );

      if (_videoManager.isPlaying) {
        _controlsManager.startControlsTimer(
          isFullscreen: _isFullscreen,
          isPlaying: true,
        );
      }
    } catch (e) {
      debugPrint('Error in double tap seek: $e');
    }
  }

  void _switchToEpisode(int index) {
    if (index < 0 || index >= _episodes.length) return;

    final newEpisode = _episodes[index];
    debugPrint('🔄 Switching to episode ${index + 1}: ${newEpisode.title}');

    if (_isFullscreen) {
      _toggleFullscreen();
    }

    setState(() {
      _currentEpisodeIndex = index;
    });

    // Scroll to top
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Memainkan: ${newEpisode.title}',
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Initialize new player
    _videoManager.initializePlayer(newEpisode);
  }

  void _onEpisodeTap(int index, VideoEpisode episode) {
    debugPrint('👆 Episode tapped: ${episode.title} (Index: $index)');

    if (index == _currentEpisodeIndex) {
      debugPrint('ℹ️ Already playing this episode, ignoring tap');
      return;
    }

    if (episode.isPremium && !_isPremiumUser) {
      debugPrint('🔒 Episode is premium-locked');
      PremiumDialogHelper.showPremiumDialog(context);
      return;
    }

    _switchToEpisode(index);
  }

  void _onOpenPdf() {
    debugPrint('Opening PDF: ${_kitab?.pdfUrl}');

    if (_kitab?.pdfUrl?.isNotEmpty == true) {
      // Navigate to PDF viewer screen using the kitab ID as ebook ID
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EbookDetailScreen(ebookId: _kitab!.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF tidak tersedia untuk kitab ini'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controlsManager.dispose();
    _videoManager.dispose();
    _scrollController.dispose();
    _tabController.dispose();

    // Restore system UI and orientation with timeout
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)
        .timeout(const Duration(seconds: 1))
        .catchError((e) => debugPrint('Error restoring UI mode: $e'));
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
        .timeout(const Duration(seconds: 1))
        .catchError((e) => debugPrint('Error restoring orientation: $e'));

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If no controller is available, show loading or error state
    if (_videoManager.controller == null && !_isLoading) {
      return _buildNoVideoState();
    }

    return YoutubePlayerBuilder(
      key: ValueKey(_videoManager.currentEpisode?.id ?? 'no-episode'),
      player: YoutubePlayer(
        controller:
            _videoManager.controller ??
            YoutubePlayerController(
              initialVideoId: '', // Empty ID - will show black screen
              flags: const YoutubePlayerFlags(
                autoPlay: false,
                hideControls: true,
              ),
            ),
        showVideoProgressIndicator: false,
        onReady: () {
          if (mounted) setState(() {});
        },
      ),
      builder: (context, player) {
        return OrientationBuilder(
          builder: (context, orientation) {
            if (_isFullscreen) {
              return _buildFullscreenLayout(player);
            } else {
              return _buildPortraitLayout(player);
            }
          },
        );
      },
    );
  }

  Widget _buildFullscreenLayout(Widget player) {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _isFullscreen) {
          await _toggleFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _videoManager.controller == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : FullscreenPlayerWidget(
                player: player,
                controller: _videoManager.controller,
                showControls: _controlsManager.showControls,
                showSkipAnimation: _controlsManager.showSkipAnimation,
                isSkipForward: _controlsManager.isSkipForward,
                isSkipOnLeftSide: _controlsManager.isSkipOnLeftSide,
                onToggleFullscreen: _toggleFullscreen,
                onShowControls: () {
                  _controlsManager.showControlsTemporarily(
                    isFullscreen: _isFullscreen,
                    isPlaying: _videoManager.isPlaying,
                  );
                },
                onHideControls: _controlsManager.hideControls,
                onTogglePlayPause: () {
                  if (_videoManager.isPlaying) {
                    _videoManager.pause();
                  } else {
                    _videoManager.play();
                  }
                },
                onDoubleTap: _handleDoubleTap,
                onStartControlsTimer: (isFullscreen, isPlaying) {
                  _controlsManager.startControlsTimer(
                    isFullscreen: isFullscreen,
                    isPlaying: isPlaying,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPortraitLayout(Widget player) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            : _kitab == null
            ? _buildErrorView()
            : _buildContent(player),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: PhosphorIcon(
          PhosphorIcons.arrowLeft(),
          color: AppTheme.textPrimaryColor,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        _kitab?.title ?? 'Kitab',
        style: const TextStyle(
          color: AppTheme.textPrimaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIcons.warning(),
            size: 48,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Kitab tidak dijumpai',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVideoState() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                PhosphorIcons.videoCamera(PhosphorIconsStyle.light),
                size: 64,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Video tidak tersedia',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sila cuba lagi atau hubungi sokongan',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: PhosphorIcon(PhosphorIcons.arrowLeft(), size: 20),
                label: const Text('Kembali'),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Widget player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Video Player (Fixed)
        if (_videoManager.controller != null &&
            _videoManager.currentEpisode != null)
          VideoPlayerWidget(
            player: player,
            controller: _videoManager.controller,
            currentEpisode: _videoManager.currentEpisode,
            showControls: _controlsManager.showControls,
            showSkipAnimation: _controlsManager.showSkipAnimation,
            isSkipForward: _controlsManager.isSkipForward,
            isSkipOnLeftSide: _controlsManager.isSkipOnLeftSide,
            onToggleFullscreen: _toggleFullscreen,
            onShowControls: () {
              _controlsManager.showControlsTemporarily(
                isFullscreen: _isFullscreen,
                isPlaying: _videoManager.isPlaying,
              );
            },
            onHideControls: _controlsManager.hideControls,
            onTogglePlayPause: () {
              if (_videoManager.isPlaying) {
                _videoManager.pause();
              } else {
                _videoManager.play();
              }
            },
            onDoubleTap: _handleDoubleTap,
            onStartControlsTimer: (isFullscreen, isPlaying) {
              _controlsManager.startControlsTimer(
                isFullscreen: isFullscreen,
                isPlaying: isPlaying,
              );
            },
          ),

        // Title and Description (Fixed)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _buildTitleAndDescription(),
        ),

        const SizedBox(height: 16),

        // Tab Bar (Fixed)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TabBarWidget(
            controller: _tabController,
            currentTabIndex: _currentTabIndex,
            episodesCount: _episodes.length,
          ),
        ),

        const SizedBox(height: 16),

        // Tab Content (Scrollable)
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _currentTabIndex == 0
                ? EpisodesTabWidget(
                    episodes: _episodes,
                    currentEpisodeIndex: _currentEpisodeIndex,
                    isPlaying: _videoManager.isPlaying,
                    isPremiumUser: _isPremiumUser,
                    onEpisodeTap: _onEpisodeTap,
                  )
                : PdfTabWidget(
                    kitab: _kitab,
                    isPremiumUser: _isPremiumUser,
                    onOpenPdf: _onOpenPdf,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleAndDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          _videoManager.currentEpisode?.title ?? _kitab?.title ?? 'Kitab',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),

        // Author
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

        // Description
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
    );
  }
}
