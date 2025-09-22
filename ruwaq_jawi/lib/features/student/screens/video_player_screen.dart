// ignore_for_file: unused_import

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/bookmark_provider.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/saved_items_provider.dart';
import '../../../core/models/kitab.dart';
import '../../../core/models/kitab_video.dart';
import '../../../core/models/video_episode.dart';
import '../widgets/save_video_button.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String kitabId;
  final String? episodeId; // Episode ID for multi-episode kitab

  const VideoPlayerScreen({super.key, required this.kitabId, this.episodeId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
  // Animation controllers for smooth animations
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String? _currentVideoId;
  YoutubePlayerController? _controller;
  Box<dynamic>? _progressBox;
  Timer? _progressTimer;
  late TabController _tabController;
  bool _isBookmarkLoading = false;
  bool _isLoading = true;

  static const String _boxName = 'video_progress';

  // Real data from database
  Kitab? _kitab;
  VideoEpisode? _currentEpisode;
  List<VideoEpisode> _episodes = [];

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

    // Load real data and initialize player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRealData();

      // Load bookmarks for save functionality
      final bookmarkProvider = Provider.of<BookmarkProvider>(
        context,
        listen: false,
      );
      if (!bookmarkProvider.isLoading && bookmarkProvider.bookmarks.isEmpty) {
        bookmarkProvider.loadBookmarks();
      }

      // Load saved items for video save functionality
      final savedItemsProvider = Provider.of<SavedItemsProvider>(
        context,
        listen: false,
      );
      if (!savedItemsProvider.isLoading &&
          savedItemsProvider.savedItems.isEmpty) {
        savedItemsProvider.loadSavedItems();
      }
    });
  }

  Future<void> _loadRealData() async {
    try {
      final kitabProvider = context.read<KitabProvider>();

      // Get kitab data
      _kitab = kitabProvider.getKitabById(widget.kitabId);
      if (_kitab == null) {
        // Load kitab if not in cache
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
          _currentEpisode = _episodes.firstWhere(
            (ep) => ep.id == widget.episodeId,
            orElse: () => _episodes.first,
          );
        } else {
          _currentEpisode = _episodes.isNotEmpty ? _episodes.first : null;
        }

        _currentVideoId = _currentEpisode?.youtubeVideoId;
      } else {
        // Single episode kitab - use deprecated field for now
        _currentVideoId = _kitab!.youtubeVideoId;
      }

      if (_currentVideoId == null || _currentVideoId!.isEmpty) {
        throw Exception('No video ID found');
      }

      // Initialize player
      await _initPlayer();

      if (mounted) {
        setState(() {
          _isLoading = false;
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
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initPlayer() async {
    if (_currentVideoId == null) return;

    // Ensure Hive box is opened
    _progressBox = await Hive.openBox(_boxName);

    final progressKey = _currentEpisode?.id ?? _currentVideoId!;
    final savedSeconds = (_progressBox!.get(progressKey) ?? 0) as int;

    _controller = YoutubePlayerController(
      initialVideoId: _currentVideoId!,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        enableCaption: true,
        controlsVisibleAtStart: true,
        forceHD: false,
        hideControls: false,
        disableDragSeek: false,
      ),
    );

    // Seek to saved position after player is ready
    _controller!.addListener(() async {
      if (!_controller!.value.isReady) return;
      // One-time seek after ready if we have progress
      if (savedSeconds > 0 &&
          _controller!.metadata.duration.inSeconds > savedSeconds) {
        _controller!.seekTo(Duration(seconds: savedSeconds));
      }
    });

    // Periodically save progress while playing
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final c = _controller;
      if (c != null && c.value.isReady && c.value.isPlaying) {
        _saveProgress();
      }
    });
  }

  // Removed debounce helper; using periodic saver instead

  Future<void> _saveProgress() async {
    if (_controller == null) return;
    final pos = _controller!.value.position.inSeconds;
    final progressKey = _currentEpisode?.id ?? _currentVideoId ?? '';
    if (progressKey.isNotEmpty) {
      await _progressBox?.put(progressKey, pos);
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _saveProgress();
    _controller?.dispose();
    _tabController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        strokeWidth: 3,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Text(
                      'Memuat pemain video...',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_kitab == null || _controller == null) {
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
                        const SizedBox(height: 24),
                        Text(
                          'Gagal Memuat Video',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Video tidak dapat dimuat. Sila cuba semula.',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
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

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppTheme.primaryColor,
        onReady: () {},
        bottomActions: [
          CurrentPosition(),
          ProgressBar(isExpanded: true),
          RemainingDuration(),
          FullScreenButton(),
        ],
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              // Main content
              Column(
                children: [
                  // Video Player
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(color: Colors.black, child: player),
                  ),
                  // Content below video with animations
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  _buildVideoHeader(),
                                  _buildActionButtons(),
                                  _buildVideoDescription(),
                                  if (_kitab!.hasMultipleVideos && _episodes.isNotEmpty)
                                    _buildEpisodesSection(),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Floating back button with enhanced design
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.black.withValues(alpha: 0.4),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => context.pop(),
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedArrowLeft01,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Floating heart button with enhanced design
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Consumer<BookmarkProvider>(
                          builder: (context, bookmarkProvider, child) {
                            final isBookmarked = bookmarkProvider.isBookmarked(
                              widget.kitabId,
                            );
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.black.withValues(alpha: 0.4),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isBookmarkLoading ? null : _toggleBookmark,
                                  borderRadius: BorderRadius.circular(50),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    child: _isBookmarkLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 200),
                                            child: HugeIcon(
                                              key: ValueKey(isBookmarked),
                                              icon: isBookmarked
                                                  ? HugeIcons.strokeRoundedFavourite
                                                  : HugeIcons.strokeRoundedHeartAdd,
                                              color: isBookmarked
                                                  ? const Color(0xFFE91E63)
                                                  : Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoHeader() {
    final kitabProvider = context.read<KitabProvider>();
    final category = kitabProvider.categories
        .where((c) => c.id == _kitab!.categoryId)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category badge with enhanced design
          if (category != null)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.2),
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedBookmark01,
                            color: AppTheme.primaryColor,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category.name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),

          // Title
          Text(
            _currentEpisode?.title ?? _kitab!.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Author
          Text(
            'Oleh ${_kitab!.author ?? 'Unknown'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Row(
                children: [
                  // Stats card with enhanced design
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(20), // xl rounded corners
                        border: Border.all(
                          color: AppTheme.borderColor.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.2),
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedPlayCircle,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Episode',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_episodes.length} Bahagian',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Watch now button with enhanced design
                  Container(
                    constraints: const BoxConstraints(maxWidth: 160),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        // Already watching, could implement next episode functionality
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedPlay,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Tonton',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoDescription() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tentang Kitab',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentEpisode?.description ??
                _kitab!.description ??
                'Tiada penerangan tersedia.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // Show full description
            },
            child: Text(
              'Baca lagi',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Episod',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Show all episodes
                },
                child: Text(
                  'Lihat semua',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _episodes.length,
            itemBuilder: (context, index) {
              return _buildModernEpisodeCard(_episodes[index], index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernEpisodeCard(VideoEpisode episode, int index) {
    final isCurrentEpisode = _currentEpisode?.id == episode.id;
    final authProvider = context.read<AuthProvider>();
    final canAccess = !_kitab!.isPremium || authProvider.hasActiveSubscription;
    final isLocked = !canAccess && !episode.isPreview;

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
                  onTap: isLocked ? null : () => _switchToEpisode(episode),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Episode number circle with enhanced design
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: isLocked
                                ? LinearGradient(
                                    colors: [
                                      AppTheme.textSecondaryColor.withValues(alpha: 0.15),
                                      AppTheme.textSecondaryColor.withValues(alpha: 0.05),
                                    ],
                                  )
                                : isCurrentEpisode
                                    ? LinearGradient(
                                        colors: [
                                          AppTheme.primaryColor,
                                          AppTheme.primaryColor.withValues(alpha: 0.8),
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          AppTheme.primaryColor.withValues(alpha: 0.15),
                                          AppTheme.primaryColor.withValues(alpha: 0.08),
                                        ],
                                      ),
                            shape: BoxShape.circle,
                            boxShadow: isCurrentEpisode || !isLocked
                                ? [
                                    BoxShadow(
                                      color: (isCurrentEpisode
                                              ? AppTheme.primaryColor
                                              : AppTheme.primaryColor)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isLocked
                                ? HugeIcon(
                                    icon: HugeIcons.strokeRoundedLockKey,
                                    color: AppTheme.textSecondaryColor,
                                    size: 22,
                                  )
                                : isCurrentEpisode
                                    ? HugeIcon(
                                        icon: HugeIcons.strokeRoundedPause,
                                        color: Colors.white,
                                        size: 22,
                                      )
                                    : Text(
                                        '${episode.partNumber}',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                          fontSize: 16,
                                        ),
                                      ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Episode content with enhanced typography
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Episode badge
                              if (episode.isPreview)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.secondaryColor,
                                        AppTheme.secondaryColor.withValues(alpha: 0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'PREVIEW',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              Text(
                                episode.title,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isLocked
                                      ? AppTheme.textSecondaryColor
                                      : AppTheme.textPrimaryColor,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedClock03,
                                    size: 14,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    episode.formattedDuration,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Action button with enhanced design
                        Container(
                          decoration: BoxDecoration(
                            color: isCurrentEpisode
                                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                : AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrentEpisode
                                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                  : AppTheme.borderColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: IconButton(
                            onPressed: isLocked ? null : () => _switchToEpisode(episode),
                            icon: HugeIcon(
                              icon: isCurrentEpisode
                                  ? HugeIcons.strokeRoundedPause
                                  : isLocked
                                      ? HugeIcons.strokeRoundedLockKey
                                      : HugeIcons.strokeRoundedPlay,
                              color: isCurrentEpisode
                                  ? AppTheme.primaryColor
                                  : isLocked
                                      ? AppTheme.textSecondaryColor
                                      : AppTheme.primaryColor,
                              size: 20,
                            ),
                            iconSize: 20,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
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

      final currentPosition = _controller?.value.position.inSeconds ?? 0;

      final success = await bookmarkProvider.toggleBookmark(
        kitabId: widget.kitabId,
        title: _currentEpisode?.title ?? _kitab!.title,
        description: _currentEpisode?.description ?? _kitab!.description ?? '',
        videoPosition: currentPosition,
        pdfPage: 1,
        contentType: 'video',
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
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  void _switchToEpisode(VideoEpisode episode) async {
    if (_currentEpisode?.id == episode.id) {
      return; // Already playing this episode
    }

    // Save progress for current episode
    await _saveProgress();

    // Dispose current controller
    _controller?.dispose();

    // Update current episode
    setState(() {
      _currentEpisode = episode;
      _currentVideoId = episode.youtubeVideoId;
    });

    // Initialize new player for this episode
    await _initPlayer();

    setState(() {});
  }
}
