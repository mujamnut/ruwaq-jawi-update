import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_bottom_nav.dart';

class AdminAnalyticsRealScreen extends StatefulWidget {
  const AdminAnalyticsRealScreen({super.key});

  @override
  State<AdminAnalyticsRealScreen> createState() => _AdminAnalyticsRealScreenState();
}

class _AdminAnalyticsRealScreenState extends State<AdminAnalyticsRealScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _analytics = {};
  String selectedPeriod = '30 hari';
  final List<String> periods = ['7 hari', '30 hari', '90 hari', '1 tahun'];

  @override
  void initState() {
    super.initState();
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
      final profile = await SupabaseService.from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        if (mounted) {
          context.go('/home');
        }
        return;
      }

      _loadFromCache();
      _loadAnalytics();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Akses ditolak. Anda tidak mempunyai kebenaran admin.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAnalytics = prefs.getString('cached_admin_analytics');
      final cacheTimestamp = prefs.getInt('cached_admin_analytics_timestamp');

      if (cachedAnalytics != null && cacheTimestamp != null) {
        // Check if cache is still valid (less than 5 minutes old)
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        const fiveMinutes = 5 * 60 * 1000; // 5 minutes in milliseconds

        if (cacheAge < fiveMinutes) {
          final analyticsJson = jsonDecode(cachedAnalytics) as Map<String, dynamic>;
          
          setState(() {
            _analytics = analyticsJson;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading cached analytics: $e');
    }
  }

  Future<void> _cacheAnalytics(Map<String, dynamic> analytics) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analyticsJson = jsonEncode(analytics);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await prefs.setString('cached_admin_analytics', analyticsJson);
      await prefs.setInt('cached_admin_analytics_timestamp', timestamp);
    } catch (e) {
      print('Error caching analytics: $e');
    }
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() {
        _isLoading = _analytics.isEmpty;
        _error = null;
      });

      final analytics = await Future.wait([
        _getUserAnalytics(),
        _getContentAnalytics(),
        _getSubscriptionAnalytics(),
        _getRevenueAnalytics(),
        _getGrowthAnalytics(),
        _getPopularContent(),
      ]);

      final analyticsData = {
        'users': analytics[0],
        'content': analytics[1],
        'subscriptions': analytics[2],
        'revenue': analytics[3],
        'growth': analytics[4],
        'popular': analytics[5],
      };

      // Cache the analytics data
      await _cacheAnalytics(analyticsData);

      setState(() {
        _analytics = analyticsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ralat memuatkan data analisis: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getUserAnalytics() async {
    try {
      // Get total users
      final totalUsers = await SupabaseService.from('profiles')
          .select('id')
          .count(CountOption.exact);

      // Get users by role
      final adminUsers = await SupabaseService.from('profiles')
          .select('id')
          .eq('role', 'admin')
          .count(CountOption.exact);

      final studentUsers = await SupabaseService.from('profiles')
          .select('id')
          .eq('role', 'student')
          .count(CountOption.exact);

      // Get active subscribers
      final activeSubscribers = await SupabaseService.from('profiles')
          .select('id')
          .eq('subscription_status', 'active')
          .count(CountOption.exact);

      // Get recent registrations (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentUsers = await SupabaseService.from('profiles')
          .select('id')
          .gte('created_at', thirtyDaysAgo.toIso8601String())
          .count(CountOption.exact);

      return {
        'total': totalUsers.count,
        'admins': adminUsers.count,
        'students': studentUsers.count,
        'activeSubscribers': activeSubscribers.count,
        'recentRegistrations': recentUsers.count,
      };
    } catch (e) {
      return {
        'total': 0,
        'admins': 0,
        'students': 0,
        'activeSubscribers': 0,
        'recentRegistrations': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getContentAnalytics() async {
    try {
      // Get kitab stats
      final totalKitab = await SupabaseService.from('kitab')
          .select('id')
          .count(CountOption.exact);

      final activeKitab = await SupabaseService.from('kitab')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);

      final premiumKitab = await SupabaseService.from('kitab')
          .select('id')
          .eq('is_premium', true)
          .count(CountOption.exact);

      final ebookAvailable = await SupabaseService.from('kitab')
          .select('id')
          .eq('is_ebook_available', true)
          .count(CountOption.exact);

      // Get categories
      final totalCategories = await SupabaseService.from('categories')
          .select('id')
          .count(CountOption.exact);

      final activeCategories = await SupabaseService.from('categories')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);

      // Get videos
      final totalVideos = await SupabaseService.from('kitab_videos')
          .select('id')
          .count(CountOption.exact);

      final activeVideos = await SupabaseService.from('kitab_videos')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);

      return {
        'totalKitab': totalKitab.count,
        'activeKitab': activeKitab.count,
        'premiumKitab': premiumKitab.count,
        'ebookAvailable': ebookAvailable.count,
        'totalCategories': totalCategories.count,
        'activeCategories': activeCategories.count,
        'totalVideos': totalVideos.count,
        'activeVideos': activeVideos.count,
      };
    } catch (e) {
      return {
        'totalKitab': 0,
        'activeKitab': 0,
        'premiumKitab': 0,
        'ebookAvailable': 0,
        'totalCategories': 0,
        'activeCategories': 0,
        'totalVideos': 0,
        'activeVideos': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getSubscriptionAnalytics() async {
    try {
      final totalSubscriptionsData = await SupabaseService.from('user_subscriptions')
          .select('id');
      final totalSubscriptions = (totalSubscriptionsData as List).length;

      final activeSubscriptionsData = await SupabaseService.from('user_subscriptions')
          .select('id')
          .eq('status', 'active')
          .gt('end_date', DateTime.now().toUtc().toIso8601String());
      final activeSubscriptions = (activeSubscriptionsData as List).length;

      final expiredSubscriptionsData = await SupabaseService.from('user_subscriptions')
          .select('id')
          .eq('status', 'active')
          .lt('end_date', DateTime.now().toUtc().toIso8601String());
      final expiredSubscriptions = (expiredSubscriptionsData as List).length;

      final cancelledSubscriptionsData = await SupabaseService.from('user_subscriptions')
          .select('id')
          .eq('status', 'cancelled');
      final cancelledSubscriptions = (cancelledSubscriptionsData as List).length;

      // Get subscriptions by plan
      final subscriptionsByPlan = await SupabaseService.from('user_subscriptions')
          .select('''
            subscription_plan_id,
            subscription_plans!inner(name)
          ''')
          .eq('status', 'active')
          .gt('end_date', DateTime.now().toUtc().toIso8601String());

      final planDistribution = <String, int>{};
      for (final sub in subscriptionsByPlan) {
        final planName = sub['subscription_plans']['name'];
        planDistribution[planName] = (planDistribution[planName] ?? 0) + 1;
      }

      return {
        'total': totalSubscriptions,
        'active': activeSubscriptions,
        'expired': expiredSubscriptions,
        'cancelled': cancelledSubscriptions,
        'planDistribution': planDistribution,
      };
    } catch (e) {
      return {
        'total': 0,
        'active': 0,
        'expired': 0,
        'cancelled': 0,
        'planDistribution': <String, int>{},
      };
    }
  }

  Future<Map<String, dynamic>> _getRevenueAnalytics() async {
    try {
      // Get all successful transactions
      final transactions = await SupabaseService.from('transactions')
          .select('amount, created_at')
          .eq('status', 'completed');

      double totalRevenue = 0;
      for (final transaction in transactions) {
        totalRevenue += double.tryParse(transaction['amount'].toString()) ?? 0.0;
      }

      // Get revenue from subscription plans (not individual subscription amounts)
      final activeSubscriptions = await SupabaseService.from('user_subscriptions')
          .select('subscription_plans!inner(price)')
          .eq('status', 'active')
          .gt('end_date', DateTime.now().toUtc().toIso8601String());

      double monthlyRecurringRevenue = 0;
      for (final sub in activeSubscriptions) {
        monthlyRecurringRevenue += double.parse(sub['subscription_plans']['price'].toString());
      }

      // Calculate revenue by month (last 6 months)
      final monthlyRevenue = <String, double>{};
      final now = DateTime.now();
      
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);
        
        final monthTransactions = transactions.where((t) {
          final transactionDate = DateTime.parse(t['created_at']);
          return transactionDate.isAfter(month) && transactionDate.isBefore(nextMonth);
        });

        double monthTotal = 0;
        for (final transaction in monthTransactions) {
          monthTotal += double.tryParse(transaction['amount'].toString()) ?? 0.0;
        }
        
        final monthKey = '${month.month.toString().padLeft(2, '0')}/${month.year}';
        monthlyRevenue[monthKey] = monthTotal;
      }

      return {
        'totalRevenue': totalRevenue,
        'monthlyRecurringRevenue': monthlyRecurringRevenue,
        'monthlyRevenue': monthlyRevenue,
        'totalTransactions': transactions.length,
      };
    } catch (e) {
      return {
        'totalRevenue': 0.0,
        'monthlyRecurringRevenue': 0.0,
        'monthlyRevenue': <String, double>{},
        'totalTransactions': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getGrowthAnalytics() async {
    try {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      
      // User growth
      final currentMonthUsers = await SupabaseService.from('profiles')
          .select('id')
          .gte('created_at', currentMonthStart.toIso8601String())
          .count(CountOption.exact);

      final lastMonthUsers = await SupabaseService.from('profiles')
          .select('id')
          .gte('created_at', lastMonthStart.toIso8601String())
          .lt('created_at', currentMonthStart.toIso8601String())
          .count(CountOption.exact);

      // Subscription growth
      final currentMonthSubsData = await SupabaseService.from('user_subscriptions')
          .select('id')
          .gte('created_at', currentMonthStart.toIso8601String());
      final currentMonthSubs = (currentMonthSubsData as List).length;

      final lastMonthSubsData = await SupabaseService.from('user_subscriptions')
          .select('id')
          .gte('created_at', lastMonthStart.toIso8601String())
          .lt('created_at', currentMonthStart.toIso8601String());
      final lastMonthSubs = (lastMonthSubsData as List).length;

      // Calculate growth percentages
      double userGrowth = 0;
      if (lastMonthUsers.count > 0) {
        userGrowth = ((currentMonthUsers.count - lastMonthUsers.count) / lastMonthUsers.count * 100);
      } else if (currentMonthUsers.count > 0) {
        userGrowth = 100;
      }

      double subscriptionGrowth = 0;
      if (lastMonthSubs > 0) {
        subscriptionGrowth = ((currentMonthSubs - lastMonthSubs) / lastMonthSubs * 100);
      } else if (currentMonthSubs > 0) {
        subscriptionGrowth = 100;
      }

      return {
        'userGrowth': userGrowth,
        'subscriptionGrowth': subscriptionGrowth,
        'currentMonthUsers': currentMonthUsers.count,
        'lastMonthUsers': lastMonthUsers.count,
        'currentMonthSubs': currentMonthSubs,
        'lastMonthSubs': lastMonthSubs,
      };
    } catch (e) {
      return {
        'userGrowth': 0.0,
        'subscriptionGrowth': 0.0,
        'currentMonthUsers': 0,
        'lastMonthUsers': 0,
        'currentMonthSubs': 0,
        'lastMonthSubs': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _getPopularContent() async {
    try {
      // Get most saved kitab
      final popularKitab = await SupabaseService.from('saved_items')
          .select('''
            kitab_id,
            kitab!inner(title)
          ''')
          .eq('item_type', 'kitab');

      // Count kitab saves
      final kitabCounts = <String, int>{};
      final kitabTitles = <String, String>{};
      
      for (final item in popularKitab) {
        final kitabId = item['kitab_id'];
        final kitabTitle = item['kitab']['title'];
        kitabCounts[kitabId] = (kitabCounts[kitabId] ?? 0) + 1;
        kitabTitles[kitabId] = kitabTitle;
      }

      // Convert to list and sort
      final popularList = <Map<String, dynamic>>[];
      kitabCounts.forEach((id, count) {
        popularList.add({
          'title': kitabTitles[id] ?? 'Unknown',
          'saves': count,
          'type': 'kitab',
        });
      });

      popularList.sort((a, b) => (b['saves'] as int).compareTo(a['saves'] as int));
      
      return popularList.take(10).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Analisis Sebenar',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return GestureDetector(
                onTap: () => context.go('/admin/profile'),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    radius: 18,
                    child: authProvider.userProfile?.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              authProvider.userProfile!.avatarUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const HugeIcon(
                                  icon: HugeIcons.strokeRoundedUser,
                                  color: Colors.white,
                                  size: 20.0,
                                );
                              },
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
      body: _buildBody(),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 4),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: 64.0, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Ralat',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCards(),
            const SizedBox(height: 24),
            _buildUserAnalytics(),
            const SizedBox(height: 24),
            _buildContentAnalytics(),
            const SizedBox(height: 24),
            _buildSubscriptionChart(),
            const SizedBox(height: 24),
            _buildRevenueAnalytics(),
            const SizedBox(height: 24),
            _buildPopularContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final users = _analytics['users'] ?? {};
    final content = _analytics['content'] ?? {};
    final subscriptions = _analytics['subscriptions'] ?? {};
    final growth = _analytics['growth'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Data Sebenar',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
          childAspectRatio: 1.3,
          children: [
            _buildOverviewCard(
              'Jumlah Pengguna',
              users['total'].toString(),
              HugeIcons.strokeRoundedUserMultiple,
              Colors.blue,
              '${growth['userGrowth']?.toStringAsFixed(1) ?? '0'}%',
            ),
            _buildOverviewCard(
              'Langganan Aktif',
              subscriptions['active'].toString(),
              HugeIcons.strokeRoundedCreditCard,
              Colors.green,
              '${growth['subscriptionGrowth']?.toStringAsFixed(1) ?? '0'}%',
            ),
            _buildOverviewCard(
              'Jumlah Kitab',
              content['totalKitab'].toString(),
              HugeIcons.strokeRoundedBook02,
              AppTheme.primaryColor,
              '${content['activeKitab']} aktif',
            ),
            _buildOverviewCard(
              'Kategori',
              content['totalCategories'].toString(),
              HugeIcons.strokeRoundedGrid,
              Colors.purple,
              '${content['activeCategories']} aktif',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                HugeIcon(icon: icon, color: color, size: 24.0),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAnalytics() {
    final users = _analytics['users'] ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analisis Pengguna',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Pelajar',
                    users['students'].toString(),
                    HugeIcons.strokeRoundedSchool,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Admin',
                    users['admins'].toString(),
                    HugeIcons.strokeRoundedUserSettings01,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Pelanggan Aktif',
                    users['activeSubscribers'].toString(),
                    HugeIcons.strokeRoundedUserCheck01,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Baru (30 hari)',
                    users['recentRegistrations'].toString(),
                    HugeIcons.strokeRoundedNewReleases,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentAnalytics() {
    final content = _analytics['content'] ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analisis Kandungan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Video',
                    content['totalVideos'].toString(),
                    HugeIcons.strokeRoundedVideo01,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Video Aktif',
                    content['activeVideos'].toString(),
                    HugeIcons.strokeRoundedPlayCircle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Premium Kitab',
                    content['premiumKitab'].toString(),
                    HugeIcons.strokeRoundedStar,
                    Colors.amber,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'E-Book Tersedia',
                    content['ebookAvailable'].toString(),
                    HugeIcons.strokeRoundedBook02,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionChart() {
    final subscriptions = _analytics['subscriptions'] ?? {};
    final planDistribution = subscriptions['planDistribution'] ?? <String, int>{};
    
    if (planDistribution.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Taburan Pelan Langganan',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text('Tiada data langganan tersedia'),
            ],
          ),
        ),
      );
    }

    final colors = [Colors.purple, Colors.blue, Colors.green, Colors.orange, Colors.red];
    final List<PieChartSectionData> sections = planDistribution.entries.map<PieChartSectionData>((entry) {
      final index = planDistribution.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        color: colors[index % colors.length],
        radius: 60,
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Taburan Pelan Langganan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueAnalytics() {
    final revenue = _analytics['revenue'] ?? {};
    final monthlyRevenue = revenue['monthlyRevenue'] ?? <String, double>{};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Analisis Pendapatan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'RM ${revenue['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Transaksi',
                    revenue['totalTransactions'].toString(),
                    HugeIcons.strokeRoundedInvoice01,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Bulanan Berulang',
                    'RM ${revenue['monthlyRecurringRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                    HugeIcons.strokeRoundedRefresh,
                    Colors.green,
                  ),
                ),
              ],
            ),
            if (monthlyRevenue.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Pendapatan 6 Bulan Terakhir',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...monthlyRevenue.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text('RM ${entry.value.toStringAsFixed(2)}'),
                  ],
                ),
              )).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPopularContent() {
    final popular = _analytics['popular'] ?? <Map<String, dynamic>>[];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kandungan Popular (Berdasarkan Simpanan)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (popular.isEmpty)
              const Text('Tiada data kandungan popular')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: popular.length,
                itemBuilder: (context, index) {
                  final content = popular[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(content['title']),
                    subtitle: Text('${content['saves']} simpanan'),
                    trailing: HugeIcon(
                      icon: content['type'] == 'kitab' ? HugeIcons.strokeRoundedBook02 : HugeIcons.strokeRoundedVideo01,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          HugeIcon(icon: icon, color: color, size: 24.0),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
