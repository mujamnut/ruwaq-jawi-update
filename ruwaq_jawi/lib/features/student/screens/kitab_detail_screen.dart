import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/saved_items_provider.dart';
import '../../../core/services/local_favorites_service.dart';
import '../../../core/models/video_kitab.dart';
import '../../../core/models/video_episode.dart';
import '../../../core/utils/youtube_utils.dart';
import '../widgets/preview_video_selection_dialog.dart';
import '../../../core/widgets/offline_banner.dart';

class KitabDetailScreen extends StatefulWidget {
  final String kitabId;

  const KitabDetailScreen({super.key, required this.kitabId});

  @override
  State<KitabDetailScreen> createState() => _KitabDetailScreenState();
}

class _KitabDetailScreenState extends State<KitabDetailScreen> {
  bool _isSaved = false;
  VideoKitab? _kitab;
  bool _isLoading = true;
  double _collapseRatio = 0.0;
  List<VideoEpisode>? _cachedEpisodes;
  bool _episodesLoading = false;

  @override
  void initState() {
    super.initState();
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
          // Icon and text
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PhosphorIcon(
                  PhosphorIcons.bookOpen(),
                  size: 64,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  _kitab?.title ?? 'Kitab',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_kitab?.author != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _kitab!.author!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
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
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.caretLeft(),
              color: AppTheme.textPrimaryColor,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_kitab == null) {
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
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                PhosphorIcons.bookOpen(),
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
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Kembali'),
              ),
            ],
          ),
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

            final newCollapseRatio = ((scrollOffset) / (expandedHeight - toolbarHeight)).clamp(0.0, 1.0);

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
            CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                _buildFloatingAppBar(),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildActionButtons(),
                      _buildDescription(),
                      if (_kitab!.totalVideos > 1) _buildEpisodesSection(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
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
                        ? Colors.red
                        : (_collapseRatio > 0.5 ? AppTheme.textSecondaryColor : Colors.white),
                  ),
                  onPressed: _toggleSaved,
                ),
              ),
            ),
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
          PhosphorIcons.caretLeft(),
          color: AppTheme.textPrimaryColor,
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
                    color: Colors.amber,
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

  Widget _buildActionButtons() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final canAccess =
            !_kitab!.isPremium || authProvider.hasActiveSubscription;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: canAccess
                      ? _startReading
                      : _showSubscriptionDialog,
                  icon: PhosphorIcon(
                    canAccess
                        ? PhosphorIcons.playCircle()
                        : PhosphorIcons.lock(),
                    size: 20,
                    color: Colors.white,
                  ),
                  label: Text(
                    canAccess ? 'Watch' : 'Premium Required',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAccess
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _previewContent,
                  icon: PhosphorIcon(
                    PhosphorIcons.eye(),
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  label: const Text('Preview'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDescription() {
    if (_kitab!.description?.isEmpty ?? true) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
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
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
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
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppTheme.textSecondaryColor),
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

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedEpisodes.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final episode = sortedEpisodes[index];
        // Use partNumber from database instead of calculated index
        return RepaintBoundary(
          child: _buildEpisodeCard(episode, episode.partNumber),
        );
      },
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: !episode.isActive
            ? () => _showInactiveEpisodeDialog()
            : isPremiumLocked
            ? _showPremiumDialog
            : (isLocked
                  ? _showSubscriptionDialog
                  : () => _playEpisode(episode)),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLocked ? Colors.white.withValues(alpha: 0.7) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.borderColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Video camera icon circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isLocked
                      ? AppTheme.textSecondaryColor.withValues(alpha: 0.1)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: PhosphorIcon(
                    isLocked
                        ? PhosphorIcons.lock()
                        : PhosphorIcons.videoCamera(),
                    color: isLocked
                        ? AppTheme.textSecondaryColor
                        : AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Episode content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Episode title with badges
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            episode.title,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
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
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PREVIEW',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                            ),
                          ),
                        if (!episode.isActive)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SEGERA',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Duration
                    Text(
                      episode.formattedDuration,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Action icons (Love + Play/Lock)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Love icon (save) - only show for non-preview videos that user can access
                  if (!episode.isPreview && !isLocked)
                    _buildEpisodeSaveButton(episode),
                  const SizedBox(width: 8),
                  // Play/Lock indicator
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: PhosphorIcon(
                      isLocked ? PhosphorIcons.lock() : PhosphorIcons.play(),
                      color: isLocked
                          ? AppTheme.textSecondaryColor
                          : AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeSaveButton(VideoEpisode episode) {
    return Consumer<SavedItemsProvider>(
      builder: (context, savedItemsProvider, child) {
        final isEpisodeSaved = savedItemsProvider.isEpisodeSaved(episode.id);

        return InkWell(
          onTap: () => _toggleEpisodeSaved(episode),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: PhosphorIcon(
              isEpisodeSaved
                  ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                  : PhosphorIcons.heart(),
              color: isEpisodeSaved ? Colors.red : AppTheme.textSecondaryColor,
              size: 18,
            ),
          ),
        );
      },
    );
  }

  void _toggleEpisodeSaved(VideoEpisode episode) async {
    final savedItemsProvider = context.read<SavedItemsProvider>();

    try {
      bool success;
      final isCurrentlySaved = savedItemsProvider.isEpisodeSaved(episode.id);

      if (isCurrentlySaved) {
        success = await savedItemsProvider.removeEpisodeFromLocal(episode.id);
      } else {
        success = await savedItemsProvider.addEpisodeToLocal(episode);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlySaved
                  ? 'Episode removed from favorites'
                  : 'Episode added to favorites',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isCurrentlySaved ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error occurred. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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

    if (_kitab!.hasVideos) {
      context.read<KitabProvider>().loadKitabVideos(_kitab!.id).then((
        episodes,
      ) {
        if (episodes.isNotEmpty) {
          final firstEpisode = episodes.first;
          context.push('/player/${widget.kitabId}?episode=${firstEpisode.id}');
        } else {
          context.push('/player/${widget.kitabId}');
        }
      });
    } else {
      context.push('/player/${widget.kitabId}');
    }
  }

  void _playEpisode(VideoEpisode episode) async {
    final hasInternet = await requiresInternet(
      context,
      message: 'error starting video. Please check your internet connection.',
    );

    if (!hasInternet) return;

    context.push('/player/${widget.kitabId}?episode=${episode.id}');
  }

  void _previewContent() async {
    if (_kitab == null) return;

    final hasInternet = await requiresInternet(
      context,
      message: 'error loading preview. Please check your internet connection.',
    );

    if (!hasInternet) return;

    try {
      final kitabProvider = context.read<KitabProvider>();
      final hasPreview = await kitabProvider.hasPreviewVideos(_kitab!.id);

      if (!hasPreview && mounted) {
        _showNoPreviewDialog();
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) =>
              PreviewVideoSelectionDialog(kitabId: _kitab!.id, kitab: _kitab!),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error load the preview ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              Navigator.pop(context);
              // Navigate to subscription screen
              context.push('/subscription');
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
              Navigator.of(context).pop();
              context.push('/subscription');
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

  void _showNoPreviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.videoCamera(),
              color: AppTheme.textSecondaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('No Preview Available'),
          ],
        ),
        content: const Text(
          'This kitab does not have any preview videos available at the moment.',
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
