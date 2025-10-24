import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/enhanced_notification.dart';
import 'notification_config_service.dart';

/// Enhanced notification service supporting both new 2-table system and legacy system
/// Provides seamless migration and backward compatibility
class EnhancedNotificationService {
  static final _supabase = Supabase.instance.client;

  /// Get current user ID for convenience
  static String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Get all notifications for current user using hybrid approach
  /// Uses enhanced 2-table system (notifications + notification_reads)
  /// Includes filtering logic for new vs existing users
  static Future<List<EnhancedNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
    int offset = 0,
    DateTime? userRegistrationDate,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      if (kDebugMode) {
        // Debug logging removed
      }

      // Get user registration date if not provided
      userRegistrationDate ??= await _getUserRegistrationDate(user.id);

      // Call hybrid database function that combines both systems
      final response = await _supabase.rpc('get_user_notifications', params: {
        'p_user_id': user.id,
        'p_limit': limit,
        'p_offset': offset,
      });

      if (response == null) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return await _fallbackToLegacySystem(unreadOnly: unreadOnly, limit: limit);
      }

      final List<EnhancedNotification> allNotifications = (response as List)
          .map((json) => EnhancedNotification.fromHybridJson(json))
          .toList();

      // Apply filters asynchronously
      List<EnhancedNotification> filteredNotifications = [];
      for (final notification in allNotifications) {
        // Apply unread filter first
        if (unreadOnly && notification.isRead) {
          continue;
        }

        // Apply user-based filtering
        final shouldShow = await _shouldShowNotification(notification, userRegistrationDate);
        if (shouldShow) {
          filteredNotifications.add(notification);
        }

        // Stop if we reached the limit
        if (filteredNotifications.length >= limit) {
          break;
        }
      }

      final List<EnhancedNotification> notifications = filteredNotifications;

      if (kDebugMode) {
        // Debug logging removed
        // Debug logging removed
        // Debug logging removed
        // Debug logging removed
      }

      return notifications;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
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
      // Debug logging removed
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
        // Debug logging removed
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
          final response = await _supabase.rpc('mark_notification_as_read', params: {
            'p_user_id': user.id,
            'p_notification_id': notificationId,
          });

          if (response == true) {
            if (kDebugMode) {
              // Debug logging removed
            }
            return true;
          }
        } catch (e) {
          if (kDebugMode) {
            // Debug logging removed
          }
          return false;
        }
      }

      if (kDebugMode) {
        // Debug logging removed
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
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
        final response = await _supabase.rpc('create_broadcast_notification_v2', params: {
          'p_title': title,
          'p_message': message,
          'p_type': 'broadcast',
          'p_metadata': metadata ?? {},
        });

        if (response != null) {
          if (kDebugMode) {
            // Debug logging removed
          }
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          // Debug logging removed
        }
        throw Exception('Failed to create broadcast notification: $e');
      }

      if (kDebugMode) {
        // Debug logging removed
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
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
        final response = await _supabase.rpc('create_personal_notification_v2', params: {
          'p_user_id': userId,
          'p_title': title,
          'p_message': message,
          'p_type': 'personal',
          'p_metadata': metadata ?? {},
        });

        if (response != null) {
          if (kDebugMode) {
            // Debug logging removed
          }
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return false;
      }

      if (kDebugMode) {
        // Debug logging removed
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
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
        // Debug logging removed
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
      return false;
    }
  }

  /// Delete notification - soft delete using notification_reads.deleted_at
  static Future<bool> deleteNotification(String notificationId, {String? source}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Use new delete_user_notification RPC function for soft delete
      try {
        final response = await _supabase.rpc('delete_user_notification_v2', params: {
          'p_user_id': user.id,
          'p_notification_id': notificationId,
        });

        if (response == true) {
          if (kDebugMode) {
            // Debug logging removed
          }
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          // Debug logging removed
        }
        return false;
      }

      if (kDebugMode) {
        // Debug logging removed
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
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
        // Debug logging removed
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

      // Test notification settings table
      try {
        await _supabase.from('notification_settings').select('id').limit(1);
        health['notification_settings'] = true;
      } catch (e) {
        health['notification_settings'] = false;
      }

      if (kDebugMode) {
        // Debug logging removed
        health.forEach((key, value) {
          // Debug logging removed
        });
      }

      return health;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
      return {};
    }
  }

  /// Get user registration date from profiles table
  static Future<DateTime?> _getUserRegistrationDate(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('created_at')
          .eq('id', userId)
          .single();

      if (response['created_at'] != null) {
        return DateTime.parse(response['created_at']).toUtc();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
      return null;
    }
  }

  /// Check if a notification should be shown to a user based on filtering rules
  static Future<bool> _shouldShowNotification(
    EnhancedNotification notification,
    DateTime? userRegistrationDate,
  ) async {
    // If no user registration date, show notification (fallback)
    if (userRegistrationDate == null) {
      return true;
    }

    try {
      // Use the config service to determine if this notification should be hidden
      final shouldHide = await NotificationConfigService.shouldHideNotificationFromUser(
        notificationDate: notification.createdAt,
        userRegistrationDate: userRegistrationDate,
        source: notification.source,
      );

      return !shouldHide;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
      // Fallback: show notification if there's an error
      return true;
    }
  }

  /// Initialize notification configuration (call this during app startup)
  static Future<void> initializeConfiguration() async {
    try {
      await NotificationConfigService.initializeDefaults();
      if (kDebugMode) {
        // Debug logging removed
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
    }
  }

  /// Get notification configuration for debugging
  static Future<Map<String, dynamic>> getNotificationConfig() async {
    try {
      return await NotificationConfigService.getCurrentConfig();
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
      return {};
    }
  }
}
