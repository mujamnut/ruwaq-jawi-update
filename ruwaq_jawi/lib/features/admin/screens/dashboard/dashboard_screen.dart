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
import 'widgets/notification_bottom_sheet.dart';
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
    final notifications = await _notificationManager.fetchNotifications();

    if (!mounted) return;

    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdminNotificationBottomSheet(
        notifications: notifications,
        onMarkAllAsRead: () async => await _markAllAsRead(notifications),
        onNotificationTap: (notification) async => await _openNotificationDetail(notification),
      ),
    );
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

  
  Future<void> _openNotificationDetail(Map<String, dynamic> notification) async {
    // Mark as read in background
    _markAsRead(notification);

    if (!mounted) return;

    // Close the notification list bottom sheet
    Navigator.pop(context);

    // Add small delay to ensure previous sheet is fully closed
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon and Title
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (notification['iconColor'] as Color).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: HugeIcon(
                                icon: notification['icon'] as IconData,
                                color: notification['iconColor'] as Color,
                                size: 48.0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              notification['title'] as String,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _getTypeLabel(notification['type'] as String),
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Details Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2A2A2A)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Maklumat Detail',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow('Ringkasan', notification['subtitle'] as String),
                            _buildDetailRow('Masa', notification['time'] as String),
                            _buildDetailRow(
                              'Jenis',
                              _getTypeLabel(notification['type'] as String),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              'Penerangan Penuh',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notification['fullDescription'] as String,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                    height: 1.6,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Close Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                            color: Colors.white,
                            size: 20.0,
                          ),
                          label: const Text('Tutup'),
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
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'ebook':
        return 'E-book Baharu';
      case 'video_kitab':
        return 'Video Kitab Baharu';
      case 'user_stats':
        return 'Statistik Pengguna';
      case 'system':
        return 'Sistem Update';
      case 'payment':
        return 'Pembayaran';
      default:
        return 'Lain-lain';
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    // Update database in background without setState
    // This prevents lifecycle errors when bottom sheet is closing
    _notificationManager.markAsRead(notification['id'] as String).catchError((e) {
      debugPrint('Error marking notification as read: $e');
    });
  }

  Future<void> _markAllAsRead(List<Map<String, dynamic>> notifications) async {
    // Update database in background
    await _notificationManager.markAllAsRead().catchError((e) {
      debugPrint('Error marking all notifications as read: $e');
      return;
    });

    if (!mounted) return;

    // Close the bottom sheet first
    Navigator.of(context).pop();

    // Then show snackbar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua notifikasi telah ditanda sebagai telah dibaca'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
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
