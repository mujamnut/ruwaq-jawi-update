import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';

// Import extracted widgets
import 'content_player_screen/widgets/pdf_tab_widget.dart';
import 'content_player_screen/widgets/loading_error_screens.dart';
import 'content_player_screen/widgets/content_player_appbar.dart';
import 'content_player_screen/widgets/resume_banner_widget.dart';
import 'content_player_screen/widgets/video_tab_content_widget.dart';
import 'content_player_screen/widgets/youtube_player_config_widget.dart';
import 'content_player_screen/widgets/normal_view_layout_widget.dart';
import 'content_player_screen/widgets/content_player_scaffold_widget.dart';

// Import extracted managers
import 'content_player_screen/managers/video_controls_manager.dart';
import 'content_player_screen/managers/data_loader_manager.dart';
import 'content_player_screen/managers/pdf_manager.dart';
import 'content_player_screen/managers/player_lifecycle_manager.dart';
import 'content_player_screen/managers/animation_manager.dart';
import 'content_player_screen/managers/favorites_manager.dart';

// Import services
import 'content_player_screen/services/notification_helper.dart';
import 'content_player_screen/services/premium_dialog_helper.dart';

// Import providers
import '../../../core/providers/auth_provider.dart';

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
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Progress tracking
  int _currentPdfPage = 1;
  int _totalPdfPages = 0;

  // Managers
  late VideoControlsManager _videoControlsManager;
  late DataLoaderManager _dataLoaderManager;
  late PdfManager _pdfManager;
  late PlayerLifecycleManager _lifecycleManager;
  late AnimationManager _animationManager;
  late FavoritesManager _favoritesManager;

  // Premium user state
  bool get _isPremiumUser {
    final authProvider = context.read<AuthProvider>();
    return authProvider.hasActiveSubscription;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize managers
    _videoControlsManager = VideoControlsManager(
      onStateChanged: () => setState(() {}),
    );
    _dataLoaderManager = DataLoaderManager(
      onStateChanged: () => setState(() {}),
      onShowNotification: (message) =>
          NotificationHelper.showError(context, message),
    );
    _pdfManager = PdfManager(onStateChanged: () => setState(() {}));
    _lifecycleManager = PlayerLifecycleManager(
      onStateChanged: () => setState(() {}),
    );
    _animationManager = AnimationManager(onStateChanged: () => setState(() {}));
    _favoritesManager = FavoritesManager(onStateChanged: () => setState(() {}));

    // Initialize animations
    _animationManager.initialize(this);

    // Load real data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    // Start progress tracking timer
    _lifecycleManager.initializeProgressTimer();
  }

  Future<void> _loadData() async {
    await _dataLoaderManager.loadRealData(
      context,
      widget.kitabId,
      widget.episodeId,
    );

    // Check save status after episode is loaded
    _favoritesManager.checkSaveStatus(
      _dataLoaderManager.currentEpisode,
      _dataLoaderManager.kitab?.id,
    );

    // Check PDF cache
    await _pdfManager.checkPdfCache(_dataLoaderManager.kitab);

    if (mounted) {
      // Start animations
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _animationManager.startAnimations();
        }
      });
    }
  }

  Widget _buildResumeBanner(int seconds) {
    return ResumeBannerWidget(
      seconds: seconds,
      onResume: () => _resumeFromBookmark(seconds),
    );
  }

  void _resumeFromBookmark(int seconds) {
    if (_dataLoaderManager.videoController == null) return;
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
    _dataLoaderManager.videoController!.seekTo(Duration(seconds: seconds));
    NotificationHelper.showVideoResumeSuccess(context, seconds);
  }

  void _onVideoEnded(YoutubeMetaData metaData) {
    debugPrint(
      '🎬 Video ended. Current episode index: ${_dataLoaderManager.currentEpisodeIndex}',
    );
    debugPrint(
      '🎬 Current episode part: ${_dataLoaderManager.currentEpisode?.partNumber}',
    );
    debugPrint('🎬 Total episodes: ${_dataLoaderManager.episodes.length}');
    debugPrint(
      '🎬 Next episode index would be: ${_dataLoaderManager.currentEpisodeIndex + 1}',
    );

    if (_dataLoaderManager.currentEpisodeIndex + 1 <
        _dataLoaderManager.episodes.length) {
      debugPrint(
        '🎬 Next episode part: ${_dataLoaderManager.episodes[_dataLoaderManager.currentEpisodeIndex + 1].partNumber}',
      );
    }

    if (mounted &&
        _dataLoaderManager.currentEpisodeIndex <
            _dataLoaderManager.episodes.length - 1) {
      // Check if next episode is premium and user doesn't have subscription
      final nextEpisodeIndex = _dataLoaderManager.currentEpisodeIndex + 1;
      final nextEpisode = _dataLoaderManager.episodes[nextEpisodeIndex];

      // Don't autoplay to premium episode if user is not subscribed
      if (nextEpisode.isPremium && !_isPremiumUser) {
        debugPrint('🎬 Next episode is premium. Stopping autoplay for free user.');
        return;
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          debugPrint('🎬 Switching to next episode...');
          _dataLoaderManager.switchToEpisode(nextEpisodeIndex);
          _favoritesManager.checkSaveStatus(
            _dataLoaderManager.currentEpisode,
            _dataLoaderManager.kitab?.id,
          );
        }
      });
    }
  }

  void _onVideoReady() {
    if (mounted) {
      setState(() {});
      if (_dataLoaderManager.videoController?.value.isPlaying == true &&
          _videoControlsManager.showControls) {
        _videoControlsManager.startControlsTimer();
      }
    }
  }

  Future<void> _toggleSaved() async {
    final success = await _favoritesManager.toggleSaved(
      _dataLoaderManager.currentEpisode,
      _dataLoaderManager.kitab?.id,
    );

    if (mounted) {
      if (success) {
        NotificationHelper.showSaveVideoSuccess(
          context,
          _favoritesManager.isSaved,
        );
      } else {
        NotificationHelper.showSaveVideoError(context);
      }
    }
  }

  @override
  void dispose() {
    _videoControlsManager.dispose();
    _dataLoaderManager.dispose();
    _lifecycleManager.dispose(_dataLoaderManager.videoController);
    _animationManager.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    _lifecycleManager.deactivate(_dataLoaderManager.videoController);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while data is loading
    if (_dataLoaderManager.isDataLoading) {
      return LoadingErrorScreens.buildLoadingScreen(context);
    }

    // Show error if kitab not found
    if (_dataLoaderManager.kitab == null) {
      return LoadingErrorScreens.buildKitabNotFoundScreen(
        context,
        _buildAppBar(),
      );
    }

    // Build main content with YouTube player
    if (_dataLoaderManager.videoController == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: PopScope(
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              await _lifecycleManager.onWillPop(
                context,
                _dataLoaderManager.videoController,
              );
            }
          },
          child: _buildNormalView(null),
        ),
      );
    }

    return YoutubePlayerConfigWidget(
      controller: _dataLoaderManager.videoController!,
      onReady: _onVideoReady,
      onEnded: _onVideoEnded,
      builder: (context, player) {
        // Use our custom fullscreen state (not YouTube's native)
        return ContentPlayerScaffoldWidget(
          isFullscreen: _videoControlsManager.isFullscreen,
          appBar: _buildAppBar(),
          normalView: _buildNormalView(player),
          player: player,
          videoController: _dataLoaderManager.videoController,
          showControls: _videoControlsManager.showControls,
          showSkipAnimation: _videoControlsManager.showSkipAnimation,
          isSkipForward: _videoControlsManager.isSkipForward,
          isSkipOnLeftSide: _videoControlsManager.isSkipOnLeftSide,
          onToggleControls: _videoControlsManager.toggleControls,
          onStartControlsTimer: _videoControlsManager.startControlsTimer,
          onShowSkipFeedback: _videoControlsManager.showSkipFeedback,
          onToggleFullscreen: _videoControlsManager.toggleFullscreen,
          onWillPop: () => _lifecycleManager.onWillPop(
            context,
            _dataLoaderManager.videoController,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return ContentPlayerAppBar(
      kitab: _dataLoaderManager.kitab,
      isSaved: _favoritesManager.isSaved,
      isSaveLoading: _favoritesManager.isSaveLoading,
      onToggleSaved: _toggleSaved,
    );
  }

  Widget _buildNormalView(Widget? player) {
    return NormalViewLayoutWidget(
      player: player,
      hidePlayer: _lifecycleManager.hidePlayer,
      videoController: _dataLoaderManager.videoController,
      isVideoLoading: _dataLoaderManager.isVideoLoading,
      currentEpisode: _dataLoaderManager.currentEpisode,
      tabController: _tabController,
      showControls: _videoControlsManager.showControls,
      showSkipAnimation: _videoControlsManager.showSkipAnimation,
      isSkipForward: _videoControlsManager.isSkipForward,
      isSkipOnLeftSide: _videoControlsManager.isSkipOnLeftSide,
      isFullscreen: _videoControlsManager.isFullscreen,
      onToggleControls: _videoControlsManager.toggleControls,
      onStartControlsTimer: _videoControlsManager.startControlsTimer,
      onShowSkipFeedback: _videoControlsManager.showSkipFeedback,
      buildResumeBanner: _buildResumeBanner,
      onToggleFullscreen: _videoControlsManager.toggleFullscreen,
      fadeAnimation: _animationManager.fadeAnimation,
      slideAnimation: _animationManager.slideAnimation,
      videoTabContent: _buildVideoTabContent(),
      pdfTabContent: _buildPdfTabWidget(),
    );
  }

  Widget _buildVideoTabContent() {
    return VideoTabContentWidget(
      isDataLoading: _dataLoaderManager.isDataLoading,
      kitab: _dataLoaderManager.kitab,
      currentEpisode: _dataLoaderManager.currentEpisode,
      episodes: _dataLoaderManager.episodes,
      currentEpisodeIndex: _dataLoaderManager.currentEpisodeIndex,
      isPremiumUser: _isPremiumUser,
      isVideoPlaying: (index) =>
          index == _dataLoaderManager.currentEpisodeIndex &&
          (_dataLoaderManager.videoController?.value.isPlaying ?? false),
      onEpisodeTap: (index) {
        // Check if tapping on a premium episode while being a free user
        if (index < _dataLoaderManager.episodes.length) {
          final tappedEpisode = _dataLoaderManager.episodes[index];

          if (tappedEpisode.isPremium && !_isPremiumUser) {
            // Show premium dialog instead of switching
            PremiumDialogHelper.showPremiumDialog(context);
            return;
          }
        }

        // Safe to switch - either free episode or user has subscription
        _dataLoaderManager.switchToEpisode(index);
        _favoritesManager.checkSaveStatus(
          _dataLoaderManager.currentEpisode,
          _dataLoaderManager.kitab?.id,
        );
      },
    );
  }

  Widget _buildPdfTabWidget() {
    return PdfTabWidget(
      kitab: _dataLoaderManager.kitab,
      pdfController: _dataLoaderManager.pdfController,
      currentPdfPage: _currentPdfPage,
      totalPdfPages: _totalPdfPages,
      cachedPdfPath: _pdfManager.cachedPdfPath,
      isPdfDownloading: _pdfManager.isPdfDownloading,
      downloadProgress: _pdfManager.downloadProgress,
      onDownloadPdf: () =>
          _pdfManager.downloadPdfIfNeeded(context, _dataLoaderManager.kitab),
      onSetCachedPath: _pdfManager.setCachedPath,
      onPageChanged: (pageNumber) {
        setState(() {
          _currentPdfPage = pageNumber;
        });
      },
      onDocumentLoaded: (pageCount) {
        setState(() {
          _totalPdfPages = pageCount;
        });
      },
    );
  }
}
