import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/saved_items_provider.dart';
import '../../../core/models/kitab.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Load real saved items from Supabase
        context.read<SavedItemsProvider>().loadSavedItems();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Saved Items',
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
          onPressed: () => context.go('/profile'),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.label,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 3,
              ),
              insets: const EdgeInsets.symmetric(horizontal: 4),
            ),
            labelColor: AppTheme.primaryColor,
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
              Tab(text: 'Videos'),
              Tab(text: 'E-book'),
            ],
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
    return Consumer<SavedItemsProvider>(
      builder: (context, savedItemsProvider, child) {
        if (savedItemsProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          );
        }

        final savedKitabs = savedItemsProvider.savedKitab;
        final savedEpisodes = savedItemsProvider.savedEpisodes;

        final hasItems = savedKitabs.isNotEmpty || savedEpisodes.isNotEmpty;

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
              if (savedEpisodes.isNotEmpty) ...[
                Text(
                  'Video',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...savedEpisodes.map((episode) => _buildEpisodeCard(episode)),
              ],
            ],
          ),
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
                    ? Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                        width: 2,
                      )
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
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFFA500),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      AppTheme.primaryColor.withValues(
                                        alpha: 0.05,
                                      ),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: kitab.isPremium
                                  ? Colors.transparent
                                  : AppTheme.primaryColor.withValues(
                                      alpha: 0.2,
                                    ),
                            ),
                            boxShadow: kitab.isPremium
                                ? [
                                    BoxShadow(
                                      color: Colors.orange.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIcons.book(PhosphorIconsStyle.fill),
                              color: kitab.isPremium
                                  ? Colors.white
                                  : AppTheme.primaryColor,
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFFD700),
                                            Color(0xFFFFA500),
                                          ],
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
                        GestureDetector(
                          onTap: () => _showKitabBottomSheet(kitab),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedMoreVertical,
                            color: AppTheme.textSecondaryColor,
                            size: 20,
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

  Widget _buildEbookTab() {
    return Consumer<SavedItemsProvider>(
      builder: (context, savedItemsProvider, child) {
        if (savedItemsProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          );
        }

        final savedEbooks = savedItemsProvider.savedEbooks;

        if (savedEbooks.isEmpty) {
          return _buildEmptyState(
            'Tiada e-book disimpan',
            'Simpan e-book kegemaran anda untuk akses mudah',
            buttonText: 'Jelajah E-book',
            onButtonPressed: () => context.go('/ebook'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: savedEbooks
                .map((ebook) => _buildEbookCard(ebook))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildEbookCard(dynamic ebook) {
    final title = ebook is Map
        ? (ebook['title'] ?? 'E-book')
        : (ebook.title ?? 'E-book');
    final author = ebook is Map
        ? (ebook['author'] ?? 'Unknown Author')
        : (ebook.author ?? 'Unknown Author');
    final isPremium = ebook is Map
        ? (ebook['is_premium'] ?? false)
        : (ebook.isPremium ?? false);

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
                border: isPremium
                    ? Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                        width: 2,
                      )
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
                  onTap: () {
                    // Navigate to ebook detail
                    final ebookId = ebook is Map ? ebook['id'] : ebook.id;
                    context.push('/ebook/$ebookId');
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
                            gradient: isPremium
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFFA500),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.1),
                                      const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.05),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isPremium
                                  ? Colors.transparent
                                  : const Color(
                                      0xFF8B5CF6,
                                    ).withValues(alpha: 0.2),
                            ),
                            boxShadow: isPremium
                                ? [
                                    BoxShadow(
                                      color: Colors.orange.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIcons.bookOpen(PhosphorIconsStyle.fill),
                              color: isPremium
                                  ? Colors.white
                                  : const Color(0xFF8B5CF6),
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
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isPremium)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFFD700),
                                            Color(0xFFFFA500),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
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
                                author,
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedBookOpen01,
                                    color: const Color(0xFF8B5CF6),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'E-book tersimpan',
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
                        GestureDetector(
                          onTap: () => _showEbookBottomSheet(ebook),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedMoreVertical,
                            color: AppTheme.textSecondaryColor,
                            size: 20,
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

  Widget _buildEpisodeCard(dynamic episode) {
    final title = episode is Map
        ? (episode['title'] ?? 'Video')
        : (episode.title ?? 'Video');

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
                    final kitabId = episode is Map
                        ? episode['video_kitab_id']
                        : episode.videoKitabId;
                    final episodeId = episode is Map
                        ? episode['id']
                        : episode.id;
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
                                const Color(0xFFFF4444).withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFFFF4444,
                              ).withValues(alpha: 0.2),
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
                        GestureDetector(
                          onTap: () => _showEpisodeBottomSheet(episode),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedMoreVertical,
                            color: AppTheme.textSecondaryColor,
                            size: 20,
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

  Widget _buildEmptyState(
    String title,
    String subtitle, {
    String buttonText = 'Jelajah Kitab',
    VoidCallback? onButtonPressed,
  }) {
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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
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
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.8),
                          ],
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
                        onPressed: onButtonPressed ?? () => context.go('/kitab'),
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
                          PhosphorIcons.compass(PhosphorIconsStyle.fill),
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          buttonText,
                          style: const TextStyle(
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

  void _removeEpisode(dynamic episode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang dari Simpanan'),
        content: const Text(
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
              final episodeId = episode is Map ? episode['id'] : episode.id;
              final success = await context
                  .read<SavedItemsProvider>()
                  .removeVideoFromSaved(episodeId);
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

  void _shareEpisodeContent(dynamic episode) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pautan video dikongsi'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _removeEbook(dynamic ebook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang dari Simpanan'),
        content: const Text(
          'Adakah anda pasti ingin membuang e-book ini dari simpanan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final ebookId = ebook is Map ? ebook['id'] : ebook.id;

              // Get the ebook object from saved list
              final provider = context.read<SavedItemsProvider>();
              final ebookToRemove = provider.savedEbooks.firstWhere(
                (e) => e.id == ebookId,
                orElse: () => throw Exception('Ebook not found'),
              );

              final success = await provider.toggleEbookSaved(ebookToRemove);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('E-book dibuang dari simpanan'),
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

  void _shareEbookContent(dynamic ebook) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pautan e-book dikongsi'),
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

  void _showKitabBottomSheet(Kitab kitab) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header with kitab info
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 60,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: kitab.isPremium
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFA500),
                                  ],
                                )
                              : LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    AppTheme.primaryColor.withValues(
                                      alpha: 0.05,
                                    ),
                                  ],
                                ),
                          border: Border.all(
                            color: kitab.isPremium
                                ? Colors.transparent
                                : AppTheme.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIcons.book(PhosphorIconsStyle.fill),
                            color: kitab.isPremium
                                ? Colors.white
                                : AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title and author
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kitab.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (kitab.author != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                kitab.author!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  height: 1,
                  color: AppTheme.borderColor.withValues(alpha: 0.5),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      // Remove option
                      _buildBottomSheetOption(
                        icon: HugeIcons.strokeRoundedDelete02,
                        title: 'Buang dari Simpanan',
                        subtitle: 'Alih keluar dari senarai simpanan',
                        iconColor: const Color(0xFFEF4444),
                        onTap: () {
                          Navigator.of(context).pop();
                          _removeFromSaved(kitab);
                        },
                      ),

                      // Share option
                      _buildBottomSheetOption(
                        icon: HugeIcons.strokeRoundedShare01,
                        title: 'Kongsi',
                        subtitle: 'Kongsi dengan rakan dan keluarga',
                        iconColor: AppTheme.primaryColor,
                        onTap: () {
                          Navigator.of(context).pop();
                          _shareContent(kitab);
                        },
                      ),
                    ],
                  ),
                ),

                // Bottom padding for safe area
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEbookBottomSheet(dynamic ebook) {
    final title = ebook is Map
        ? (ebook['title'] ?? 'E-book')
        : (ebook.title ?? 'E-book');
    final author = ebook is Map
        ? (ebook['author'] ?? 'Unknown Author')
        : (ebook.author ?? 'Unknown Author');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header with ebook info
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 60,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                              const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIcons.bookOpen(PhosphorIconsStyle.fill),
                            color: const Color(0xFF8B5CF6),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title and author
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              author,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  height: 1,
                  color: AppTheme.borderColor.withValues(alpha: 0.5),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      // Remove option
                      _buildBottomSheetOption(
                        icon: HugeIcons.strokeRoundedDelete02,
                        title: 'Buang',
                        subtitle: 'Alih keluar dari senarai simpanan',
                        iconColor: const Color(0xFFEF4444),
                        onTap: () {
                          Navigator.of(context).pop();
                          _removeEbook(ebook);
                        },
                      ),

                      // Share option
                      _buildBottomSheetOption(
                        icon: HugeIcons.strokeRoundedShare01,
                        title: 'Kongsi',
                        subtitle: 'Kongsi dengan rakan dan keluarga',
                        iconColor: AppTheme.primaryColor,
                        onTap: () {
                          Navigator.of(context).pop();
                          _shareEbookContent(ebook);
                        },
                      ),
                    ],
                  ),
                ),

                // Bottom padding for safe area
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEpisodeBottomSheet(dynamic episode) {
    final title = episode is Map
        ? (episode['title'] ?? 'Video')
        : (episode.title ?? 'Video');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header with episode info
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 60,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF4444).withValues(alpha: 0.1),
                              const Color(0xFFFF4444).withValues(alpha: 0.05),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFFFF4444,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIcons.play(PhosphorIconsStyle.fill),
                            color: const Color(0xFFFF4444),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Video tersimpan',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  height: 1,
                  color: AppTheme.borderColor.withValues(alpha: 0.5),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      // Remove option
                      _buildBottomSheetOption(
                        icon: HugeIcons.strokeRoundedDelete02,
                        title: 'Buang',
                        subtitle: 'Alih keluar dari senarai simpanan',
                        iconColor: const Color(0xFFEF4444),
                        onTap: () {
                          Navigator.of(context).pop();
                          _removeEpisode(episode);
                        },
                      ),

                      // Share option
                      _buildBottomSheetOption(
                        icon: HugeIcons.strokeRoundedShare01,
                        title: 'Kongsi',
                        subtitle: 'Kongsi dengan rakan dan keluarga',
                        iconColor: AppTheme.primaryColor,
                        onTap: () {
                          Navigator.of(context).pop();
                          _shareEpisodeContent(episode);
                        },
                      ),
                    ],
                  ),
                ),

                // Bottom padding for safe area
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build individual option in bottom sheet
  Widget _buildBottomSheetOption({
    required dynamic icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor == AppTheme.primaryColor
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: iconColor == AppTheme.primaryColor
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : AppTheme.borderColor,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: icon is IconData
                      ? PhosphorIcon(icon, color: iconColor, size: 20)
                      : HugeIcon(icon: icon, color: iconColor, size: 20),
                ),
              ),
              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              PhosphorIcon(
                PhosphorIcons.caretRight(),
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
