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

  /// Activate subscription - optimized version for both new and existing users
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
        print('🚀 Activating subscription for user: $userId, plan: $planId, amount: RM$amount');
      }

      // Get plan details
      final plan = await _supabase
          .from('subscription_plans')
          .select('duration_days, name, price')
          .eq('id', planId)
          .maybeSingle();

      if (plan == null) {
        throw Exception('Plan not found: $planId');
      }

      final durationDays = plan['duration_days'] ?? 30;
      final planName = plan['name'] ?? 'Unknown Plan';
      final planPrice = double.tryParse(plan['price']?.toString() ?? '0.0') ?? amount;

      // Get user profile
      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      final userName = profile?['full_name'] ?? 'Unknown User';

      // Check existing active subscription - COMPREHENSIVE CHECK
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

      String subscriptionType;
      DateTime startDate;
      DateTime endDate;

      if (existingSubscription != null) {
        if (kDebugMode) {
          print('⚠️ User already has active subscription, EXTENDING...');
          print('📅 Current end date: ${existingSubscription['end_date']}');
          print('➕ Adding $durationDays days');
        }

        // EXTEND existing subscription
        final currentEndDate = DateTime.parse(existingSubscription['end_date']);
        startDate = currentEndDate; // New period starts when current ends
        endDate = currentEndDate.add(Duration(days: durationDays));
        subscriptionType = 'extension';

        // Update existing subscription
        await _supabase
            .from('user_subscriptions')
            .update({
              'end_date': endDate.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'change_type': 'extension',
              'upgrade_reason': 'Subscription extension via payment',
            })
            .eq('id', existingSubscription['id']);

        if (kDebugMode) {
          print('📅 New end date: ${endDate.toIso8601String()}');
        }
      } else {
        if (kDebugMode) {
          print('🆕 No active subscription found, CREATING NEW...');
        }

        // CREATE new subscription
        startDate = now;
        endDate = now.add(Duration(days: durationDays));
        subscriptionType = 'new';

        await _supabase.from('user_subscriptions').insert({
          'user_id': userId,
          'subscription_plan_id': planId,
          'status': 'active',
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'amount': planPrice,
          'currency': 'MYR',
          'user_name': userName,
          'change_type': 'new',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        if (kDebugMode) {
          print('📅 Subscription period: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
        }
      }

      // Create payment record using payments table
      await _supabase.from('payments').insert({
        'user_id': userId,
        'amount_cents': (amount * 100).round(), // Convert to cents
        'currency': 'MYR',
        'status': 'completed',
        'provider': 'toyyibpay',
        'provider_payment_id': transactionId,
        'bill_id': transactionId,
        'plan_id': planId,
        'user_name': userName,
        'description': '$subscriptionType: $planName',
        'paid_at': now.toIso8601String(),
        'activation_type': 'api',
        'metadata': {
          'user_name': userName,
          'plan_name': planName,
          'plan_price': planPrice,
          'subscription_type': subscriptionType,
          'activated_at': now.toIso8601String(),
          'subscription_activation': true,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'duration_days': durationDays,
        },
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      if (kDebugMode) {
        print('✅ Subscription $subscriptionType completed successfully');
        print('💰 Payment recorded: RM${amount.toStringAsFixed(2)}');
        print('📱 Plan: $planName ($durationDays days)');
        print('👤 User: $userName');
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
      if (kDebugMode) {
        print('🔍 SubscriptionService: Fetching subscription plans from database...');
      }

      final result = await _supabase
          .from('subscription_plans')
          .select('*')
          .eq('is_active', true)
          .order('price');

      if (kDebugMode) {
        print('✅ SubscriptionService: Successfully fetched ${result.length} plans');
      }

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      if (kDebugMode) {
        print('❌ SubscriptionService: Error getting subscription plans: $e');
        print('📊 Error details: ${e.runtimeType}');

        // Check if it's an authentication error
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('authretryablefetchexception') ||
            errorString.contains('access token is expired') ||
            errorString.contains('permission denied') ||
            errorString.contains('unauthorized')) {
          print('🔐 SubscriptionService: Authentication error detected');
        } else if (errorString.contains('socketexception') ||
                   errorString.contains('failed host lookup')) {
          print('🌐 SubscriptionService: Network connectivity error detected');
        }
      }
      return [];
    }
  }

  /// DEPRECATED: Store pending payment functionality moved to PaymentProcessingService
  @deprecated
  Future<void> storePendingPayment({
    required String billId,
    required String planId,
    required double amount,
    required String userId,
  }) async {
    if (kDebugMode) {
      print('⚠️ storePendingPayment is deprecated - use PaymentProcessingService instead');
    }
    // No-op - payment records are now handled by PaymentProcessingService
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

  /// Update pending payment status - FIXED to use payments table
  Future<void> updatePendingPaymentStatus(String billId, String status) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Add paid_at timestamp if status is completed
      if (status == 'completed') {
        updateData['paid_at'] = DateTime.now().toUtc().toIso8601String();
        updateData['activation_type'] = 'webhook';
      }

      await _supabase
          .from('payments')
          .update(updateData)
          .eq('bill_id', billId)
          .eq('status', 'pending'); // Only update pending payments

      if (kDebugMode) {
        print('✅ Pending payment status updated: $billId -> $status');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating pending payment status: $e');
      }
      rethrow;
    }
  }
}