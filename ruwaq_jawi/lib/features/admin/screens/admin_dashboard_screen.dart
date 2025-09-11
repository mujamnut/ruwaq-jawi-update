import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/screens/login_screen.dart';
import 'admin_users_screen.dart';
import 'admin_ebook_list_screen.dart';
import 'admin_category_form_screen.dart';
import 'admin_analytics_real_screen.dart';
import '../widgets/admin_bottom_nav.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;
  String? _error;
  
  // Scroll controller for responsive AppBar
  late ScrollController _scrollController;
  late AnimationController _appBarAnimationController;
  late AnimationController _titleAnimationController;
  late Animation<double> _appBarAnimation;
  late Animation<Offset> _titleSlideAnimation;
  
  bool _isScrollingDown = false;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    
    // Initialize scroll controller
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // Initialize animation controllers - start in visible state
    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: 0.0, // Start visible
    );
    
    _titleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
      value: 0.0, // Start visible
    );
    
    // Create animations
    _appBarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _appBarAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _titleSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0),
    ).animate(CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _loadFromCache();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _appBarAnimationController.dispose();
    _titleAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    final isScrollingDown = currentOffset > _lastScrollOffset;
    
    // Only trigger animation if there's significant scroll movement
    if ((currentOffset - _lastScrollOffset).abs() < 5) return;
    
    if (isScrollingDown && currentOffset > 100 && !_isScrollingDown) {
      // Scrolling down - hide AppBar and slide title left
      _isScrollingDown = true;
      _appBarAnimationController.forward();
      _titleAnimationController.forward();
    } else if (!isScrollingDown && _isScrollingDown) {
      // Scrolling up - show AppBar and center title
      _isScrollingDown = false;
      _appBarAnimationController.reverse();
      _titleAnimationController.reverse();
    }
    
    _lastScrollOffset = currentOffset;
  }

  void _showNotifications() {
    showShadSheet(
      context: context,
      builder: (context) => ShadSheet(
        title: const Text('Notifikasi'),
        description: const Text('Aktiviti dan update terkini sistem'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationCard(
              icon: HugeIcons.strokeRoundedCreditCard,
              iconColor: Colors.green,
              title: 'Pembayaran Baharu',
              subtitle: 'Pengguna telah membuat pembayaran premium',
              time: '2 minit lalu',
            ),
            const SizedBox(height: 12),
            _buildNotificationCard(
              icon: HugeIcons.strokeRoundedBook02,
              iconColor: AppTheme.primaryColor,
              title: 'Kitab Baharu Ditambah',
              subtitle: 'Kitab "Fiqh Muamalat" telah ditambah',
              time: '1 jam lalu',
            ),
            const SizedBox(height: 12),
            _buildNotificationCard(
              icon: HugeIcons.strokeRoundedUserAdd01,
              iconColor: Colors.blue,
              title: 'Pengguna Baharu',
              subtitle: '5 pengguna baharu mendaftar hari ini',
              time: '3 jam lalu',
            ),
            const SizedBox(height: 12),
            _buildNotificationCard(
              icon: HugeIcons.strokeRoundedSystemUpdate02,
              iconColor: Colors.orange,
              title: 'Sistem Update',
              subtitle: 'Sistem telah dikemas kini ke versi 2.1.0',
              time: '1 hari lalu',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(icon: icon, color: iconColor, size: 20.0),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Load cached data first for faster UI
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStats = prefs.getString('cached_dashboard_stats');
      final cachedActivities = prefs.getString('cached_recent_activities');
      
      if (cachedStats != null && cachedActivities != null) {
        setState(() {
          _stats = jsonDecode(cachedStats);
          _recentActivities = List<Map<String, dynamic>>.from(jsonDecode(cachedActivities));
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  // Cache data for faster loading next time
  Future<void> _cacheData(Map<String, dynamic> stats, List<Map<String, dynamic>> activities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_dashboard_stats', jsonEncode(stats));
      await prefs.setString('cached_recent_activities', jsonEncode(activities));
    } catch (e) {
      print('Error caching data: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _error = null;
      });

      // Load real stats from database
      final statsResult = await SupabaseService.client.rpc('get_dashboard_stats');
      
      final stats = {
        'totalUsers': statsResult['total_users'] ?? 0,
        'totalKitabs': (statsResult['total_ebooks'] ?? 0) + (statsResult['total_video_kitab'] ?? 0),
        'totalCategories': statsResult['total_categories'] ?? 0,
        'premiumUsers': statsResult['premium_users'] ?? 0,
      };

      // Load recent activities from database
      final activitiesResult = await SupabaseService.client
          .from('profiles')
          .select('full_name, created_at')
          .gte('created_at', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
          .order('created_at', ascending: false)
          .limit(3);

      final activities = activitiesResult.map((activity) {
        final createdAt = DateTime.parse(activity['created_at']);
        final now = DateTime.now();
        final difference = now.difference(createdAt);
        
        String timeAgo;
        if (difference.inMinutes < 60) {
          timeAgo = '${difference.inMinutes} minit lalu';
        } else if (difference.inHours < 24) {
          timeAgo = '${difference.inHours} jam lalu';
        } else {
          timeAgo = '${difference.inDays} hari lalu';
        }

        return {
          'title': 'Pengguna Baharu Mendaftar',
          'description': '${activity['full_name'] ?? 'Pengguna'} telah mendaftar sebagai pengguna baharu',
          'time': timeAgo,
        };
      }).toList();

      // Cache the data
      await _cacheData(stats, activities);

      setState(() {
        _stats = stats;
        _recentActivities = activities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuatkan data dashboard: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToAddCategory() async {
    final result = await context.push('/admin/categories/add');
    if (result != null) {
      // Refresh dashboard jika kategori berjaya ditambah
      _loadDashboardData();
    }
  }

  Future<void> _navigateToAddKitab() async {
    final result = await context.push('/admin/kitabs/add');
    if (result != null) {
      // Refresh dashboard jika kitab berjaya ditambah
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedBuilder(
          animation: _appBarAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -kToolbarHeight * _appBarAnimation.value),
              child: AppBar(
                title: AnimatedBuilder(
                  animation: _appBarAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 1.0 - _appBarAnimation.value,
                      child: SlideTransition(
                        position: _titleSlideAnimation,
                        child: const Text(
                          'Dashboard Admin',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textLightColor,
                elevation: 0,
                actions: [
                  // Hide icons when AppBar is hidden (in status bar area)
                  AnimatedBuilder(
                    animation: _appBarAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: 1.0 - _appBarAnimation.value,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Notification icon with badge
                            IconButton(
                              icon: Stack(
                                children: [
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedNotification03,
                                    color: Colors.white,
                                    size: 24.0,
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 12,
                                        minHeight: 12,
                                      ),
                                      child: const Text(
                                        '3',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: _showNotifications,
                              tooltip: 'Notifikasi',
                            ),
                            const SizedBox(width: 8),
                            // Avatar with border
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                return GestureDetector(
                                  onTap: () => context.go('/admin/profile'),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 16),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      radius: 18,
                                      child: authProvider.userProfile?.avatarUrl != null
                                          ? ClipOval(
                                              child: Image.network(
                                                authProvider.userProfile!.avatarUrl!,
                                                width: 36,
                                                height: 36,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const HugeIcon(
                                                  icon: HugeIcons.strokeRoundedUser,
                                                  color: Colors.white,
                                                  size: 20.0,
                                                ),
                                              ),
                                            )
                                          : const HugeIcon(
                                              icon: HugeIcons.strokeRoundedUser,
                                              color: Colors.white,
                                              size: 20.0,
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 0),
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
            const HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: 64.0, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Ralat Dashboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
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

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat Datang, Admin!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Urus kandungan dan pengguna aplikasi Ruwaq Jawi',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Jumlah Pengguna',
          '${_stats['totalUsers'] ?? 0}',
          HugeIcons.strokeRoundedUserMultiple,
          Colors.blue,
        ),
        _buildStatCard(
          'Jumlah Kitab',
          '${_stats['totalKitabs'] ?? 0}',
          HugeIcons.strokeRoundedBook02,
          Colors.green,
        ),
        _buildStatCard(
          'Kategori',
          '${_stats['totalCategories'] ?? 0}',
          HugeIcons.strokeRoundedGrid,
          Colors.orange,
        ),
        _buildStatCard(
          'Premium Users',
          '${_stats['premiumUsers'] ?? 0}',
          HugeIcons.strokeRoundedStar,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HugeIcon(icon: icon, color: color, size: 24.0),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tindakan Pantas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2,
          children: [
            _buildActionButton(
              'Tambah Kategori',
              HugeIcons.strokeRoundedPlusSignCircle,
              Colors.blue,
              _navigateToAddCategory,
            ),
            _buildActionButton(
              'Tambah Kitab',
              HugeIcons.strokeRoundedLibrary,
              Colors.green,
              _navigateToAddKitab,
            ),
            _buildActionButton(
              'Urus Pengguna',
              HugeIcons.strokeRoundedUserSettings01,
              Colors.orange,
              () => context.go('/admin/users'),
            ),
            _buildActionButton(
              'Laporan',
              HugeIcons.strokeRoundedAnalytics01,
              Colors.purple,
              () => context.go('/admin/reports'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return ShadButton(
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: color, size: 20.0),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aktiviti Terkini',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_recentActivities.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Tiada aktiviti terkini',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentActivities.length,
            itemBuilder: (context, index) {
              final activity = _recentActivities[index];
              return _buildActivityItem(activity);
            },
          ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedTime04,
              color: AppTheme.primaryColor,
              size: 20.0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'] ?? 'Aktiviti',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity['description'] ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  activity['time'] ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
