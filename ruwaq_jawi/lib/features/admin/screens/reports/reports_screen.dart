import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic> _reportData = {};
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      final profile = await SupabaseService.from(
        'profiles',
      ).select('role').eq('id', user.id).maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        if (mounted) {
          context.go('/home');
        }
        return;
      }

      _loadReportData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Akses ditolak. Anda tidak mempunyai kebenaran admin.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReportData() async {
    try {
      setState(() {
        _error = null;
        _isLoading = true;
      });

      // Get current date ranges
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);
      final lastMonth = DateTime(now.year, now.month - 1, 1);

      // Parallel queries for better performance
      final results = await Future.wait<dynamic>([
        // Total counts
        SupabaseService.from(
          'profiles',
        ).select('id').then((data) => (data as List).length),
        SupabaseService.from(
          'ebooks',
        ).select('id').then((data) => (data as List).length),
        SupabaseService.from(
          'video_kitab',
        ).select('id').then((data) => (data as List).length),
        SupabaseService.from(
          'categories',
        ).select('id').then((data) => (data as List).length),

        // Active subscriptions
        SupabaseService.from('user_subscriptions')
            .select('user_id')
            .eq('status', 'active')
            .gt('end_date', now.toUtc().toIso8601String())
            .then((data) => (data as List).length),

        // This month new users
        SupabaseService.from('profiles')
            .select('id')
            .gte('created_at', thisMonth.toIso8601String())
            .then((data) => (data as List).length),

        // Last month new users
        SupabaseService.from('profiles')
            .select('id')
            .gte('created_at', lastMonth.toIso8601String())
            .lt('created_at', thisMonth.toIso8601String())
            .then((data) => (data as List).length),

        // This month payments
        SupabaseService.from('payments')
            .select('amount_cents')
            .eq('status', 'succeeded')
            .gte('created_at', thisMonth.toIso8601String())
            .then((data) => data as List),

        // Total revenue (all time)
        SupabaseService.from('payments')
            .select('amount_cents')
            .eq('status', 'succeeded')
            .then((data) => data as List),

        // Top categories by content count
        SupabaseService.client.rpc('get_category_content_counts'),

        // Recent content (last 30 days)
        SupabaseService.from('ebooks')
            .select('title, created_at')
            .gte(
              'created_at',
              DateTime.now()
                  .subtract(const Duration(days: 30))
                  .toIso8601String(),
            )
            .order('created_at', ascending: false)
            .limit(5)
            .then((ebookData) async {
              final videoData = await SupabaseService.from('video_kitab')
                  .select('title, created_at')
                  .gte(
                    'created_at',
                    DateTime.now()
                        .subtract(const Duration(days: 30))
                        .toIso8601String(),
                  )
                  .order('created_at', ascending: false)
                  .limit(5);

              List<Map<String, dynamic>> combined = [];
              for (var item in ebookData) {
                combined.add({...item, 'type': 'ebook'});
              }
              for (var item in videoData) {
                combined.add({...item, 'type': 'video_kitab'});
              }

              combined.sort(
                (a, b) => DateTime.parse(
                  b['created_at'],
                ).compareTo(DateTime.parse(a['created_at'])),
              );
              return combined.take(10).toList();
            }),
      ]);

      // Extract results
      final totalUsers = results[0] as int;
      final totalEbooks = results[1] as int;
      final totalVideoKitab = results[2] as int;
      final totalCategories = results[3] as int;
      final activeSubscriptions = results[4] as int;
      final thisMonthUsers = results[5] as int;
      final lastMonthUsers = results[6] as int;
      final thisMonthPayments = results[7] as List;
      final totalRevenue = results[8] as List;
      final topCategories = results[9];
      final recentContent = results[10] as List;

      // Calculate revenue
      final thisMonthRevenue = thisMonthPayments.fold<double>(
        0,
        (sum, payment) => sum + ((payment['amount_cents'] ?? 0) / 100),
      );
      final totalRevenueAmount = totalRevenue.fold<double>(
        0,
        (sum, payment) => sum + ((payment['amount_cents'] ?? 0) / 100),
      );

      // Calculate growth rates
      final userGrowthRate = lastMonthUsers > 0
          ? ((thisMonthUsers - lastMonthUsers) / lastMonthUsers * 100)
          : (thisMonthUsers > 0 ? 100.0 : 0.0);

      setState(() {
        _reportData = {
          'overview': {
            'totalUsers': totalUsers,
            'totalContent': totalEbooks + totalVideoKitab,
            'totalEbooks': totalEbooks,
            'totalVideoKitab': totalVideoKitab,
            'totalCategories': totalCategories,
            'activeSubscriptions': activeSubscriptions,
            'subscriptionRate': totalUsers > 0
                ? (activeSubscriptions / totalUsers * 100)
                : 0.0,
          },
          'growth': {
            'thisMonthUsers': thisMonthUsers,
            'lastMonthUsers': lastMonthUsers,
            'userGrowthRate': userGrowthRate,
            'thisMonthRevenue': thisMonthRevenue,
            'totalRevenue': totalRevenueAmount,
          },
          'content': {
            'topCategories': topCategories ?? [],
            'recentContent': recentContent,
            'contentBreakdown': {
              'ebooks': totalEbooks,
              'videoKitab': totalVideoKitab,
            },
          },
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuatkan data laporan: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppTheme.textPrimaryColor,
            size: 24.0,
          ),
          onPressed: () => context.go('/admin'),
        ),
        title: const Text(
          'Laporan Sistem',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              color: AppTheme.textPrimaryColor,
              size: 24.0,
            ),
            onPressed: _loadReportData,
            tooltip: 'Muat Semula',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedAnalytics01,
                color: Colors.white,
                size: 20.0,
              ),
              text: 'Ringkasan',
            ),
            Tab(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowUp01,
                color: Colors.white,
                size: 20.0,
              ),
              text: 'Pertumbuhan',
            ),
            Tab(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedBook02,
                color: Colors.white,
                size: 20.0,
              ),
              text: 'Kandungan',
            ),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
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
            Text('Memuatkan laporan...'),
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
              'Ralat Memuat Laporan',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              onPressed: _loadReportData,
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [_buildOverviewTab(), _buildGrowthTab(), _buildContentTab()],
    );
  }

  Widget _buildOverviewTab() {
    final overview = _reportData['overview'] ?? {};

    return RefreshIndicator(
      onRefresh: _loadReportData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    AppTheme.primaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedAnalytics01,
                      color: AppTheme.primaryColor,
                      size: 24.0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ringkasan Sistem',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Statistik keseluruhan platform Ruwaq Jawi',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  'Jumlah Pengguna',
                  '${overview['totalUsers'] ?? 0}',
                  HugeIcons.strokeRoundedUserMultiple,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Jumlah Kandungan',
                  '${overview['totalContent'] ?? 0}',
                  HugeIcons.strokeRoundedLibrary,
                  Colors.green,
                ),
                _buildStatCard(
                  'Kategori Aktif',
                  '${overview['totalCategories'] ?? 0}',
                  HugeIcons.strokeRoundedGrid,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Pengguna Premium',
                  '${overview['activeSubscriptions'] ?? 0}',
                  HugeIcons.strokeRoundedStar,
                  Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Subscription Rate
            _buildInfoCard(
              'Kadar Langganan Premium',
              '${(overview['subscriptionRate'] ?? 0.0).toStringAsFixed(1)}%',
              'Peratusan pengguna yang melanggan premium',
              HugeIcons.strokeRoundedPercentCircle,
              Colors.indigo,
            ),

            const SizedBox(height: 16),

            // Content Breakdown
            _buildContentBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthTab() {
    final growth = _reportData['growth'] ?? {};

    return RefreshIndicator(
      onRefresh: _loadReportData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.withValues(alpha: 0.1),
                    Colors.green.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowUp01,
                      color: Colors.green,
                      size: 24.0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analisis Pertumbuhan',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trend dan pertumbuhan platform bulan ini',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Growth Stats
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildGrowthCard(
                  'Pengguna Baru (Bulan Ini)',
                  '${growth['thisMonthUsers'] ?? 0}',
                  '${(growth['userGrowthRate'] ?? 0.0).toStringAsFixed(1)}%',
                  HugeIcons.strokeRoundedUserAdd02,
                  Colors.blue,
                  (growth['userGrowthRate'] ?? 0.0) >= 0,
                ),
                _buildStatCard(
                  'Pengguna Baru (Bulan Lalu)',
                  '${growth['lastMonthUsers'] ?? 0}',
                  HugeIcons.strokeRoundedUserMultiple,
                  Colors.grey,
                ),
                _buildRevenueCard(
                  'Pendapatan (Bulan Ini)',
                  'RM ${(growth['thisMonthRevenue'] ?? 0.0).toStringAsFixed(2)}',
                  HugeIcons.strokeRoundedDollar01,
                  Colors.green,
                ),
                _buildRevenueCard(
                  'Jumlah Pendapatan',
                  'RM ${(growth['totalRevenue'] ?? 0.0).toStringAsFixed(2)}',
                  HugeIcons.strokeRoundedMoneyBag02,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTab() {
    final content = _reportData['content'] ?? {};
    final recentContent = content['recentContent'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _loadReportData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.withValues(alpha: 0.1),
                    Colors.orange.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedBook02,
                      color: Colors.orange,
                      size: 24.0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analisis Kandungan',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Statistik dan trend kandungan platform',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recent Content
            const Text(
              'Kandungan Terkini (30 Hari)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (recentContent.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Tiada kandungan baharu dalam 30 hari terakhir',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentContent.length,
                itemBuilder: (context, index) {
                  final item = recentContent[index];
                  return _buildContentItem(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HugeIcon(icon: icon, color: color, size: 20.0),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthCard(
    String title,
    String value,
    String percentage,
    IconData icon,
    Color color,
    bool isPositive,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HugeIcon(icon: icon, color: color, size: 20.0),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: isPositive
                            ? HugeIcons.strokeRoundedArrowUp01
                            : HugeIcons.strokeRoundedArrowDown01,
                        size: 12.0,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        percentage,
                        style: TextStyle(
                          fontSize: 12,
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HugeIcon(icon: icon, color: color, size: 20.0),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(icon: icon, color: color, size: 24.0),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentBreakdown() {
    final overview = _reportData['overview'] ?? {};
    final totalEbooks = overview['totalEbooks'] ?? 0;
    final totalVideoKitab = overview['totalVideoKitab'] ?? 0;
    final total = totalEbooks + totalVideoKitab;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedChart,
                color: AppTheme.primaryColor,
                size: 20.0,
              ),
              const SizedBox(width: 8),
              Text(
                'Pecahan Kandungan',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildBreakdownItem(
                  'E-books',
                  totalEbooks,
                  total > 0 ? (totalEbooks / total * 100) : 0,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBreakdownItem(
                  'Video Kitab',
                  totalVideoKitab,
                  total > 0 ? (totalVideoKitab / total * 100) : 0,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
    String title,
    int count,
    double percentage,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$count item',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildContentItem(Map<String, dynamic> item) {
    final isEbook = item['type'] == 'ebook';
    final createdAt = DateTime.parse(item['created_at']);
    final timeAgo = _formatTimeAgo(createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEbook
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: isEbook
                  ? HugeIcons.strokeRoundedBook02
                  : HugeIcons.strokeRoundedVideo01,
              color: isEbook ? Colors.blue : Colors.green,
              size: 20.0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? 'Tanpa Tajuk',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isEbook
                            ? Colors.blue.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isEbook
                              ? Colors.blue.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Text(
                        isEbook ? 'E-book' : 'Video Kitab',
                        style: TextStyle(
                          fontSize: 11,
                          color: isEbook
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
