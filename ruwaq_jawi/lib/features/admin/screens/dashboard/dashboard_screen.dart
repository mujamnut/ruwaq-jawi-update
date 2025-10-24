import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../widgets/admin_bottom_nav.dart';
import 'managers/admin_dashboard_animation_manager.dart';
import 'managers/admin_dashboard_data_manager.dart';
import 'managers/admin_dashboard_scroll_manager.dart';
import 'managers/admin_notification_manager.dart';
import 'widgets/admin_dashboard_app_bar.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/recent_activity_section.dart';
import 'widgets/stats_grid.dart';
import 'widgets/welcome_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  final AdminDashboardDataManager _dataManager = AdminDashboardDataManager();
  final AdminNotificationManager _notificationManager = AdminNotificationManager();
  late final AdminDashboardAnimationManager _animationManager;
  late final AdminDashboardScrollManager _scrollManager;
  late final ScrollController _scrollController;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animationManager = AdminDashboardAnimationManager()..initialize(this);
    _scrollManager = AdminDashboardScrollManager(animationManager: _animationManager);
    _scrollController = ScrollController()..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminAccessAndLoad();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _animationManager.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccessAndLoad() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    final isAdmin = await _dataManager.isCurrentUserAdmin();
    if (!mounted) return;

    if (!isAdmin) {
      context.go('/home');
      return;
    }

    await _loadCachedData();
    await _loadDashboardData();
  }

  Future<void> _loadCachedData() async {
    final cachedData = await _dataManager.loadCachedData();
    if (!mounted || cachedData == null) {
      return;
    }

    setState(() {
      _stats = cachedData.stats;
      _recentActivities = cachedData.recentActivities;
      _isLoading = false;
    });
  }

  Future<void> _loadDashboardData() async {
    try {
      if (mounted) {
        setState(() {
          _error = null;
        });
      }

      final data = await _dataManager.fetchDashboardData();
      await _dataManager.cacheData(data);

      if (!mounted) {
        return;
      }

      setState(() {
        _stats = data.stats;
        _recentActivities = data.recentActivities;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Gagal memuatkan data dashboard: $e';
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    _scrollManager.handleScroll(_scrollController.offset);
  }

  Future<void> _showNotifications() async {
    // Navigate to notification inbox page
    context.go('/admin/notifications/inbox');
  }

  Future<void> _navigateToAddCategory() async {
    final result = await context.push('/admin/categories/add');
    if (result != null) {
      await _loadDashboardData();
    }
  }

  Future<void> _navigateToAddKitab() async {
    final result = await context.push('/admin/kitabs/add');
    if (result != null) {
      await _loadDashboardData();
    }
  }


  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuatkan data dashboard...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 64.0,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Ralat Dashboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ShadButton(
              onPressed: _loadDashboardData,
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      );
    }

    // Fallback content if data is empty
    if (_stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedHome02,
              size: 64.0,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Dashboard Kosong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tiada data untuk dipaparkan',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ShadButton(
              onPressed: _loadDashboardData,
              child: const Text('Muat Semula'),
            ),
          ],
        ),
      );
    }

    // Compute dynamic top padding so content never sits under the AppBar
    final double statusBar = MediaQuery.of(context).padding.top;
    final double visibleAppBar = (1.0 - _animationManager.appBarAnimation.value) * kToolbarHeight;
    // Tighten the top padding while still staying below status/app bar
    final double topPadding = 8 + statusBar + visibleAppBar;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminDashboardWelcomeCard(),
            const SizedBox(height: 6),
            AdminDashboardStatsGrid(stats: _stats),
            const SizedBox(height: 12),
            AdminDashboardQuickActions(
              onAddCategory: _navigateToAddCategory,
              onAddKitab: _navigateToAddKitab,
              onManageUsers: () => context.go('/admin/users'),
              onReports: () => context.go('/admin/reports'),
              onNotifications: () => context.go('/admin/notifications'),
              onManageCategories: () => context.go('/admin/categories'),
            ),
            const SizedBox(height: 16),
            AdminDashboardRecentActivitySection(recentActivities: _recentActivities),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.backgroundColor,
      appBar: AdminDashboardAppBar(
        animationManager: _animationManager,
        notificationCountFuture: _notificationManager.getNotificationCount,
        onNotificationTap: _showNotifications,
        onProfileTap: () => context.go('/admin/profile'),
      ),
      body: AnimatedBuilder(
        animation: _animationManager.appBarAnimation,
        builder: (context, _) {
          return OfflineBanner(child: _buildBody());
        },
      ),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 0),
    );
  }
}
