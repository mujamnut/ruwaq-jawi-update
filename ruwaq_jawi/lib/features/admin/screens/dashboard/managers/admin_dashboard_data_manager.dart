import 'dart:convert';

import 'package:ruwaq_jawi/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardData {
  AdminDashboardData({
    required this.stats,
    required this.recentActivities,
  });

  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> recentActivities;
}

class AdminDashboardDataManager {
  static const _statsCacheKey = 'cached_dashboard_stats';
  static const _activitiesCacheKey = 'cached_recent_activities';

  Future<bool> isCurrentUserAdmin() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      return false;
    }

    try {
      final profile = await SupabaseService.from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      return profile != null && profile['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  Future<AdminDashboardData?> loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStats = prefs.getString(_statsCacheKey);
      final cachedActivities = prefs.getString(_activitiesCacheKey);

      if (cachedStats == null || cachedActivities == null) {
        return null;
      }

      return AdminDashboardData(
        stats: Map<String, dynamic>.from(jsonDecode(cachedStats) as Map),
        recentActivities: List<Map<String, dynamic>>.from(
          (jsonDecode(cachedActivities) as List).map(
            (activity) => Map<String, dynamic>.from(activity as Map),
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheData(AdminDashboardData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statsCacheKey, jsonEncode(data.stats));
      await prefs.setString(_activitiesCacheKey, jsonEncode(data.recentActivities));
    } catch (_) {
      // Best effort caching - ignore errors
    }
  }

  Future<AdminDashboardData> fetchDashboardData() async {
    final usersData = await SupabaseService.from('profiles').select('id');
    final ebooksData = await SupabaseService.from('ebooks').select('id');
    final videoKitabData = await SupabaseService.from('video_kitab').select('id');
    final categoriesData = await SupabaseService.from('categories').select('id');

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final premiumData = await SupabaseService.from('user_subscriptions')
        .select('user_id')
        .eq('status', 'active')
        .gte('end_date', nowIso);

    final stats = <String, dynamic>{
      'totalUsers': (usersData as List).length,
      'totalKitabs': (ebooksData as List).length + (videoKitabData as List).length,
      'totalCategories': (categoriesData as List).length,
      'premiumUsers': (premiumData as List)
          .map((item) => item['user_id'] as String?)
          .whereType<String>()
          .toSet()
          .length,
    };

    final activitiesResult = await SupabaseService.client
        .from('profiles')
        .select('full_name, created_at')
        .gte('created_at', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
        .order('created_at', ascending: false)
        .limit(3);

    final activities = (activitiesResult as List<dynamic>).map((activity) {
      final createdAt = DateTime.parse(activity['created_at'] as String);
      final difference = DateTime.now().difference(createdAt);

      final String timeAgo;
      if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes} minit lalu';
      } else if (difference.inHours < 24) {
        timeAgo = '${difference.inHours} jam lalu';
      } else {
        timeAgo = '${difference.inDays} hari lalu';
      }

      return <String, dynamic>{
        'title': 'Pengguna Baharu Mendaftar',
        'description':
            '${activity['full_name'] ?? 'Pengguna'} telah mendaftar sebagai pengguna baharu',
        'time': timeAgo,
      };
    }).toList();

    return AdminDashboardData(
      stats: stats,
      recentActivities: activities,
    );
  }
}
