import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service untuk track user activity dan update last_seen_at
class ActivityTrackingService {
  static final _supabase = Supabase.instance.client;

  /// Update user's last seen timestamp
  /// Call this when user opens app, navigates, or performs significant actions
  static Future<void> updateLastSeen() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.rpc('update_user_last_seen', params: {
        'user_uuid': user.id,
      });

      if (kDebugMode) {
        print('✅ Updated last_seen_at for user: ${user.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update last_seen_at: $e');
      }
    }
  }

  /// Update last seen with throttling (max once per 5 minutes)
  static DateTime? _lastUpdate;
  static const _throttleMinutes = 5;

  static Future<void> updateLastSeenThrottled() async {
    final now = DateTime.now();

    if (_lastUpdate != null &&
        now.difference(_lastUpdate!).inMinutes < _throttleMinutes) {
      // Skip update if called too recently
      return;
    }

    _lastUpdate = now;
    await updateLastSeen();
  }

  /// Track specific app actions for better user engagement analytics
  static Future<void> trackAction(String action, {Map<String, dynamic>? data}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Update last seen when user performs actions
      await updateLastSeen();

      // Optional: Log to analytics table if you have one
      if (kDebugMode) {
        print('📊 User action tracked: $action ${data != null ? data.toString() : ''}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to track action: $e');
      }
    }
  }

  /// Common app lifecycle tracking
  static Future<void> onAppResume() async {
    await updateLastSeen();
  }

  static Future<void> onAppPause() async {
    // Update last seen when app goes to background
    await updateLastSeen();
  }

  /// Track content engagement
  static Future<void> trackContentView(String contentType, String contentId) async {
    await trackAction('content_view', data: {
      'content_type': contentType,
      'content_id': contentId,
    });
  }

  /// Track navigation
  static Future<void> trackNavigation(String route) async {
    await trackAction('navigation', data: {
      'route': route,
    });
  }

  /// Track login/logout
  static Future<void> trackLogin() async {
    await trackAction('login');
  }

  static Future<void> trackLogout() async {
    await trackAction('logout');
  }
}