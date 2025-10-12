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

      // Get recent ebooks from past 24 hours
    final ebooksResult = await SupabaseService.client
        .from('ebooks')
        .select('title, created_at, category_id')
        .gte('created_at', DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
        .order('created_at', ascending: false);

    // Get recent videos from past 24 hours
    final videosResult = await SupabaseService.client
        .from('video_kitab')
        .select('title, created_at, category_id')
        .gte('created_at', DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> allActivities = [];

    // Process ebooks
    for (final ebook in ebooksResult as List<dynamic>) {
      final createdAt = DateTime.parse(ebook['created_at'] as String);
      final difference = DateTime.now().difference(createdAt);

      final String timeAgo;
      if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes} minit lalu';
      } else {
        timeAgo = '${difference.inHours} jam lalu';
      }

      allActivities.add({
        'title': 'E-book Baharu Ditambah',
        'description': '${ebook['title'] ?? 'E-book tanpa tajuk'} telah ditambah ke dalam koleksi',
        'time': timeAgo,
        'created_at': ebook['created_at'],
        'type': 'ebook',
      });
    }

    // Process videos
    for (final video in videosResult as List<dynamic>) {
      final createdAt = DateTime.parse(video['created_at'] as String);
      final difference = DateTime.now().difference(createdAt);

      final String timeAgo;
      if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes} minit lalu';
      } else {
        timeAgo = '${difference.inHours} jam lalu';
      }

      allActivities.add({
        'title': 'Video Kitab Baharu Ditambah',
        'description': '${video['title'] ?? 'Video tanpa tajuk'} telah ditambah ke dalam koleksi',
        'time': timeAgo,
        'created_at': video['created_at'],
        'type': 'video',
      });
    }

    // Sort by created_at descending and take latest 5
    allActivities.sort((a, b) =>
        DateTime.parse(b['created_at'] as String).compareTo(DateTime.parse(a['created_at'] as String)));

    final activities = allActivities.take(5).toList();

    return AdminDashboardData(
      stats: stats,
      recentActivities: activities,
    );
  }
}
