import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import 'enhanced_notification_service.dart';

/// Service untuk background verification of pending payments
/// Runs automatically dan check pending payments secara berkala
class BackgroundPaymentService {
  static Timer? _timer;
  static bool _isRunning = false;
  static const Duration _checkInterval = Duration(minutes: 2);
  static const Duration _maxRunDuration = Duration(minutes: 30); // Stop after 30 mins
  static DateTime? _startTime;

  /// Start background payment verification
  static void startBackgroundVerification(BuildContext context) {
    if (_isRunning) {
      if (kDebugMode) {
        print('🔄 Background payment verification already running');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('🚀 Starting background payment verification...');
      debugPrint('⚠️ NOTE: Background verification disabled - pending_payments table does not exist');
    }

    // Feature temporarily disabled - requires pending_payments table
    // Will be enabled when database schema is updated
    return;

    // Code below will be enabled when pending_payments table is created
    /*
    _isRunning = true;
    _startTime = DateTime.now();

    _timer = Timer.periodic(_checkInterval, (timer) async {
      try {
        // Check if max duration exceeded
        if (_startTime != null &&
            DateTime.now().difference(_startTime!).compareTo(_maxRunDuration) > 0) {
          debugPrint('⏰ Background verification max duration reached, stopping...');
          stopBackgroundVerification();
          return;
        }

        // Only run if context is still valid and mounted
        if (!context.mounted) {
          debugPrint('⚠️ Context not mounted, stopping background verification');
          stopBackgroundVerification();
          return;
        }

        final subscriptionProvider = Provider.of<SubscriptionProvider>(
          context,
          listen: false
        );

        // Get pending payments
        final pendingPayments = await subscriptionProvider.getPendingPayments();

        if (pendingPayments.isNotEmpty) {
          debugPrint('🔍 Background check: Found ${pendingPayments.length} pending payments');

          // Verify each pending payment
          bool anySuccess = false;
          for (final payment in pendingPayments) {
            final billId = payment['bill_id'];
            final planId = payment['plan_id'];
            final amount = payment['amount']?.toDouble() ?? 0.0;

            debugPrint('⏳ Background verifying: $billId');

            try {
              final success = await subscriptionProvider.verifyPaymentStatus(
                billId: billId,
                planId: planId,
                amount: amount,
              );

              if (success) {
                anySuccess = true;
                debugPrint('✅ Background verification successful for: $billId');

                // Show success notification
                if (context.mounted) {
                  await _showPaymentSuccessNotification(context, payment);
                }

                // Don't check other payments immediately to avoid spam
                break;
              }
            } catch (e) {
              debugPrint('❌ Error in background verification for $billId: $e');
            }

            // Small delay between checks
            await Future.delayed(Duration(seconds: 1));
          }

          // If any payment was successful, extend the running time
          if (anySuccess) {
            _startTime = DateTime.now(); // Reset timer
          }
        } else {
          debugPrint('📋 Background check: No pending payments found');
        }

      } catch (e) {
        debugPrint('❌ Error in background payment verification: $e');
      }
    });
    */
  }

  /// Stop background payment verification
  static void stopBackgroundVerification() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
    _isRunning = false;
    _startTime = null;
    debugPrint('🛑 Background payment verification stopped');
  }

  /// Check if background verification is running
  static bool get isRunning => _isRunning;

  /// Show success notification when payment is verified
  static Future<void> _showPaymentSuccessNotification(
    BuildContext context,
    Map<String, dynamic> payment
  ) async {
    if (!context.mounted) return;

    try {
      // 1. Insert payment success notification to database
      final billId = payment['bill_id']?.toString() ?? 'Unknown';
      final planId = payment['plan_id']?.toString() ?? 'Unknown';
      final amountRaw = payment['amount'];

      // Format amount with 2 decimal places
      final amount = (amountRaw is num)
          ? amountRaw.toStringAsFixed(2)
          : (double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0).toStringAsFixed(2);

      // Get current user ID
      final currentUser = EnhancedNotificationService.currentUserId;
      if (currentUser == null) {
        debugPrint('❌ No current user found, cannot insert payment notification');
        return;
      }

      final success = await EnhancedNotificationService.createPersonalNotification(
        userId: currentUser,
        title: 'Pembayaran Berjaya! 🎉',
        message: 'Terima kasih! Pembayaran RM$amount untuk langganan $planId telah berjaya. Langganan anda kini aktif.',
        metadata: {
          'type': 'payment_success',
          'sub_type': 'payment_success',
          'icon': '🎉',
          'priority': 'high',
          'bill_id': billId,
          'plan_id': planId,
          'amount': amount,
          'payment_date': DateTime.now().toIso8601String(),
          'action_url': '/subscription',
          'source': 'background_payment_service',
        },
      );

      if (success) {
        debugPrint('✅ Payment notification inserted to database');
      } else {
        debugPrint('❌ Failed to insert payment notification to database');
      }

      // 2. Show snackbar notification
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🎉 Payment berhasil! Langganan anda telah diaktifkan.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Lihat',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to subscription screen
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/subscription',
                (route) => route.isFirst,
              );
            },
          ),
        ),
      );

      // 3. Also show a dialog for more visibility
      if (context.mounted) {
        _showPaymentSuccessDialog(context, payment);
      }
    } catch (e) {
      debugPrint('❌ Error showing payment success notification: $e');
    }
  }

  /// Show success dialog
  static void _showPaymentSuccessDialog(
    BuildContext context,
    Map<String, dynamic> payment
  ) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Payment Berhasil!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pembayaran anda telah diproses dengan jayanya!',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bill ID: ${payment['bill_id']}', 
                       style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text('Plan: ${payment['subscription_plans']?['name'] ?? 'Premium Plan'}'),
                  Text('Amount: RM${payment['amount']}'),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Langganan premium anda kini aktif dan boleh digunakan!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/subscription',
                (route) => route.isFirst,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Lihat Langganan'),
          ),
        ],
      ),
    );
  }

  /// Manual trigger untuk check pending payments
  static Future<void> checkPendingPaymentsNow(BuildContext context) async {
    try {
      debugPrint('🔍 Manual check for pending payments...');

      final subscriptionProvider = Provider.of<SubscriptionProvider>(
        context,
        listen: false
      );

      await subscriptionProvider.verifyAllPendingPayments();
      debugPrint('✅ Manual pending payments check completed');
    } catch (e) {
      debugPrint('❌ Error in manual pending payments check: $e');
    }
  }

  /// Clean up method (call during app dispose)
  static void dispose() {
    stopBackgroundVerification();
  }
}
