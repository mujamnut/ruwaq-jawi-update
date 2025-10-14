import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ruwaq_jawi/core/theme/app_theme.dart';

import '../../../core/providers/kitab_provider.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/services/popup_service.dart';
import '../widgets/student_bottom_nav.dart';

// Import managers
import 'student_home_screen/managers/home_animation_manager.dart';
import 'student_home_screen/managers/home_scroll_manager.dart';

// Import widgets
import 'student_home_screen/widgets/home_header_widget.dart';
import 'student_home_screen/widgets/featured_section_widget.dart';
import 'student_home_screen/widgets/categories_section_widget.dart';
import 'student_home_screen/widgets/recent_section_widget.dart';
import 'student_home_screen/widgets/continue_reading_section_widget.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with TickerProviderStateMixin {
  late PageController _featuredScrollController;
  late HomeAnimationManager _animationManager;
  late HomeScrollManager _scrollManager;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _featuredScrollController = PageController(viewportFraction: 1.0);

    // Initialize managers
    _animationManager = HomeAnimationManager();
    _animationManager.initialize(this);

    _scrollManager = HomeScrollManager(
      featuredScrollController: _featuredScrollController,
      progressAnimationController: _animationManager.progressAnimationController,
      onStateChanged: () => setState(() {}),
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
      _scrollManager.startAutoScroll();
    });
  }

  void _checkSubscriptionPromo() {
    PopupService.checkAndShowSubscriptionPromo(context);
  }

  @override
  void dispose() {
    _scrollManager.dispose();
    _featuredScrollController.dispose();
    _animationManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with greeting and search
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: HomeHeaderWidget(),
            ),

            const SizedBox(height: 32),

            // Featured content section
            FeaturedSectionWidget(
              scrollManager: _scrollManager,
              progressAnimationController: _animationManager.progressAnimationController,
              onTotalCardsChanged: (count) {
                _scrollManager.totalCards = count;
              },
            ),

            const SizedBox(height: 32),

            // Categories section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: CategoriesSectionWidget(),
            ),

            const SizedBox(height: 32),

            // Recent content section
            const RecentSectionWidget(),

            const SizedBox(height: 32),

            // Continue reading section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: ContinueReadingSectionWidget(),
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: const StudentBottomNav(currentIndex: 0),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }
}
