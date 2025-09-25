import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_notification.dart';
/// Enhanced notification model for the 2-table system
/// Uses notifications + notification_reads tables
class EnhancedNotification {
  final String id;
  final String type; // 'broadcast', 'personal', 'group'
  final String title;
  final String message;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final String source; // 'new_system' or 'legacy_system'
  final String? targetType; // 'all', 'user', 'role' (for new system)
  final Map<String, dynamic> targetCriteria;

  EnhancedNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.metadata,
    required this.createdAt,
    required this.isRead,
    this.readAt,
    required this.source,
    this.targetType,
    this.targetCriteria = const {},
  });

  /// Create from hybrid system query result (new system)
  factory EnhancedNotification.fromHybridJson(Map<String, dynamic> json) {
    return EnhancedNotification(
      id: json['id'],
      type: json['type'] ?? 'broadcast',
      title: json['title'] ?? 'Notification',
      message: json['message'] ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'] ?? false,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      source: json['source'] ?? 'new_system',
      targetType: json['target_type'],
      targetCriteria: Map<String, dynamic>.from(json['target_criteria'] ?? {}),
    );
  }

  /// Create from new notifications table
  factory EnhancedNotification.fromNewSystem({
    required Map<String, dynamic> notification,
    required Map<String, dynamic>? readRecord,
  }) {
    return EnhancedNotification(
      id: notification['id'],
      type: notification['type'] ?? 'broadcast',
      title: notification['title'] ?? 'Notification',
      message: notification['message'] ?? '',
      metadata: Map<String, dynamic>.from(notification['metadata'] ?? {}),
      createdAt: DateTime.parse(notification['created_at']),
      isRead: readRecord?['is_read'] ?? false,
      readAt: readRecord?['read_at'] != null ? DateTime.parse(readRecord!['read_at']) : null,
      source: 'new_system',
      targetType: notification['target_type'],
      targetCriteria: Map<String, dynamic>.from(notification['target_criteria'] ?? {}),
    );
  }

  /// Create from migrated legacy notifications (no longer used)
  factory EnhancedNotification.fromLegacyJson(Map<String, dynamic> json) {
    final metadata = Map<String, dynamic>.from(json['metadata'] ?? {});
    final isGlobal = json['user_id'] == null;

    // For global notifications, check if current user has read it
    bool isRead = false;
    DateTime? readAt;

    if (isGlobal) {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final readBy = List<String>.from(metadata['read_by'] ?? []);
        isRead = readBy.contains(currentUser.id);
        if (isRead) {
          // Approximate read time
          readAt = DateTime.parse(json['delivered_at']);
        }
      }
    } else {
      // Individual notification - check status in metadata
      final status = metadata['status'] ?? 'unread';
      isRead = status == 'read';
      if (isRead && metadata['read_at'] != null) {
        readAt = DateTime.parse(metadata['read_at']);
      }
    }

    return EnhancedNotification(
      id: json['id'],
      type: isGlobal ? 'broadcast' : 'personal',
      title: metadata['title'] ?? 'Legacy Notification',
      message: json['message'] ?? '',
      metadata: metadata,
      createdAt: DateTime.parse(json['delivered_at']),
      isRead: isRead,
      readAt: readAt,
      source: 'legacy_system',
      targetType: isGlobal ? 'all' : 'user',
      targetCriteria: Map<String, dynamic>.from(json['target_criteria'] ?? {}),
    );
  }

  /// Check if this is a global/broadcast notification
  bool get isGlobal => type == 'broadcast' || targetType == 'all';

  /// Check if this is a personal notification
  bool get isPersonal => type == 'personal' || targetType == 'user';

  /// Get icon from metadata with fallback to type-based icons
  String get icon => metadata['icon'] ?? _getDefaultIcon();

  /// Get action URL from metadata
  String get actionUrl => metadata['action_url'] ?? '/home';

  /// Get content type from metadata (for content notifications)
  String? get contentType => metadata['content_type'];

  /// Get content ID from metadata
  String? get contentId => metadata['content_id'];

  /// Get target roles for broadcast notifications
  List<String> get targetRoles {
    if (targetCriteria['target_roles'] != null) {
      return List<String>.from(targetCriteria['target_roles']);
    }
    return List<String>.from(metadata['target_roles'] ?? ['student']);
  }

  /// Get body text (alias for message for compatibility)
  String get body => message;

  /// Get formatted time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

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

  /// Get priority level from metadata
  String get priority => metadata['priority'] ?? 'normal';

  /// Check if notification is high priority
  bool get isHighPriority => priority == 'high' || priority == 'urgent';

  /// Get expiry date from metadata
  DateTime? get expiresAt {
    if (metadata['expires_at'] != null) {
      return DateTime.parse(metadata['expires_at']);
    }
    return null;
  }

  /// Check if notification has expired
  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  /// Get default icon based on type and content
  String _getDefaultIcon() {
    switch (type) {
      case 'broadcast':
        final contentType = metadata['content_type'];
        switch (contentType) {
          case 'video_kitab':
            return '📹';
          case 'video_episode':
            return '🎬';
          case 'ebook':
            return '📚';
          default:
            return '📢'; // Broadcast/announcement
        }
      case 'personal':
        final subType = metadata['sub_type'] ?? metadata['type'];
        switch (subType) {
          case 'payment_success':
            return '🎉';
          case 'subscription_expiring':
            return '⏰';
          case 'welcome':
            return '👋';
          case 'reminder':
            return '🔔';
          default:
            return 'ℹ️';
        }
      case 'group':
        return '👥';
      default:
        return 'ℹ️';
    }
  }

  /// Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'source': source,
      'target_type': targetType,
      'target_criteria': targetCriteria,
    };
  }

  /// Convert to UserNotificationItem format for backward compatibility
  UserNotificationItem toLegacyUserNotificationItem() {
    return UserNotificationItem(
      id: id,
      userId: isPersonal ? targetCriteria['user_id'] : null,
      message: '$title\n$message',
      metadata: {
        'title': title,
        'body': message,
        'type': type,
        'source': source,
        'read_at': readAt?.toIso8601String(),
        ...metadata,
      },
      deliveredAt: createdAt,
      targetCriteria: targetCriteria,
      readAt: readAt,
    );
  }

  /// Create a copy with updated fields
  EnhancedNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
    String? source,
    String? targetType,
    Map<String, dynamic>? targetCriteria,
  }) {
    return EnhancedNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      source: source ?? this.source,
      targetType: targetType ?? this.targetType,
      targetCriteria: targetCriteria ?? this.targetCriteria,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancedNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'EnhancedNotification(id: $id, type: $type, title: $title, source: $source, isRead: $isRead)';
  }
}

/// Enhanced notification statistics
class EnhancedNotificationStats {
  final int totalNotifications;
  final int readCount;
  final int unreadCount;
  final int broadcastCount;
  final int personalCount;
  final int newSystemCount;
  final int legacySystemCount;
  final double readPercentage;

  EnhancedNotificationStats({
    required this.totalNotifications,
    required this.readCount,
    required this.unreadCount,
    required this.broadcastCount,
    required this.personalCount,
    required this.newSystemCount,
    required this.legacySystemCount,
    required this.readPercentage,
  });

  factory EnhancedNotificationStats.fromNotifications(List<EnhancedNotification> notifications) {
    final total = notifications.length;
    final read = notifications.where((n) => n.isRead).length;
    final unread = total - read;
    final broadcast = notifications.where((n) => n.isGlobal).length;
    final personal = notifications.where((n) => n.isPersonal).length;
    final newSystem = notifications.where((n) => n.source == 'new_system').length;
    final legacy = notifications.where((n) => n.source == 'legacy_system').length;
    final readPercentage = total > 0 ? (read / total * 100) : 0.0;

    return EnhancedNotificationStats(
      totalNotifications: total,
      readCount: read,
      unreadCount: unread,
      broadcastCount: broadcast,
      personalCount: personal,
      newSystemCount: newSystem,
      legacySystemCount: legacy,
      readPercentage: readPercentage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_notifications': totalNotifications,
      'read_count': readCount,
      'unread_count': unreadCount,
      'broadcast_count': broadcastCount,
      'personal_count': personalCount,
      'new_system_count': newSystemCount,
      'legacy_system_count': legacySystemCount,
      'read_percentage': readPercentage,
    };
  }
}