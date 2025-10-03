import 'dart:async';
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

// Import widgets
import 'content_player_screen/widgets/episode_card_widget.dart';
import 'content_player_screen/services/premium_dialog_helper.dart';

// Import services
import '../../../core/services/video_progress_service.dart';

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

class _ContentPlayerScreenState extends State<ContentPlayerScreen> {
  VideoKitab? _kitab;
  List<VideoEpisode> _episodes = [];
  VideoEpisode? _currentEpisode;
  bool _isLoading = true;
  int _currentEpisodeIndex = 0;

  // Video player state
  YoutubePlayerController? _videoController;
  bool _isFullscreen = false; // Track fullscreen state
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _showSkipAnimation = false;
  bool _isSkipForward = false;
  bool _isSkipOnLeftSide = false;
  Timer? _skipAnimationTimer;

  bool get _isPremiumUser {
    final authProvider = context.read<AuthProvider>();
    return authProvider.hasActiveSubscription;
  }

  @override
  void initState() {
    super.initState();

    // Allow all orientations for auto-rotation
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
          final episodeIndex =
              _episodes.indexWhere((ep) => ep.id == widget.episodeId);
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

        // Initialize video player for current episode
        if (_currentEpisode != null) {
          _initializePlayer(_currentEpisode!);
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _initializePlayer(VideoEpisode episode) {
    final videoId = episode.youtubeVideoId;

    if (videoId.isEmpty) {
      return;
    }

    // Dispose old controller
    _videoController?.dispose();

    _videoController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
        controlsVisibleAtStart: false,
        hideControls: true,
        disableDragSeek: true,
        loop: false,
        useHybridComposition: true,
      ),
    );

    _videoController!.addListener(_onPlayerStateChange);

    // Restore saved position
    final savedPosition = VideoProgressService.getVideoPosition(episode.id);
    if (savedPosition > 10) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_videoController != null && mounted) {
          _videoController!.seekTo(Duration(seconds: savedPosition));
        }
      });
    }
  }

  void _onPlayerStateChange() {
    if (!mounted) return;

    if (_videoController != null && _videoController!.value.isReady && _currentEpisode != null) {
      final position = _videoController!.value.position.inSeconds;
      final duration = _videoController!.metadata.duration.inSeconds;

      VideoProgressService.saveVideoPosition(_currentEpisode!.id, position);

      // Check if video ended
      if (position > 0 && duration > 0 && (duration - position) < 2) {
        _onVideoEnded();
      }
    }
  }

  void _onVideoEnded() {
    // Auto play next episode if available
    if (_currentEpisodeIndex + 1 < _episodes.length) {
      final nextEpisode = _episodes[_currentEpisodeIndex + 1];
      // Check if next episode is premium
      if (!nextEpisode.isPremium || _isPremiumUser) {
        _switchToEpisode(_currentEpisodeIndex + 1);
      }
    }
  }

  // Toggle fullscreen by changing orientation
  // OrientationBuilder will detect and switch layouts automatically
  Future<void> _toggleFullscreen() async {
    if (_videoController == null || !mounted) return;

    setState(() {
      _isFullscreen = !_isFullscreen;
      // Always show controls when entering/exiting fullscreen
      _showControls = true;
    });

    // Cancel any auto-hide timer
    _controlsTimer?.cancel();

    if (_isFullscreen) {
      // Enter fullscreen - hide UI and force landscape
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      // Start auto-hide timer for fullscreen
      _startControlsTimer();
    } else {
      // Exit fullscreen - show UI and allow portrait
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }


  void _startControlsTimer() {
    _controlsTimer?.cancel();
    // Increase timer to 5 seconds for better UX - gives user more time to interact
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _showSkipFeedback(bool isBackward, int seconds, bool isLeftSide) {
    setState(() {
      _showSkipAnimation = true;
      _isSkipForward = !isBackward;
      _isSkipOnLeftSide = isLeftSide;
    });

    _skipAnimationTimer?.cancel();
    _skipAnimationTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showSkipAnimation = false;
        });
      }
    });
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_videoController == null) return;

    final size = MediaQuery.of(context).size;
    final position = details.localPosition;
    final isLeftSide = position.dx < size.width / 2;
    final skipSeconds = isLeftSide ? -10 : 10;

    try {
      final currentPosition = _videoController!.value.position.inSeconds;
      final videoDuration = _videoController!.metadata.duration.inSeconds;
      final newPosition = (currentPosition + skipSeconds).clamp(0, videoDuration);

      _videoController!.seekTo(Duration(seconds: newPosition.toInt()));
      _showSkipFeedback(isLeftSide, skipSeconds.abs(), isLeftSide);

      if (_videoController!.value.isPlaying) {
        _startControlsTimer();
      }
    } catch (e) {
      debugPrint('Error in double tap seek: $e');
    }
  }

  void _switchToEpisode(int index) {
    if (index < 0 || index >= _episodes.length) return;

    setState(() {
      _currentEpisodeIndex = index;
      _currentEpisode = _episodes[index];
    });

    _initializePlayer(_currentEpisode!);
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _skipAnimationTimer?.cancel();
    _videoController?.dispose();

    // Reset to portrait and restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _videoController ?? YoutubePlayerController(
          initialVideoId: 'dQw4w9WgXcQ', // Dummy - won't be used
          flags: const YoutubePlayerFlags(autoPlay: false),
        ),
        showVideoProgressIndicator: false,
        onReady: () {
          if (mounted) setState(() {});
        },
      ),
      builder: (context, player) {
        // OrientationBuilder to switch between fullscreen and normal layouts
        // SAME player widget used in both layouts - NO REBUILD!
        return OrientationBuilder(
          builder: (context, orientation) {
            // Choose layout based on FULLSCREEN STATE (not orientation)
            // _isFullscreen is the source of truth, controlled by _toggleFullscreen()
            if (_isFullscreen) {
              return _buildLandscapeFullscreen(player);
            } else {
              return _buildPortraitNormal(player);
            }
          },
        );
      },
    );
  }

  // Landscape fullscreen layout
  Widget _buildLandscapeFullscreen(Widget player) {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _isFullscreen) {
          // Exit fullscreen instead of popping route
          await _toggleFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _videoController == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _buildFullscreenPlayerLayout(player),
      ),
    );
  }

  // Portrait normal view layout
  Widget _buildPortraitNormal(Widget player) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _kitab == null
              ? _buildErrorView()
              : _buildContent(player),
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

  Widget _buildContent(Widget player) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Player Section (like YouTube)
          if (_videoController != null && _currentEpisode != null)
            _buildVideoPlayerLayout(player),

          // Content Section (scrollable)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        _currentEpisode?.title ?? _kitab?.title ?? 'Kitab',
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
                  ),
                ),

                const SizedBox(height: 20),

                // Episodes Playlist
                if (_episodes.isNotEmpty) _buildEpisodesSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fullscreen player layout (landscape)
  Widget _buildFullscreenPlayerLayout(Widget player) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Player fills entire screen
          Positioned.fill(child: player),

          // Skip animation feedback
          if (_showSkipAnimation)
            Positioned(
              left: _isSkipOnLeftSide ? 40 : null,
              right: !_isSkipOnLeftSide ? 40 : null,
              top: MediaQuery.of(context).size.height / 2 - 50,
              child: AnimatedOpacity(
                opacity: _showSkipAnimation ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        _isSkipForward
                            ? PhosphorIcons.fastForward(PhosphorIconsStyle.fill)
                            : PhosphorIcons.rewind(PhosphorIconsStyle.fill),
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '10s',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Controls overlay with gesture detection
          _buildControlsOverlay(),

          // Gesture detector for showing controls when hidden
          // Place AFTER controls so it doesn't block control buttons
          if (!_showControls)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (mounted) {
                    setState(() {
                      _showControls = true;
                    });
                    _startControlsTimer();
                  }
                },
                onDoubleTap: () {},
                onDoubleTapDown: _handleDoubleTap,
                child: Container(
                  color: Colors.transparent,
                  // Add visual feedback hint
                  child: Center(
                    child: Icon(
                      Icons.touch_app_outlined,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Normal view player layout (portrait) - 16:9 aspect ratio
  Widget _buildVideoPlayerLayout(Widget player) {
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
                const SizedBox(height: 16),
                const Text(
                  'Video tidak tersedia',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          // Player
          Positioned.fill(child: player),

          // Skip animation feedback
          if (_showSkipAnimation)
            Positioned(
              left: _isSkipOnLeftSide ? 40 : null,
              right: !_isSkipOnLeftSide ? 40 : null,
              top: MediaQuery.of(context).size.height / 2 - 200,
              child: AnimatedOpacity(
                opacity: _showSkipAnimation ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        _isSkipForward
                            ? PhosphorIcons.fastForward(PhosphorIconsStyle.fill)
                            : PhosphorIcons.rewind(PhosphorIconsStyle.fill),
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '10s',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Controls overlay with gesture detection
          _buildControlsOverlay(),

          // Gesture detector for showing controls when hidden
          if (!_showControls)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (mounted) {
                    setState(() {
                      _showControls = true;
                    });
                    _startControlsTimer();
                  }
                },
                onDoubleTap: () {},
                onDoubleTapDown: _handleDoubleTap,
                child: Container(
                  color: Colors.transparent,
                  // Add visual feedback hint
                  child: Center(
                    child: Icon(
                      Icons.touch_app_outlined,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        // Controls overlay
        if (_showControls)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Stack(
                children: [
                  // Tap to hide controls (background layer)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // Tap on overlay area (not on buttons) hides controls
                        setState(() {
                          _showControls = false;
                          _controlsTimer?.cancel();
                        });
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                  // Center Play/Pause (on top of gesture detector)
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
                                _startControlsTimer();
                              }
                            }
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? PhosphorIcons.pause() : PhosphorIcons.play(),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Controls
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        // Prevent tap from hiding controls when interacting with bottom controls
                      },
                      child: _buildBottomControls(),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Skip Animation
        if (_showSkipAnimation)
          Positioned(
            left: _isSkipOnLeftSide ? 40 : null,
            right: !_isSkipOnLeftSide ? 40 : null,
            top: 0,
            bottom: 0,
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
                    const Text(
                      '10s',
                      style: TextStyle(
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
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Bar
          StreamBuilder<Duration>(
            stream: Stream.periodic(
              const Duration(milliseconds: 100),
              (_) => _videoController?.value.position ?? Duration.zero,
            ),
            builder: (context, snapshot) {
              final position = _videoController?.value.position ?? Duration.zero;
              final duration = _videoController?.metadata.duration ?? Duration.zero;
              final value = duration.inSeconds > 0 ? position.inSeconds / duration.inSeconds : 0.0;

              return Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: AppTheme.primaryColor,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                      thumbColor: AppTheme.primaryColor,
                      overlayColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                    child: Slider(
                      value: value.clamp(0.0, 1.0),
                      onChanged: (newValue) {
                        if (_videoController != null) {
                          final newPosition = Duration(
                            seconds: (newValue * duration.inSeconds).toInt(),
                          );
                          _videoController!.seekTo(newPosition);
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),

          // Fullscreen Button (toggles orientation)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Larger fullscreen button for better visibility
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleFullscreen,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: PhosphorIcon(
                      _isFullscreen
                          ? PhosphorIcons.arrowsIn(PhosphorIconsStyle.bold)
                          : PhosphorIcons.arrowsOut(PhosphorIconsStyle.bold),
                      color: Colors.white,
                      size: 24, // Increased from 20 to 24
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Widget _buildEpisodesSection() {
    return Padding(
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
          ..._episodes.asMap().entries.map(
                (entry) => _buildEpisodeCard(entry.value, entry.key),
              ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(VideoEpisode episode, int index) {
    final isCurrentEpisode = index == _currentEpisodeIndex;
    final isPlaying = isCurrentEpisode && (_videoController?.value.isPlaying ?? false);
    final isPremium = episode.isPremium == true;
    final isBlocked = isPremium && !_isPremiumUser;

    return EpisodeCardWidget(
      episode: episode,
      index: index,
      isCurrentEpisode: isCurrentEpisode,
      isPlaying: isPlaying,
      isPremium: isPremium,
      isBlocked: isBlocked,
      onEpisodeTap: () => _onEpisodeTap(index, episode),
    );
  }

  void _onEpisodeTap(int index, VideoEpisode episode) {
    if (episode.isPremium && !_isPremiumUser) {
      PremiumDialogHelper.showPremiumDialog(context);
      return;
    }

    // Switch to selected episode (player stays embedded)
    _switchToEpisode(index);
  }
}
