import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/providers/subscription_provider.dart';
import '../../../../../core/providers/auth_provider.dart';
import '../../../../../core/theme/app_theme.dart';

class EbookPremiumService {
  /// Check if user has active subscription (FIXED - Use AuthProvider)
  static bool hasActiveSubscription(BuildContext context) {
    try {
      // PRIMARY CHECK: Use AuthProvider (profiles table) - MOST ACCURATE
      final authProvider = context.read<AuthProvider>();

      debugPrint('🔑 [EbookPremiumService] Checking subscription status:');
      debugPrint('   AuthProvider.hasActiveSubscription: ${authProvider.hasActiveSubscription}');
      debugPrint('   AuthProvider.subscriptionStatus: ${authProvider.userProfile?.subscriptionStatus}');

      // Use profile subscription status which is updated by database functions
      bool isProfileActive = authProvider.hasActiveSubscription;

      // SECONDARY CHECK: Fallback to SubscriptionProvider (for safety)
      if (!isProfileActive) {
        try {
          final subscriptionProvider = context.read<SubscriptionProvider>();
          bool isSubscriptionActive = subscriptionProvider.hasActiveSubscription;
          debugPrint('   SubscriptionProvider.hasActiveSubscription (fallback): $isSubscriptionActive');

          // If subscription provider shows active but profile doesn't, refresh the profile
          if (isSubscriptionActive && authProvider.userProfile != null) {
            debugPrint('⚠️ [EbookPremiumService] Inconsistency detected! Refreshing subscription status...');
            authProvider.refreshSubscriptionStatus();
          }
        } catch (e) {
          debugPrint('   SubscriptionProvider fallback error: $e');
        }
      }

      return isProfileActive;
    } catch (e) {
      debugPrint('❌ [EbookPremiumService] Error checking subscription status: $e');
      return false;
    }
  }

  /// Show premium dialog to encourage subscription
  static void showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            PhosphorIcon(PhosphorIcons.crown(), color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            const Text('Premium Content'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anda perlu melanggan untuk mengakses content premium ini.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.lightbulb(),
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Dapatkan akses tidak terhad ke semua content premium!',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Langgan Sekarang'),
          ),
        ],
      ),
    );
  }
}