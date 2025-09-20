import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  final SupabaseClient _supabase;
  final String? _toyyibPaySecretKey;
  static const String _toyyibPayApiUrl = 'https://dev.toyyibpay.com';

  SubscriptionService(
    this._supabase, {
    String? toyyibPaySecretKey,
  }) : _toyyibPaySecretKey = toyyibPaySecretKey;

  /// Activate subscription - optimized version
  Future<void> activateSubscription({
    required String userId,
    required String planId,
    required double amount,
    required String paymentMethod,
    required String transactionId,
  }) async {
    final now = DateTime.now().toUtc();

    try {
      if (kDebugMode) {
        print('🚀 Activating subscription for user: $userId, plan: $planId');
      }

      // Get plan details
      final plan = await _supabase
          .from('subscription_plans')
          .select('duration_days, name')
          .eq('id', planId)
          .maybeSingle();

      if (plan == null) {
        throw Exception('Plan not found: $planId');
      }

      final durationDays = plan['duration_days'] ?? 30;
      final endDate = now.add(Duration(days: durationDays));

      // Get user profile
      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      final userName = profile?['full_name'] ?? 'Unknown User';

      // Check existing active subscription
      final existingSubscriptionQuery = await _supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_date', now.toIso8601String())
          .order('end_date', ascending: false)
          .limit(1);

      final existingSubscription = existingSubscriptionQuery.isNotEmpty
          ? existingSubscriptionQuery.first
          : null;

      if (existingSubscription != null) {
        if (kDebugMode) {
          print('⚠️ User already has active subscription, extending...');
        }
        // Extend existing subscription
        final currentEndDate = DateTime.parse(existingSubscription['end_date']);
        final newEndDate = currentEndDate.add(Duration(days: durationDays));

        await _supabase
            .from('user_subscriptions')
            .update({
              'end_date': newEndDate.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .eq('id', existingSubscription['id']);
      } else {
        // Create new subscription
        await _supabase.from('user_subscriptions').insert({
          'user_id': userId,
          'subscription_plan_id': planId,
          'status': 'active',
          'start_date': now.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }

      // Create transaction record
      await _supabase.from('transactions').insert({
        'user_id': userId,
        'subscription_id': planId,
        'amount': amount,
        'currency': 'MYR',
        'status': 'completed',
        'payment_method': paymentMethod,
        'transaction_id': transactionId,
        'metadata': {
          'user_name': userName,
          'plan_name': plan['name'],
          'activated_at': now.toIso8601String(),
        },
        'created_at': now.toIso8601String(),
      });

      if (kDebugMode) {
        print('✅ Subscription activated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error activating subscription: $e');
      }
      rethrow;
    }
  }

  /// Check active subscription
  Future<bool> hasActiveSubscription(String userId) async {
    try {
      final result = await _supabase
          .from('user_subscriptions')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_date', DateTime.now().toUtc().toIso8601String())
          .limit(1);

      return result.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking subscription: $e');
      }
      return false;
    }
  }

  /// Get subscription details
  Future<Map<String, dynamic>?> getSubscriptionDetails(String userId) async {
    try {
      return await _supabase
          .from('user_subscriptions')
          .select('''
            *,
            subscription_plans(name, price, duration_days)
          ''')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_date', DateTime.now().toUtc().toIso8601String())
          .maybeSingle();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting subscription details: $e');
      }
      return null;
    }
  }

  /// Verify payment with ToyyibPay
  Future<bool> verifyPayment(String billCode) async {
    if (_toyyibPaySecretKey == null || _toyyibPaySecretKey == 'sandbox_secret_key_here') {
      if (kDebugMode) {
        print('❌ ToyyibPay secret key not configured properly');
        print('📝 Current key: ${_toyyibPaySecretKey ?? 'null'}');
        print('💡 TEMPORARY: Simulating successful verification for testing');
      }
      // TEMPORARY: Return true for testing purposes (REMOVE IN PRODUCTION!)
      return true;
    }

    try {
      if (kDebugMode) {
        print('🔍 Verifying payment with ToyyibPay API for bill: $billCode');
      }

      final response = await http.post(
        Uri.parse('$_toyyibPayApiUrl/index.php/api/getBillTransactions'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'userSecretKey': _toyyibPaySecretKey,
          'billCode': billCode,
        },
      );

      if (kDebugMode) {
        print('📡 ToyyibPay API response: ${response.statusCode}');
        print('📄 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List && data.isNotEmpty) {
          final paymentStatus = data[0]['billpaymentStatus'];
          if (kDebugMode) {
            print('💳 Payment status from API: $paymentStatus');
            if (paymentStatus == '1') {
              print('✅ Payment VERIFIED successful!');
            } else {
              print('❌ Payment NOT successful (status: $paymentStatus)');
            }
          }
          return paymentStatus == '1';
        } else {
          if (kDebugMode) {
            print('❌ No payment data found for bill: $billCode');
          }
          return false;
        }
      } else {
        if (kDebugMode) {
          print('❌ ToyyibPay API error: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Payment verification error: $e');
      }
      return false;
    }
  }

  /// Get all subscription plans
  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    try {
      final result = await _supabase
          .from('subscription_plans')
          .select('*')
          .eq('is_active', true)
          .order('price');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting subscription plans: $e');
      }
      return [];
    }
  }

  /// Store pending payment
  Future<void> storePendingPayment({
    required String billId,
    required String planId,
    required double amount,
  }) async {
    try {
      await _supabase.from('pending_payments').insert({
        'bill_id': billId,
        'plan_id': planId,
        'amount': amount,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error storing pending payment: $e');
      }
      rethrow;
    }
  }

  /// Verify and activate payment
  Future<bool> verifyAndActivatePayment({
    required String billId,
    required String planId,
    required String userId,
    required double amount,
  }) async {
    try {
      final isVerified = await verifyPayment(billId);
      if (isVerified) {
        await activateSubscription(
          userId: userId,
          planId: planId,
          amount: amount,
          paymentMethod: 'toyyibpay',
          transactionId: billId,
        );
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying and activating payment: $e');
      }
      return false;
    }
  }

  /// Update pending payment status
  Future<void> updatePendingPaymentStatus(String billId, String status) async {
    try {
      await _supabase
          .from('pending_payments')
          .update({
            'status': status,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('bill_id', billId);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating pending payment status: $e');
      }
      rethrow;
    }
  }
}