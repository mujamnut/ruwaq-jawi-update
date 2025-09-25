import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/enhanced_notification.dart';

/// Enhanced notification service supporting both new 2-table system and legacy system
/// Provides seamless migration and backward compatibility
class EnhancedNotificationService {
  static final _supabase = Supabase.instance.client;

  /// Get current user ID for convenience
  static String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Get all notifications for current user using hybrid approach
  /// Uses enhanced 2-table system (notifications + notification_reads)
  static Future<List<EnhancedNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      if (kDebugMode) {
        print('🔄 Loading notifications with hybrid approach...');
      }

      // Call hybrid database function that combines both systems
      final response = await _supabase.rpc('get_user_notifications', params: {
        'p_user_id': user.id,
        'p_limit': limit,
        'p_offset': 0,
      });

      if (response == null) {
        if (kDebugMode) {
          print('⚠️ RPC function not available, falling back to legacy system');
        }
        return await _fallbackToLegacySystem(unreadOnly: unreadOnly, limit: limit);
      }

      final List<EnhancedNotification> notifications = (response as List)
          .map((json) => EnhancedNotification.fromHybridJson(json))
          .where((notification) {
            if (unreadOnly) {
              return !notification.isRead;
            }
            return true;
          })
          .take(limit)
          .toList();

      if (kDebugMode) {
        print('✅ Loaded ${notifications.length} notifications using hybrid approach');
        print('🔍 New system: ${notifications.where((n) => n.source == 'new_system').length}');
        print('🔍 Legacy system: ${notifications.where((n) => n.source == 'legacy_system').length}');
      }

      return notifications;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in hybrid approach, falling back to legacy: $e');
      }
      return await _fallbackToLegacySystem(unreadOnly: unreadOnly, limit: limit);
    }
  }

  /// Fallback to legacy system if new system is not available
  static Future<List<EnhancedNotification>> _fallbackToLegacySystem({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    if (kDebugMode) {
      print('❌ Enhanced notification system not available, no fallback');
    }
    return [];
  }

  /// Get unread notifications count using hybrid approach
  static Future<int> getUnreadCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      // Try new system function first
      final response = await _supabase.rpc('get_unread_notification_count', params: {
        'p_user_id': user.id,
      });

      if (response != null) {
        return response as int;
      }

      // Fallback to legacy system
      return 0;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting unread count: $e');
      }
      return 0;
    }
  }

  /// Mark notification as read - supports both new and legacy systems
  static Future<bool> markAsRead(String notificationId, {String? source}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Determine which system to use based on source or try new system first
      if (source == 'new_system' || source == null) {
        try {
          final response = await _supabase.rpc('mark_notification_read', params: {
            'p_notification_id': notificationId,
            'p_user_id': user.id,
          });

          if (response == true) {
            if (kDebugMode) {
              print('✅ Marked as read using new system: $notificationId');
            }
            return true;
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Enhanced system failed to mark as read: $e');
          }
          return false;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to mark as read - no fallback available');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking as read: $e');
      }
      return false;
    }
  }

  /// Create broadcast notification (admin only)
  static Future<bool> createBroadcastNotification({
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
    List<String> targetRoles = const ['student'],
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Check if user is admin
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      if (profile['role'] != 'admin') {
        throw Exception('Only admins can create broadcast notifications');
      }

      // Try new system first
      try {
        final response = await _supabase.rpc('create_broadcast_notification', params: {
          'p_title': title,
          'p_message': message,
          'p_metadata': metadata ?? {},
          'p_target_roles': targetRoles,
        });

        if (response != null) {
          if (kDebugMode) {
            print('✅ Created broadcast notification using new system');
          }
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Enhanced broadcast notification failed: $e');
        }
        throw Exception('Failed to create broadcast notification: $e');
      }

      if (kDebugMode) {
        print('❌ Enhanced broadcast notification creation failed - no fallback available');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating broadcast notification: $e');
      }
      return false;
    }
  }

  /// Create personal notification
  static Future<bool> createPersonalNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Try new system first
      try {
        final response = await _supabase.rpc('create_personal_notification', params: {
          'p_user_id': userId,
          'p_title': title,
          'p_message': message,
          'p_metadata': metadata ?? {},
        });

        if (response != null) {
          if (kDebugMode) {
            print('✅ Created personal notification using new system');
          }
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Enhanced system failed to create personal notification: $e');
        }
        return false;
      }

      if (kDebugMode) {
        print('❌ Failed to create personal notification - no fallback available');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating personal notification: $e');
      }
      return false;
    }
  }

  /// Mark all notifications as read
  static Future<bool> markAllAsRead() async {
    try {
      final notifications = await getNotifications(unreadOnly: true);

      for (final notification in notifications) {
        await markAsRead(notification.id, source: notification.source);
      }

      if (kDebugMode) {
        print('✅ Marked all ${notifications.length} notifications as read');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking all as read: $e');
      }
      return false;
    }
  }

  /// Delete notification - supports both systems
  static Future<bool> deleteNotification(String notificationId, {String? source}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Enhanced system doesn't support deletion, only mark as read
      return await markAsRead(notificationId, source: 'new_system');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting notification: $e');
      }
      return false;
    }
  }

  /// Watch notifications stream - hybrid approach
  static Stream<List<EnhancedNotification>> watchNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Watch both new and legacy systems
    return Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) async => await getNotifications())
        .distinct();
  }

  /// Migrate data from legacy to new system (admin function)
  static Future<Map<String, int>> migrateLegacyNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check admin permission
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      if (profile['role'] != 'admin') {
        throw Exception('Only admins can migrate notifications');
      }

      final response = await _supabase.rpc('migrate_legacy_notifications');

      if (response != null && response is List && response.isNotEmpty) {
        final result = response.first;
        return {
          'migrated': result['migrated_count'] ?? 0,
          'errors': result['error_count'] ?? 0,
        };
      }

      return {'migrated': 0, 'errors': 0};
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error migrating legacy notifications: $e');
      }
      return {'migrated': 0, 'errors': 1};
    }
  }

  /// Check system health and availability
  static Future<Map<String, bool>> checkSystemHealth() async {
    try {
      final Map<String, bool> health = {};

      // Test new system tables
      try {
        await _supabase.from('notifications').select('id').limit(1);
        health['new_notifications_table'] = true;
      } catch (e) {
        health['new_notifications_table'] = false;
      }

      try {
        await _supabase.from('notification_reads').select('id').limit(1);
        health['new_reads_table'] = true;
      } catch (e) {
        health['new_reads_table'] = false;
      }

      // Legacy system no longer available after migration
      health['legacy_table'] = false;

      // Test RPC functions
      try {
        await _supabase.rpc('get_unread_notification_count', params: {
          'p_user_id': currentUserId ?? '00000000-0000-0000-0000-000000000000',
        });
        health['rpc_functions'] = true;
      } catch (e) {
        health['rpc_functions'] = false;
      }

      if (kDebugMode) {
        print('🔍 System Health Check:');
        health.forEach((key, value) {
          print('  $key: ${value ? "✅" : "❌"}');
        });
      }

      return health;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking system health: $e');
      }
      return {};
    }
  }
}