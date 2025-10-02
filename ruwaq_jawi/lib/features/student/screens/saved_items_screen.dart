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
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: savedEbooks.map((ebook) => _buildEbookCard(ebook)).toList(),
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
                                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                  )
                                : LinearGradient(
                                    colors: [
                                      const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                      const Color(0xFF8B5CF6).withValues(alpha: 0.05)
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isPremium
                                  ? Colors.transparent
                                  : const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                            ),
                            boxShadow: isPremium ? [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIcons.bookOpen(PhosphorIconsStyle.fill),
                              color: isPremium ? Colors.white : const Color(0xFF8B5CF6),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
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
                        PopupMenuButton<String>(
                          onSelected: (value) => _handleEbookAction(value, ebook),
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
                          onSelected: (value) => _handleEpisodeAction(value, episode),
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

  void _handleEbookAction(String action, dynamic ebook) {
    switch (action) {
      case 'remove':
        _removeEbook(ebook);
        break;
      case 'share':
        _shareEbookContent(ebook);
        break;
    }
  }

  void _handleEpisodeAction(String action, dynamic episode) {
    switch (action) {
      case 'remove':
        _removeEpisode(episode);
        break;
      case 'share':
        _shareEpisodeContent(episode);
        break;
    }
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
              final episodeId = episode is Map
                  ? episode['id']
                  : episode.id;
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
}
