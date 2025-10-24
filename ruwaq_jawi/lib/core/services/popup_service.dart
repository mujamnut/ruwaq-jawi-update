import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../widgets/subscription_promo_popup.dart';
import 'supabase_service.dart';

class PopupService {
  static const String _subscriptionPromoType = 'subscription_promo';

  // Track if popup was shown in current app session
  static bool _shownInCurrentSession = false;

  /// Check if subscription promo popup should be shown
  /// Returns true if should show, false otherwise
  static Future<bool> shouldShowSubscriptionPromo() async {
    try {
      // Check if already shown in current session
      if (_shownInCurrentSession) return false;

      // Check if user is authenticated
      final user = SupabaseService.currentUser;
      if (user == null) return false;

      // Check if user already has active subscription (don't show to premium users)
      final hasActiveSubscription = await SupabaseService.hasActiveSubscription();
      if (hasActiveSubscription) return false;

      // Get popup tracking data
      final popupData = await _getPopupTracking(user.id, _subscriptionPromoType);

      // If no tracking data exists, show popup (first time)
      if (popupData == null) return true;

      // Check if user dismissed permanently
      if (popupData['dismissed_permanently'] == true) return false;

      // Frequency policy: once per calendar day (both dev and prod)
      final lastShown = DateTime.parse(popupData['last_shown_at']).toLocal();
      final now = DateTime.now();
      final isSameDay = lastShown.year == now.year &&
          lastShown.month == now.month &&
          lastShown.day == now.day;

      // If already shown today, do not show again until tomorrow
      return !isSameDay;
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
      return false;
    }
  }

  /// Show subscription promo popup
  static Future<void> showSubscriptionPromo(BuildContext context) async {
    try {
      // Mark as shown in current session
      _shownInCurrentSession = true;

      // Record that popup was shown
      await _recordPopupShown(_subscriptionPromoType);

      // Show the popup
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.6),
          builder: (BuildContext context) {
            return SubscriptionPromoPopup(
              onDismiss: () {
                if (kDebugMode) {
                  // Debug logging removed
                }
              },
              onSubscribe: () {
                if (kDebugMode) {
                  // Debug logging removed
                }
              },
            );
          },
        );
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
    }
  }

  /// Record that popup was shown
  static Future<void> _recordPopupShown(String popupType) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      await SupabaseService.upsertPopupTracking(
        userId: user.id,
        popupType: popupType,
      );
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
    }
  }

  /// Mark popup as permanently dismissed
  static Future<void> dismissPermanently(String popupType) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      await SupabaseService.dismissPopupPermanently(
        userId: user.id,
        popupType: popupType,
      );
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
    }
  }

  /// Get popup tracking data for user
  static Future<Map<String, dynamic>?> _getPopupTracking(
    String userId,
    String popupType,
  ) async {
    try {
      return await SupabaseService.getPopupTracking(
        userId: userId,
        popupType: popupType,
      );
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
      return null;
    }
  }

  /// Check and show subscription promo if criteria met
  /// This is the main method to call after login
  static Future<void> checkAndShowSubscriptionPromo(BuildContext context) async {
    try {
      final shouldShow = await shouldShowSubscriptionPromo();

      if (shouldShow && context.mounted) {
        // Add small delay for better UX
        await Future.delayed(const Duration(milliseconds: 500));

        if (context.mounted) {
          await showSubscriptionPromo(context);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
    }
  }

  /// Reset session flag (call on logout or app restart)
  static void resetSessionFlag() {
    _shownInCurrentSession = false;
    if (kDebugMode) {
      // Debug logging removed
    }
  }

  /// Reset popup tracking for testing purposes (development only)
  static Future<void> resetPopupTracking() async {
    if (!AppConfig.isDevelopment) return;

    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      await SupabaseService.resetPopupTracking(userId: user.id);
      _shownInCurrentSession = false; // Also reset session flag

      if (kDebugMode) {
        // Debug logging removed
      }
    } catch (e) {
      if (kDebugMode) {
        // Debug logging removed
      }
    }
  }
}
