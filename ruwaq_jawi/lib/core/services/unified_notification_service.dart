import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Unified notification service for handling both individual and global notifications
/// Uses single user_notifications table with special global user ID
class UnifiedNotificationService {
  static final _supabase = Supabase.instance.client;

  // Special UUID for global notifications
  static const String globalUserId = '00000000-0000-0000-0000-000000000000';

  /// Get all notifications for current user (including global ones)
  static Future<List<UnifiedNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 50
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      // Get user profile to determine role
      final profileResponse = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      final userRole = profileResponse['role'] ?? 'student';

      // Build query to get both individual notifications and global notifications
      // that target the user's role
      var query = _supabase
          .from('user_notifications')
          .select('*')
          .or(
            'user_id.eq.${user.id},' + // Individual notifications for this user
            'and(user_id.eq.$globalUserId,metadata->>target_roles.cs.["$userRole"])' // Global notifications for user's role
          );

      if (unreadOnly) {
        query = query.eq('status', 'unread');
      }

      final response = await query
          .order('delivered_at', ascending: false)
          .limit(limit);

      if (response == null) return [];

      final List<UnifiedNotification> notifications = (response as List)
          .map((json) => UnifiedNotification.fromJson(json))
          .toList();

      if (kDebugMode) {
        print('✅ Loaded ${notifications.length} unified notifications (${notifications.where((n) => n.isGlobal).length} global)');
      }

      return notifications;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading unified notifications: $e');
      }
      return [];
    }
  }

  /// Get unread notifications count
  static Future<int> getUnreadCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final profileResponse = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      final userRole = profileResponse['role'] ?? 'student';

      final response = await _supabase
          .from('user_notifications')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('status', 'unread')
          .or(
            'user_id.eq.${user.id},' + // Individual unread
            'and(user_id.eq.$globalUserId,metadata->>target_roles.cs.["$userRole"])' // Global unread
          );

      return response.count ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting unread count: $e');
      }
      return 0;
    }
  }

  /// Mark notification as read
  static Future<bool> markAsRead(String notificationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // For global notifications, we need to create a read tracking record
      // For individual notifications, update the record directly

      // First check if it's a global notification
      final { data: notification } = await _supabase
          .from('user_notifications')
          .select('user_id, metadata')
          .eq('id', notificationId)
          .single();

      if (notification['user_id'] == globalUserId) {
        // Global notification - create read tracking in metadata or separate tracking
        // For simplicity, we'll add user to a 'read_by' array in metadata
        final currentMetadata = Map<String, dynamic>.from(notification['metadata'] ?? {});
        final readBy = List<String>.from(currentMetadata['read_by'] ?? []);

        if (!readBy.contains(user.id)) {
          readBy.add(user.id);
          currentMetadata['read_by'] = readBy;

          await _supabase
              .from('user_notifications')
              .update({'metadata': currentMetadata})
              .eq('id', notificationId);
        }
      } else {
        // Individual notification - mark as read normally
        await _supabase
            .from('user_notifications')
            .update({'status': 'read', 'read_at': DateTime.now().toIso8601String()})
            .eq('id', notificationId)
            .eq('user_id', user.id);
      }

      if (kDebugMode) {
        print('✅ Marked notification as read: $notificationId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking notification as read: $e');
      }
      return false;
    }
  }

  /// Check if user has read a global notification
  static bool hasUserReadGlobalNotification(UnifiedNotification notification, String userId) {
    if (!notification.isGlobal) return false;

    final readBy = List<String>.from(notification.metadata['read_by'] ?? []);
    return readBy.contains(userId);
  }

  /// Mark all notifications as read
  static Future<bool> markAllAsRead() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final profileResponse = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      final userRole = profileResponse['role'] ?? 'student';

      // Get all notifications for processing
      final notifications = await getNotifications(unreadOnly: true);

      for (final notification in notifications) {
        await markAsRead(notification.id);
      }

      if (kDebugMode) {
        print('✅ Marked all notifications as read for user');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking all notifications as read: $e');
      }
      return false;
    }
  }

  /// Listen to notifications (including global ones)
  static Stream<List<UnifiedNotification>> watchNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('user_notifications')
        .stream(primaryKey: ['id'])
        .order('delivered_at', ascending: false)
        .asyncMap((_) async => await getNotifications());
  }

  /// Create individual notification (for specific user)
  static Future<bool> createIndividualNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notification = {
        'user_id': userId,
        'message': '$title\n$body',
        'metadata': {
          'title': title,
          'body': body,
          'type': type,
          'source': 'individual_notification',
          'created_at': DateTime.now().toIso8601String(),
          ...(metadata ?? {})
        },
        'status': 'unread',
        'delivery_status': 'delivered',
        'delivered_at': DateTime.now().toIso8601String(),
        'target_criteria': {
          'individual_notification': true,
        }
      };

      final { error } = await _supabase
          .from('user_notifications')
          .insert(notification);

      if (error != null) {
        throw Exception('Failed to create individual notification: ${error.message}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating individual notification: $e');
      }
      return false;
    }
  }

  /// Admin function: Get notification statistics
  static Future<NotificationStats?> getNotificationStats(String notificationId) async {
    try {
      final { data: notification } = await _supabase
          .from('user_notifications')
          .select('user_id, metadata')
          .eq('id', notificationId)
          .single();

      if (notification['user_id'] == globalUserId) {
        // Global notification stats
        final metadata = Map<String, dynamic>.from(notification['metadata'] ?? {});
        final studentCount = metadata['student_count'] ?? 0;
        final readBy = List<String>.from(metadata['read_by'] ?? []);
        final readCount = readBy.length;

        return NotificationStats(
          totalStudents: studentCount,
          readCount: readCount,
          unreadCount: studentCount - readCount,
          readPercentage: studentCount > 0 ? (readCount / studentCount * 100) : 0,
        );
      } else {
        // Individual notification - always 1 user
        final status = notification['status'] ?? 'unread';
        return NotificationStats(
          totalStudents: 1,
          readCount: status == 'read' ? 1 : 0,
          unreadCount: status == 'read' ? 0 : 1,
          readPercentage: status == 'read' ? 100 : 0,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting notification stats: $e');
      }
      return null;
    }
  }
}

/// Unified notification model
class UnifiedNotification {
  final String id;
  final String userId;
  final String message;
  final Map<String, dynamic> metadata;
  final String status;
  final DateTime deliveredAt;
  final Map<String, dynamic> targetCriteria;

  UnifiedNotification({
    required this.id,
    required this.userId,
    required this.message,
    required this.metadata,
    required this.status,
    required this.deliveredAt,
    required this.targetCriteria,
  });

  factory UnifiedNotification.fromJson(Map<String, dynamic> json) {
    return UnifiedNotification(
      id: json['id'],
      userId: json['user_id'],
      message: json['message'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      status: json['status'] ?? 'unread',
      deliveredAt: DateTime.parse(json['delivered_at']),
      targetCriteria: Map<String, dynamic>.from(json['target_criteria'] ?? {}),
    );
  }

  /// Check if this is a global notification
  bool get isGlobal => userId == UnifiedNotificationService.globalUserId;

  /// Check if this is an individual notification
  bool get isIndividual => !isGlobal;

  /// Get title from metadata
  String get title => metadata['title'] ?? 'Notification';

  /// Get body from metadata
  String get body => metadata['body'] ?? message;

  /// Get type from metadata
  String get type => metadata['type'] ?? 'info';

  /// Get icon from metadata
  String get icon => metadata['icon'] ?? _getDefaultIcon();

  /// Get action URL from metadata
  String get actionUrl => metadata['action_url'] ?? '/home';

  /// Check if notification is unread for specific user
  bool isUnreadForUser(String currentUserId) {
    if (isIndividual) {
      return status == 'unread';
    } else {
      // Global notification - check if user has read it
      final readBy = List<String>.from(metadata['read_by'] ?? []);
      return !readBy.contains(currentUserId);
    }
  }

  /// Get target roles for global notifications
  List<String> get targetRoles => List<String>.from(metadata['target_roles'] ?? ['student']);

  String _getDefaultIcon() {
    switch (type) {
      case 'content_published':
        final contentType = metadata['content_type'];
        switch (contentType) {
          case 'video_kitab':
            return '📹';
          case 'video_episode':
            return '🎬';
          case 'ebook':
            return '📚';
          default:
            return '📖';
        }
      case 'payment_success':
        return '🎉';
      case 'subscription_expiring':
        return '⏰';
      case 'admin_announcement':
        return '📢';
      case 'maintenance':
        return '🔧';
      default:
        return 'ℹ️';
    }
  }

  /// Get formatted time ago
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(deliveredAt);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return '${(difference.inDays / 7).floor()} minggu yang lalu';
    }
  }
}

/// Notification statistics model
class NotificationStats {
  final int totalStudents;
  final int readCount;
  final int unreadCount;
  final double readPercentage;

  NotificationStats({
    required this.totalStudents,
    required this.readCount,
    required this.unreadCount,
    required this.readPercentage,
  });
}