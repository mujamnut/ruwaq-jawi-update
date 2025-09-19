import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  final SupabaseClient _supabase;
  final String? _toyyibPaySecretKey;
  final String? _toyyibPayCategoryCode;
  static const String _toyyibPayApiUrl = 'https://dev.toyyibpay.com';

  SubscriptionService(
    this._supabase, {
    String? toyyibPaySecretKey,
    String? toyyibPayCategoryCode,
  }) : _toyyibPaySecretKey = toyyibPaySecretKey,
       _toyyibPayCategoryCode = toyyibPayCategoryCode;

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
      final existingSubscription = await _supabase
          .from('user_subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_date', now.toIso8601String())
          .maybeSingle();

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
    if (_toyyibPaySecretKey == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_toyyibPayApiUrl/index.php/api/getBillTransactions'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'userSecretKey': _toyyibPaySecretKey!,
          'billCode': billCode,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List && data.isNotEmpty && data[0]['billpaymentStatus'] == '1';
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Payment verification error: $e');
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
}