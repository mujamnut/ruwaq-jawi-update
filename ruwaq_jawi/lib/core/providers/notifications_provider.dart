import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_notification.dart';

class NotificationsProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = false;
  String? _error;
  final List<UserNotificationItem> _inbox = [];

  bool get isLoading => _loading;
  String? get error => _error;
  List<UserNotificationItem> get inbox => List.unmodifiable(_inbox);

  int get unreadCount {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;
    return _inbox.where((n) => !n.isReadByUser(user.id)).length;
  }

  // Enhanced getters for different notification types
  List<UserNotificationItem> get paymentNotifications =>
      _inbox.where((n) => n.isPaymentNotification).toList();

  List<UserNotificationItem> get contentNotifications =>
      _inbox.where((n) => n.isContentNotification).toList();

  List<UserNotificationItem> get adminAnnouncements =>
      _inbox.where((n) => n.isAdminAnnouncement).toList();

  List<UserNotificationItem> get subscriptionNotifications =>
      _inbox.where((n) => n.isSubscriptionNotification).toList();

  List<UserNotificationItem> get highPriorityNotifications =>
      _inbox.where((n) => n.isHighPriority).toList();

  int get highPriorityUnreadCount {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;
    return _inbox.where((n) => !n.isReadByUser(user.id) && n.isHighPriority).length;
  }

  Future<void> loadInbox() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Query both user-specific AND global notifications
      // Using OR condition to get: user_id = current_user OR user_id IS NULL
      final res = await _supabase
          .from('user_notifications')
          .select('*')
          .or('user_id.eq.${user.id},user_id.is.null')
          .order('delivered_at', ascending: false);

      print('📬 Loaded ${(res as List).length} notifications (including global)');

      // Filter out notifications that the current user has deleted
      final allNotifications = res.map<UserNotificationItem>(
        (row) => UserNotificationItem.fromMap(row),
      ).toList();

      final filteredNotifications = allNotifications.where((notification) {
        return !notification.isDeletedByUser(user.id);
      }).toList();

      _inbox
        ..clear()
        ..addAll(filteredNotifications);

      // Log breakdown of notifications
      final userSpecific = _inbox.where((n) => !n.isGlobal).length;
      final global = _inbox.where((n) => n.isGlobal).length;
      print('📊 Notification breakdown: $userSpecific user-specific, $global global');

      _loading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading notifications: $e');
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String userNotificationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Find the notification to check if it's global
      final notificationIndex = _inbox.indexWhere((n) => n.id == userNotificationId);
      if (notificationIndex == -1) return;

      final notification = _inbox[notificationIndex];

      if (notification.isGlobal) {
        // For global notifications, use the UnifiedNotificationService approach
        // Update metadata to track which users have read it
        final currentMetadata = Map<String, dynamic>.from(notification.metadata ?? {});
        final readBy = List<String>.from(currentMetadata['read_by'] ?? []);

        if (!readBy.contains(user.id)) {
          readBy.add(user.id);
          currentMetadata['read_by'] = readBy;

          await _supabase
              .from('user_notifications')
              .update({'metadata': currentMetadata})
              .eq('id', userNotificationId);
        }
      } else {
        // For individual notifications, update readAt timestamp via metadata
        final currentMetadata = Map<String, dynamic>.from(notification.metadata ?? {});
        currentMetadata['read_at'] = DateTime.now().toIso8601String();

        await _supabase
            .from('user_notifications')
            .update({'metadata': currentMetadata})
            .eq('id', userNotificationId)
            .eq('user_id', user.id);
      }

      // Update local state
      final item = _inbox[notificationIndex];
      // Update metadata for read status
      final updatedMetadata = Map<String, dynamic>.from(item.metadata ?? {});
      if (notification.isGlobal) {
        final readBy = List<String>.from(updatedMetadata['read_by'] ?? []);
        if (!readBy.contains(user.id)) {
          readBy.add(user.id);
          updatedMetadata['read_by'] = readBy;
        }
      } else {
        updatedMetadata['read_at'] = DateTime.now().toIso8601String();
      }

      _inbox[notificationIndex] = UserNotificationItem(
        id: item.id,
        userId: item.userId,
        message: item.message,
        metadata: updatedMetadata,
        deliveredAt: item.deliveredAt,
        targetCriteria: item.targetCriteria,
        deliveryStatus: item.deliveryStatus,
        isFavorite: item.isFavorite,
        readAt: DateTime.now(),
        purchaseId: item.purchaseId,
        notificationId: item.notificationId,
      );
      notifyListeners();

      print('✅ Marked notification as read: ${notification.isGlobal ? 'global' : 'individual'}');
    } catch (e) {
      if (kDebugMode) {
        print('❌ markAsRead error: $e');
      }
    }
  }

  Future<void> deleteNotification(String userNotificationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Find the notification to check if it's global
      final notification = _inbox.firstWhere((n) => n.id == userNotificationId, orElse: () => throw Exception('Notification not found'));

      if (notification.isGlobal) {
        // For global notifications, add user to 'deleted_by' list instead of hard delete
        final currentMetadata = Map<String, dynamic>.from(notification.metadata ?? {});
        final deletedBy = List<String>.from(currentMetadata['deleted_by'] ?? []);

        if (!deletedBy.contains(user.id)) {
          deletedBy.add(user.id);
          currentMetadata['deleted_by'] = deletedBy;

          await _supabase
              .from('user_notifications')
              .update({'metadata': currentMetadata})
              .eq('id', userNotificationId);
        }
      } else {
        // For individual notifications, hard delete if it belongs to current user
        await _supabase
            .from('user_notifications')
            .delete()
            .eq('id', userNotificationId)
            .eq('user_id', user.id);
      }

      // Remove from local state
      _inbox.removeWhere((n) => n.id == userNotificationId);
      notifyListeners();

      print('🗑️ Deleted notification: ${notification.isGlobal ? 'global (soft delete)' : 'individual (hard delete)'}');
    } catch (e) {
      if (kDebugMode) {
        print('❌ deleteNotification error: $e');
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
