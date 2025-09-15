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

class VideoPlayerScreen extends StatefulWidget {
  final String kitabId;
  final String? episodeId; // Episode ID for multi-episode kitab

  const VideoPlayerScreen({super.key, required this.kitabId, this.episodeId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
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
      }
    } catch (e) {
      print('Error loading data: $e');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundColor,
          foregroundColor: AppTheme.textPrimaryColor,
          elevation: 0,
          title: const Text(
            'Loading...',
            style: TextStyle(color: Colors.black),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_kitab == null || _controller == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundColor,
          foregroundColor: AppTheme.textPrimaryColor,
          elevation: 0,
          title: const Text('Error', style: TextStyle(color: Colors.black)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Failed to load video',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
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
                  // Content below video
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildVideoHeader(),
                          _buildActionButtons(),
                          _buildVideoDescription(),
                          if (_kitab!.hasMultipleVideos && _episodes.isNotEmpty)
                            _buildEpisodesSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Floating back button
              Positioned(
                top: 50,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: PhosphorIcon(
                      PhosphorIcons.arrowLeft(),
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
              // Floating heart button
              Positioned(
                top: 50,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Consumer<BookmarkProvider>(
                    builder: (context, bookmarkProvider, child) {
                      final isBookmarked = bookmarkProvider.isBookmarked(
                        widget.kitabId,
                      );
                      return IconButton(
                        icon: _isBookmarkLoading
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
                            : PhosphorIcon(
                                isBookmarked
                                    ? PhosphorIcons.heart(
                                        PhosphorIconsStyle.fill,
                                      )
                                    : PhosphorIcons.heart(),
                                color: isBookmarked ? Colors.red : Colors.white,
                                size: 20,
                              ),
                        onPressed: _isBookmarkLoading ? null : _toggleBookmark,
                      );
                    },
                  ),
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
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category badge
          if (category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                category.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
      child: Row(
        children: [
          // Stats card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: PhosphorIcon(
                      PhosphorIcons.playCircle(),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Episod',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondaryColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_episodes.length} Bahagian',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
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

          // Watch now button
          Container(
            constraints: const BoxConstraints(maxWidth: 160),
            child: ElevatedButton(
              onPressed: () {
                // Already watching, could implement next episode functionality
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 4,
                shadowColor: AppTheme.primaryColor.withOpacity(0.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.play(),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tonton Sekarang',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isLocked ? null : () => _switchToEpisode(episode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrentEpisode
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentEpisode
                  ? AppTheme.primaryColor
                  : AppTheme.borderColor.withOpacity(0.3),
              width: isCurrentEpisode ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Episode number circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isLocked
                      ? AppTheme.textSecondaryColor.withOpacity(0.1)
                      : isCurrentEpisode
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isLocked
                      ? PhosphorIcon(
                          PhosphorIcons.lock(),
                          color: AppTheme.textSecondaryColor,
                          size: 20,
                        )
                      : Text(
                          '${episode.partNumber}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCurrentEpisode
                                ? Colors.white
                                : AppTheme.primaryColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Episode content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isLocked
                            ? AppTheme.textSecondaryColor
                            : Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      episode.formattedDuration,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Play/Current indicator
              Container(
                padding: const EdgeInsets.all(8),
                child: PhosphorIcon(
                  isCurrentEpisode
                      ? PhosphorIcons.pause()
                      : isLocked
                          ? PhosphorIcons.lock()
                          : PhosphorIcons.play(),
                  color: isCurrentEpisode
                      ? AppTheme.primaryColor
                      : isLocked
                          ? AppTheme.textSecondaryColor
                          : AppTheme.textSecondaryColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Episode/Video Info
          Text(
            _currentEpisode?.title ?? _kitab!.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _kitab!.author ?? 'Unknown Author',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            _currentEpisode?.description ??
                _kitab!.description ??
                'Tiada penerangan tersedia.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Episodes Section (for multi-episode kitab)
          if (_kitab!.hasMultipleVideos && _episodes.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Episod (${_episodes.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  _kitab!.formattedDuration,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._episodes.map((episode) => _buildEpisodeCard(episode)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(VideoEpisode episode) {
    final isCurrentEpisode = _currentEpisode?.id == episode.id;
    final authProvider = context.read<AuthProvider>();
    final canAccess = !_kitab!.isPremium || authProvider.hasActiveSubscription;
    final isLocked = !canAccess && !episode.isPreview;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentEpisode
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentEpisode
              ? AppTheme.primaryColor
              : AppTheme.borderColor,
          width: isCurrentEpisode ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isLocked ? null : () => _switchToEpisode(episode),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Episode number/thumbnail
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isLocked
                      ? AppTheme.textSecondaryColor.withOpacity(0.1)
                      : isCurrentEpisode
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: isLocked
                      ? Icon(
                          Icons.lock,
                          color: AppTheme.textSecondaryColor,
                          size: 20,
                        )
                      : isCurrentEpisode
                      ? Icon(Icons.play_arrow, color: Colors.white, size: 24)
                      : Text(
                          '${episode.partNumber}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
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
                        Expanded(
                          child: Text(
                            episode.title,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: isCurrentEpisode
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isLocked
                                      ? AppTheme.textSecondaryColor
                                      : AppTheme.textPrimaryColor,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (episode.isPreview)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PREVIEW',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textPrimaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      episode.formattedDuration,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Status indicator
              if (isCurrentEpisode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'SEMASA',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                )
              else if (isLocked)
                Icon(Icons.lock, color: AppTheme.textSecondaryColor, size: 20)
              else
                Icon(
                  Icons.play_circle_outline,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEBookTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'E-Book tidak tersedia untuk video ini',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
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
    if (_currentEpisode?.id == episode.id)
      return; // Already playing this episode

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
