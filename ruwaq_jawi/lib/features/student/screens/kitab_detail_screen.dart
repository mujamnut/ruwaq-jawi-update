import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/providers/saved_items_provider.dart';
import '../../../core/services/network_service.dart';
import '../../../core/models/video_kitab.dart';
import '../../../core/models/video_episode.dart';
import '../../../core/utils/youtube_utils.dart';
import '../../../core/services/preview_service.dart';
import '../../../core/models/preview_models.dart';

class KitabDetailScreen extends StatefulWidget {
  final String kitabId;

  const KitabDetailScreen({super.key, required this.kitabId});

  @override
  State<KitabDetailScreen> createState() => _KitabDetailScreenState();
}

class _KitabDetailScreenState extends State<KitabDetailScreen>
    with TickerProviderStateMixin {
  bool _isSaved = false;
  VideoKitab? _kitab;
  bool _isLoading = true;
  double _collapseRatio = 0.0;
  bool _episodesLoading = false;
  final Map<String, bool> _episodePreviewStatus =
      {}; // Track preview status for each episode
  List<VideoEpisode>? _cachedEpisodes;

  // Animation controllers for smooth animations
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Carousel controller for header thumbnail/video
  late PageController _headerCarouselController;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();

    // Initialize carousel controller with smooth settings
    _headerCarouselController = PageController(
      initialPage: 0,
      keepPage: true,
      viewportFraction: 1.0,
    );

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
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _loadKitabData();
    _checkIfSaved();

    // Listen to SavedItemsProvider changes for auto-sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavedItemsProvider>().addListener(_updateSavedStatus);
    });
  }

  void _updateSavedStatus() {
    if (_kitab != null && mounted) {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      final newSavedStatus = savedItemsProvider.isKitabSaved(_kitab!.id);
      if (_isSaved != newSavedStatus) {
        setState(() {
          _isSaved = newSavedStatus;
        });
      }
    }
  }

  void _loadKitabData() {
    final kitabProvider = context.read<KitabProvider>();

    try {
      _kitab = kitabProvider.activeVideoKitab.firstWhere(
        (vk) => vk.id == widget.kitabId,
      );
      setState(() {
        _isLoading = false;
      });
      _checkIfSaved();
      _loadEpisodes(); // Load episodes immediately after kitab data

      // Start animations
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _fadeAnimationController.forward();
          _slideAnimationController.forward();
        }
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        kitabProvider.initialize().then((_) {
          if (mounted) {
            try {
              setState(() {
                _kitab = kitabProvider.activeVideoKitab.firstWhere(
                  (vk) => vk.id == widget.kitabId,
                );
                _isLoading = false;
              });
              _checkIfSaved();
              _loadEpisodes(); // Load episodes here too

              // Start animations
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  _fadeAnimationController.forward();
                  _slideAnimationController.forward();
                }
              });
            } catch (e) {
              setState(() {
                _kitab = null;
                _isLoading = false;
              });
            }
          }
        });
      });
    }
  }

  void _loadEpisodes() async {
    if (_kitab == null || _episodesLoading || _cachedEpisodes != null) return;

    setState(() {
      _episodesLoading = true;
    });

    try {
      final kitabProvider = context.read<KitabProvider>();
      final episodes = await kitabProvider.loadKitabVideos(_kitab!.id);

      if (mounted) {
        // Check preview status for each episode
        await _loadPreviewStatus(episodes);

        setState(() {
          _cachedEpisodes = episodes;
          _episodesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedEpisodes = [];
          _episodesLoading = false;
        });
      }
    }
  }

  Future<void> _loadPreviewStatus(List<VideoEpisode> episodes) async {
    for (final episode in episodes) {
      try {
        final hasPreview = await PreviewService.hasPreview(
          contentType: PreviewContentType.videoEpisode,
          contentId: episode.id,
        );
        _episodePreviewStatus[episode.id] = hasPreview;
      } catch (e) {
        _episodePreviewStatus[episode.id] = false;
      }
    }
  }

  bool _isEpisodePreview(VideoEpisode episode) {
    return _episodePreviewStatus[episode.id] ?? false;
  }

  @override
  void dispose() {
    // Remove listener from SavedItemsProvider
    try {
      context.read<SavedItemsProvider>().removeListener(_updateSavedStatus);
    } catch (e) {
      // Provider might already be disposed
    }
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _headerCarouselController.dispose();
    super.dispose();
  }

  void _checkIfSaved() {
    if (_kitab != null) {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      setState(() {
        _isSaved = savedItemsProvider.isKitabSaved(_kitab!.id);
      });
    }
  }

  Widget _buildThumbnailImage() {
    // Try to get YouTube thumbnail first
    final youtubeThumbnail = YouTubeUtils.getBestThumbnailUrl(
      _kitab?.thumbnailUrl,
    );

    if (youtubeThumbnail != null) {
      return Image.network(
        youtubeThumbnail,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholderImage();
        },
      );
    }

    // If not a YouTube URL, try to use as direct image URL
    if (_kitab?.thumbnailUrl != null && _kitab!.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        _kitab!.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholderImage();
        },
      );
    }

    // Default placeholder
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppTheme.surfaceColor,
      child: Stack(
        children: [
          // Background pattern or gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.secondaryColor.withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
          // Icon only
          Center(
            child: PhosphorIcon(
              PhosphorIcons.bookOpen(),
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
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
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: IconButton(
              icon: PhosphorIcon(
                PhosphorIcons.arrowLeft(),
                color: AppTheme.textPrimaryColor,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Memuat kitab...',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_kitab == null) {
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
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: IconButton(
              icon: PhosphorIcon(
                PhosphorIcons.arrowLeft(),
                color: AppTheme.textPrimaryColor,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        body: SafeArea(
          child: TweenAnimationBuilder<double>(
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
                              color: AppTheme.textSecondaryColor.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.textSecondaryColor.withValues(
                                  alpha: 0.2,
                                ),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedBookOpen01,
                                color: AppTheme.textSecondaryColor,
                                size: 48,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Kitab Tidak Ditemui',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppTheme.textPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Kitab yang dicari tidak wujud atau telah dipadam',
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
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.primaryColor.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.3,
                                  ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: PhosphorIcon(
                                PhosphorIcons.arrowLeft(
                                  PhosphorIconsStyle.fill,
                                ),
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
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo is ScrollUpdateNotification) {
                final scrollOffset = scrollInfo.metrics.pixels;
                final expandedHeight = 280.0;
                final toolbarHeight = kToolbarHeight;

                final newCollapseRatio =
                    ((scrollOffset) / (expandedHeight - toolbarHeight)).clamp(
                      0.0,
                      1.0,
                    );

                if (_collapseRatio != newCollapseRatio) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _collapseRatio = newCollapseRatio;
                      });
                    }
                  });
                }
              }
              return false;
            },
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            _buildFloatingAppBar(),
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  _buildDescription(),
                                  if (_kitab!.totalVideos > 1)
                                    _buildEpisodesSection(),
                                  const SizedBox(height: 100),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Adaptive floating back button
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    decoration: _collapseRatio > 0.5
                        ? null // No background when collapsed
                        : BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                    child: IconButton(
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        color: _collapseRatio > 0.5
                            ? AppTheme.textPrimaryColor
                            : Colors.white,
                        size: 28,
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                // Adaptive floating love button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: _collapseRatio > 0.5
                        ? null // No background when collapsed
                        : BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                    child: IconButton(
                      icon: PhosphorIcon(
                        _isSaved
                            ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                            : PhosphorIcons.heart(),
                      color: _isSaved
                          ? const Color(0xFFE91E63)
                          : (_collapseRatio > 0.5
                                ? AppTheme.textSecondaryColor
                                : Colors.white),
                        size: 24,
                      ),
                      onPressed: _toggleSaved,
                    ),
                  ),
                ),
                // Fixed bottom button
                _buildBottomButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      snap: false,
      forceElevated: false,
      backgroundColor: AppTheme.backgroundColor,
      foregroundColor: AppTheme.textPrimaryColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: AppTheme.backgroundColor,
      title: null,
      automaticallyImplyLeading: false,
      actions: [
        const SizedBox(width: 48), // Placeholder space
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate collapse ratio (0.0 = fully expanded, 1.0 = fully collapsed)
          final expandedHeight = 280.0;
          final toolbarHeight = kToolbarHeight;
          final currentHeight = constraints.maxHeight;

          final collapseRatio =
              ((expandedHeight - currentHeight) /
                      (expandedHeight - toolbarHeight))
                  .clamp(0.0, 1.0);

          // Interpolate color from white to black based on collapse
          final titleColor =
              Color.lerp(
                Colors.white,
                AppTheme.textPrimaryColor,
                collapseRatio,
              ) ??
              Colors.white;

          return FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            titlePadding: const EdgeInsets.only(
              left: 50,
              bottom: 15,
              right: 16,
            ),
            title: _currentCarouselIndex == 1
                ? null // Hide title in video preview mode
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width *
                              0.4, // 40% screen width for longer text
                        ),
                        child: Text(
                          _kitab?.title ?? 'Kitab',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_kitab?.isPremium == true) ...[
                        const SizedBox(width: 8),
                        PhosphorIcon(
                          PhosphorIcons.crown(PhosphorIconsStyle.fill),
                          color: const Color(0xFFFFD700),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
            background: RepaintBoundary(
              child: Stack(
                children: [
                  // Carousel untuk thumbnail/video
                  Positioned.fill(child: _buildHeaderCarousel()),
                  // Gradient overlay - pointer transparent so taps go through
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
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
                      ),
                    ),
                  ),
                  // Carousel page number indicator
                  _buildPageNumberIndicator(),
                  // Episode count badge on header
                  _buildEpisodeCountBadge(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final hasActiveSubscription = authProvider.hasActiveSubscription;

        // Check if user can access any content (first episode at minimum)
        // If there are episodes, check first episode accessibility
        // If no episodes, use kitab-level access (existing behavior for non-video kitabs)
        bool canAccess = true;
        String buttonText = 'Tonton Sekarang';

        if (_cachedEpisodes != null && _cachedEpisodes!.isNotEmpty) {
          // Find the first accessible episode
          final sortedEpisodes = List<VideoEpisode>.from(_cachedEpisodes!);
          sortedEpisodes.sort((a, b) {
            final aIsPreview = _isEpisodePreview(a);
            final bIsPreview = _isEpisodePreview(b);
            if (aIsPreview && !bIsPreview) return -1;
            if (!aIsPreview && bIsPreview) return 1;
            return a.partNumber.compareTo(b.partNumber);
          });

          final firstEpisode = sortedEpisodes.first;
          final episodeRequiresPremium =
              firstEpisode.isPremium && !_isEpisodePreview(firstEpisode);
          canAccess = !episodeRequiresPremium || hasActiveSubscription;

          if (!canAccess) {
            buttonText = 'Premium Diperlukan';
          }
        } else {
          // Fallback to kitab-level check for non-video content
          canAccess = !_kitab!.isPremium || hasActiveSubscription;
          if (!canAccess) {
            buttonText = 'Premium Diperlukan';
          }
        }

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 16,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canAccess ? _startReading : _showSubscriptionDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAccess
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDescription() {
    if (_kitab!.description?.isEmpty ?? true) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _kitab!.description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Episode',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEpisodesList(),
        ],
      ),
    );
  }

  Widget _buildEpisodesList() {
    if (_episodesLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_cachedEpisodes == null || _cachedEpisodes!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No episodes available.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      );
    }

    // Sort episodes: Preview episodes first, then regular episodes by part_number
    final sortedEpisodes = List<VideoEpisode>.from(_cachedEpisodes!);
    sortedEpisodes.sort((a, b) {
      // Preview videos go to top
      final aIsPreview = _isEpisodePreview(a);
      final bIsPreview = _isEpisodePreview(b);
      if (aIsPreview && !bIsPreview) return -1;
      if (!aIsPreview && bIsPreview) return 1;

      // If both are preview or both are regular, sort by part_number (ascending)
      return a.partNumber.compareTo(b.partNumber);
    });

    // Limit to 6 episodes only
    final limitedEpisodes = sortedEpisodes.take(6).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: limitedEpisodes.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final episode = limitedEpisodes[index];
        // Use partNumber from database instead of calculated index
        return RepaintBoundary(
          child: _buildEpisodeCard(episode, episode.partNumber),
        );
      },
    );
  }

  Widget _buildVideoThumbnail(VideoEpisode episode) {
    // Use YouTube utils to get thumbnail
    final thumbnailUrl = YouTubeUtils.getThumbnailUrl(
      episode.youtubeVideoId,
      quality: YouTubeThumbnailQuality.hqdefault,
    );

    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          thumbnailUrl,
          width: 100,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultThumbnail();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 100,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      );
    } else {
      return _buildDefaultThumbnail();
    }
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: 100,
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: PhosphorIcon(
          PhosphorIcons.videoCamera(),
          size: 32,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildEpisodeCard(VideoEpisode episode, int number) {
    final authProvider = context.read<AuthProvider>();
    final hasActiveSubscription = authProvider.hasActiveSubscription;

    // New logic: Check both kitab and episode premium status
    // Episode access rules:
    // 1. If episode is not premium (episode.isPremium = false) -> always accessible
    // 2. If episode is premium (episode.isPremium = true) -> requires subscription
    // 3. Preview episodes are always accessible regardless of premium status
    final episodeRequiresPremium =
        episode.isPremium && !_isEpisodePreview(episode);
    final canAccessEpisode = !episodeRequiresPremium || hasActiveSubscription;

    // Episode is locked if:
    // 1. Episode requires premium but user has no subscription
    // 2. Episode is inactive
    final isLocked = !canAccessEpisode || !episode.isActive;

    // Show premium lock specifically when episode requires subscription
    final isPremiumLocked = episodeRequiresPremium && !hasActiveSubscription;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (number * 50)),
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
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20), // xl rounded corners
                border: Border.all(color: AppTheme.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: !episode.isActive
                      ? () => _showInactiveEpisodeDialog()
                      : isPremiumLocked
                      ? _showPremiumDialog
                      : (isLocked
                            ? _showSubscriptionDialog
                            : () => _playEpisode(episode)),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail with enhanced design
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _buildVideoThumbnail(episode),
                              ),
                            ),
                            // Preview badge with enhanced design
                            if (_isEpisodePreview(episode))
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.secondaryColor,
                                        AppTheme.secondaryColor.withValues(
                                          alpha: 0.8,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.secondaryColor
                                            .withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'PREVIEW',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            // Locked overlay with enhanced design
                            if (isLocked)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedLockKey,
                                        color: AppTheme.textSecondaryColor,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(width: 16),

                        // Content with enhanced typography
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Episode number badge with premium indicator
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Episode ${episode.partNumber}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Free/Premium badge
                                  if (episode.isPremium &&
                                      !_isEpisodePreview(episode))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFFD700,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFFFD700,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PhosphorIcon(
                                            PhosphorIcons.crown(
                                              PhosphorIconsStyle.fill,
                                            ),
                                            color: const Color(0xFFFFD700),
                                            size: 10,
                                          ),
                                          const SizedBox(width: 2),
                                          const Text(
                                            'PREMIUM',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFFD700),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (!episode.isPremium)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'FREE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Title with enhanced styling
                              Text(
                                episode.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isLocked
                                      ? AppTheme.textSecondaryColor
                                      : AppTheme.textPrimaryColor,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Action button with enhanced design
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.borderColor.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: IconButton(
                            onPressed: !episode.isActive
                                ? () => _showInactiveEpisodeDialog()
                                : isPremiumLocked
                                ? _showPremiumDialog
                                : (isLocked
                                      ? _showSubscriptionDialog
                                      : () => _playEpisode(episode)),
                            icon: HugeIcon(
                              icon: isLocked
                                  ? HugeIcons.strokeRoundedLockKey
                                  : HugeIcons.strokeRoundedPlay,
                              color: isLocked
                                  ? AppTheme.textSecondaryColor
                                  : AppTheme.primaryColor,
                              size: 18,
                            ),
                            iconSize: 18,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
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

  void _toggleSaved() async {
    if (_kitab == null) return;

    try {
      HapticFeedback.lightImpact();
      final savedItemsProvider = context.read<SavedItemsProvider>();

      if (_isSaved) {
        // Remove from saved (Supabase)
        await savedItemsProvider.removeFromSaved(_kitab!.id);

        if (mounted) {
          setState(() {
            _isSaved = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.heartBreak(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('Dibuang dari simpanan'),
                ],
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Add to saved (Supabase)
        await savedItemsProvider.addToSaved(_kitab!.id);

        if (mounted) {
          setState(() {
            _isSaved = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.heart(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('Disimpan ke koleksi anda'),
                ],
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'Lihat',
                textColor: Colors.white,
                onPressed: () {
                  context.push('/saved');
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ralat berlaku. Sila cuba lagi.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    }
  }

  void _startReading() async {
    // Use centralized network check
    final hasInternet = await NetworkService.requiresInternet(
      context,
      message:
          'Video memerlukan sambungan internet. Sila periksa sambungan anda.',
    );

    if (!hasInternet) return;

    if (!mounted) return;
    final goRouter = GoRouter.of(context);

    if (_kitab!.hasVideos) {
      final kitabProvider = context.read<KitabProvider>();
      final episodes = await kitabProvider.loadKitabVideos(_kitab!.id);

      if (!mounted) return;

      if (episodes.isNotEmpty) {
        // Sort episodes to ensure Part 1 comes first
        final sortedEpisodes = List<VideoEpisode>.from(episodes);
        sortedEpisodes.sort((a, b) {
          // Preview videos go to top
          final aIsPreview = _isEpisodePreview(a);
          final bIsPreview = _isEpisodePreview(b);
          if (aIsPreview && !bIsPreview) return -1;
          if (!aIsPreview && bIsPreview) return 1;

          // If both are preview or both are regular, sort by part_number (ascending)
          return a.partNumber.compareTo(b.partNumber);
        });

        // Get the first episode (Part 1)
        final firstEpisode = sortedEpisodes.first;
        goRouter.push('/player/${widget.kitabId}?episode=${firstEpisode.id}');
      } else {
        goRouter.push('/player/${widget.kitabId}');
      }
    } else {
      goRouter.push('/player/${widget.kitabId}');
    }
  }

  void _playEpisode(VideoEpisode episode) async {
    // Use centralized network check
    final hasInternet = await NetworkService.requiresInternet(
      context,
      message:
          'Video memerlukan sambungan internet. Sila periksa sambungan anda.',
    );

    if (!hasInternet) return;

    if (!mounted) return;
    final goRouter = GoRouter.of(context);
    goRouter.push('/player/${widget.kitabId}?episode=${episode.id}');
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            PhosphorIcon(PhosphorIcons.crown(), color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            const Text('Premium Content'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You need a premium subscription to access this kitab. Subscribe now to unlock all premium videos and features!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.lightbulb(),
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Premium members get unlimited access to all kitabs, exclusive content, and offline downloads.',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              final goRouter = GoRouter.of(context);
              navigator.pop();
              // Navigate to subscription screen
              goRouter.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Premium Required'),
        content: const Text(
          'This kitab is premium content. Please subscribe to access all premium videos and features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              final goRouter = GoRouter.of(context);
              navigator.pop();
              goRouter.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  void _showInactiveEpisodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.clockClockwise(),
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('Episode Coming Soon'),
          ],
        ),
        content: const Text(
          'This episode is not yet available. Please check back later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCarousel() {
    // Get preview episodes
    final previewEpisodes =
        _cachedEpisodes
            ?.where((episode) => _isEpisodePreview(episode))
            .toList() ??
        [];
    final hasPreview = previewEpisodes.isNotEmpty;

    return PageView(
      controller: _headerCarouselController,
      // Smooth scrolling physics
      physics: const BouncingScrollPhysics(),
      // Reduce sensitivity for smoother navigation
      clipBehavior: Clip.none,
      padEnds: false,
      onPageChanged: (index) {
        // Debounce setState to prevent jerky animation
        if (_currentCarouselIndex != index) {
          setState(() {
            _currentCarouselIndex = index;
          });
        }
      },
      children: [
        // Slide 1: Thumbnail Image
        _buildThumbnailImage(),
        // Slide 2: Preview Video (if available)
        if (hasPreview)
          _HeaderVideoPlayer(
            episode: previewEpisodes.first,
            onBackToThumbnail: () {
              // Smooth animation back to thumbnail
              if (_currentCarouselIndex != 0) {
                setState(() {
                  _currentCarouselIndex = 0;
                });
                _headerCarouselController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutQuart,
                );
              }
            },
          ),
      ],
    );
  }

  Widget _buildPageNumberIndicator() {
    final previewEpisodes =
        _cachedEpisodes
            ?.where((episode) => _isEpisodePreview(episode))
            .toList() ??
        [];
    final hasPreview = previewEpisodes.isNotEmpty;

    if (!hasPreview) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${_currentCarouselIndex + 1}/2',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeCountBadge() {
    final totalVideos = _kitab?.totalVideos ?? 0;
    if (totalVideos <= 1) return const SizedBox.shrink();

    // If header has preview (shows page indicator at bottom-right),
    // offset the badge upward to avoid overlap; else keep at bottom-right.
    final hasPreview = (_cachedEpisodes
                ?.where((episode) => _isEpisodePreview(episode))
                .toList() ??
            [])
        .isNotEmpty;

    return Positioned(
      bottom: hasPreview ? 56 : 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$totalVideos ep',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// Header video player for carousel preview
class _HeaderVideoPlayer extends StatefulWidget {
  final VideoEpisode episode;
  final VoidCallback? onBackToThumbnail;

  const _HeaderVideoPlayer({required this.episode, this.onBackToThumbnail});

  @override
  State<_HeaderVideoPlayer> createState() => _HeaderVideoPlayerState();
}

class _HeaderVideoPlayerState extends State<_HeaderVideoPlayer> {
  YoutubePlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isOnline = false;
  bool _showControls = false;
  bool _isPlaying = false;
  bool _isFullscreen = false;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndInitialize();
  }

  Future<void> _checkConnectivityAndInitialize() async {
    try {
      // Use centralized connectivity provider
      final connectivity = context.read<ConnectivityProvider>();
      await connectivity.refreshConnectivity();

      if (!mounted) return;

      final isConnected = connectivity.isOnline;

      setState(() {
        _isOnline = isConnected;
      });

      if (isConnected) {
        await _initializePlayer();
      } else {
        setState(() {
          _hasError = true;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = true;
          _isOnline = false;
        });
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      final videoUrl = widget.episode.youtubeVideoUrl;
      if (videoUrl != null && videoUrl.isNotEmpty) {
        final videoId = YoutubePlayer.convertUrlToId(videoUrl);
        if (videoId != null) {
          _controller = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              enableCaption: false,
              loop: false,
              hideControls: true, // Hide all default controls
              disableDragSeek: true, // Disable seek by dragging
              controlsVisibleAtStart: true,
              showLiveFullscreenButton: false,
            ),
          );

          // Add listener to track video state
          _controller!.addListener(() {
            if (mounted) {
              setState(() {
                _isPlaying = _controller!.value.isPlaying;
              });
            }
          });

          if (mounted) {
            setState(() {
              _isInitialized = true;
              _hasError = false;
            });
          }
        } else {
          throw Exception('Invalid video URL');
        }
      } else {
        throw Exception('No video URL provided');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = true;
        });
      }
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });

    // Cancel existing timer
    _hideControlsTimer?.cancel();

    // Start new timer to hide controls after 3 seconds
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _togglePlayPause() {
    if (_controller != null) {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _showControlsTemporarily();
    }
  }

  Future<void> _toggleFullscreen() async {
    if (_controller == null || !mounted) return;

    setState(() {
      _isFullscreen = !_isFullscreen;
      // Always show controls when entering/exiting fullscreen
      _showControls = true;
    });

    // Cancel any auto-hide timer
    _hideControlsTimer?.cancel();

    if (_isFullscreen) {
      // Enter fullscreen - hide UI and force landscape
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      // Start auto-hide timer for fullscreen
      _showControlsTemporarily();
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

  @override
  void dispose() {
    // Reset orientation when disposing
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    try {
      _hideControlsTimer?.cancel();
      _controller?.dispose();
      _controller = null;
    } catch (e) {
      // Error disposing controller
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (!_isInitialized) {
      // Fullscreen mode: fill entire screen
      if (_isFullscreen) {
        return SizedBox.expand(
          child: Container(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          ),
        );
      }
      // Portrait mode: maintain 16:9 aspect ratio
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
        ),
      );
    }

    // Show error/offline state with fallback thumbnail
    if (_hasError || !_isOnline || _controller == null) {
      final errorContent = Stack(
        children: [
          // Fallback thumbnail
          if (widget.episode.thumbnailUrl != null)
            Positioned.fill(
              child: Image.network(
                widget.episode.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildOfflinePlaceholder();
                },
              ),
            ),
          if (widget.episode.thumbnailUrl == null)
            Positioned.fill(child: _buildOfflinePlaceholder()),

          // Offline/Error overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: _isOnline
                          ? HugeIcons.strokeRoundedAlert01
                          : HugeIcons.strokeRoundedWifiDisconnected01,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isOnline ? 'Video Error' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOnline
                          ? 'Cannot load video'
                          : 'Connect to internet\nto watch preview',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Preview badge overlay
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isOnline ? AppTheme.primaryColor : Colors.grey,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'PREVIEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      );

      // Fullscreen mode: fill entire screen
      if (_isFullscreen) {
        return SizedBox.expand(child: errorContent);
      }
      // Portrait mode: maintain 16:9 aspect ratio
      return AspectRatio(aspectRatio: 16 / 9, child: errorContent);
    }

    // Show working video player
    final videoPlayerContent = Stack(
      children: [
        // Video Player takes full space - no tap gestures to prevent seek conflicts
        Positioned.fill(
          child: YoutubePlayer(
            controller: _controller!,
            showVideoProgressIndicator: false, // Hide default progress
            onReady: () {
              // YouTube player ready
            },
            onEnded: (metaData) {
              // Video ended
            },
          ),
        ),

        // Tap overlay to show controls (invisible when controls hidden)
        if (!_showControls)
          Positioned.fill(
            child: GestureDetector(
              onTap: _showControlsTemporarily,
              child: Container(color: Colors.transparent),
            ),
          ),

        // Custom Controls Overlay (only show when _showControls is true)
        if (_showControls)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Stack(
                children: [
                  // Center Play/Pause Button
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlaying
                              ? PhosphorIcons.pause()
                              : PhosphorIcons.play(),
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),

                  // Bottom Progress Bar (Read-Only)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 80,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: StreamBuilder<Duration>(
                        stream: _controller?.value.position != null
                            ? Stream.periodic(
                                const Duration(milliseconds: 100),
                                (_) => _controller!.value.position,
                              )
                            : Stream.empty(),
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration =
                              _controller?.metadata.duration ?? Duration.zero;
                          final progress = duration.inMilliseconds > 0
                              ? position.inMilliseconds /
                                    duration.inMilliseconds
                              : 0.0;

                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Fullscreen Button (Bottom Right)
                  Positioned(
                    bottom: 8,
                    right: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleFullscreen,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: PhosphorIcon(
                            _isFullscreen
                                ? PhosphorIcons.arrowsIn(
                                    PhosphorIconsStyle.bold,
                                  )
                                : PhosphorIcons.arrowsOut(
                                    PhosphorIconsStyle.bold,
                                  ),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    // Fullscreen mode: fill entire screen
    if (_isFullscreen) {
      return SizedBox.expand(child: videoPlayerContent);
    }
    // Portrait mode: maintain 16:9 aspect ratio
    return AspectRatio(aspectRatio: 16 / 9, child: videoPlayerContent);
  }

  Widget _buildOfflinePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.surfaceColor,
      child: Stack(
        children: [
          // Background pattern
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  AppTheme.secondaryColor.withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
          // Video icon
          Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedVideoOff,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
