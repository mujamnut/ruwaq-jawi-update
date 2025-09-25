import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/popup_service.dart';
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
    _featuredScrollController = PageController(viewportFraction: 1.0);
    _progressAnimationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kitabProvider = context.read<KitabProvider>();
      final connectivityProvider = context.read<ConnectivityProvider>();

      // Only initialize if we have internet connection
      if (connectivityProvider.isOnline) {
        if (kitabProvider.videoKitabList.isEmpty &&
            kitabProvider.ebookList.isEmpty) {
          kitabProvider.initialize();
        }
        // Load notifications inbox for signed-in users
        context.read<NotificationsProvider>().loadInbox();
      }

      // Check and show subscription promo popup if criteria met
      _checkSubscriptionPromo();

      // Start auto-scroll after content loads
      _startAutoScroll();
    });
  }

  void _checkSubscriptionPromo() {
    // Check and show subscription promo popup
    PopupService.checkAndShowSubscriptionPromo(context);
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
      backgroundColor: Colors.white, // Putih bersih untuk background
      appBar: _buildAppBar(), // Add transparent app bar
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // Smooth scrolling
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with greeting and search
            Padding(
              padding: const EdgeInsets.all(
                20.0,
              ), // Increased padding for better spacing
              child: _buildHeader(),
            ),

            const SizedBox(height: 32), // Increased spacing
            // Featured content section
            _buildFeaturedSection(),

            const SizedBox(height: 32),

            // Categories section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildCategoriesSection(),
            ),

            const SizedBox(height: 32),

            // Recent content section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildRecentSection(),
            ),

            const SizedBox(height: 32),

            // Continue reading section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildContinueReadingSection(),
            ),

            // Add bottom padding to prevent overflow with bottom navigation
            const SizedBox(height: 120), // Increased bottom padding
          ],
        ),
      ),
      bottomNavigationBar: const StudentBottomNav(currentIndex: 0),
    );
  }

  // Build transparent app bar with phosphor icons
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 0, // Hide default app bar since we have custom header
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
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
                            final provider = context
                                .read<NotificationsProvider>();
                            await provider.loadInbox();

                            // Auto mark all unread notifications as read when user opens notification
                            final user =
                                Supabase.instance.client.auth.currentUser;
                            if (user != null) {
                              final unreadNotifications = provider.inbox
                                  .where((n) => !n.isReadByUser(user.id))
                                  .toList();
                              for (final notification in unreadNotifications) {
                                await provider.markAsRead(notification.id);
                              }
                            }

                            if (!mounted) return;
                            // Show enhanced notification bottom sheet
                            _showNotificationBottomSheet();
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
                                    color: const Color(
                                      0xFFFF3B30,
                                    ), // Pure red, no border
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
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

            // Search bar - Enhanced design
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () {
                  context.push('/search');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor, // Use theme surface color
                    borderRadius: BorderRadius.circular(
                      16,
                    ), // Larger rounded corners
                    border: Border.all(color: AppTheme.borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.magnifyingGlass(),
                        color: AppTheme.textSecondaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Cari kitab, video, atau topik...',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 15,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.borderColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PhosphorIcon(
                              PhosphorIcons.magnifyingGlass(),
                              color: AppTheme.textSecondaryColor,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Cari',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedSection() {
    return Consumer2<KitabProvider, ConnectivityProvider>(
      builder: (context, kitabProvider, connectivityProvider, child) {
        // Show loading state
        if (kitabProvider.isLoading) {
          return Container(
            height: 220,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 100,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (context, index) => Container(
                      width: 300,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Show error state when offline or has error
        if (connectivityProvider.isOffline || kitabProvider.errorMessage != null) {
          return Container(
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  connectivityProvider.isOffline
                    ? Icons.cloud_off_outlined
                    : Icons.error_outline,
                  color: AppTheme.textSecondaryColor,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  connectivityProvider.isOffline
                    ? 'Tiada sambungan internet'
                    : kitabProvider.errorMessage ?? 'Tidak dapat memuat kandungan',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Show only premium video kitab for featured section
        final featuredContent = kitabProvider.premiumVideoKitab.take(5).toList();

        if (featuredContent.isEmpty) {
          return const SizedBox.shrink();
        }

        // Update total cards count for auto-scroll
        _totalCards = featuredContent.length;

        return Container(
          color: Colors.white, // Pastikan background putih bersih
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.star(PhosphorIconsStyle.fill),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Pilihan Utama',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 200,
                  maxHeight: 240,
                ),
                child: PageView.builder(
                  controller: _featuredScrollController,
                  padEnds: false,
                  clipBehavior: Clip.none,
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
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildFeaturedCard(content),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Dots indicator with progress animation
              _buildDotsIndicator(),
            ],
          ),
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
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Opacity(
              opacity: value,
              child: Container(
                height: 280, // Fixed height for proper thumbnail display
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    24,
                  ), // xl-2xl radius for modern feel
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.surfaceColor,
                      AppTheme.surfaceColor,
                      AppTheme.backgroundColor,
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
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
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.push(route),
                    child: Stack(
                      children: [
                        // Thumbnail background
                        if (content.thumbnailUrl != null && content.thumbnailUrl!.isNotEmpty)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.network(
                                content.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppTheme.surfaceColor,
                                          AppTheme.backgroundColor,
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        // Dark overlay for better text readability
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Premium crown badge
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  PhosphorIcons.crown(PhosphorIconsStyle.fill),
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Spacer(),
                              // Title only, positioned lower to show more thumbnail
                              Text(
                                content.title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      height: 1.2,
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(0, 1),
                                          blurRadius: 3,
                                          color: Colors.black.withValues(alpha: 0.8),
                                        ),
                                      ],
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.folders(),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Kategori',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton.icon(
                    onPressed: () => context.go('/kitab'),
                    icon: PhosphorIcon(
                      PhosphorIcons.arrowRight(),
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    label: Text(
                      'Lihat Semua',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      16,
                    ), // Increased border radius
                    onTap: () => context.push(
                      '/kitab?category=${Uri.encodeComponent(category.name)}',
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // xl radius for cards
                        border: Border.all(
                          color: AppTheme.borderColor,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Top section with Arabic text
                          Expanded(
                            flex: 2,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppTheme.primaryColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    AppTheme.primaryColor.withValues(
                                      alpha: 0.06,
                                    ),
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _getArabicTextForCategory(category.name),
                                  style: const TextStyle(
                                    fontFamily: 'ArefRuqaa',
                                    fontSize:
                                        32, // Slightly smaller for better fit
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
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      category.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimaryColor,
                                            fontSize: 12,
                                            height: 1.2,
                                          ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.backgroundColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$totalCount item',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondaryColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
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
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.clockCounterClockwise(),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Terbaru',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton.icon(
                    onPressed: () => context.go('/kitab?sort=newest'),
                    icon: PhosphorIcon(
                      PhosphorIcons.arrowRight(),
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    label: Text(
                      'Lihat Semua',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 220, maxHeight: 260),
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
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16), // xl radius for cards
        onTap: () => context.push(route),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16), // xl radius for cards
            border: Border.all(color: AppTheme.borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
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
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16), // Match card radius
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
                            top: Radius.circular(16), // Match card radius
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
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
            // Handle loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            // Handle error state
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tidak dapat memuat bacaan tersimpan',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Handle empty data
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
                    const SizedBox(width: 12),
                    Text(
                      'Sambung Bacaan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      20,
                    ), // 2xl radius for enhanced cards
                    onTap: () => context.push('/kitab/${kitab.id}'),
                    child: Container(
                      padding: const EdgeInsets.all(20), // Increased padding
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(20), // 2xl radius
                        border: Border.all(
                          color: AppTheme.borderColor,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.15),
                                  AppTheme.primaryColor.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                16,
                              ), // Larger radius
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.2,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: PhosphorIcon(
                                PhosphorIcons.bookOpen(PhosphorIconsStyle.fill),
                                color: AppTheme.primaryColor,
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
                            size: 20,
                          ),
                        ],
                      ),
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
    final isPremium = authProvider
        .hasActiveSubscription; // Check if user has active subscription

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
            gradient: isPremium
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFD700), // Bright gold
                      const Color(0xFFFFA500), // Orange gold
                      const Color(0xFFFFD700), // Bright gold
                      const Color(0xFFDAA520), // Darker gold
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  )
                : null,
            border: isPremium
                ? null
                : Border.all(color: Colors.white, width: 2),
          ),
          padding: EdgeInsets.all(isPremium ? 2 : 1),
          child: isPremium
              ? Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white, // White layer untuk spacing
                  ),
                  padding: const EdgeInsets.all(
                    2,
                  ), // Spacing antara gold dan avatar
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: _buildAvatarContent(
                        profileImageUrl,
                        userName,
                        isPremium,
                        getInitials,
                      ),
                    ),
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white, // Same as appbar background
                  ),
                  child: ClipOval(
                    child: _buildAvatarContent(
                      profileImageUrl,
                      userName,
                      isPremium,
                      getInitials,
                    ),
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
                border: Border.all(color: Colors.white, width: 1.8),
              ),
              child: const Icon(Icons.diamond, size: 9, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarContent(
    String? profileImageUrl,
    String userName,
    bool isPremium,
    String Function(String) getInitials,
  ) {
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
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                colors: getGradientFromLetter(
                  initials.isNotEmpty ? initials[0] : 'A',
                ),
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
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

  // Enhanced notification bottom sheet with modern design
  void _showNotificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
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
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIcons.bell(PhosphorIconsStyle.fill),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifikasi',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            Consumer<NotificationsProvider>(
                              builder: (context, provider, child) {
                                final unreadCount = provider.inbox
                                    .where((n) => n.readAt == null)
                                    .length;
                                return Text(
                                  unreadCount > 0
                                      ? '$unreadCount notifikasi belum dibaca'
                                      : 'Semua notifikasi sudah dibaca',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Mark all as read button
                      Consumer<NotificationsProvider>(
                        builder: (context, provider, child) {
                          final hasUnread = provider.inbox.any(
                            (n) => n.readAt == null,
                          );
                          if (!hasUnread) return const SizedBox.shrink();

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                for (final notification in provider.inbox) {
                                  if (notification.readAt == null) {
                                    await provider.markAsRead(notification.id);
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Tandai semua',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Consumer<NotificationsProvider>(
                    builder: (context, provider, child) {
                      final notifications = provider.inbox;

                      if (notifications.isEmpty) {
                        return _buildEmptyNotificationState();
                      }

                      return TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 400),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  20,
                                ),
                                itemCount: notifications.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _buildNotificationCard(
                                    notifications[index],
                                    index,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyNotificationState() {
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
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
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
                          icon: HugeIcons.strokeRoundedNotification02,
                          color: AppTheme.primaryColor,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Tiada Notifikasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Semua notifikasi akan muncul di sini',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildNotificationCard(dynamic notification, int index) {
    final isUnread = notification.readAt == null;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: isUnread
                    ? AppTheme.primaryColor.withValues(alpha: 0.05)
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUnread
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : AppTheme.borderColor,
                  width: isUnread ? 1.5 : 1,
                ),
                boxShadow: isUnread
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
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
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    if (isUnread) {
                      await context.read<NotificationsProvider>().markAsRead(
                        notification.id,
                      );
                    }
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icon container
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: isUnread
                                ? LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor,
                                      AppTheme.primaryColor.withValues(
                                        alpha: 0.8,
                                      ),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      AppTheme.textSecondaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      AppTheme.textSecondaryColor.withValues(
                                        alpha: 0.05,
                                      ),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isUnread
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withValues(
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
                              isUnread
                                  ? PhosphorIcons.envelope(
                                      PhosphorIconsStyle.fill,
                                    )
                                  : PhosphorIcons.envelopeOpen(
                                      PhosphorIconsStyle.fill,
                                    ),
                              color: isUnread
                                  ? Colors.white
                                  : AppTheme.textSecondaryColor,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notification.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isUnread
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: AppTheme.textPrimaryColor,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isUnread)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notification.body,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondaryColor,
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedClock01,
                                    color: AppTheme.textSecondaryColor,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatNotificationTime(
                                      notification.deliveredAt,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minit lalu';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
