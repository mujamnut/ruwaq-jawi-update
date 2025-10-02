import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_notification.dart';
import '../models/enhanced_notification.dart';
import '../services/enhanced_notification_service.dart';

class NotificationsProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = false;
  String? _error;
  final List<UserNotificationItem> _inbox = [];
  final List<EnhancedNotification> _enhancedInbox = [];

  bool get isLoading => _loading;
  String? get error => _error;
  List<UserNotificationItem> get inbox => List.unmodifiable(_inbox);
  List<EnhancedNotification> get enhancedInbox => List.unmodifiable(_enhancedInbox);

  int get unreadCount {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    // Use enhanced inbox if available, otherwise fallback to legacy
    if (_enhancedInbox.isNotEmpty) {
      return _enhancedInbox.where((n) => !n.isRead).length;
    }
    return _inbox.where((n) => !n.isReadByUser(user.id)).length;
  }

  // Enhanced getters for different notification types - enhanced system
  List<EnhancedNotification> get paymentNotifications =>
      _enhancedInbox.where((n) => n.type == 'personal' &&
          (n.metadata['type'] == 'payment_success' || n.metadata['sub_type'] == 'payment_success')).toList();

  List<EnhancedNotification> get contentNotifications =>
      _enhancedInbox.where((n) => n.type == 'broadcast' &&
          (n.metadata['type'] == 'content_published' || n.contentType != null)).toList();

  List<EnhancedNotification> get adminAnnouncements =>
      _enhancedInbox.where((n) => n.metadata['type'] == 'admin_announcement').toList();

  List<EnhancedNotification> get subscriptionNotifications =>
      _enhancedInbox.where((n) => n.metadata['type'] == 'subscription_expiring' ||
          n.metadata['sub_type'] == 'subscription').toList();

  List<EnhancedNotification> get highPriorityNotifications =>
      _enhancedInbox.where((n) => n.isHighPriority).toList();

  int get highPriorityUnreadCount {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    if (_enhancedInbox.isNotEmpty) {
      return _enhancedInbox.where((n) => !n.isRead && n.isHighPriority).length;
    }
    return _inbox.where((n) => !n.isReadByUser(user.id) && n.isHighPriority).length;
  }

  // Legacy getters for backward compatibility
  List<UserNotificationItem> get legacyPaymentNotifications =>
      _inbox.where((n) => n.isPaymentNotification).toList();

  List<UserNotificationItem> get legacyContentNotifications =>
      _inbox.where((n) => n.isContentNotification).toList();

  List<UserNotificationItem> get legacyAdminAnnouncements =>
      _inbox.where((n) => n.isAdminAnnouncement).toList();

  Future<void> loadInbox() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Try enhanced system first
      try {
        final enhancedNotifications = await EnhancedNotificationService.getNotifications(limit: 50);

        if (enhancedNotifications.isNotEmpty) {
          _enhancedInbox
            ..clear()
            ..addAll(enhancedNotifications);

          // Convert to legacy format for backward compatibility
          final legacyNotifications = enhancedNotifications
              .map((enhanced) => enhanced.toLegacyUserNotificationItem())
              .toList();

          _inbox
            ..clear()
            ..addAll(legacyNotifications);

          if (kDebugMode) {
            print('✅ Loaded ${enhancedNotifications.length} notifications using enhanced system');
            print('📊 Enhanced breakdown: ${enhancedNotifications.where((n) => n.isPersonal).length} personal, '
                  '${enhancedNotifications.where((n) => n.isGlobal).length} broadcast');

            // Debug: Check read status conversion
            for (var i = 0; i < enhancedNotifications.length && i < 3; i++) {
              final enhanced = enhancedNotifications[i];
              final legacy = legacyNotifications[i];
              print('🔍 [$i] ${enhanced.title.substring(0, 20)}...');
              print('   Enhanced: isRead=${enhanced.isRead}, readAt=${enhanced.readAt}');
              print('   Legacy: readAt=${legacy.readAt}, isGlobal=${legacy.isGlobal}');
              if (user != null) {
                print('   isReadByUser(${user.id})=${legacy.isReadByUser(user.id)}');
              }
            }
          }

          _loading = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Enhanced system failed, falling back to legacy: $e');
        }
      }

      // Enhanced system failed, no fallback available
      if (kDebugMode) {
        print('❌ Enhanced notification system failed, no notifications loaded');
      }
      _loading = false;
      notifyListeners();

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading notifications: $e');
      }
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }


  Future<void> markAsRead(String userNotificationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Find the notification to check if it's from enhanced or legacy system
      final notificationIndex = _inbox.indexWhere((n) => n.id == userNotificationId);
      if (notificationIndex == -1) return;

      final notification = _inbox[notificationIndex];

      // Try enhanced notification service first
      final enhancedIndex = _enhancedInbox.indexWhere((n) => n.id == userNotificationId);
      if (enhancedIndex != -1) {
        final enhancedNotification = _enhancedInbox[enhancedIndex];
        final success = await EnhancedNotificationService.markAsRead(
          userNotificationId,
          source: enhancedNotification.source
        );

        if (success) {
          // Update local enhanced state
          _enhancedInbox[enhancedIndex] = enhancedNotification.copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );

          // Update corresponding legacy item if exists
          if (notificationIndex != -1) {
            final item = _inbox[notificationIndex];
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
          }

          notifyListeners();
          if (kDebugMode) {
            print('✅ Marked notification as read using enhanced system: $userNotificationId');
          }
          return;
        }
      }

      // Enhanced system only - no fallback to legacy operations
      if (kDebugMode) {
        print('❌ Enhanced system mark as read failed, no fallback available');
      }
      return;

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

      // Check if this is from enhanced system first
      final enhancedIndex = _enhancedInbox.indexWhere((n) => n.id == userNotificationId);
      if (enhancedIndex != -1) {
        final enhancedNotification = _enhancedInbox[enhancedIndex];
        final success = await EnhancedNotificationService.deleteNotification(
          userNotificationId,
          source: enhancedNotification.source
        );

        if (success) {
          // Remove from both enhanced and legacy local state
          _enhancedInbox.removeWhere((n) => n.id == userNotificationId);
          _inbox.removeWhere((n) => n.id == userNotificationId);
          notifyListeners();

          if (kDebugMode) {
            print('🗑️ Deleted notification using enhanced system: $userNotificationId');
          }
          return;
        }
      }

      // Enhanced system only - no fallback available
      if (kDebugMode) {
        print('❌ Enhanced system delete failed, no fallback available');
      }
      return;
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
