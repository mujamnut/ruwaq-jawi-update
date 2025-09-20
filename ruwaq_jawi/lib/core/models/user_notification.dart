class UserNotificationItem {
  final String id; // user_notifications.id
  final String? userId; // Made nullable to support global notifications (user_id = null)
  final String? message;
  final Map<String, dynamic>? metadata;
  // Removed status column - using metadata for read tracking
  final DateTime deliveredAt;
  final Map<String, dynamic>? targetCriteria; // Enhanced targeting info

  // Optional fields that may not exist in database - provide defaults
  final String deliveryStatus;
  final bool isFavorite;
  final DateTime? readAt;
  final String? purchaseId; // Reference to specific purchase
  final String? notificationId; // Foreign key to notifications table

  const UserNotificationItem({
    required this.id,
    this.userId, // Made optional for global notifications
    this.message,
    this.metadata,
    required this.deliveredAt,
    this.targetCriteria,
    this.deliveryStatus = 'delivered', // Default value
    this.isFavorite = false, // Default value
    this.readAt,
    this.purchaseId,
    this.notificationId,
  });

  factory UserNotificationItem.fromMap(Map<String, dynamic> map) {
    // Extract readAt from metadata if exists
    DateTime? readAt;
    final metadata = map['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata['read_at'] != null) {
      try {
        readAt = DateTime.parse(metadata['read_at'] as String);
      } catch (e) {
        readAt = null;
      }
    }

    return UserNotificationItem(
      id: map['id'] as String,
      userId: map['user_id'] as String?, // Nullable for global notifications
      message: map['message'] as String?,
      metadata: metadata,
      deliveredAt: DateTime.parse(map['delivered_at'] as String),
      targetCriteria: map['target_criteria'] as Map<String, dynamic>?,
      // Optional fields with safe defaults (these may not exist in database)
      deliveryStatus: map.containsKey('delivery_status')
          ? (map['delivery_status'] as String? ?? 'delivered')
          : 'delivered',
      isFavorite: map.containsKey('is_favorite')
          ? (map['is_favorite'] as bool? ?? false)
          : false,
      readAt: readAt,
      purchaseId: map.containsKey('purchase_id') ? map['purchase_id'] as String? : null,
      notificationId: map.containsKey('notification_id') ? map['notification_id'] as String? : null,
    );
  }

  // Helper getters to extract notification info from metadata or message
  String get title {
    if (metadata != null && metadata!['title'] != null) {
      return metadata!['title'] as String;
    }
    // Extract title from message (first line)
    if (message != null && message!.contains('\n')) {
      return message!.split('\n').first;
    }
    return message ?? 'Notifikasi';
  }

  String get body {
    if (metadata != null && metadata!['body'] != null) {
      return metadata!['body'] as String;
    }
    // Extract body from message (after first line)
    if (message != null && message!.contains('\n')) {
      final lines = message!.split('\n');
      if (lines.length > 1) {
        return lines.skip(1).join('\n');
      }
    }
    return message ?? '';
  }

  String get type {
    if (metadata != null && metadata!['type'] != null) {
      return metadata!['type'] as String;
    }
    return 'general';
  }

  String? get icon {
    if (metadata != null && metadata!['icon'] != null) {
      return metadata!['icon'] as String;
    }
    return null;
  }

  String? get actionUrl {
    if (metadata != null && metadata!['action_url'] != null) {
      return metadata!['action_url'] as String;
    }
    return null;
  }

  Map<String, dynamic>? get data {
    if (metadata != null && metadata!['data'] != null) {
      return metadata!['data'] as Map<String, dynamic>;
    }
    return null;
  }

  // Check if notification is read by current user
  bool isReadByUser(String currentUserId) {
    if (isGlobal) {
      // For global notifications, check if user is in read_by list
      final readBy = metadata?['read_by'] as List<dynamic>? ?? [];
      return readBy.contains(currentUserId);
    } else {
      // For individual notifications, use status or readAt
      return readAt != null; // Only use readAt for individual notifications
    }
  }

  // Legacy getter for backward compatibility
  bool get isRead => readAt != null;

  // Check if notification was deleted by current user
  bool isDeletedByUser(String currentUserId) {
    if (isGlobal) {
      final deletedBy = metadata?['deleted_by'] as List<dynamic>? ?? [];
      return deletedBy.contains(currentUserId);
    }
    return false; // Individual notifications are hard deleted
  }

  // Check if this is a global notification
  bool get isGlobal => userId == null;

  // Get effective user ID for operations (use current user ID for global notifications)
  String getEffectiveUserId(String currentUserId) => userId ?? currentUserId;

  // Helper getters for enhanced targeting info
  bool get isPurchaseRelated => purchaseId != null;

  bool get isAdminAnnouncement => type == 'admin_announcement';

  bool get isContentNotification => type == 'content_published';

  bool get isPaymentNotification => type == 'payment_success';

  bool get isSubscriptionNotification => type == 'subscription_expiring';

  bool get isReEngagementNotification => type == 'inactive_user_engagement';

  // Get targeting criteria details
  String? get targetingType {
    if (targetCriteria == null) return null;
    if (targetCriteria!['purchase_specific'] == true) return 'purchase_specific';
    if (targetCriteria!['role_based'] == true) return 'role_based';
    if (targetCriteria!['content_specific'] == true) return 'content_specific';
    if (targetCriteria!['admin_announcement'] == true) return 'admin_announcement';
    if (targetCriteria!['re_engagement'] == true) return 're_engagement';
    return 'general';
  }

  // Get priority level
  String get priority {
    if (metadata != null && metadata!['priority'] != null) {
      return metadata!['priority'] as String;
    }
    if (targetCriteria != null && targetCriteria!['priority'] != null) {
      return targetCriteria!['priority'] as String;
    }
    return 'medium';
  }

  // Check if notification has high priority
  bool get isHighPriority => priority == 'high';
}
