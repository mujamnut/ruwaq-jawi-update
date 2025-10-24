import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';

/// Service untuk background verification of pending payments
/// Runs automatically dan check pending payments secara berkala
class BackgroundPaymentService {
  static Timer? _timer;
  static bool _isRunning = false;

  /// Start background payment verification
  static void startBackgroundVerification(BuildContext context) {
    if (_isRunning) {
      if (kDebugMode) {
        // Debug logging removed
      }
      return;
    }

    if (kDebugMode) {
      // Debug logging removed
      // Debug logging removed
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
          // Debug logging removed
          stopBackgroundVerification();
          return;
        }

        // Only run if context is still valid and mounted
        if (!context.mounted) {
          // Debug logging removed
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
          // Debug logging removed

          // Verify each pending payment
          bool anySuccess = false;
          for (final payment in pendingPayments) {
            final billId = payment['bill_id'];
            final planId = payment['plan_id'];
            final amount = payment['amount']?.toDouble() ?? 0.0;

            // Debug logging removed

            try {
              final success = await subscriptionProvider.verifyPaymentStatus(
                billId: billId,
                planId: planId,
                amount: amount,
              );

              if (success) {
                anySuccess = true;
                // Debug logging removed

                // Show success notification
                if (context.mounted) {
                  await _showPaymentSuccessNotification(context, payment);
                }

                // Don't check other payments immediately to avoid spam
                break;
              }
            } catch (e) {
              // Debug logging removed
            }

            // Small delay between checks
            await Future.delayed(Duration(seconds: 1));
          }

          // If any payment was successful, extend the running time
          if (anySuccess) {
            _startTime = DateTime.now(); // Reset timer
          }
        } else {
          // Debug logging removed
        }

      } catch (e) {
        // Debug logging removed
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
    // Debug logging removed
  }

  /// Check if background verification is running
  static bool get isRunning => _isRunning;

  /// Manual trigger untuk check pending payments
  static Future<void> checkPendingPaymentsNow(BuildContext context) async {
    try {
      // Debug logging removed

      final subscriptionProvider = Provider.of<SubscriptionProvider>(
        context,
        listen: false
      );

      await subscriptionProvider.verifyAllPendingPayments();
      // Debug logging removed
    } catch (e) {
      // Debug logging removed
    }
  }

  /// Clean up method (call during app dispose)
  static void dispose() {
    stopBackgroundVerification();
  }
}
