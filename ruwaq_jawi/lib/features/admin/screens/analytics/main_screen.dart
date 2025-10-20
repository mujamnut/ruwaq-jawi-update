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
  String selectedPeriod = '30 hari';
  final List<String> periods = ['7 hari', '30 hari', '90 hari', '1 tahun'];
  DateTime? _lastUpdated;

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
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ralat memuatkan data analisis: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Helpers: period handling and formatting
  Duration _durationForSelectedPeriod() {
    switch (selectedPeriod) {
      case '7 hari':
        return const Duration(days: 7);
      case '90 hari':
        return const Duration(days: 90);
      case '1 tahun':
        return const Duration(days: 365);
      case '30 hari':
      default:
        return const Duration(days: 30);
    }
  }

  DateTime _startDateForSelectedPeriod() {
    return DateTime.now().subtract(_durationForSelectedPeriod());
  }

  String _formatNumber(num? n) {
    if (n == null) return '0';
    final intPart = n.floor();
    final s = intPart.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final reverseIndex = s.length - 1 - i;
      buf.write(s[reverseIndex]);
      if (i % 3 == 2 && reverseIndex != 0) buf.write(',');
    }
    final formattedInt = buf.toString().split('').reversed.join();
    final hasFraction = (n is double) && (n != n.truncateToDouble());
    if (hasFraction) {
      final frac = (n as double).toStringAsFixed(2).split('.').last;
      return '$formattedInt.$frac';
    }
    return formattedInt;
  }

  String _formatCurrency(num? n) {
    final value = (n ?? 0).toDouble();
    final intPart = value.floor();
    final frac = (value - intPart).abs();
    final intFormatted = _formatNumber(intPart);
    return 'RM$intFormatted.${(frac * 100).round().toString().padLeft(2, '0')}';
  }

  String _formatPercent(double? v) {
    if (v == null) return '0%';
    return '${v.toStringAsFixed(1)}%';
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

      // Get recent registrations (selected period)
      final fromDate = _startDateForSelectedPeriod();
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
      final period = _durationForSelectedPeriod();
      final currentStart = now.subtract(period);
      final previousStart = currentStart.subtract(period);

      // User growth (current vs previous period)
      final currentUsers = await SupabaseService.from('profiles')
          .select('id')
          .gte('created_at', currentStart.toIso8601String())
          .lt('created_at', now.toIso8601String())
          .count(CountOption.exact);

      final previousUsers = await SupabaseService.from('profiles')
          .select('id')
          .gte('created_at', previousStart.toIso8601String())
          .lt('created_at', currentStart.toIso8601String())
          .count(CountOption.exact);

      // Subscription growth (current vs previous period)
      final currentSubsData = await SupabaseService.from('user_subscriptions')
          .select('id')
          .gte('created_at', currentStart.toIso8601String())
          .lt('created_at', now.toIso8601String());
      final currentSubs = (currentSubsData as List).length;

      final previousSubsData = await SupabaseService.from('user_subscriptions')
          .select('id')
          .gte('created_at', previousStart.toIso8601String())
          .lt('created_at', currentStart.toIso8601String());
      final previousSubs = (previousSubsData as List).length;

      double userGrowth = 0;
      if (previousUsers.count > 0) {
        userGrowth = ((currentUsers.count - previousUsers.count) / previousUsers.count * 100);
      } else if (currentUsers.count > 0) {
        userGrowth = 100;
      }

      double subscriptionGrowth = 0;
      if (previousSubs > 0) {
        subscriptionGrowth = ((currentSubs - previousSubs) / previousSubs * 100);
      } else if (currentSubs > 0) {
        subscriptionGrowth = 100;
      }

      return {
        'userGrowth': userGrowth,
        'subscriptionGrowth': subscriptionGrowth,
        'currentMonthUsers': currentUsers.count,
        'lastMonthUsers': previousUsers.count,
        'currentMonthSubs': currentSubs,
        'lastMonthSubs': previousSubs,
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
          'title': videoKitabTitles[id] ?? 'Unknown Video Kitab',
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
          'Analisis Sebenar',
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
            _buildPeriodChips(),
            const SizedBox(height: 8),
            if (_lastUpdated != null)
              Text(
                'Kemas kini terakhir: ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            const SizedBox(height: 16),
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

  Widget _buildPeriodChips() {
    return Wrap(
      spacing: 8,
      children: periods.map((p) {
        final selected = p == selectedPeriod;
        return ChoiceChip(
          label: Text(p),
          selected: selected,
          onSelected: (val) {
            if (!val) return;
            setState(() {
              selectedPeriod = p;
            });
            _loadAnalytics();
          },
        );
      }).toList(),
    );
  }

  Widget _buildOverviewCards() {
    final users = _analytics['users'] ?? {};
    final content = _analytics['content'] ?? {};
    final subscriptions = _analytics['subscriptions'] ?? {};
    final growth = _analytics['growth'] ?? {};
    final revenue = _analytics['revenue'] ?? {};

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatChip(
              'Jumlah Pengguna',
              _formatNumber(users['total'] ?? 0),
              HugeIcons.strokeRoundedUserMultiple,
              Colors.blue,
              trend: (growth['userGrowth'] is num)
                  ? (growth['userGrowth'] as num).toDouble()
                  : null,
            ),
            _buildStatChip(
              'Langganan Aktif',
              _formatNumber(subscriptions['active'] ?? 0),
              HugeIcons.strokeRoundedCreditCard,
              Colors.green,
              trend: (growth['subscriptionGrowth'] is num)
                  ? (growth['subscriptionGrowth'] as num).toDouble()
                  : null,
            ),
            _buildStatChip(
              'Jumlah Video',
              _formatNumber(content['totalVideos'] ?? 0),
              HugeIcons.strokeRoundedVideo01,
              AppTheme.primaryColor,
              subtitle: '${content['activeVideos'] ?? 0} aktif',
            ),
            _buildStatChip(
              'Kategori',
              _formatNumber(content['totalCategories'] ?? 0),
              HugeIcons.strokeRoundedGrid,
              Colors.purple,
              subtitle: '${content['activeCategories'] ?? 0} aktif',
            ),
            _buildStatChip(
              'MRR',
              _formatCurrency((revenue['monthlyRecurringRevenue'] ?? 0) as num),
              HugeIcons.strokeRoundedRefresh,
              Colors.teal,
            ),
            _buildStatChip(
              'Transaksi',
              _formatNumber(revenue['totalTransactions'] ?? 0),
              HugeIcons.strokeRoundedInvoice01,
              Colors.indigo,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    double? trend,
  }) {
    Widget? trailing;
    if (trend != null) {
      final isUp = trend >= 0;
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward,
              color: isUp ? Colors.green : Colors.red, size: 14),
          const SizedBox(width: 2),
          Text(_formatPercent(trend.abs()),
              style: TextStyle(
                color: isUp ? Colors.green : Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              )),
        ],
      );
    } else if (subtitle != null) {
      trailing = Text(subtitle,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54));
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: HugeIcon(icon: icon, color: color, size: 18.0),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing,
          ]
        ],
      ),
    );
  }

  Widget _buildUserAnalytics() {
    final users = _analytics['users'] ?? {};
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analisis Pengguna',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
    );
  }

  Widget _buildContentAnalytics() {
    final content = _analytics['content'] ?? {};

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analisis Kandungan',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
                  'Total E-Book',
                  content['totalEbooks'].toString(),
                  HugeIcons.strokeRoundedBook02,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'E-Book Aktif',
                  content['activeEbooks'].toString(),
                  HugeIcons.strokeRoundedBook02,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Kategori',
                  content['totalCategories'].toString(),
                  HugeIcons.strokeRoundedGrid,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionChart() {
    final subscriptions = _analytics['subscriptions'] ?? {};
    final dynamic raw = subscriptions['planDistribution'];
    final Map<String, int> planDistribution = raw is Map
        ? raw.map<String, int>((key, value) => MapEntry(key.toString(), (value is num) ? value.toInt() : int.tryParse(value.toString()) ?? 0))
        : <String, int>{};
    
    if (planDistribution.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Taburan Pelan Langganan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text('Tiada data langganan tersedia'),
          ],
        ),
      );
    }

    // Sort plans by size for consistent coloring and legend ordering
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taburan Pelan Langganan',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
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
                      'Aktif',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    Text(
                      _formatNumber(subscriptions['active'] ?? total),
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
    );
  }

  Widget _buildRevenueAnalytics() {
    final revenue = _analytics['revenue'] ?? {};
    final monthlyRevenue = revenue['monthlyRevenue'] ?? <String, double>{};
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                _formatCurrency((revenue['totalRevenue'] ?? 0) as num),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Transaksi',
                  _formatNumber(revenue['totalTransactions'] ?? 0),
                  HugeIcons.strokeRoundedInvoice01,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Bulanan Berulang',
                  _formatCurrency((revenue['monthlyRecurringRevenue'] ?? 0) as num),
                  HugeIcons.strokeRoundedRefresh,
                  Colors.green,
                ),
              ),
            ],
          ),
          if (monthlyRevenue.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                      Text(_formatCurrency(entry.value)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildPopularContent() {
    final popular = _analytics['popular'] ?? <Map<String, dynamic>>[];
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kandungan Popular (Berdasarkan Simpanan)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (popular.isEmpty)
            const Text('Tiada data kandungan popular')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: popular.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
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
                    icon: content['type'] == 'video_kitab' ? HugeIcons.strokeRoundedVideo01 : HugeIcons.strokeRoundedBook02,
                    color: Colors.grey,
                  ),
                );
              },
            ),
        ],
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
