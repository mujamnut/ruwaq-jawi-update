import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/saved_items_provider.dart';
import '../../../core/providers/bookmark_provider.dart';
import '../../../core/models/kitab.dart';
import '../../../core/services/local_saved_items_service.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Animation controllers for smooth animations
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize tab controller
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SavedItemsProvider>().loadSavedItems();
        // Also load bookmarks so the Video tab (sourced from bookmarks) has data
        final bm = context.read<BookmarkProvider>();
        if (!bm.isLoading && bm.bookmarks.isEmpty) {
          bm.loadBookmarks();
        }

        // Add test data for demonstration
        _addTestData();

        // Start animations with delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _fadeAnimationController.forward();
            _slideAnimationController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  void _addTestData() async {
    try {
      final provider = context.read<SavedItemsProvider>();

      // Add sample kitab data untuk test
      final sampleKitab = Kitab(
        id: 'test_kitab_1',
        title: 'Kitab Test Simpanan',
        author: 'Penulis Test',
        description: 'Ini adalah kitab test untuk local storage',
        thumbnailUrl: '',
        categoryId: 'test_category',
        isActive: true,
        isPremium: false,
        sortOrder: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await provider.addKitabToLocal(sampleKitab);

      // Add sample video data untuk test
      await LocalSavedItemsService.saveVideo({
        'kitabId': 'test_kitab_1',
        'episodeId': 'test_episode_1',
        'title': 'Video Test Simpanan',
        'description': 'Video test untuk local storage',
        'createdAt': DateTime.now().toIso8601String(),
      });

      debugPrint('Test data added successfully');
    } catch (e) {
      debugPrint('Error adding test data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadLocalVideos() async {
    try {
      return await LocalSavedItemsService.getSavedVideos();
    } catch (e) {
      debugPrint('Error loading local videos: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Simpanan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppTheme.textPrimaryColor,
            size: 24,
          ),
          onPressed: () => context.go('/home'),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondaryColor,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Kitab & Video'),
                Tab(text: 'E-book'),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: SlideTransition(
              position: _slideAnimation,
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [_buildKitabAndVideoTab(), _buildEbookTab()],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKitabAndVideoTab() {
    return Consumer2<SavedItemsProvider, BookmarkProvider>(
      builder: (context, savedItemsProvider, bookmarkProvider, child) {
        final isLoading =
            savedItemsProvider.isLoading || bookmarkProvider.isLoading;

        if (isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          );
        }

        final savedKitabs = savedItemsProvider.savedKitab;
        final videoBookmarks = bookmarkProvider.getBookmarksByType('video');

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadLocalVideos(),
          builder: (context, snapshot) {
            final localVideos = snapshot.data ?? [];
            final allVideos = [...videoBookmarks, ...localVideos];

            final hasItems = savedKitabs.isNotEmpty || allVideos.isNotEmpty;

            if (!hasItems) {
              return _buildEmptyState(
                'Tiada simpanan',
                'Simpan kitab dan video kegemaran anda untuk akses mudah',
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (savedKitabs.isNotEmpty) ...[
                    Text(
                      'Kitab',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...savedKitabs.map((kitab) => _buildKitabCard(kitab)),
                    const SizedBox(height: 16),
                  ],
                  if (allVideos.isNotEmpty) ...[
                    Text(
                      'Video',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...allVideos.map((video) => _buildVideoCard(video)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKitabTab() {
    return Consumer<SavedItemsProvider>(
      builder: (context, savedItemsProvider, child) {
        if (savedItemsProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          );
        }

        if (savedItemsProvider.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedAlert02,
                        color: Color(0xFFEF4444),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ralat memuatkan simpanan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    savedItemsProvider.error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => savedItemsProvider.loadSavedItems(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: PhosphorIcon(
                        PhosphorIcons.arrowClockwise(PhosphorIconsStyle.fill),
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Cuba Lagi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (savedItemsProvider.savedKitab.isEmpty) {
          return _buildEmptyState(
            'Tiada kitab disimpan',
            'Simpan kitab kegemaran anda untuk akses mudah',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: savedItemsProvider.savedKitab.length,
          itemBuilder: (context, index) {
            return _buildKitabCard(savedItemsProvider.savedKitab[index]);
          },
        );
      },
    );
  }

  Widget _buildVideoTab() {
    return Consumer<BookmarkProvider>(
      builder: (context, bmProvider, child) {
        if (bmProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (bmProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ralat memuatkan video disimpan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bmProvider.error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => bmProvider.loadBookmarks(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textLightColor,
                  ),
                  child: const Text('Cuba Lagi'),
                ),
              ],
            ),
          );
        }

        final videos = bmProvider.getBookmarksByType('video');
        if (videos.isEmpty) {
          return _buildEmptyState(
            'Tiada video disimpan',
            'Simpan video kegemaran anda untuk tontonan kemudian',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final v = videos[index];
            final title = v.title.isNotEmpty ? v.title : 'Tanpa Tajuk';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: InkWell(
                onTap: () {
                  // Open the content player for this kitab and show the video tab
                  context.push('/player/${v.kitabId}');
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kitab: ${v.kitabId}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'remove') {
                            final ok = await context
                                .read<BookmarkProvider>()
                                .removeBookmark(v.kitabId);
                            if (ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Video dibuang dari simpanan'),
                                ),
                              );
                            }
                          } else if (value == 'share') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Pautan "$title" dikongsi'),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.bookmark_remove),
                                SizedBox(width: 8),
                                Text('Buang'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share),
                                SizedBox(width: 8),
                                Text('Kongsi'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKitabCard(Kitab kitab) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: kitab.isPremium
                    ? Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3), width: 2)
                    : Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/kitab/${kitab.id}'),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: kitab.isPremium
                                ? const LinearGradient(
                                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                  )
                                : LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor.withValues(alpha: 0.1),
                                      AppTheme.primaryColor.withValues(alpha: 0.05)
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: kitab.isPremium
                                  ? Colors.transparent
                                  : AppTheme.primaryColor.withValues(alpha: 0.2),
                            ),
                            boxShadow: kitab.isPremium ? [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIcons.book(PhosphorIconsStyle.fill),
                              color: kitab.isPremium ? Colors.white : AppTheme.primaryColor,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      kitab.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (kitab.isPremium)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'PREMIUM',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                kitab.author ?? 'Unknown Author',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (kitab.durationMinutes != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedClock01,
                                      color: AppTheme.primaryColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${kitab.durationMinutes} min',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) => _handleKitabAction(value, kitab),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedMoreVertical,
                            color: AppTheme.textSecondaryColor,
                            size: 20,
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  PhosphorIcon(
                                    PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill),
                                    color: const Color(0xFFEF4444),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Buang dari simpanan'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedShare01,
                                    color: AppTheme.primaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Kongsi'),
                                ],
                              ),
                            ),
                          ],
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

  Widget _buildEbookTab() {
    // For now, show placeholder for e-book saved items
    // This will need to be connected to actual e-book saved items provider
    return _buildEmptyState(
      'Tiada e-book disimpan',
      'Simpan e-book kegemaran anda untuk akses mudah',
    );
  }

  Widget _buildVideoCard(dynamic bookmark) {
    final title = bookmark is Map
        ? (bookmark['title'] ?? 'Video')
        : (bookmark.title ?? 'Video');

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Navigate to video player
                    final kitabId = bookmark is Map
                        ? bookmark['kitabId']
                        : bookmark.kitabId;
                    final episodeId = bookmark is Map
                        ? bookmark['episodeId']
                        : bookmark.episodeId;
                    context.push('/player/$kitabId?episode=$episodeId');
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF4444).withValues(alpha: 0.1),
                                const Color(0xFFFF4444).withValues(alpha: 0.05)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFF4444).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIcons.play(PhosphorIconsStyle.fill),
                              color: const Color(0xFFFF4444),
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryColor,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedVideoReplay,
                                    color: const Color(0xFFFF4444),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Video tersimpan',
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) => _handleVideoAction(value, bookmark),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedMoreVertical,
                            color: AppTheme.textSecondaryColor,
                            size: 20,
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedDelete02,
                                    color: const Color(0xFFEF4444),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Buang'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedShare01,
                                    color: AppTheme.primaryColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Kongsi'),
                                ],
                              ),
                            ),
                          ],
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

  Widget _buildEmptyState(String title, String subtitle) {
    return TweenAnimationBuilder<double>(
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
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedBookmark02,
                          color: AppTheme.primaryColor,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondaryColor,
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
                        onPressed: () => context.go('/kitab'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: PhosphorIcon(
                          PhosphorIcons.compass(PhosphorIconsStyle.fill),
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'Jelajah Kitab',
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
    );
  }

  void _handleKitabAction(String action, Kitab kitab) {
    switch (action) {
      case 'remove':
        _removeFromSaved(kitab);
        break;
      case 'share':
        _shareContent(kitab);
        break;
    }
  }

  void _handleVideoAction(String action, dynamic bookmark) {
    switch (action) {
      case 'remove':
        _removeVideoBookmark(bookmark);
        break;
      case 'share':
        _shareVideoContent(bookmark);
        break;
    }
  }

  void _removeVideoBookmark(dynamic bookmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang dari Simpanan'),
        content: Text(
          'Adakah anda pasti ingin membuang video ini dari simpanan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final kitabId = bookmark is Map
                  ? bookmark['kitabId']
                  : bookmark.kitabId;
              final success = await context
                  .read<BookmarkProvider>()
                  .removeBookmark(kitabId);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Video dibuang dari simpanan'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
  }

  void _shareVideoContent(dynamic bookmark) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pautan video dikongsi'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _removeFromSaved(Kitab kitab) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang dari Simpanan'),
        content: Text(
          'Adakah anda pasti ingin membuang "${kitab.title}" dari simpanan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await context
                  .read<SavedItemsProvider>()
                  .removeFromSaved(kitab.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${kitab.title} dibuang dari simpanan'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
  }

  void _shareContent(Kitab kitab) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pautan "${kitab.title}" dikongsi'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
