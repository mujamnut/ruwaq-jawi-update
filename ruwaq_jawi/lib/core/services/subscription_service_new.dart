import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SubscriptionService {
  final SupabaseClient _supabase;
  final String? _toyyibPaySecretKey;
  final String? _toyyibPayCategoryCode;
  static const String _toyyibPayApiUrl = 'https://dev.toyyibpay.com'; // Dev/Sandbox URL

  SubscriptionService(this._supabase, {String? toyyibPaySecretKey, String? toyyibPayCategoryCode}) 
    : _toyyibPaySecretKey = toyyibPaySecretKey,
      _toyyibPayCategoryCode = toyyibPayCategoryCode;

  /// Activate subscription menggunakan user_subscriptions table sahaja
  Future<void> activateSubscription({
    required String userId,
    required String planId,
    required double amount,
    required String paymentMethod,
    required String transactionId,
  }) async {
    final now = DateTime.now().toUtc();

    try {
      print('🚀 Activating subscription for user: $userId, plan: $planId');

      // Get plan details
      final plan = await _supabase
          .from('subscription_plans')
          .select('duration_days, name')
          .eq('id', planId)
          .maybeSingle();
      
      if (plan == null) {
        print('❌ Plan not found: $planId');
        throw Exception('Plan not found: $planId');
      }

      final durationDays = plan['duration_days'] ?? 30;
      final endDate = now.add(Duration(days: durationDays));

      // Get user name
      String? userName;
      try {
        final profile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        userName = profile?['full_name'];
      } catch (e) {
        print('⚠️ Warning - could not get user name: $e');
        userName = null;
      }

      print('📅 Plan duration: $durationDays days, end date: ${endDate.toIso8601String()}');

      // 1. Update user_subscriptions table
      print('📝 Updating user_subscriptions...');
      final subscriptionResponse = await _supabase
          .from('user_subscriptions')
          .upsert({
            'user_id': userId,
            'user_name': userName,
            'subscription_plan_id': planId,
            'status': 'active',
            'start_date': now.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'payment_id': transactionId,
            'amount': amount,
            'currency': 'MYR',
            'updated_at': now.toIso8601String()
          });
      final subscriptionError = subscriptionResponse?.error;

      if (subscriptionError != null) {
        print('❌ Error updating subscription: $subscriptionError');
        throw Exception('Failed to update subscription: $subscriptionError');
      }
      print('✅ user_subscriptions updated');

      // 2. Update profile subscription status
      print('👤 Updating profile status...');
      final profileUpdateResponse = await _supabase
          .from('profiles')
          .update({
            'subscription_status': 'active',
            'updated_at': now.toIso8601String(),
          })
          .eq('id', userId);
      final profileUpdateError = profileUpdateResponse?.error;

      if (profileUpdateError != null) {
        print('❌ Error updating profile: $profileUpdateError');
        throw Exception('Failed to update profile: $profileUpdateError');
      }
      print('✅ Profile status updated to active');

      // 3. Create payment record
      print('💳 Creating payment record...');
      final paymentRecordResponse = await _supabase
          .from('payments')
          .insert({
            'user_id': userId,
            'payment_id': transactionId,
            'reference_number': '${userId}_$planId',
            'amount': amount,
            'currency': 'MYR',
            'status': 'completed',
            'payment_method': paymentMethod,
            'paid_at': now.toIso8601String(),
            'metadata': {
              'plan_id': planId,
              'plan_name': plan?['name'],
              'user_name': userName
            },
            'created_at': now.toIso8601String()
          });
      final paymentError = paymentRecordResponse?.error;

      if (paymentError != null) {
        print('❌ Error creating payment record: $paymentError');
        // Don't throw - subscription still activated
      } else {
        print('✅ Payment record created');
      }

      print('🎉 Subscription activation completed for user: $userId');
      
    } catch (e) {
      print('💥 Failed to activate subscription: $e');
      throw Exception('Failed to activate subscription: $e');
    }
  }

  /// Check if user has active subscription in user_subscriptions table
  Future<bool> hasActiveSubscription(String userId) async {
    final now = DateTime.now().toUtc();
    
    try {
      print('🔍 Checking subscription for user: $userId');
      
      final subscription = await _supabase
          .from('user_subscriptions')
          .select('*')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_date', now.toIso8601String())
          .maybeSingle();

      final hasActive = subscription != null;
      print('📊 Active subscription found: $hasActive');
      
      if (subscription != null) {
        print('📋 Subscription details: ${subscription['subscription_plan_id']}, ends: ${subscription['end_date']}');
        
        // Ensure profile status matches subscription status
        await _updateProfileSubscriptionStatus(userId, 'active');
      } else {
        // Check if there's an expired subscription
        final expiredSub = await _supabase
            .from('user_subscriptions')
            .select('*')
            .eq('user_id', userId)
            .eq('status', 'active')
            .lt('end_date', now.toIso8601String())
            .maybeSingle();

        if (expiredSub != null) {
          // Mark as expired
          await _supabase
              .from('user_subscriptions')
              .update({'status': 'expired'})
              .eq('id', expiredSub['id']);
          
          await _updateProfileSubscriptionStatus(userId, 'expired');
          print('📋 Marked expired subscription');
        } else {
          // No subscription found - set to inactive
          await _updateProfileSubscriptionStatus(userId, 'inactive');
          print('📋 No subscription found - profile set to inactive');
        }
      }
      
      return hasActive;
    } catch (e) {
      print('❌ Error checking subscription: $e');
      return false;
    }
  }

  /// Get user's active subscription details
  Future<Map<String, dynamic>?> getUserActiveSubscription(String userId) async {
    try {
      final now = DateTime.now().toUtc();
      
      final subscription = await _supabase
          .from('user_subscriptions')
          .select('*, subscription_plans(*)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_date', now.toIso8601String())
          .order('end_date', ascending: false)
          .maybeSingle();
          
      return subscription;
    } catch (e) {
      print('Error getting user subscription: $e');
      return null;
    }
  }

  /// Get subscription end date
  Future<DateTime?> getSubscriptionEndDate(String userId) async {
    try {
      final subscription = await getUserActiveSubscription(userId);
      
      if (subscription != null && subscription['end_date'] != null) {
        return DateTime.parse(subscription['end_date']);
      }
      
      return null;
    } catch (e) {
      print('Error getting subscription end date: $e');
      return null;
    }
  }

  /// Update profile subscription status
  Future<void> _updateProfileSubscriptionStatus(String userId, String status) async {
    try {
      final profileStatusResponse = await _supabase
          .from('profiles')
          .update({
            'subscription_status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
      final error = profileStatusResponse?.error;

      if (error != null) {
        print('❌ Error updating profile subscription status: $error');
      } else {
        print('✅ Profile subscription_status updated to: $status');
      }
    } catch (e) {
      print('❌ Exception updating profile status: $e');
    }
  }

  /// Manual subscription activation (for testing/admin)
  Future<void> manuallyActivateSubscription({
    required String userId,
    required String planId,
    required double amount,
    int? customDurationDays,
  }) async {
    try {
      print('🔧 Manual subscription activation for user: $userId');
      
      await activateSubscription(
        userId: userId,
        planId: planId,
        amount: amount,
        paymentMethod: 'manual',
        transactionId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      print('✅ Manual activation completed');
    } catch (e) {
      print('❌ Manual activation failed: $e');
      rethrow;
    }
  }

  /// Check payment status dari ToyyibPay API
  Future<Map<String, dynamic>?> checkToyyibPaymentStatus(String billId) async {
    if (_toyyibPaySecretKey == null) {
      print('❌ ToyyibPay Secret Key not configured');
      return null;
    }

    try {
      print('🔍 Checking ToyyibPay payment status for Bill ID: $billId');
      print('🔧 Using API URL: $_toyyibPayApiUrl');
      print('🔑 Using Secret Key: ${_toyyibPaySecretKey?.substring(0, 10)}...');
      
      final requestBody = {
        'userSecretKey': _toyyibPaySecretKey,
        'billId': billId,
      };
      
      print('📤 Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse('$_toyyibPayApiUrl/index.php/api/getBillTransactions'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode != 200) {
        print('❌ HTTP Error: ${response.statusCode} - ${response.body}');
        return {
          'status': 'error',
          'billId': billId,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
          'raw': response.body,
        };
      }

      final data = jsonDecode(response.body);
      print('📄 ToyyibPay parsed response: $data');
      
      return _parseToyyibPayResponse(data);
    } catch (e) {
      print('❌ Error checking ToyyibPay status: $e');
      return {
        'status': 'error',
        'billId': billId,
        'error': e.toString(),
        'raw': null,
      };
    }
  }

  /// Parse response dari ToyyibPay API
  Map<String, dynamic>? _parseToyyibPayResponse(dynamic apiResponse) {
    print('🔧 Parsing ToyyibPay response: $apiResponse');
    print('🔧 Response type: ${apiResponse.runtimeType}');
    
    // Handle different response formats
    if (apiResponse is List && apiResponse.isNotEmpty) {
      final transaction = apiResponse[0]; // Ambil transaction terbaru
      print('🔧 Found transaction: $transaction');
      
      final status = transaction['billpaymentStatus']?.toString() ?? '0';
      print('🔧 Payment status from API: $status');
      
      return {
        'billId': transaction['billId'],
        'status': status, // 1 = Success, 0 = Pending, 3 = Failed
        'amount': double.tryParse(transaction['billAmount']?.toString() ?? '0') ?? 0.0,
        'paymentDate': transaction['billpaymentDate'],
        'transactionId': transaction['billpaymentInvoiceNo'],
        'paidAmount': double.tryParse(transaction['billpaidAmount']?.toString() ?? '0') ?? 0.0,
        'raw': transaction,
      };
    }
    
    // Handle empty array response (bill not found or no transactions)
    if (apiResponse is List && apiResponse.isEmpty) {
      print('🔧 Empty response - bill might not exist or no transactions');
      return {
        'status': 'not_found',
        'billId': null,
        'amount': 0.0,
        'paymentDate': null,
        'transactionId': null,
        'paidAmount': 0.0,
        'raw': apiResponse,
      };
    }
    
    // Handle error response or other formats
    if (apiResponse is Map && apiResponse.containsKey('error')) {
      print('🔧 API returned error: ${apiResponse['error']}');
      return {
        'status': 'error',
        'billId': null,
        'amount': 0.0,
        'paymentDate': null,
        'transactionId': null,
        'paidAmount': 0.0,
        'error': apiResponse['error'],
        'raw': apiResponse,
      };
    }

    print('🔧 Unexpected response format - treating as pending');
    return {
      'status': 'pending',
      'billId': null,
      'amount': 0.0,
      'paymentDate': null,
      'transactionId': null,
      'paidAmount': 0.0,
      'raw': apiResponse,
    };
  }

  /// Check dan activate subscription jika payment success
  Future<bool> verifyAndActivatePayment({
    required String billId,
    required String userId,
    required String planId,
  }) async {
    try {
      print('🔍 Verifying payment for Bill ID: $billId');
      
      final paymentStatus = await checkToyyibPaymentStatus(billId);
      
      if (paymentStatus == null) {
        print('❌ Could not get payment status');
        return false;
      }

      final status = paymentStatus['status'].toString();
      print('📊 Payment status: $status');
      print('📊 Full payment data: $paymentStatus');

      // Handle different status types
      if (status == '1') {
        print('💰 Payment successful! Activating subscription...');
        
        await activateSubscription(
          userId: userId,
          planId: planId,
          amount: paymentStatus['paidAmount'] ?? paymentStatus['amount'],
          paymentMethod: 'toyyibpay',
          transactionId: paymentStatus['transactionId'] ?? billId,
        );
        
        return true;
      } else if (status == '3') {
        print('❌ Payment failed');
        return false;
      } else if (status == 'error') {
        print('❌ Payment verification error: ${paymentStatus['error']}');
        return false;
      } else if (status == 'not_found') {
        print('⚠️ Bill not found or no transactions yet');
        return false;
      } else {
        print('⏳ Payment still pending (status: $status)');
        return false;
      }
    } catch (e) {
      print('❌ Error verifying payment: $e');
      return false;
    }
  }
  
  /// Method untuk test sandbox payment activation
  /// Guna ini untuk testing sahaja - jangan guna untuk production
  Future<bool> testSandboxPaymentActivation({
    required String userId,
    required String planId,
  }) async {
    try {
      print('🧪 SANDBOX TEST: Manual payment activation');
      print('⚠️ WARNING: This is for testing only!');
      
      await activateSubscription(
        userId: userId,
        planId: planId,
        amount: 6.90, // Test amount - updated to match new pricing
        paymentMethod: 'sandbox_test',
        transactionId: 'test_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      print('✅ SANDBOX TEST: Payment activation successful');
      return true;
    } catch (e) {
      print('❌ SANDBOX TEST: Payment activation failed: $e');
      return false;
    }
  }

  /// Store pending payment untuk di-track
  Future<void> storePendingPayment({
    required String billId,
    required String userId,
    required String planId,
    required double amount,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      
      final pendingPaymentResponse = await _supabase
          .from('pending_payments')
          .upsert({
            'bill_id': billId,
            'user_id': userId,
            'plan_id': planId,
            'amount': amount,
            'status': 'pending',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          });
      final error = pendingPaymentResponse?.error;

      if (error != null) {
        print('❌ Error storing pending payment: $error');
      } else {
        print('✅ Pending payment stored: $billId');
      }
    } catch (e) {
      print('❌ Exception storing pending payment: $e');
    }
  }

  /// Get pending payments untuk polling
  Future<List<Map<String, dynamic>>> getPendingPayments() async {
    try {
      final pendingPayments = await _supabase
          .from('pending_payments')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(pendingPayments ?? []);
    } catch (e) {
      print('❌ Exception getting pending payments: $e');
      return [];
    }
  }

  /// Update pending payment status
  Future<void> updatePendingPaymentStatus(String billId, String status) async {
    try {
      final updatePaymentStatusResponse = await _supabase
          .from('pending_payments')
          .update({
            'status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('bill_id', billId);
      final error = updatePaymentStatusResponse?.error;

      if (error != null) {
        print('❌ Error updating pending payment: $error');
      }
    } catch (e) {
      print('❌ Exception updating pending payment: $e');
    }
  }
}
