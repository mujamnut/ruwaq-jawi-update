import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../utils/auth_utils.dart';
import '../utils/database_utils.dart';

/// Unified notification service for handling both individual and global notifications
/// Uses single user_notifications table with special global user ID
class UnifiedNotificationService {
  static final _supabase = Supabase.instance.client;

  // Special identifier for global notifications (now uses NULL in database)
  static const String? globalUserId = null;

  /// Get current user ID for convenience
  static String? get currentUserId => _supabase.auth.currentUser?.id;

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

      // Optimized query: Get both individual and global notifications
      // Using separate queries for better performance than OR condition
      List<dynamic> individualNotifications = [];
      List<dynamic> globalNotifications = [];

      // Get individual notifications for user
      final individualQuery = _supabase
          .from('user_notifications')
          .select('*')
          .eq('user_id', user.id);

      // Get global notifications (NULL user_id)
      final globalQuery = _supabase
          .from('user_notifications')
          .select('*')
          .is_('user_id', null);

      // Apply filters and execute queries in parallel
      if (unreadOnly) {
        individualQuery.eq('status', 'unread');
        // Global notifications don't have status, check via metadata
      }

      // Execute both queries in parallel for better performance
      final results = await Future.wait([
        individualQuery.order('delivered_at', ascending: false).limit(limit ~/ 2),
        globalQuery.order('delivered_at', ascending: false).limit(limit ~/ 2),
      ]);

      individualNotifications = results[0] as List<dynamic>;
      globalNotifications = results[1] as List<dynamic>;

      // Combine and sort by delivered_at
      final List<dynamic> response = [
        ...individualNotifications,
        ...globalNotifications,
      ];

      // Sort combined results by delivered_at
      response.sort((a, b) {
        final aDate = DateTime.parse(a['delivered_at']);
        final bDate = DateTime.parse(b['delivered_at']);
        return bDate.compareTo(aDate); // descending order
      });

      // Apply limit to combined results
      final limitedResponse = response.take(limit).toList();


      if (kDebugMode) {
        print('🔍 Individual notifications: ${individualNotifications.length}');
        print('🔍 Global notifications: ${globalNotifications.length}');
        print('🔍 Combined response: ${limitedResponse.length} records');
        print('🔍 User ID: ${user.id}');
      }

      if (kDebugMode) {
        print('🔄 Starting mapping ${limitedResponse.length} records to UnifiedNotification objects...');
      }

      final List<UnifiedNotification> allMapped = limitedResponse
          .map((json) {
            try {
              final notification = UnifiedNotification.fromJson(json);
              if (kDebugMode) {
                print('✅ Mapped: ${notification.title} (Global: ${notification.isGlobal})');
              }
              return notification;
            } catch (e) {
              if (kDebugMode) {
                print('❌ Mapping error for record: $json');
                print('❌ Error: $e');
              }
              return null;
            }
          })
          .where((notification) => notification != null)
          .cast<UnifiedNotification>()
          .toList();

      if (kDebugMode) {
        print('🔄 Successfully mapped ${allMapped.length} notifications');
        print('🔄 Starting filtering process...');
      }

      final List<UnifiedNotification> notifications = allMapped
          .where((notification) {
            // Filter out deleted notifications for current user
            if (notification.isGlobal) {
              final deletedBy = List<String>.from(notification.metadata['deleted_by'] ?? []);
              final isDeleted = deletedBy.contains(user.id);
              if (kDebugMode && isDeleted) {
                print('🗑️ Filtered out deleted global notification: ${notification.title}');
              }
              return !isDeleted;
            }
            return true; // Individual notifications are already filtered by user_id
          })
          .toList();

      if (kDebugMode) {
        print('✅ Loaded ${notifications.length} unified notifications (${notifications.where((n) => n.isGlobal).length} global)');
        print('🔍 User role: $userRole, User ID: ${user.id}');
        print('🔍 Query used: user_id.eq.${user.id} OR user_id.is.null with target_roles containing $userRole');
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

      // Optimized: Get unread count using separate queries
      final results = await Future.wait([
        // Individual unread notifications
        _supabase
            .from('user_notifications')
            .select('id', const FetchOptions(count: CountOption.exact))
            .eq('user_id', user.id)
            .eq('status', 'unread'),
        // Global notifications (check if user hasn't read them)
        _supabase
            .from('user_notifications')
            .select('id, metadata', const FetchOptions(count: CountOption.exact))
            .is_('user_id', null),
      ]);

      final individualCount = (results[0] as List).length;
      final globalNotifications = results[1] as List;

      // Count global notifications that user hasn't read
      int globalUnreadCount = 0;
      for (final notification in globalNotifications) {
        final readBy = List<String>.from(notification['metadata']?['read_by'] ?? []);
        if (!readBy.contains(user.id)) {
          globalUnreadCount++;
        }
      }

      return individualCount + globalUnreadCount;
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
      final notificationResponse = await _supabase
          .from('user_notifications')
          .select('user_id, metadata')
          .eq('id', notificationId)
          .single();

      final notification = notificationResponse;

      if (notification['user_id'] == null) { // Check for global notifications (NULL user_id)
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
            .update({'status': 'read'})
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

  /// DEBUG: Test raw database query without filters
  static Future<void> debugRawQuery() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user');
        return;
      }

      print('🔍 DEBUG: Testing raw query...');
      print('🔍 User ID: ${user.id}');
      print('🔍 User email: ${user.email}');
      print('🔍 User role: ${user.userMetadata?['role'] ?? 'Unknown'}');

      // Test basic query first
      final rawResponse = await _supabase
          .from('user_notifications')
          .select('*')
          .limit(5);

      print('🔍 Raw SELECT * response: ${rawResponse.length} records');
      if (rawResponse.isNotEmpty) {
        print('🔍 First record: ${rawResponse[0]}');
      }

      // Test with OR condition
      final orResponse = await _supabase
          .from('user_notifications')
          .select('*')
          .or('user_id.eq.${user.id},user_id.is.null')
          .limit(5);

      print('🔍 OR query response: ${orResponse.length} records');
      if (orResponse.isNotEmpty) {
        print('🔍 First OR record: ${orResponse[0]}');
      }

      // Test just global notifications - use filter for NULL check
      final globalResponse = await _supabase
          .from('user_notifications')
          .select('*')
          .filter('user_id', 'is', null)
          .limit(5);

      print('🔍 Global-only response: ${globalResponse.length} records');
      if (globalResponse.isNotEmpty) {
        print('🔍 First global record: ${globalResponse[0]}');
      }

    } catch (e) {
      print('❌ Debug query error: $e');
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
        'delivered_at': DateTime.now().toIso8601String(),
        'target_criteria': {
          'individual_notification': true,
        }
      };

      final response = await _supabase
          .from('user_notifications')
          .insert(notification);

      final error = response.error;

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

  /// Delete notification (soft delete for global, hard delete for individual)
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // First check if it's a global notification
      final notificationResponse = await _supabase
          .from('user_notifications')
          .select('user_id, metadata')
          .eq('id', notificationId)
          .single();

      final notification = notificationResponse;

      if (notification['user_id'] == null) {
        // Global notification - soft delete by adding user to 'deleted_by' array
        final currentMetadata = Map<String, dynamic>.from(notification['metadata'] ?? {});
        final deletedBy = List<String>.from(currentMetadata['deleted_by'] ?? []);

        if (!deletedBy.contains(user.id)) {
          deletedBy.add(user.id);
          currentMetadata['deleted_by'] = deletedBy;

          await _supabase
              .from('user_notifications')
              .update({'metadata': currentMetadata})
              .eq('id', notificationId);
        }
      } else {
        // Individual notification - hard delete if it belongs to current user
        await _supabase
            .from('user_notifications')
            .delete()
            .eq('id', notificationId)
            .eq('user_id', user.id);
      }

      if (kDebugMode) {
        print('✅ Deleted notification: $notificationId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting notification: $e');
      }
      return false;
    }
  }

  /// Check if user has deleted a global notification
  static bool hasUserDeletedGlobalNotification(UnifiedNotification notification, String userId) {
    if (!notification.isGlobal) return false;

    final deletedBy = List<String>.from(notification.metadata['deleted_by'] ?? []);
    return deletedBy.contains(userId);
  }

  /// Admin function: Get notification statistics
  static Future<NotificationStats?> getNotificationStats(String notificationId) async {
    try {
      final notificationResponse = await _supabase
          .from('user_notifications')
          .select('user_id, metadata')
          .eq('id', notificationId)
          .single();

      final notification = notificationResponse;

      if (notification['user_id'] == null) { // Check for global notifications (NULL user_id)
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
  final String? userId; // Nullable for global notifications
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
      userId: json['user_id'], // This can be null for global notifications
      message: json['message'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      status: json['status'] ?? 'unread',
      deliveredAt: DateTime.parse(json['delivered_at']),
      targetCriteria: Map<String, dynamic>.from(json['target_criteria'] ?? {}),
    );
  }

  /// Check if this is a global notification
  bool get isGlobal => userId == null; // Global notifications have NULL user_id

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

  /// Check if notification has been read (for compatibility with notification screen)
  DateTime? get readAt {
    if (isIndividual) {
      // Individual notification - check status
      return status == 'read' ? deliveredAt : null;
    } else {
      // Global notification - check if current user has read it
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return null;

      final readBy = List<String>.from(metadata['read_by'] ?? []);
      return readBy.contains(currentUser.id) ? deliveredAt : null;
    }
  }

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