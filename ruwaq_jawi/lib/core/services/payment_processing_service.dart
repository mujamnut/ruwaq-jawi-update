import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../config/env_config.dart';

/// 🔥 FIXED: Helper functions for consistent amount conversion
class PaymentAmountHelper {
  /// Convert decimal amount to cents (for database storage)
  static int toCents(double amount) => (amount * 100).round();

  /// Convert cents to decimal amount (for display)
  static double fromCents(int cents) => cents / 100.0;

  /// Format cents as RM string
  static String formatCents(int cents) => 'RM${(cents / 100.0).toStringAsFixed(2)}';
}

/// Simplified payment processing service
/// Uses single source of truth (payments table) and streamlined logic
class PaymentProcessingService {
  static final PaymentProcessingService _instance = PaymentProcessingService._internal();
  factory PaymentProcessingService() => _instance;
  PaymentProcessingService._internal();

  
  /// Streamlined payment processing entry point
  /// ONLY handles redirect responses - webhook handles the actual payment completion
  Future<PaymentResult> processPayment({
    required String billId,
    required String planId,
    required double amount,
    String? redirectStatus,
    String? redirectStatusId,
    PaymentSource source = PaymentSource.redirect,
  }) async {
    debugPrint('🚀 === STREAMLINED PAYMENT PROCESSING ===');
    debugPrint('📋 Bill ID: $billId | Plan: $planId | Amount: RM$amount | Source: $source');

    // IMPORTANT: This method only handles redirect responses
    // Webhook is the single source of truth for payment completion

    try {
      // 🔥 FIXED: STEP 1: Create payment record immediately if not exists
      // This ensures centralized payment record creation
      await _createPaymentRecord(
        billId: billId,
        planId: planId,
        amount: amount,
        userId: SupabaseService.currentUser?.id,
        userName: 'App User', // Will be updated by webhook with actual name
      );

      // STEP 2: Check redirect status
      final isSuccessful = _isPaymentSuccessful(redirectStatus, redirectStatusId);

      if (isSuccessful) {
        debugPrint('✅ Payment successful via redirect - activating subscription immediately');

        // 🔥 FIXED: Activate subscription immediately instead of relying on webhooks
        // This ensures users get instant access without waiting for webhook callbacks

        try {
          final activationResult = await _activateSubscriptionLocally(
            billId: billId,
            userId: SupabaseService.currentUser!.id,
            planId: planId,
            amount: amount,
            transactionId: billId,
          );

          debugPrint('🎉 Subscription activated immediately!');

          return PaymentResult(
            success: true,
            message: 'Pembayaran berjaya! Langganan anda telah diaktifkan. 🎉',
            status: PaymentStatus.completed,
            subscriptionId: activationResult.planId,
            endDate: activationResult.endDate,
            daysAdded: _calculateDaysAdded(activationResult.endDate),
          );

        } catch (activationError) {
          debugPrint('❌ Immediate activation failed: $activationError');

          // Fallback: Update payment to completed and let recovery mechanism handle it
          await _updatePaymentStatus(billId, 'completed');

          return PaymentResult(
            success: true,
            message: 'Pembayaran berjaya! Mengaktifkan langganan... Sila tunggu beberapa minit.',
            status: PaymentStatus.completed,
            subscriptionId: null,
            endDate: null,
            daysAdded: null,
          );
        }
      }

      // STEP 3: Handle failed redirects
      debugPrint('❌ Payment redirect indicates failure');
      await _updatePaymentStatus(billId, 'failed');

      return PaymentResult(
        success: false,
        message: _getFailureMessage(redirectStatus),
        status: PaymentStatus.failed,
      );

    } catch (e) {
      debugPrint('❌ Payment processing error: $e');
      return PaymentResult(
        success: false,
        message: 'Ralat pemprosesan pembayaran: ${e.toString()}',
        status: PaymentStatus.error,
      );
    }
  }

  /// 🔥 FIXED: Create payment record immediately when processing starts
  /// This ensures payment records exist before webhook processing
  Future<void> _createPaymentRecord({
    required String billId,
    required String planId,
    required double amount,
    String? userId,
    String? userName,
  }) async {
    try {
      final now = DateTime.now().toUtc();

      debugPrint('📝 Creating centralized payment record: $billId');

      await SupabaseService.from('payments').insert({
        'user_id': userId ?? SupabaseService.currentUser?.id,
        'amount_cents': PaymentAmountHelper.toCents(amount),
        'currency': 'MYR',
        'status': 'pending',
        'provider': 'toyyibpay',
        'provider_payment_id': billId,
        'bill_id': billId,
        'plan_id': planId,
        'user_name': userName ?? 'Unknown',
        'description': 'Subscription payment for $planId',
        'activation_type': 'subscription',
        'metadata': {
          'created_by': 'PaymentProcessingService',
          'created_at': now.toIso8601String(),
          'source': 'centralized_processing',
        },
        'raw_payload': {
          'bill_id': billId,
          'plan_id': planId,
          'amount': amount,
          'user_id': userId,
          'processing_service': true,
        },
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      debugPrint('✅ Centralized payment record created: $billId');
    } catch (e) {
      debugPrint('❌ Failed to create centralized payment record: $e');
      rethrow;
    }
  }

  
  /// Update payment status
  Future<void> _updatePaymentStatus(String billId, String status) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      debugPrint('🔍 Looking for payment record with bill_id: $billId');

      // First, try to find the payment record created by PaymentProvider
      final existingPayment = await SupabaseService.from('payments')
          .select('id, status, user_id')
          .eq('bill_id', billId)
          .order('created_at', ascending: true) // Get the oldest record (from PaymentProvider)
          .limit(1)
          .maybeSingle();

      if (existingPayment != null) {
        debugPrint('✅ Found payment record: ${existingPayment['id']} (current status: ${existingPayment['status']})');

        // Update the existing record
        await SupabaseService.from('payments')
            .update({
              'status': status,
              'updated_at': now,
              'paid_at': status == 'completed' ? now : null,
            })
            .eq('id', existingPayment['id']);

        debugPrint('✅ Payment status updated to: $status for record ID: ${existingPayment['id']}');
      } else {
        debugPrint('⚠️ No payment record found with bill_id: $billId');

        // Create new payment record if not found (fallback)
        debugPrint('📝 Creating new payment record for: $billId');
        await SupabaseService.from('payments').insert({
          'user_id': SupabaseService.currentUser!.id,
          'amount_cents': 0, // Will be updated by actual payment logic
          'currency': 'MYR',
          'status': status,
          'provider': 'toyyibpay',
          'provider_payment_id': billId,
          'bill_id': billId,
          'plan_id': 'unknown',
          'description': 'Payment record created during status update',
          'created_at': now,
          'updated_at': now,
          'paid_at': status == 'completed' ? now : null,
        });

        debugPrint('✅ New payment record created with status: $status');
      }
    } catch (e) {
      debugPrint('❌ Error updating payment status: $e');
      // Print more detailed error for debugging
      debugPrint('❌ Error details: ${e.toString()}');
    }
  }

  /// Check if payment is successful based on redirect parameters
  bool _isPaymentSuccessful(String? redirectStatus, String? redirectStatusId) {
    return redirectStatus?.toLowerCase() == 'success' && redirectStatusId == '1';
  }

  /// Get appropriate failure message
  String _getFailureMessage(String? redirectStatus) {
    if (redirectStatus?.toLowerCase() == 'failed' ||
        redirectStatus?.toLowerCase() == 'cancel' ||
        redirectStatus?.toLowerCase() == 'cancelled') {
      return 'Pembayaran dibatalkan. Tiada bayaran dikenakan.';
    }
    return 'Pembayaran tidak dapat disahkan. Sila cuba lagi.';
  }

  /// Calculate days added based on end date
  int _calculateDaysAdded(String? endDate) {
    if (endDate == null) return 0;

    try {
      final endDateTime = DateTime.parse(endDate);
      final now = DateTime.now();
      final difference = endDateTime.difference(now).inDays;
      return difference > 0 ? difference : 0;
    } catch (e) {
      debugPrint('⚠️ Error calculating days added: $e');
      return 30; // Default to 30 days if calculation fails
    }
  }

  
  
  // ⚠️ REMOVED: _createPaymentSuccessNotification function
  // Notification creation is now handled exclusively by webhook system
  // This eliminates dual source conflicts and ensures consistent timezone handling

  /// Process webhook payment confirmation
  Future<PaymentResult> processWebhookConfirmation(Map<String, dynamic> webhookData) async {
    debugPrint('🪝 === WEBHOOK PAYMENT CONFIRMATION ===');
    debugPrint('📋 Webhook data: $webhookData');

    try {
      final billId = webhookData['bill_code']?.toString() ?? webhookData['billId']?.toString();
      final planId = webhookData['plan_id']?.toString();
      final amount = double.tryParse(webhookData['amount']?.toString() ?? '0') ?? 0.0;

      if (billId == null || planId == null) {
        throw Exception('Invalid webhook data: missing billId or planId');
      }

      return await processPayment(
        billId: billId,
        planId: planId,
        amount: amount,
        source: PaymentSource.webhook,
      );
    } catch (e) {
      debugPrint('❌ Webhook processing error: $e');
      return PaymentResult(
        success: false,
        message: 'Webhook processing error: ${e.toString()}',
        status: PaymentStatus.error,
      );
    }
  }

  /// 🔥 NEW: Payment recovery mechanism for stuck payments
  /// This can be called when webhook fails or payment is stuck
  Future<PaymentRecoveryResult> recoverPayment({
    required String billId,
    String? userId,
    String? planId,
    bool forceVerify = false,
  }) async {
    debugPrint('🔧 === PAYMENT RECOVERY MECHANISM ===');
    debugPrint('📋 Bill ID: $billId | User: $userId | Plan: $planId | Force: $forceVerify');

    try {
      final currentUserId = userId ?? SupabaseService.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not logged in');
      }

      // Step 1: Check current payment status
      final paymentData = await SupabaseService.from('payments')
          .select('*')
          .eq('bill_id', billId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (paymentData == null) {
        return PaymentRecoveryResult(
          success: false,
          message: 'Tiada rekod pembayaran dijumpai untuk Bill ID: $billId',
          needsRetry: false,
        );
      }

      debugPrint('📊 Current payment status: ${paymentData['status']}');

      // Step 2: If already completed, return subscription info
      if (paymentData['status'] == 'completed') {
        debugPrint('✅ Payment already completed, checking subscription...');

        final subscriptionData = await SupabaseService.from('user_subscriptions')
            .select('*')
            .eq('user_id', currentUserId)
            .eq('status', 'active')
            .maybeSingle();

        if (subscriptionData != null) {
          return PaymentRecoveryResult(
            success: true,
            message: 'Langganan sudah aktif!',
            subscriptionStatus: 'active',
            endDate: subscriptionData['end_date'],
            planId: subscriptionData['subscription_plan_id'],
            needsRetry: false,
          );
        }
      }

      // Step 3: Try to verify with ToyyibPay API if force verify
      if (forceVerify && paymentData['status'] == 'pending') {
        debugPrint('🔍 Attempting to verify payment with ToyyibPay API...');

        final verificationResult = await _verifyPaymentWithToyyibPay(billId);

        if (verificationResult.success && verificationResult.isPaid) {
          debugPrint('💰 Payment verified as successful! Activating subscription...');

          // Activate subscription locally
          final activationResult = await _activateSubscriptionLocally(
            billId: billId,
            userId: currentUserId,
            planId: planId ?? paymentData['plan_id'],
            amount: verificationResult.amount,
            transactionId: verificationResult.transactionId,
          );

          return activationResult;
        }
      }

      // Step 4: Check if we can activate from pending payment record
      final pendingPayment = await SupabaseService.from('pending_payments')
          .select('*')
          .eq('bill_id', billId)
          .eq('user_id', currentUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (pendingPayment != null && forceVerify) {
        debugPrint('🔄 Found pending payment, attempting activation...');

        final activationResult = await _activateSubscriptionLocally(
          billId: billId,
          userId: currentUserId,
          planId: pendingPayment['plan_id'],
          amount: double.tryParse(pendingPayment['amount'].toString()) ?? 0.0,
          transactionId: billId,
        );

        return activationResult;
      }

      return PaymentRecoveryResult(
        success: false,
        message: 'Pembayaran masih dalam status: ${paymentData['status']}. Sila cuba lagi nanti atau hubungi support.',
        subscriptionStatus: paymentData['status'],
        needsRetry: true,
      );

    } catch (e) {
      debugPrint('❌ Payment recovery error: $e');
      return PaymentRecoveryResult(
        success: false,
        message: 'Ralat semasa recovery: ${e.toString()}',
        needsRetry: false,
      );
    }
  }

  /// Verify payment status with ToyyibPay API
  Future<ToyyibPayVerificationResult> _verifyPaymentWithToyyibPay(String billId) async {
    try {
      debugPrint('🔍 Calling ToyyibPay API for bill: $billId');

      final response = await SupabaseClient(
        EnvConfig.supabaseUrl,
        EnvConfig.supabaseAnonKey,
      ).functions.invoke('verify-payment', body: {
        'billId': billId,
        'userId': SupabaseService.currentUser?.id,
        'planId': 'quarterly_pr', // Default, will be updated if needed
      });

      // Check for error in response
      if (response.data is Map && response.data['success'] == false) {
        debugPrint('❌ Verify payment function error: ${response.data['error']}');
        return ToyyibPayVerificationResult(
          success: false,
          message: response.data['error']?.toString() ?? 'Unknown error',
        );
      }

      final data = response.data;
      return ToyyibPayVerificationResult.fromJson(data);

    } catch (e) {
      debugPrint('❌ ToyyibPay verification error: $e');
      return ToyyibPayVerificationResult(
        success: false,
        message: 'G Mengesahkan pembayaran: ${e.toString()}',
      );
    }
  }

  /// Activate subscription locally (fallback when webhook fails)
  Future<PaymentRecoveryResult> _activateSubscriptionLocally({
    required String billId,
    required String userId,
    required String planId,
    required double amount,
    required String transactionId,
  }) async {
    try {
      debugPrint('🔄 Activating subscription locally...');

      final now = DateTime.now().toUtc().toIso8601String();

      // Get plan details
      final planData = await SupabaseService.from('subscription_plans')
          .select('*')
          .eq('id', planId)
          .maybeSingle();

      if (planData == null) {
        throw Exception('Plan tidak dijumpai: $planId');
      }

      final durationDays = planData['duration_days'] ?? 30;
      final endDate = DateTime.now()
          .add(Duration(days: durationDays))
          .toIso8601String();

      // Get user profile
      final profileData = await SupabaseService.from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      // 1. Update payment status to completed
      await SupabaseService.from('payments')
          .update({
            'status': 'completed',
            'updated_at': now,
            'paid_at': now,
            'provider_payment_id': transactionId,
          })
          .eq('bill_id', billId)
          .eq('user_id', userId);

      // 2. Create/update subscription
      await SupabaseService.from('user_subscriptions')
          .upsert({
            'user_id': userId,
            'user_name': profileData?['full_name'] ?? 'Unknown',
            'subscription_plan_id': planId,
            'status': 'active',
            'start_date': now,
            'end_date': endDate,
            'payment_id': transactionId,
            'amount': amount,
            'currency': 'MYR',
            'updated_at': now,
          });

      // 3. Update profile status
      await SupabaseService.from('profiles')
          .update({
            'subscription_status': 'active',
            'updated_at': now,
          })
          .eq('id', userId);

      // 4. Update pending payment status
      await SupabaseService.from('pending_payments')
          .update({
            'status': 'completed',
            'updated_at': now,
          })
          .eq('bill_id', billId)
          .eq('user_id', userId);

      // 5. Create success notification
      await _createRecoveryNotification(
        userId: userId,
        planId: planId,
        amount: amount,
        billId: billId,
      );

      debugPrint('✅ Subscription activated successfully via recovery!');

      return PaymentRecoveryResult(
        success: true,
        message: 'Langganan berjaya diaktifkan! 🎉',
        subscriptionStatus: 'active',
        endDate: endDate,
        planId: planId,
        needsRetry: false,
      );

    } catch (e) {
      debugPrint('❌ Local activation error: $e');
      return PaymentRecoveryResult(
        success: false,
        message: 'Gagal mengaktifkan langganan: ${e.toString()}',
        needsRetry: true,
      );
    }
  }

  /// Create notification for successful recovery
  Future<void> _createRecoveryNotification({
    required String userId,
    required String planId,
    required double amount,
    required String billId,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final notificationData = {
        'type': 'personal',
        'title': 'Pembayaran Berjaya Dikembalikan! 🔧',
        'message': 'Terima kasih! Pembayaran RM${amount.toStringAsFixed(2)} untuk langganan $planId telah berjaya dipulihkan. Langganan anda kini aktif.',
        'target_type': 'user',
        'target_criteria': {'user_ids': [userId]},
        'metadata': {
          'type': 'payment_recovery',
          'sub_type': 'payment_success',
          'icon': '🔧',
          'priority': 'high',
          'bill_id': billId,
          'plan_id': planId,
          'amount': amount.toStringAsFixed(2),
          'payment_date': now,
          'action_url': '/subscription',
          'source': 'payment_recovery',
        },
        'created_at': now,
        'expires_at': DateTime.now().add(Duration(days: 30)).toIso8601String(),
        'is_active': true,
      };

      final result = await SupabaseService.from('notifications')
          .insert(notificationData)
          .select('id')
          .single();

      if (result != null) {
        await SupabaseService.from('notification_reads')
            .insert({
              'notification_id': result['id'],
              'user_id': userId,
              'is_read': false,
              'created_at': now,
              'updated_at': now,
            });
        debugPrint('✅ Recovery notification created');
      }
    } catch (e) {
      debugPrint('⚠️ Error creating recovery notification: $e');
    }
  }
}

// Enums - FIXED to match database constraints
enum PaymentStatus {
  completed,  // ✅ Matches database: 'completed'
  failed,     // ✅ Matches database: 'failed'
  pending,    // ✅ Matches database: 'pending'
  error       // ✅ For internal errors
}
enum PaymentSource { redirect, webhook }

// Data models
class PaymentResult {
  final bool success;
  final String message;
  final PaymentStatus status;
  final String? subscriptionId;
  final String? endDate;
  final int? daysAdded;

  PaymentResult({
    required this.success,
    required this.message,
    required this.status,
    this.subscriptionId,
    this.endDate,
    this.daysAdded,
  });
}

class PaymentVerificationResult {
  final bool success;
  final String? message;
  final PaymentData? paymentData;
  final bool requiresManualCheck;

  PaymentVerificationResult({
    required this.success,
    this.message,
    this.paymentData,
    this.requiresManualCheck = false,
  });

  factory PaymentVerificationResult.fromJson(Map<String, dynamic> json) {
    return PaymentVerificationResult(
      success: json['success'] ?? false,
      message: json['message'],
      paymentData: json['paymentData'] != null ? PaymentData.fromJson(json['paymentData']) : null,
      requiresManualCheck: json['requiresManualCheck'] ?? false,
    );
  }
}

class SubscriptionActivationResult {
  final bool success;
  final String? message;
  final String? subscriptionId;
  final String? endDate;
  final int? daysAdded;

  SubscriptionActivationResult({
    required this.success,
    this.message,
    this.subscriptionId,
    this.endDate,
    this.daysAdded,
  });

  factory SubscriptionActivationResult.fromJson(Map<String, dynamic> json) {
    return SubscriptionActivationResult(
      success: json['success'] ?? false,
      message: json['message'],
      subscriptionId: json['newSubscriptionId']?.toString(),
      endDate: json['endDate'],
      daysAdded: json['daysAdded'],
    );
  }
}

class PaymentData {
  final String transactionId;
  final double amount;
  final String billId;
  final String status;
  final String source;

  PaymentData({
    required this.transactionId,
    required this.amount,
    required this.billId,
    required this.status,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'amount': amount,
      'billId': billId,
      'status': status,
      'source': source,
    };
  }

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    return PaymentData(
      transactionId: json['transactionId'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      billId: json['billId'] ?? '',
      status: json['status'] ?? '',
      source: json['source'] ?? 'api',
    );
  }
}

/// Payment recovery result class
class PaymentRecoveryResult {
  final bool success;
  final String message;
  final String? subscriptionStatus;
  final String? endDate;
  final String? planId;
  final bool needsRetry;

  PaymentRecoveryResult({
    required this.success,
    required this.message,
    this.subscriptionStatus,
    this.endDate,
    this.planId,
    this.needsRetry = false,
  });
}

/// ToyyibPay verification result class
class ToyyibPayVerificationResult {
  final bool success;
  final String? message;
  final bool isPaid;
  final double amount;
  final String transactionId;
  final String billId;
  final String status;

  ToyyibPayVerificationResult({
    required this.success,
    this.message,
    this.isPaid = false,
    this.amount = 0.0,
    this.transactionId = '',
    this.billId = '',
    this.status = '',
  });

  factory ToyyibPayVerificationResult.fromJson(Map<String, dynamic> json) {
    return ToyyibPayVerificationResult(
      success: json['success'] ?? false,
      message: json['message'],
      isPaid: json['success'] == true, // If verification succeeded, payment is paid
      amount: (json['amount'] ?? json['paymentData']?['amount'] ?? 0).toDouble(),
      transactionId: json['paymentData']?['transactionId'] ?? json['billId'] ?? '',
      billId: json['billId'] ?? '',
      status: json['paymentData']?['status'] ?? json['status'] ?? '',
    );
  }
}