import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';

class AdminAnalyticsRealScreen extends StatefulWidget {
  const AdminAnalyticsRealScreen({super.key});

  @override
  State<AdminAnalyticsRealScreen> createState() => _AdminAnalyticsRealScreenState();
}

class _AdminAnalyticsRealScreenState extends State<AdminAnalyticsRealScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _analytics = {};
  String selectedPeriod = '30 days';
  final List<String> periods = ['7 days', '30 days', '90 days', '1 year'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminAccess();
    });
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
          _error = 'Access denied. You do not have admin permission.';
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
      if (!mounted) return;
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

      if (!mounted) return;
      setState(() {
        _analytics = analyticsData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load analytics: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // (no helpers needed in original)

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
      final fromDate = DateTime.now().subtract(const Duration(days: 30));
      final recentUsers = await SupabaseService.from('profiles')
          .select('id')
          .gte('created_at', fromDate.toIso8601String())
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
      // Get video kitab stats
      final totalKitab = await SupabaseService.from('video_kitab')
          .select('id')
          .count(CountOption.exact);

      final activeKitab = await SupabaseService.from('video_kitab')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);

      final premiumKitab = await SupabaseService.from('video_kitab')
          .select('id')
          .eq('is_premium', true)
          .count(CountOption.exact);

      // Get ebooks stats
      final totalEbooks = await SupabaseService.from('ebooks')
          .select('id')
          .count(CountOption.exact);

      final activeEbooks = await SupabaseService.from('ebooks')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);

      // Get categories
      final totalCategories = await SupabaseService.from('categories')
          .select('id')
          .count(CountOption.exact);

      final activeCategories = await SupabaseService.from('categories')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);

      // Get video episodes
      final totalVideos = await SupabaseService.from('video_episodes')
          .select('id')
          .count(CountOption.exact);

      final activeVideos = await SupabaseService.from('video_episodes')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);

      return {
        'totalKitab': totalKitab.count,
        'activeKitab': activeKitab.count,
        'premiumKitab': premiumKitab.count,
        'totalEbooks': totalEbooks.count,
        'activeEbooks': activeEbooks.count,
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
        'totalEbooks': 0,
        'activeEbooks': 0,
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
      // Get all successful payments
      final payments = await SupabaseService.from('payments')
          .select('amount_cents, created_at')
          .eq('status', 'succeeded');

      double totalRevenue = 0;
      for (final payment in payments) {
        totalRevenue += (payment['amount_cents'] as int) / 100.0; // Convert cents to dollars
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

        final monthPayments = payments.where((p) {
          final paymentDate = DateTime.parse(p['created_at']);
          return paymentDate.isAfter(month) && paymentDate.isBefore(nextMonth);
        });

        double monthTotal = 0;
        for (final payment in monthPayments) {
          monthTotal += (payment['amount_cents'] as int) / 100.0;
        }

        final monthKey = '${month.month.toString().padLeft(2, '0')}/${month.year}';
        monthlyRevenue[monthKey] = monthTotal;
      }

      return {
        'totalRevenue': totalRevenue,
        'monthlyRecurringRevenue': monthlyRecurringRevenue,
        'monthlyRevenue': monthlyRevenue,
        'totalTransactions': payments.length,
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
      // Get most saved video kitab
      final popularVideoKitab = await SupabaseService.from('video_kitab_user_interactions')
          .select('''
            video_kitab_id,
            video_kitab!inner(title)
          ''')
          .eq('is_saved', true);

      // Get most saved ebooks
      final popularEbooks = await SupabaseService.from('ebook_user_interactions')
          .select('''
            ebook_id,
            ebooks!inner(title)
          ''')
          .eq('is_saved', true);

      // Count saves for video kitab
      final videoKitabCounts = <String, int>{};
      final videoKitabTitles = <String, String>{};

      for (final item in popularVideoKitab) {
        final kitabId = item['video_kitab_id'];
        final kitabTitle = item['video_kitab']['title'];
        videoKitabCounts[kitabId] = (videoKitabCounts[kitabId] ?? 0) + 1;
        videoKitabTitles[kitabId] = kitabTitle;
      }

      // Count saves for ebooks
      final ebookCounts = <String, int>{};
      final ebookTitles = <String, String>{};

      for (final item in popularEbooks) {
        final ebookId = item['ebook_id'];
        final ebookTitle = item['ebooks']['title'];
        ebookCounts[ebookId] = (ebookCounts[ebookId] ?? 0) + 1;
        ebookTitles[ebookId] = ebookTitle;
      }

      // Convert to list and sort
      final popularList = <Map<String, dynamic>>[];

      // Add video kitab
      videoKitabCounts.forEach((id, count) {
        popularList.add({
          'title': videoKitabTitles[id] ?? 'Unknown Video',
          'saves': count,
          'type': 'video_kitab',
        });
      });

      // Add ebooks
      ebookCounts.forEach((id, count) {
        popularList.add({
          'title': ebookTitles[id] ?? 'Unknown Ebook',
          'saves': count,
          'type': 'ebook',
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
          'Analytics',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return GestureDetector(
                onTap: () => context.go('/admin/profile'),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12, width: 2),
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.05),
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
                                  color: Colors.black87,
                                  size: 20.0,
                                );
                              },
                            ),
                          )
                        : const HugeIcon(
                            icon: HugeIcons.strokeRoundedUser,
                            color: Colors.black87,
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
              'Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('Try Again'),
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
            _buildUsersAndContentCard(),
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
          'Overview',
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
              'Total Users',
              users['total'].toString(),
              HugeIcons.strokeRoundedUserMultiple,
              Colors.blue,
              '${growth['userGrowth']?.toStringAsFixed(1) ?? '0'}%',
            ),
            _buildOverviewCard(
              'Active Subscriptions',
              subscriptions['active'].toString(),
              HugeIcons.strokeRoundedCreditCard,
              Colors.green,
              '${growth['subscriptionGrowth']?.toStringAsFixed(1) ?? '0'}%',
            ),
            _buildOverviewCard(
              'Total Video Kitab',
              content['totalKitab'].toString(),
              HugeIcons.strokeRoundedVideo01,
              AppTheme.primaryColor,
              '${content['activeKitab']} active',
            ),
            _buildOverviewCard(
              'Categories',
              content['totalCategories'].toString(),
              HugeIcons.strokeRoundedGrid,
              Colors.purple,
              '${content['activeCategories']} active',
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
                  style: const TextStyle(
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
              'User Analytics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Students',
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
                    'Active Subscribers',
                    users['activeSubscribers'].toString(),
                    HugeIcons.strokeRoundedUserCheck01,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'New (30 days)',
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
              'Content Analytics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Videos',
                    content['totalVideos'].toString(),
                    HugeIcons.strokeRoundedVideo01,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Active Videos',
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
                    'Premium Video Kitab',
                    content['premiumKitab'].toString(),
                    HugeIcons.strokeRoundedStar,
                    Colors.amber,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total E-books',
                    content['totalEbooks'].toString(),
                    HugeIcons.strokeRoundedBook02,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Active E-books',
                    content['activeEbooks'].toString(),
                    HugeIcons.strokeRoundedBook02,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total Categories',
                    content['totalCategories'].toString(),
                    HugeIcons.strokeRoundedGrid,
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

  // Combined Users + Content in one card to reduce card count
  Widget _buildUsersAndContentCard() {
    final users = _analytics['users'] ?? {};
    final content = _analytics['content'] ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Users subsection
            Text(
              'User Analytics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Students',
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Active Subscribers',
                    users['activeSubscribers'].toString(),
                    HugeIcons.strokeRoundedUserCheck01,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'New (30 days)',
                    users['recentRegistrations'].toString(),
                    HugeIcons.strokeRoundedNewReleases,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Content subsection
            Text(
              'Content Analytics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Videos',
                    content['totalVideos'].toString(),
                    HugeIcons.strokeRoundedVideo01,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Active Videos',
                    content['activeVideos'].toString(),
                    HugeIcons.strokeRoundedPlayCircle,
                    Colors.green,
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
    // Normalize dynamic map into <String,int> safely
    final dynamic raw = subscriptions['planDistribution'];
    final Map<String, int> planDistribution = raw is Map
        ? raw.map<String, int>((key, value) => MapEntry(
              key.toString(),
              (value is num) ? value.toInt() : int.tryParse(value.toString()) ?? 0,
            ))
        : <String, int>{};
    
    if (planDistribution.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'Subscription Plan Distribution',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
              const SizedBox(height: 16),
              const Text('No subscription data available'),
            ],
          ),
        ),
      );
    }

    // Sort plans by size for consistent coloring + legend order
    final entries = planDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      AppTheme.primaryColor,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
    ];

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    final List<PieChartSectionData> sections = [
      for (var i = 0; i < entries.length; i++)
        (() {
          final entry = entries[i];
          final percent = total == 0 ? 0.0 : (entry.value / total) * 100.0;
          final showLabel = percent >= 8.0;
          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: showLabel ? '${percent.toStringAsFixed(0)}%' : '',
            color: colors[i % colors.length],
            radius: 64,
          );
        })(),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Plan Distribution',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 1,
                      centerSpaceRadius: 52,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Text(
                      'Active',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                      Text(
                        (subscriptions['active'] ?? total).toString(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var i = 0; i < entries.length; i++)
                  (() {
                    final e = entries[i];
                    final percent = total == 0 ? 0.0 : (e.value / total) * 100.0;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${e.key} (${e.value}, ${percent.toStringAsFixed(0)}%)'),
                      ],
                    );
                  })(),
              ],
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
              'Revenue Analytics',
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
                    'Monthly Recurring',
                    'RM ${revenue['monthlyRecurringRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                    HugeIcons.strokeRoundedRefresh,
                    Colors.green,
                  ),
                ),
              ],
            ),
            if (monthlyRevenue.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Last 6 Months Revenue',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                children: [
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
                      )),
                ],
              ),
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
              'Popular Content (By Saves)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (popular.isEmpty)
              const Text('No popular content data')
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
                    subtitle: Text('${content['saves']} saves'),
                    trailing: HugeIcon(
                      icon: content['type'] == 'video_kitab' ? HugeIcons.strokeRoundedVideo01 : HugeIcons.strokeRoundedBook02,
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
