import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/thumbnail_utils.dart';
import '../widgets/student_bottom_nav.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with TickerProviderStateMixin {
  late PageController _featuredScrollController;
  Timer? _autoScrollTimer;
  late AnimationController _progressAnimationController;
  int _currentCardIndex = 0;
  int _totalCards = 0;
  bool _userIsScrolling = false;

  @override
  void initState() {
    super.initState();
    _featuredScrollController = PageController(viewportFraction: 0.9);
    _progressAnimationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );


    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kitabProvider = context.read<KitabProvider>();
      if (kitabProvider.videoKitabList.isEmpty &&
          kitabProvider.ebookList.isEmpty) {
        kitabProvider.initialize();
      }
      // Load notifications inbox for signed-in users
      context.read<NotificationsProvider>().loadInbox();

      // Start auto-scroll after content loads
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    _resetAutoScrollTimer();
  }

  void _resetAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _progressAnimationController.stop();
    _progressAnimationController.reset();

    // Start first animation
    _startProgressAnimation();
  }

  void _startProgressAnimation() {
    if (mounted && !_userIsScrolling) {
      _progressAnimationController.forward().then((_) {
        if (mounted &&
            _featuredScrollController.hasClients &&
            !_userIsScrolling) {
          _scrollToNextCard();
          // Start next cycle
          _progressAnimationController.reset();
          _startProgressAnimation();
        }
      });
    } else {
      // If user is scrolling, try again after 100ms
      Timer(const Duration(milliseconds: 100), () {
        _userIsScrolling = false;
        _startProgressAnimation();
      });
    }
  }

  void _scrollToNextCard() {
    if (_totalCards == 0) return;

    // Move to next card
    _currentCardIndex = (_currentCardIndex + 1) % _totalCards;

    // Trigger rebuild for dots indicator
    setState(() {});

    // Use PageController to animate to next page
    final pageController = _featuredScrollController;
    final currentPage = pageController.page?.round() ?? 0;
    final nextPage = currentPage + 1;

    pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _featuredScrollController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with greeting and search
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildHeader(),
              ),

              const SizedBox(height: 24),

              // Featured content section (full width with margins)
              _buildFeaturedSection(),

              const SizedBox(height: 24),

              // Categories section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildCategoriesSection(),
              ),

              const SizedBox(height: 24),

              // Recent content section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildRecentSection(),
              ),

              const SizedBox(height: 24),

              // Continue reading section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildContinueReadingSection(),
              ),

              // Add bottom padding to prevent overflow with bottom navigation
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const StudentBottomNav(currentIndex: 0),
    );
  }

  Widget _buildHeader() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final userName = authProvider.userProfile?.fullName ?? 'Pengguna';
        final firstName = userName.split(' ').first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assalamualaikum,',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      Text(
                        firstName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondaryColor,
                            ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Notification Icon
                    Consumer<NotificationsProvider>(
                      builder: (context, notif, _) {
                        final unread = notif.unreadCount;
                        final icon = IconButton(
                          icon: PhosphorIcon(
                            PhosphorIcons.bell(),
                            color: AppTheme.textPrimaryColor,
                          ),
                          onPressed: () async {
                            // Refresh inbox and show simple list
                            final provider = context.read<NotificationsProvider>();
                            await provider.loadInbox();

                            // Auto mark all unread notifications as read when user opens notification
                            final user = Supabase.instance.client.auth.currentUser;
                            if (user != null) {
                              final unreadNotifications = provider.inbox.where((n) => !n.isReadByUser(user.id)).toList();
                              for (final notification in unreadNotifications) {
                                await provider.markAsRead(notification.id);
                              }
                            }

                            if (!mounted) return;
                            // Show bottom sheet with notifications (same behavior)
                            // ignore: use_build_context_synchronously
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: AppTheme.surfaceColor,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              builder: (_) {
                                final items = context
                                    .read<NotificationsProvider>()
                                    .inbox;
                                if (items.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Center(
                                      child: Text(
                                        'Tiada notifikasi',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color:
                                                  AppTheme.textSecondaryColor,
                                            ),
                                      ),
                                    ),
                                  );
                                }
                                return SafeArea(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: items.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 16),
                                    itemBuilder: (ctx, i) {
                                      final n = items[i];
                                      final isUnread = n.readAt == null;
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: PhosphorIcon(
                                          isUnread
                                              ? PhosphorIcons.envelope(
                                                  PhosphorIconsStyle.fill,
                                                )
                                              : PhosphorIcons.envelope(),
                                          color: isUnread
                                              ? AppTheme.primaryColor
                                              : AppTheme.textSecondaryColor,
                                        ),
                                        title: Text(
                                          n.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                fontWeight: isUnread
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color:
                                                    AppTheme.textPrimaryColor,
                                              ),
                                        ),
                                        subtitle: Text(
                                          n.body,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color:
                                                    AppTheme.textSecondaryColor,
                                              ),
                                        ),
                                        onTap: () async {
                                          await context
                                              .read<NotificationsProvider>()
                                              .markAsRead(n.id);
                                          if (!mounted) return;
                                          Navigator.of(context).pop();
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        );
                        if (unread > 0) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              icon,
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30), // Pure red, no border
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      unread > 99 ? '99+' : '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        height: 1.0,
                                        letterSpacing: -0.1,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return icon;
                      },
                    ),
                    const SizedBox(width: 12),
                    // Profile Avatar
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: _buildProfileAvatar(authProvider),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search bar
            GestureDetector(
              onTap: () {
                context.push('/search');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.magnifyingGlass(),
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Cari kitab, video, atau topik...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedSection() {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        // Combine premium video kitab and ebooks for featured section
        final featuredContent = [
          ...kitabProvider.premiumVideoKitab.take(3),
          ...kitabProvider.premiumEbooks.take(2),
        ];

        if (featuredContent.isEmpty) {
          return const SizedBox.shrink();
        }

        // Update total cards count for auto-scroll
        _totalCards = featuredContent.length;


        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Pilihan Utama',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              color: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 180,
                  maxHeight: 220,
                ),
                child: PageView.builder(
                  controller: _featuredScrollController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentCardIndex = index % featuredContent.length;
                    });
                    _userIsScrolling = true;
                    _resetAutoScrollTimer();
                  },
                  itemBuilder: (context, index) {
                    // Infinite scroll logic - cycle through original content
                    final actualIndex = index % featuredContent.length;
                    final content = featuredContent[actualIndex];

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildFeaturedCard(content),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Dots indicator with progress animation
            _buildDotsIndicator(),
          ],
        );
      },
    );
  }

  Widget _buildDotsIndicator() {
    if (_totalCards == 0) return const SizedBox.shrink();

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalCards, (index) {
          final isActive = index == (_currentCardIndex % _totalCards);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: isActive
                ? // Active dot becomes progress bar
                  AnimatedBuilder(
                    animation: _progressAnimationController,
                    builder: (context, child) {
                      return Container(
                        width: 24,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _userIsScrolling
                              ? 0
                              : _progressAnimationController.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : // Inactive dots remain as circles
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.borderColor,
                    ),
                  ),
          );
        }),
      ),
    );
  }

  Widget _buildFeaturedCard(dynamic content) {
    final isEbook = content.runtimeType.toString().contains('Ebook');
    final route = isEbook ? '/ebook/${content.id}' : '/kitab/${content.id}';

    return GestureDetector(
      onTap: () => context.push(route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFFF8F9FA), // Light gray instead of pure white
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'PREMIUM',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    content.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.description ??
                        (isEbook
                            ? 'E-book premium dengan kandungan berkualiti tinggi'
                            : 'Video kitab premium dengan kandungan berkualiti tinggi'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        final categories = kitabProvider.categories.take(6).toList();

        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kategori',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/kitab'),
                  child: Text(
                    'Lihat Semua',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                // Count both video kitab and ebooks for this category
                final videoKitabCount = kitabProvider.videoKitabList
                    .where((k) => k.categoryId == category.id)
                    .length;
                final ebookCount = kitabProvider.ebookList
                    .where((e) => e.categoryId == category.id)
                    .length;
                final totalCount = videoKitabCount + ebookCount;

                return GestureDetector(
                  onTap: () => context.push(
                    '/kitab?category=${Uri.encodeComponent(category.name)}',
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      children: [
                        // Top section with Arabic text
                        Expanded(
                          flex: 2,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _getArabicTextForCategory(category.name),
                                style: const TextStyle(
                                  fontFamily: 'ArefRuqaa',
                                  fontSize: 35,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        // Bottom section with category name and count
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    category.name,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimaryColor,
                                          fontSize: 12,
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: Text(
                                    '$totalCount item',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textSecondaryColor,
                                          fontSize: 10,
                                        ),
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
          ],
        );
      },
    );
  }

  Widget _buildRecentSection() {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        // Combine both video kitab and ebooks for recent section
        final recentContent =
            <dynamic>[
              ...kitabProvider.videoKitabList,
              ...kitabProvider.ebookList,
            ]..sort(
              (a, b) =>
                  (b as dynamic).createdAt.compareTo((a as dynamic).createdAt),
            );
        final displayContent = recentContent.take(4).toList();

        if (displayContent.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terbaru',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/kitab?sort=newest'),
                  child: Text(
                    'Lihat Semua',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 220,
                maxHeight: 260,
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: displayContent.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  return Container(
                    width: 160,
                    margin: EdgeInsets.only(
                      right: index < displayContent.length - 1 ? 12 : 0,
                    ),
                    child: _buildContentCard(displayContent[index]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _getYouTubeThumbnailUrl(String? youtubeUrl) {
    if (youtubeUrl == null || youtubeUrl.isEmpty) return '';

    // Extract video ID from various YouTube URL formats
    String? videoId;

    if (youtubeUrl.contains('youtube.com/watch?v=')) {
      videoId = youtubeUrl.split('v=')[1].split('&')[0];
    } else if (youtubeUrl.contains('youtu.be/')) {
      videoId = youtubeUrl.split('youtu.be/')[1].split('?')[0];
    } else if (youtubeUrl.contains('youtube.com/embed/')) {
      videoId = youtubeUrl.split('embed/')[1].split('?')[0];
    }

    if (videoId != null && videoId.isNotEmpty) {
      // Use high quality thumbnail (hqdefault.jpg)
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }

    return '';
  }

  Widget _buildVideoThumbnail(dynamic content) {
    String thumbnailUrl = '';

    // Check if content has thumbnailUrl (VideoKitab case)
    if (content.thumbnailUrl != null && content.thumbnailUrl.isNotEmpty) {
      thumbnailUrl = content.thumbnailUrl;
    }
    // If no thumbnailUrl, try to get from youtubeWatchUrl (VideoEpisode case)
    else if (content.runtimeType.toString().contains('VideoEpisode') &&
        content.youtubeWatchUrl != null) {
      thumbnailUrl = _getYouTubeThumbnailUrl(content.youtubeWatchUrl);
    }

    if (thumbnailUrl.isNotEmpty) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.videoCamera(),
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
      );
    } else {
      // Fallback to icon if no YouTube URL
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTheme.primaryColor.withOpacity(0.1),
        child: Center(
          child: PhosphorIcon(
            PhosphorIcons.videoCamera(),
            size: 48,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }
  }

  Widget _buildContentCard(dynamic content) {
    final isEbook = content.runtimeType.toString().contains('Ebook');
    final route = isEbook ? '/ebook/${content.id}' : '/kitab/${content.id}';

    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail section with proper constraints
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: isEbook
                    ? // Keep icon for ebooks
                      Center(
                        child: PhosphorIcon(
                          PhosphorIcons.filePdf(),
                          size: 48,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : // Use thumbnail for video kitab with proper clipping
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: _buildVideoThumbnail(content),
                      ),
              ),
            ),
            // Content section with flexible height
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      content.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content.author ?? 'Unknown Author',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Show appropriate info based on content type
                    Row(
                      children: [
                        PhosphorIcon(
                          isEbook
                              ? PhosphorIcons.filePdf()
                              : PhosphorIcons.videoCamera(),
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isEbook
                                ? (content.totalPages != null
                                      ? '${content.totalPages} hal'
                                      : 'E-book')
                                : (content.totalVideos > 0
                                      ? '${content.totalVideos} episod'
                                      : '1 episod'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueReadingSection() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.hasActiveSubscription) {
          return const SizedBox.shrink();
        }
        return FutureBuilder<List<dynamic>>(
          future: context.read<KitabProvider>().loadContinueReading(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            final item = snapshot.data!.first; // { kitab, progress }
            final kitab = item["kitab"];
            final progress =
                item["progress"]; // expects progress_percentage, current_page
            final progressValue =
                ((progress["progress_percentage"] ?? 0) as num).toDouble() /
                100.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.bookOpen(),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sambung Bacaan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.push('/kitab/${kitab.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: PhosphorIcon(
                            PhosphorIcons.bookOpen(),
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kitab.title,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                kitab.author ?? '—',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: progressValue.clamp(0.0, 1.0),
                                backgroundColor: AppTheme.borderColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(progressValue * 100).toStringAsFixed(0)}% selesai',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        PhosphorIcon(
                          PhosphorIcons.caretRight(),
                          color: AppTheme.textSecondaryColor,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProfileAvatar(AuthProvider authProvider) {
    final userProfile = authProvider.userProfile;
    final userName = userProfile?.fullName ?? 'User';
    final profileImageUrl = userProfile?.avatarUrl;
    final isPremium = authProvider.hasActiveSubscription; // Check if user has active subscription

    // Get initials from name
    String getInitials(String name) {
      final words = name.trim().split(' ');
      if (words.isEmpty) return 'U';
      if (words.length == 1) return words[0][0].toUpperCase();
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isPremium ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFD700), // Bright gold
                const Color(0xFFFFA500), // Orange gold
                const Color(0xFFFFD700), // Bright gold
                const Color(0xFFDAA520), // Darker gold
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ) : null,
            border: isPremium ? null : Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
          padding: EdgeInsets.all(isPremium ? 2 : 1),
          child: isPremium
            ? Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white, // White layer untuk spacing
                ),
                padding: const EdgeInsets.all(2), // Spacing antara gold dan avatar
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: _buildAvatarContent(profileImageUrl, userName, isPremium, getInitials),
                  ),
                ),
              )
            : Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white, // Same as appbar background
                ),
                child: ClipOval(
                  child: _buildAvatarContent(profileImageUrl, userName, isPremium, getInitials),
                ),
              ),
        ),
        // Premium crown icon
        if (isPremium)
          Positioned(
            right: -1,
            top: -3,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFD700), // Bright gold
                    Color(0xFFB8860B), // Darker gold
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.8,
                ),
              ),
              child: const Icon(
                Icons.diamond,
                size: 9,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarContent(String? profileImageUrl, String userName, bool isPremium, String Function(String) getInitials) {
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return Image.network(
        profileImageUrl,
        width: isPremium ? 32 : 38,
        height: isPremium ? 32 : 38,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialsAvatar(getInitials(userName), isPremium);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: isPremium ? 32 : 38,
            height: isPremium ? 32 : 38,
            color: AppTheme.primaryColor.withOpacity(0.1),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else {
      return _buildInitialsAvatar(getInitials(userName), isPremium);
    }
  }

  Widget _buildInitialsAvatar(String initials, [bool isPremium = false]) {
    // Generate gradient colors based on first letter for premium users
    List<Color> getGradientFromLetter(String letter) {
      final colors = [
        [const Color(0xFFE91E63), const Color(0xFFAD1457)], // Pink
        [const Color(0xFF9C27B0), const Color(0xFF6A1B9A)], // Purple
        [const Color(0xFF673AB7), const Color(0xFF4527A0)], // Deep Purple
        [const Color(0xFF3F51B5), const Color(0xFF283593)], // Indigo
        [const Color(0xFF2196F3), const Color(0xFF1565C0)], // Blue
        [const Color(0xFF03A9F4), const Color(0xFF0277BD)], // Light Blue
        [const Color(0xFF00BCD4), const Color(0xFF00838F)], // Cyan
        [const Color(0xFF009688), const Color(0xFF00695C)], // Teal
        [const Color(0xFF4CAF50), const Color(0xFF2E7D32)], // Green
        [const Color(0xFF8BC34A), const Color(0xFF558B2F)], // Light Green
        [const Color(0xFFCDDC39), const Color(0xFF9E9D24)], // Lime
        [const Color(0xFFFFEB3B), const Color(0xFFF9A825)], // Yellow
        [const Color(0xFFFFC107), const Color(0xFFFF8F00)], // Amber
        [const Color(0xFFFF9800), const Color(0xFFEF6C00)], // Orange
        [const Color(0xFFFF5722), const Color(0xFFD84315)], // Deep Orange
        [const Color(0xFF795548), const Color(0xFF5D4037)], // Brown
      ];

      final index = letter.codeUnitAt(0) % colors.length;
      return colors[index];
    }

    return Container(
      width: isPremium ? 32 : 38,
      height: isPremium ? 32 : 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPremium ? null : null,
        gradient: isPremium
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: getGradientFromLetter(initials.isNotEmpty ? initials[0] : 'A'),
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
              ],
            ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white, // Both premium and non-premium use white text
            fontSize: isPremium ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getArabicTextForCategory(String categoryName) {
    final category = categoryName.toLowerCase().trim();

    if (category.contains('fiqh')) {
      return 'الفقه';
    } else if (category.contains('akidah')) {
      return 'العقيدة';
    } else if (category.contains('quran & tafsir')) {
      return 'القران و التفسير';
    } else if (category.contains('hadith')) {
      return 'الحديث';
    } else if (category.contains('sirah')) {
      return 'السيرة';
    } else if (category.contains('akhlak & tasawuf')) {
      return 'التصوف';
    } else if (category.contains('usul fiqh')) {
      return 'أصول الفقه';
    } else if (category.contains('bahasa arab')) {
      return 'لغة العربية';
    } else {
      return 'كتاب';
    }
  }
}
