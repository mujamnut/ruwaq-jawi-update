import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Import models
import '../../../core/models/video_episode.dart';

// Import theme
import '../../../core/theme/app_theme.dart';

// Import services
import '../../../core/services/video_progress_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoEpisode episode;
  final String kitabTitle;
  final VoidCallback? onVideoEnded;

  const VideoPlayerScreen({
    super.key,
    required this.episode,
    required this.kitabTitle,
    this.onVideoEnded,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  YoutubePlayerController? _controller;
  bool _isFullscreen = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _showSkipAnimation = false;
  bool _isSkipForward = false;
  bool _isSkipOnLeftSide = false;
  Timer? _skipAnimationTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    final videoId = widget.episode.youtubeVideoId;

    if (videoId.isEmpty) {
      return;
    }

    _controller = YoutubePlayerController(
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

    _controller!.addListener(_onPlayerStateChange);

    // Restore saved position
    final savedPosition = VideoProgressService.getVideoPosition(widget.episode.id);
    if (savedPosition > 10) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_controller != null && mounted) {
          _controller!.seekTo(Duration(seconds: savedPosition));
        }
      });
    }
  }

  void _onPlayerStateChange() {
    if (!mounted) return;

    // Track progress
    if (_controller != null && _controller!.value.isReady) {
      final position = _controller!.value.position.inSeconds;
      final duration = _controller!.metadata.duration.inSeconds;

      VideoProgressService.saveVideoPosition(widget.episode.id, position);

      // Check if video ended (when position is close to duration)
      if (position > 0 && duration > 0 && (duration - position) < 2) {
        if (widget.onVideoEnded != null) {
          widget.onVideoEnded!();
        }
      }
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    _showControls = true;
    _controlsTimer?.cancel();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls && _controller?.value.isPlaying == true) {
      _startControlsTimer();
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
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
    if (_controller == null) return;

    final size = MediaQuery.of(context).size;
    final position = details.localPosition;
    final isLeftSide = position.dx < size.width / 2;
    final skipSeconds = isLeftSide ? -10 : 10;

    try {
      final currentPosition = _controller!.value.position.inSeconds;
      final videoDuration = _controller!.metadata.duration.inSeconds;
      final newPosition = (currentPosition + skipSeconds).clamp(0, videoDuration);

      _controller!.seekTo(Duration(seconds: newPosition.toInt()));
      _showSkipFeedback(isLeftSide, skipSeconds.abs(), isLeftSide);

      if (_controller!.value.isPlaying) {
        _startControlsTimer();
      }
    } catch (e) {
      debugPrint('Error in double tap seek: $e');
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _skipAnimationTimer?.cancel();
    _controller?.dispose();

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
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
      );
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: false,
        onReady: () {
          if (mounted) setState(() {});
        },
      ),
      builder: (context, player) {
        return _isFullscreen ? _buildFullscreenView(player) : _buildNormalView(player);
      },
    );
  }

  Widget _buildFullscreenView(Widget player) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _toggleFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _buildPlayerWithControls(player),
        ),
      ),
    );
  }

  Widget _buildNormalView(Widget player) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.arrowLeft(),
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.episode.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.kitabTitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _buildPlayerWithControls(player),
    );
  }

  Widget _buildPlayerWithControls(Widget player) {
    return Stack(
      children: [
        // Player
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              onDoubleTap: () {},
              onDoubleTapDown: _handleDoubleTap,
              child: player,
            ),
          ),
        ),

        // Custom Controls Overlay
        if (_showControls)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              onDoubleTap: () {},
              onDoubleTapDown: _handleDoubleTap,
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Stack(
                  children: [
                    // Center Play/Pause Button
                    Center(
                      child: StreamBuilder<Duration>(
                        stream: Stream.periodic(
                          const Duration(milliseconds: 100),
                          (_) => _controller?.value.position ?? Duration.zero,
                        ),
                        builder: (context, snapshot) {
                          final isPlaying = _controller?.value.isPlaying ?? false;
                          return GestureDetector(
                            onTap: () {
                              if (_controller != null) {
                                if (_controller!.value.isPlaying) {
                                  _controller!.pause();
                                } else {
                                  _controller!.play();
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
                      child: _buildBottomControls(),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Skip Animation Overlay
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
              (_) => _controller?.value.position ?? Duration.zero,
            ),
            builder: (context, snapshot) {
              final position = _controller?.value.position ?? Duration.zero;
              final duration = _controller?.metadata.duration ?? Duration.zero;
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
                        if (_controller != null) {
                          final newPosition = Duration(
                            seconds: (newValue * duration.inSeconds).toInt(),
                          );
                          _controller!.seekTo(newPosition);
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

          // Fullscreen Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  _isFullscreen ? PhosphorIcons.arrowsIn() : PhosphorIcons.arrowsOut(),
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _toggleFullscreen,
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
}
