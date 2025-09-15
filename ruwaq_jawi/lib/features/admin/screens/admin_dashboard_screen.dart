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
import '../widgets/admin_bottom_nav.dart';
import 'admin_notification_detail_screen.dart';

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

  void _showNotifications() async {
    // Fetch real notification data
    final recentContent = await _fetchRecentContent();
    final totalUsers = await _fetchTotalUsers();
    final notifications = await _buildNotificationsList(recentContent, totalUsers);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title and Read All button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifikasi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _markAllAsRead(notifications),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    color: AppTheme.primaryColor,
                    size: 16.0,
                  ),
                  label: Text(
                    'Baca Semua',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Aktiviti dan update terkini sistem',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            
            // Notification list
            Expanded(
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildEnhancedNotificationCard(notification),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecentContent() async {
    try {
      final response = await SupabaseService.from('ebooks')
          .select('id, title, author, created_at')
          .gte('created_at', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
          .order('created_at', ascending: false)
          .limit(2);
      
      final response2 = await SupabaseService.from('video_kitab')
          .select('id, title, author, created_at')
          .gte('created_at', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
          .order('created_at', ascending: false)
          .limit(2);
      
      List<Map<String, dynamic>> allContent = [];
      
      // Add ebooks with type
      for (var item in response) {
        allContent.add({
          ...item,
          'type': 'ebook',
          'formatted_time': _formatTimeAgo(DateTime.parse(item['created_at'])),
        });
      }
      
      // Add video kitab with type
      for (var item in response2) {
        allContent.add({
          ...item,
          'type': 'video_kitab',
          'formatted_time': _formatTimeAgo(DateTime.parse(item['created_at'])),
        });
      }
      
      // Sort by created_at
      allContent.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
      
      return allContent;
    } catch (e) {
      print('Error fetching recent content: $e');
      return [];
    }
  }

  Future<int> _fetchTotalUsers() async {
    try {
      final response = await SupabaseService.from('profiles')
          .select('id');
      return (response as List).length;
    } catch (e) {
      print('Error fetching total users: $e');
      return 0;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else {
      return '${difference.inDays} hari lalu';
    }
  }

  Future<int> _getNotificationCount() async {
    try {
      // Count recent content (ebooks + video kitab) from last 7 days
      final recentContent = await _fetchRecentContent();
      // Always show at least 2 (system notifications) + recent content count
      return 2 + recentContent.length;
    } catch (e) {
      print('Error getting notification count: $e');
      return 5; // Default fallback count
    }
  }

  Future<List<Map<String, dynamic>>> _buildNotificationsList(
    List<Map<String, dynamic>> recentContent,
    int totalUsers,
  ) async {
    List<Map<String, dynamic>> notifications = [];
    
    // Add content notifications
    for (var content in recentContent.take(3)) {
      notifications.add({
        'id': 'content_${content['id']}',
        'title': content['type'] == 'ebook' 
            ? 'E-book Baharu Ditambah'
            : 'Video Kitab Baharu Ditambah',
        'subtitle': '${content['type'] == 'ebook' ? 'E-book' : 'Video Kitab'} "${content['title']}" oleh ${content['author'] ?? 'Penulis'}',
        'fullDescription': 'Kandungan baharu telah ditambah ke sistem. ${content['type'] == 'ebook' ? 'E-book' : 'Video Kitab'} "${content['title']}" oleh ${content['author'] ?? 'Penulis'} kini tersedia untuk pengguna. Pastikan untuk semak kualiti kandungan dan tetapan yang bersesuaian.',
        'time': content['formatted_time'],
        'icon': content['type'] == 'ebook' 
            ? HugeIcons.strokeRoundedBook02
            : HugeIcons.strokeRoundedVideo01,
        'iconColor': const Color(0xFF00BF6D),
        'type': content['type'],
        'isRead': false, // Default to unread for demonstration
      });
    }
    
    // Add system notifications
    notifications.add({
      'id': 'user_stats',
      'title': 'Statistik Pengguna',
      'subtitle': 'Jumlah pengguna berdaftar: $totalUsers',
      'fullDescription': 'Sistem melaporkan bahawa terdapat $totalUsers pengguna yang berdaftar dalam platform. Ini termasuk admin dan pengguna biasa. Sila pantau pertumbuhan pengguna dan pastikan pengalaman pengguna yang optimum.',
      'time': 'Baru sahaja',
      'icon': HugeIcons.strokeRoundedUserMultiple,
      'iconColor': Colors.blue,
      'type': 'user_stats',
      'isRead': false,
    });
    
    notifications.add({
      'id': 'system_update',
      'title': 'Sistem Update',
      'subtitle': 'Sistem dashboard telah dikemas kini dengan notifikasi data sebenar',
      'fullDescription': 'Dashboard admin telah dikemas kini dengan sistem notifikasi yang lebih baik. Kini anda boleh melihat status baca/belum dibaca, menanda semua sebagai telah dibaca, dan melihat butiran penuh setiap notifikasi. Sistem kini menggunakan data sebenar dari pangkalan data.',
      'time': 'Baru sahaja',
      'icon': HugeIcons.strokeRoundedSystemUpdate02,
      'iconColor': Colors.orange,
      'type': 'system',
      'isRead': true, // This one is read by default
    });
    
    return notifications;
  }

  Widget _buildEnhancedNotificationCard(Map<String, dynamic> notification) {
    final bool isRead = notification['isRead'] ?? false;
    
    return GestureDetector(
      onTap: () => _openNotificationDetail(notification),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppTheme.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead 
                ? Colors.grey.shade200 
                : AppTheme.primaryColor.withValues(alpha: 0.2),
            width: isRead ? 1 : 2,
          ),
          boxShadow: [
            if (!isRead)
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Icon with indicator
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (notification['iconColor'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: HugeIcon(
                    icon: notification['icon'],
                    color: notification['iconColor'],
                    size: 24.0,
                  ),
                ),
                if (!isRead)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                      color: isRead ? Colors.black87 : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['subtitle'],
                    style: TextStyle(
                      fontSize: 14,
                      color: isRead ? Colors.grey[600] : Colors.grey[700],
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['time'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            
            // Chevron
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: Colors.grey.shade400,
              size: 16.0,
            ),
          ],
        ),
      ),
    );
  }

  void _openNotificationDetail(Map<String, dynamic> notification) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminNotificationDetailScreen(
          title: notification['title'],
          subtitle: notification['subtitle'],
          time: notification['time'],
          fullDescription: notification['fullDescription'],
          icon: notification['icon'],
          iconColor: notification['iconColor'],
          notificationType: notification['type'],
        ),
      ),
    ).then((_) {
      // Mark as read when returning from detail page
      _markAsRead(notification);
    });
  }

  void _markAsRead(Map<String, dynamic> notification) {
    // In a real app, this would update the database
    setState(() {
      notification['isRead'] = true;
    });
  }

  void _markAllAsRead(List<Map<String, dynamic>> notifications) {
    // In a real app, this would update the database
    setState(() {
      for (var notification in notifications) {
        notification['isRead'] = true;
      }
    });
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Semua notifikasi telah ditanda sebagai telah dibaca'),
        backgroundColor: AppTheme.primaryColor,
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
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF00BF6D),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BF6D).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AppBar(
                  backgroundColor: Colors.transparent,
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
                                      child: FutureBuilder<int>(
                                        future: _getNotificationCount(),
                                        builder: (context, snapshot) {
                                          final count = snapshot.data ?? 5;
                                          return Text(
                                            count.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          );
                                        },
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
              const Color(0xFF00BF6D),
              _navigateToAddCategory,
            ),
            _buildActionButton(
              'Tambah Kitab',
              HugeIcons.strokeRoundedLibrary,
              const Color(0xFF00BF6D),
              _navigateToAddKitab,
            ),
            _buildActionButton(
              'Urus Pengguna',
              HugeIcons.strokeRoundedUserSettings01,
              const Color(0xFF00BF6D),
              () => context.go('/admin/users'),
            ),
            _buildActionButton(
              'Laporan',
              HugeIcons.strokeRoundedAnalytics01,
              const Color(0xFF00BF6D),
              () => context.go('/admin/reports'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(icon: icon, color: color, size: 20.0),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
