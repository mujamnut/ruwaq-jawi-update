class UserNotificationItem {
  final String id; // user_notifications.id
  final String userId;
  final String? message;
  final Map<String, dynamic>? metadata;
  final String status;
  final String deliveryStatus;
  final bool isFavorite;
  final DateTime deliveredAt;
  final DateTime? readAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? targetCriteria; // Enhanced targeting info
  final String? purchaseId; // Reference to specific purchase
  final String? notificationId; // Foreign key to notifications table

  const UserNotificationItem({
    required this.id,
    required this.userId,
    this.message,
    this.metadata,
    required this.status,
    required this.deliveryStatus,
    required this.isFavorite,
    required this.deliveredAt,
    this.readAt,
    required this.updatedAt,
    this.targetCriteria,
    this.purchaseId,
    this.notificationId,
  });

  factory UserNotificationItem.fromMap(Map<String, dynamic> map) {
    return UserNotificationItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      message: map['message'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      status: map['status'] as String? ?? 'unread',
      deliveryStatus: map['delivery_status'] as String? ?? 'delivered',
      isFavorite: map['is_favorite'] as bool? ?? false,
      deliveredAt: DateTime.parse(map['delivered_at'] as String),
      readAt: map['read_at'] == null ? null : DateTime.parse(map['read_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      targetCriteria: map['target_criteria'] as Map<String, dynamic>?,
      purchaseId: map['purchase_id'] as String?,
      notificationId: map['notification_id'] as String?,
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

  bool get isRead => readAt != null || status == 'read';

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
