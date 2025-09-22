import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/local_favorites_service.dart';
import '../../../core/models/video_kitab.dart';
import '../../../core/models/video_episode.dart';
import '../../../core/utils/youtube_utils.dart';
import '../../../core/widgets/offline_banner.dart';

class KitabDetailScreen extends StatefulWidget {
  final String kitabId;

  const KitabDetailScreen({super.key, required this.kitabId});

  @override
  State<KitabDetailScreen> createState() => _KitabDetailScreenState();
}

class _KitabDetailScreenState extends State<KitabDetailScreen> with TickerProviderStateMixin {
  bool _isSaved = false;
  VideoKitab? _kitab;
  bool _isLoading = true;
  double _collapseRatio = 0.0;
  List<VideoEpisode>? _cachedEpisodes;
  bool _episodesLoading = false;

  // Animation controllers for smooth animations
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

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

    _loadKitabData();
    _checkIfSaved();
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

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  void _checkIfSaved() {
    if (_kitab != null) {
      setState(() {
        _isSaved = LocalFavoritesService.isVideoKitabFavorite(_kitab!.id);
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
              borderRadius: BorderRadius.circular(12),
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
              borderRadius: BorderRadius.circular(12),
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
                              icon: HugeIcons.strokeRoundedBookOpen01,
                              color: AppTheme.textSecondaryColor,
                              size: 48,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
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
                            icon: PhosphorIcon(
                              PhosphorIcons.arrowLeft(PhosphorIconsStyle.fill),
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

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NotificationListener<ScrollNotification>(
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
                              if (_kitab!.totalVideos > 1) _buildEpisodesSection(),
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
            // Adaptive floating love button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: Container(
                decoration: _collapseRatio > 0.5
                    ? null // No background when collapsed
                    : BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
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
      leading: IconButton(
        icon: PhosphorIcon(
          PhosphorIcons.arrowLeft(),
          color: _collapseRatio > 0.5
              ? AppTheme.textPrimaryColor
              : Colors.white,
        ),
        onPressed: () => context.pop(),
      ),
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
              bottom: 17,
              right: 16,
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _kitab?.title ?? 'Kitab',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                      fontSize: 16,
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
                  // Background image from thumbnail
                  Positioned.fill(child: _buildThumbnailImage()),
                  // Gradient overlay
                  Positioned.fill(
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
        final canAccess =
            !_kitab!.isPremium || authProvider.hasActiveSubscription;

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.backgroundColor.withValues(alpha: 0.5), AppTheme.backgroundColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                  spreadRadius: 0,
                ),
              ],
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
                  canAccess ? 'Tonton Sekarang' : 'Premium Diperlukan',
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
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_kitab!.totalVideos}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
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
      if (a.isPreview && !b.isPreview) return -1;
      if (!a.isPreview && b.isPreview) return 1;

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
    final canAccess = !_kitab!.isPremium || authProvider.hasActiveSubscription;

    // Episode is locked if:
    // 1. Premium kitab without subscription and not preview
    // 2. Episode is inactive
    final isLocked = (!canAccess && !episode.isPreview) || !episode.isActive;

    // Always show premium videos but lock them if no subscription
    final isPremiumLocked =
        _kitab!.isPremium &&
        !authProvider.hasActiveSubscription &&
        !episode.isPreview;

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
                border: Border.all(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
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
                            // Duration badge with enhanced design
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
                                    episode.displayDuration,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            // Preview badge with enhanced design
                            if (episode.isPreview)
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
                                        AppTheme.secondaryColor.withValues(alpha: 0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.secondaryColor.withValues(alpha: 0.3),
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
                                        color: Colors.white.withValues(alpha: 0.9),
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
                              // Episode number badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
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

                              const SizedBox(height: 6),

                              // Duration with icon
                              Row(
                                children: [
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
                            ],
                          ),
                        ),

                        // Action button with enhanced design
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.borderColor.withValues(alpha: 0.5),
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
      bool success;

      if (_isSaved) {
        // Remove from local favorites
        success = await LocalFavoritesService.removeVideoKitabFromFavorites(
          _kitab!.id,
        );
      } else {
        // Add to local favorites
        success = await LocalFavoritesService.addVideoKitabToFavorites(
          _kitab!.id,
        );
      }

      if (success && mounted) {
        setState(() {
          _isSaved = !_isSaved;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSaved
                  ? 'Kitab added to favorites'
                  : 'Kitab removed from favorites',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _isSaved ? Colors.green : Colors.orange,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling saved status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error occurred. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startReading() async {
    final hasInternet = await requiresInternet(
      context,
      message: 'error starting video. Please check your internet connection.',
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
          if (a.isPreview && !b.isPreview) return -1;
          if (!a.isPreview && b.isPreview) return 1;

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
    final hasInternet = await requiresInternet(
      context,
      message: 'error starting video. Please check your internet connection.',
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
}
