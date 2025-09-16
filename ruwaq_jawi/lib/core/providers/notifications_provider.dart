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
  int get unreadCount => _inbox.where((n) => !n.isRead).length;

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

  int get highPriorityUnreadCount =>
      _inbox.where((n) => !n.isRead && n.isHighPriority).length;

  Future<void> loadInbox() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final res = await _supabase
          .from('user_notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('delivered_at', ascending: false);

      _inbox
        ..clear()
        ..addAll(
          (res as List)
              .map<UserNotificationItem>(
                (row) => UserNotificationItem.fromMap(row),
              ),
        );

      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String userNotificationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('user_notifications')
          .update({
            'read_at': DateTime.now().toIso8601String(),
            'status': 'read',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userNotificationId)
          .eq('user_id', user.id);

      final idx = _inbox.indexWhere((n) => n.id == userNotificationId);
      if (idx != -1) {
        final item = _inbox[idx];
        _inbox[idx] = UserNotificationItem(
          id: item.id,
          userId: item.userId,
          message: item.message,
          metadata: item.metadata,
          status: 'read',
          deliveryStatus: item.deliveryStatus,
          isFavorite: item.isFavorite,
          deliveredAt: item.deliveredAt,
          readAt: DateTime.now(),
          updatedAt: DateTime.now(),
          targetCriteria: item.targetCriteria,
          purchaseId: item.purchaseId,
          notificationId: item.notificationId,
        );
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('markAsRead error: $e');
      }
    }
  }

  Future<void> deleteNotification(String userNotificationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('user_notifications')
          .delete()
          .eq('id', userNotificationId)
          .eq('user_id', user.id);

      _inbox.removeWhere((n) => n.id == userNotificationId);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('deleteNotification error: $e');
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
