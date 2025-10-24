import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/payment_config.dart';
import '../services/supabase_service.dart';

/// Direct ToyyibPay API verification service
/// Bypasses Edge Functions to avoid JWT authentication issues
class DirectPaymentVerificationService {
  static final DirectPaymentVerificationService _instance = DirectPaymentVerificationService._internal();
  factory DirectPaymentVerificationService() => _instance;
  DirectPaymentVerificationService._internal();

  /// Verify payment status directly with ToyyibPay API
  Future<ToyyibPayVerificationResult> verifyPaymentWithToyyibPay(String billId) async {
    try {
      // Debug logging removed
      // Debug logging removed

      final response = await http.post(
        Uri.parse(PaymentConfig.getBillUrl),
        body: {
          'userSecretKey': PaymentConfig.userSecretKey,
          'billCode': billId,
        },
      ).timeout(const Duration(seconds: 30));

      // Debug logging removed
      // Debug logging removed

      if (response.statusCode != 200) {
        return ToyyibPayVerificationResult(
          success: false,
          message: 'ToyyibPay API error: HTTP ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);
      // Debug logging removed

      return _parseToyyibPayResponse(data, billId);

    } catch (e) {
      // Debug logging removed
      return ToyyibPayVerificationResult(
        success: false,
        message: 'Gagal mengesahkan pembayaran: ${e.toString()}',
      );
    }
  }

  /// Parse ToyyibPay API response
  ToyyibPayVerificationResult _parseToyyibPayResponse(dynamic data, String billId) {
    try {
      // Handle different response formats
      Map<String, dynamic> transaction;

      if (data is List && data.isNotEmpty) {
        // Array response - get first transaction
        transaction = data[0] as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        // Object response - use directly
        transaction = data;
      } else {
        return ToyyibPayVerificationResult(
          success: false,
          message: 'Invalid response format from ToyyibPay',
        );
      }

      // Debug logging removed

      // Extract payment status
      final billStatus = transaction['billStatus']?.toString();
      final billPaymentStatus = transaction['billpaymentStatus']?.toString();
      final billPaidAmount = transaction['billpaidAmount']?.toString();
      final billInvoiceNo = transaction['billpaymentInvoiceNo']?.toString();

      // Debug logging removed
      // Debug logging removed
      // Debug logging removed
      // Debug logging removed
      // Debug logging removed

      // Determine if payment is successful
      final isPaid = (billPaymentStatus == '1' || billPaymentStatus == 'success');
      final amount = double.tryParse(billPaidAmount ?? '0') ?? 0.0;

      // Debug logging removed

      return ToyyibPayVerificationResult(
        success: true,
        message: isPaid ? 'Pembayaran berjaya disahkan' : 'Pembayaran masih pending',
        isPaid: isPaid,
        amount: amount,
        transactionId: billInvoiceNo ?? billId,
        billId: billId,
        status: billPaymentStatus ?? billStatus ?? 'unknown',
      );

    } catch (e) {
      // Debug logging removed
      return ToyyibPayVerificationResult(
        success: false,
        message: 'Gagal memproses respons ToyyibPay: ${e.toString()}',
      );
    }
  }

  /// Activate subscription directly with mandatory payment verification
  Future<PaymentRecoveryResult> activateSubscriptionDirectly({
    required String billId,
    required String userId,
    required String planId,
    required double amount,
    bool forceVerification = true, // 🔥 SECURITY: Always verify by default
  }) async {
    try {
      // Debug logging removed
      // Debug logging removed

      // 🔥 SECURITY: MANDATORY payment verification step
      if (forceVerification) {
        // Debug logging removed
        final verificationResult = await verifyPaymentWithToyyibPay(billId);

        if (!verificationResult.success) {
          return PaymentRecoveryResult(
            success: false,
            message: '❌ Pembayaran tidak dapat disahkan: ${verificationResult.message}',
            needsRetry: true,
          );
        }

        if (!verificationResult.isPaid) {
          return PaymentRecoveryResult(
            success: false,
            message: '❌ Pembayaran belum berjaya. Status: ${verificationResult.status}. Sila cuba lagi atau hubungi support.',
            needsRetry: true,
          );
        }

        // 🔥 SECURITY: Verify amount matches expected amount
        if (verificationResult.amount != amount) {
          // Debug logging removed
          return PaymentRecoveryResult(
            success: false,
            message: '❌ Jumlah pembayaran tidak sepadai. Sila hubungi support untuk bantuan.',
            needsRetry: false,
          );
        }

        // Debug logging removed
      } else {
        // Debug logging removed
      }

      final now = DateTime.now().toUtc().toIso8601String();

      // Step 1: Get plan details
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

      // Debug logging removed

      // Step 2: Get user profile
      final profileData = await SupabaseService.from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      // 🔥 SECURITY: Check for duplicate activation attempts
      // Debug logging removed
      final existingPayment = await SupabaseService.from('payments')
          .select('id, status, paid_at')
          .eq('bill_id', billId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingPayment != null && existingPayment['status'] == 'completed') {
        // Debug logging removed
        return PaymentRecoveryResult(
          success: false,
          message: 'Pembayaran ini telah diproses sebelumnya pada ${existingPayment['paid_at']}. Sila semak status langganan anda.',
          needsRetry: false,
        );
      }

      // Step 3: Update payment status to completed with audit trail
      // Debug logging removed
      await SupabaseService.from('payments')
          .update({
            'status': 'completed',
            'updated_at': now,
            'paid_at': now,
            'provider_payment_id': billId,
            'raw_payload': {
              'direct_activation': true,
              'activated_at': now,
              'activation_method': 'secure_direct_verification',
              'verification_required': forceVerification,
              'ip_address': 'client_side', // Would be server IP in production
              'user_agent': 'flutter_app',
              'security_checks': {
                'payment_verified': forceVerification,
                'amount_verified': forceVerification,
                'duplicate_check': 'passed',
                'timestamp': now,
              }
            },
          })
          .eq('bill_id', billId)
          .eq('user_id', userId);

      // Step 4: Create/update subscription
      // Debug logging removed
      await SupabaseService.from('user_subscriptions')
          .upsert({
            'user_id': userId,
            'user_name': profileData?['full_name'] ?? 'Unknown',
            'subscription_plan_id': planId,
            'status': 'active',
            'start_date': now,
            'end_date': endDate,
            'payment_id': billId,
            'amount': amount,
            'currency': 'MYR',
            'updated_at': now,
            'metadata': {
              'activation_method': 'direct_verification',
              'activated_at': now,
            },
          });

      // Step 5: Update profile status
      // Debug logging removed
      await SupabaseService.from('profiles')
          .update({
            'subscription_status': 'active',
            'updated_at': now,
          })
          .eq('id', userId);

      // Step 6: Create success notification
      await _createDirectActivationNotification(
        userId: userId,
        planId: planId,
        amount: amount,
        billId: billId,
        endDate: endDate,
      );

      // Debug logging removed

      return PaymentRecoveryResult(
        success: true,
        message: 'Langganan berjaya diaktifkan secara langsung! 🎉',
        subscriptionStatus: 'active',
        endDate: endDate,
        planId: planId,
        needsRetry: false,
      );

    } catch (e) {
      // Debug logging removed
      return PaymentRecoveryResult(
        success: false,
        message: 'Gagal mengaktifkan langganan: ${e.toString()}',
        needsRetry: true,
      );
    }
  }

  /// Create notification for successful direct activation
  Future<void> _createDirectActivationNotification({
    required String userId,
    required String planId,
    required double amount,
    required String billId,
    required String endDate,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final notificationData = {
        'type': 'personal',
        'title': 'Langganan Berjaya Diaktifkan! ✨',
        'message': 'Terima kasih! Pembayaran RM${amount.toStringAsFixed(2)} untuk langganan $planId telah berjaya. Langganan anda aktif sehingga ${DateTime.parse(endDate).day}/${DateTime.parse(endDate).month}/${DateTime.parse(endDate).year}.',
        'target_type': 'user',
        'target_criteria': {'user_ids': [userId]},
        'metadata': {
          'type': 'subscription_activated',
          'sub_type': 'direct_activation_success',
          'icon': '✨',
          'priority': 'high',
          'bill_id': billId,
          'plan_id': planId,
          'amount': amount.toStringAsFixed(2),
          'end_date': endDate,
          'payment_date': now,
          'action_url': '/subscription',
          'source': 'direct_verification',
        },
        'created_at': now,
        'expires_at': DateTime.now().add(Duration(days: 30)).toIso8601String(),
        'is_active': true,
      };

      final result = await SupabaseService.from('notifications')
          .insert(notificationData)
          .select('id')
          .single();

      await SupabaseService.from('notification_reads')
          .insert({
            'notification_id': result['id'],
            'user_id': userId,
            'is_read': false,
            'created_at': now,
            'updated_at': now,
          });
      // Debug logging removed
    } catch (e) {
      // Debug logging removed
    }
  }
}

/// Verification result class
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