import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/subscription.dart';
import '../models/transaction.dart';
import '../services/subscription_service.dart';
import '../services/supabase_service.dart';

class SubscriptionProvider with ChangeNotifier {
  List<Subscription> _subscriptions = [];
  List<Transaction> _transactions = [];
  Map<String, dynamic> _subscriptionPlans = {};
  bool _isLoading = false;
  String? _error;
  SubscriptionService? _subscriptionService;

  SubscriptionProvider() {
    _initializeSubscriptionService();
  }

  // Add getter to check if service is ready
  bool get isServiceReady => _subscriptionService != null;
  
  Future<void> _initializeSubscriptionService() async {
    // Try to get ToyyibPay credentials from app settings
    String? secretKey;

    try {
      final secretSetting = await SupabaseService.getSetting('toyyibpay_secret_key');

      secretKey = secretSetting?.settingValue?['value'];

      print('🔑 ToyyibPay credentials loaded: ${secretKey != null ? 'Secret Key found' : 'No secret key'}');
    } catch (e) {
      print('⚠️ Could not load ToyyibPay credentials from settings: $e');
      // Use hardcoded for testing (remove in production!)
      secretKey = 'sandbox_secret_key_here'; // Replace with actual sandbox key
    }

    // Always initialize SubscriptionService, even without credentials
    _subscriptionService = SubscriptionService(
      SupabaseService.client,
      toyyibPaySecretKey: secretKey,
    );

    print('✅ SubscriptionService initialized successfully');
  }

  // Getters
  List<Subscription> get subscriptions => _subscriptions;
  List<Transaction> get transactions => _transactions;
  Map<String, dynamic> get subscriptionPlans => _subscriptionPlans;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Subscription? get activeSubscription {
    try {
      // Find subscription that is actually active (not expired)
      final now = DateTime.now().toUtc();
      return _subscriptions.firstWhere((sub) {
        return sub.isActive && sub.endDate.isAfter(now);
      });
    } catch (e) {
      return null;
    }
  }

  bool get hasActiveSubscription => activeSubscription != null;

  // Load user's subscription data from subscriptions table
  Future<void> loadUserSubscriptions() async {
    try {
      _setLoading(true);
      _clearError();

      // Use subscriptions table
      final user = SupabaseService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await SupabaseService.from('user_subscriptions')
          .select('*, subscription_plans(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Convert to Subscription model format using fromJson
      _subscriptions = response.map<Subscription>((sub) {
        return Subscription.fromJson(sub);
      }).toList();

      // Load transactions (keep this as is)
      final transactions = await SupabaseService.getUserTransactions();
      _transactions = transactions;

    } catch (e) {
      _setError('Ralat memuatkan data langganan: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Load subscription plans from app settings
  Future<void> loadSubscriptionPlans() async {
    try {
      final plansSetting = await SupabaseService.getSetting(
        'subscription_plans',
      );
      if (plansSetting?.settingValue != null) {
        _subscriptionPlans = plansSetting!.settingValue!;
        }
    } catch (e) {
      // Use default plans if loading fails - Updated prices to match database
      _subscriptionPlans = {
        '1month': {'price': 6.90, 'currency': 'MYR', 'name': '1 Bulan'},
        '3month': {'price': 6.90, 'currency': 'MYR', 'name': '3 Bulan'}, // Keep this if exists
        '6month': {'price': 27.90, 'currency': 'MYR', 'name': '6 Bulan'},
        '12month': {'price': 60.00, 'currency': 'MYR', 'name': '1 Tahun'},
      };
    }
  }

  // Create a new subscription
  Future<String> createSubscription({
    required String planType,
    required String paymentMethod,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = SupabaseService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final plan = _subscriptionPlans[planType];
      if (plan == null) {
        throw Exception('Invalid plan type: $planType');
      }

      final now = DateTime.now();
      final endDate = _calculateEndDate(now, planType);

      // Create subscription record
      final subscriptionData = {
        'user_id': user.id,
        'plan_type': planType,
        'start_date': now.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'status': 'pending',
        'amount': plan['price'],
        'currency': plan['currency'] ?? 'MYR',
        'payment_method': paymentMethod,
        'auto_renew': false,
      };

      final response = await SupabaseService.from(
        'subscriptions',
      ).insert(subscriptionData).select().single();

      final subscription = Subscription.fromJson(response);

      // Create transaction record
      final transaction = await SupabaseService.createTransaction(
        subscriptionId: subscription.id,
        amount: plan['price'],
        paymentMethod: paymentMethod,
        currency: plan['currency'] ?? 'MYR',
        metadata: {
          'plan_type': planType,
          'user_id': user.id,
          'subscription_id': subscription.id,
        },
      );

      // Add to local state
      _subscriptions.insert(0, subscription);
      _transactions.insert(0, transaction);

      return subscription.id;
    } catch (e) {
      _setError('Ralat membuat langganan: ${e.toString()}');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Cancel subscription
  Future<void> cancelSubscription(String subscriptionId) async {
    try {
      _setLoading(true);
      _clearError();

      await SupabaseService.from('user_subscriptions')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId);

      // Update local state
      final index = _subscriptions.indexWhere(
        (sub) => sub.id == subscriptionId,
      );
      if (index != -1) {
        _subscriptions[index] = _subscriptions[index].copyWith(
          status: 'cancelled',
          updatedAt: DateTime.now(),
        );
      }

    } catch (e) {
      _setError('Ralat membatalkan langganan: ${e.toString()}');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Get plan details
  Map<String, dynamic>? getPlanDetails(String planType) {
    return _subscriptionPlans[planType];
  }

  // Calculate subscription end date
  DateTime _calculateEndDate(DateTime startDate, String planType) {
    switch (planType) {
      case '1month':
        return startDate.add(const Duration(days: 30));
      case '3month':
        return startDate.add(const Duration(days: 90));
      case '6month':
        return startDate.add(const Duration(days: 180));
      case '12month':
        return startDate.add(const Duration(days: 365));
      default:
        return startDate.add(const Duration(days: 30));
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  void _setError(String error) {
    _error = error;
  }

  void _clearError() {
    _error = null;
  }

  void clearData() {
    _subscriptions.clear();
    _transactions.clear();
    _subscriptionPlans.clear();
    _isLoading = false;
    _error = null;
  }


  /// DEPRECATED: Store pending payment functionality moved to PaymentProcessingService
  /// This method is kept for backward compatibility only
  @deprecated
  Future<void> storePendingPayment({
    required String billId,
    required String planId,
    required double amount,
  }) async {
    print('⚠️ storePendingPayment is deprecated - payment records are now handled automatically by PaymentProcessingService');
    // No-op - payment records are now handled by PaymentProcessingService
  }

  /// Verify payment status using separated Edge Functions (NEW ARCHITECTURE)
  Future<bool> verifyPaymentStatus({
    required String billId,
    required String planId,
    required double amount,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = SupabaseService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 === NEW PAYMENT VERIFICATION FLOW ===');
      print('📋 Bill ID: $billId');
      print('📋 Plan ID: $planId');
      print('📋 Amount: RM$amount');

      // STEP 1: Verify payment with verify-payment Edge Function (v31)
      print('🔍 STEP 1: Verifying payment status...');
      final paymentResult = await _verifyPaymentOnly(
        billId: billId,
        userId: user.id,
        planId: planId,
      );

      if (!paymentResult['success']) {
        print('❌ PAYMENT VERIFICATION FAILED');
        print('   Reason: ${paymentResult['message']}');
        print('   Status: ${paymentResult['paymentStatus']}');
        return false;
      }

      print('✅ PAYMENT VERIFICATION SUCCESSFUL');
      print('   Status: ${paymentResult['paymentStatus']}');
      print('   Amount: RM${paymentResult['paymentData']['amount']}');

      // STEP 2: Activate/Extend subscription
      print('🔁 STEP 2: Activating/Extending subscription...');

      // Check if user has existing active subscription
      final hasExistingSubscription = await _hasActiveSubscription(user.id);

      bool activationSuccess = false;

      if (hasExistingSubscription) {
        print('🔄 User has existing subscription - Using extend-subscription...');
        activationSuccess = await _extendSubscription(
          userId: user.id,
          planId: planId,
          paymentData: paymentResult['paymentData'],
        );
      } else {
        print('🆕 User has no active subscription - Using activate-subscription...');
        activationSuccess = await _activateSubscription(
          userId: user.id,
          planId: planId,
          paymentData: paymentResult['paymentData'],
        );
      }

      if (activationSuccess) {
        print('✅ SUBSCRIPTION ACTIVATION SUCCESSFUL');
        // Reload subscriptions to reflect changes
        await loadUserSubscriptions();
        print('✅ User data refreshed');
        return true;
      } else {
        print('❌ SUBSCRIPTION ACTIVATION FAILED');
        return false;
      }

    } catch (e) {
      print('❌ Error in payment verification flow: $e');
      _setError('Error verifying payment: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// STEP 1: Verify payment only (using verify-payment v31)
  Future<Map<String, dynamic>> _verifyPaymentOnly({
    required String billId,
    required String userId,
    required String planId,
  }) async {
    try {
      final requestBody = jsonEncode({
        'billId': billId,
        'userId': userId,
        'planId': planId,
      });

      print('📤 Calling verify-payment Edge Function (v31)...');

      final response = await http.post(
        Uri.parse('https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/verify-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseService.client.auth.currentSession?.accessToken}',
        },
        body: requestBody,
      );

      print('📥 verify-payment Response:');
      print('   Status: ${response.statusCode}');
      print('   Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('✅ Payment verification completed');
          print('   Success: ${data['success']}');
          print('   Status: ${data['paymentStatus']}');
          print('   Message: ${data['message']}');
          return data;
        } catch (jsonError) {
          print('❌ Failed to parse verify-payment response: $jsonError');
          return {'success': false, 'error': 'Invalid response format'};
        }
      } else {
        print('❌ verify-payment HTTP Error: ${response.statusCode}');
        return {'success': false, 'error': 'HTTP error ${response.statusCode}'};
      }
    } catch (error) {
      print('❌ verify-payment request error: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// STEP 2: Extend existing subscription (using extend-subscription)
  Future<bool> _extendSubscription({
    required String userId,
    required String planId,
    required Map<String, dynamic> paymentData,
  }) async {
    try {
      final requestBody = jsonEncode({
        'userId': userId,
        'planId': planId,
        'paymentData': paymentData,
      });

      print('📤 Calling extend-subscription Edge Function...');

      final response = await http.post(
        Uri.parse('https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/extend-subscription'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseService.client.auth.currentSession?.accessToken}',
        },
        body: requestBody,
      );

      print('📥 extend-subscription Response:');
      print('   Status: ${response.statusCode}');
      print('   Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('✅ Subscription extension completed');
          print('   Success: ${data['success']}');
          print('   Action: ${data['action']}');
          print('   Message: ${data['message']}');
          print('   Days Added: ${data['daysAdded'] ?? 0}');
          return data['success'] ?? false;
        } catch (jsonError) {
          print('❌ Failed to parse extend-subscription response: $jsonError');
          return false;
        }
      } else {
        print('❌ extend-subscription HTTP Error: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      print('❌ extend-subscription request error: $error');
      return false;
    }
  }

  /// STEP 2: Activate new subscription (using activate-subscription)
  Future<bool> _activateSubscription({
    required String userId,
    required String planId,
    required Map<String, dynamic> paymentData,
  }) async {
    try {
      final requestBody = jsonEncode({
        'userId': userId,
        'planId': planId,
        'paymentData': paymentData,
      });

      print('📤 Calling activate-subscription Edge Function...');

      final response = await http.post(
        Uri.parse('https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/activate-subscription'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseService.client.auth.currentSession?.accessToken}',
        },
        body: requestBody,
      );

      print('📥 activate-subscription Response:');
      print('   Status: ${response.statusCode}');
      print('   Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('✅ Subscription activation completed');
          print('   Success: ${data['success']}');
          print('   Action: ${data['action']}');
          print('   Message: ${data['message']}');
          print('   Days Added: ${data['daysAdded'] ?? 0}');
          return data['success'] ?? false;
        } catch (jsonError) {
          print('❌ Failed to parse activate-subscription response: $jsonError');
          return false;
        }
      } else {
        print('❌ activate-subscription HTTP Error: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      print('❌ activate-subscription request error: $error');
      return false;
    }
  }

  /// Check if user has active subscription
  Future<bool> _hasActiveSubscription(String userId) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return false;

      final response = await SupabaseService.from('user_subscriptions')
          .select('*')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return false;

      final subscription = response.first;
      final now = DateTime.now().toUtc();
      final endDate = DateTime.parse(subscription['end_date']).toUtc();

      return endDate.isAfter(now);
    } catch (e) {
      print('⚠️ Error checking active subscription: $e');
      return false;
    }
  }

  /// Check jika ada pending payments untuk user
  Future<List<Map<String, dynamic>>> getPendingPayments() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return [];

      // Use payments table with pending status instead of non-existent pending_payments table
      final response = await SupabaseService.from('payments')
          .select('*')
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting pending payments: $e');
      return [];
    }
  }

  /// Verify all pending payments untuk user
  Future<void> verifyAllPendingPayments() async {
    try {
      _setLoading(true);
      
      final pendingPayments = await getPendingPayments();
      print('🔍 Found ${pendingPayments.length} pending payments');
      
      for (final payment in pendingPayments) {
        final billId = payment['bill_id'];
        final planId = payment['plan_id'];
        final amount = payment['amount']?.toDouble() ?? 0.0;

        print('⏳ Verifying payment: $billId');
        await verifyPaymentStatus(
          billId: billId,
          planId: planId,
          amount: amount,
        );
        
        // Small delay antara requests
        await Future.delayed(Duration(milliseconds: 500));
      }
      
    } catch (e) {
      print('❌ Error verifying pending payments: $e');
      _setError('Error verifying payments: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Handle payment redirect dari ToyyibPay - OPTIMIZED
  /// Guna method ini bila user di-redirect balik dari ToyyibPay
  Future<bool> handlePaymentRedirect({
    required String billCode,
    required String status,
    required String statusId,
    required String transactionId,
    required String planId,
  }) async {
    try {
      print('🔄 Processing payment redirect:');
      print('  Bill Code: $billCode');
      print('  Status: $status');
      print('  Status ID: $statusId');
      print('  Transaction ID: $transactionId');
      print('  Plan ID: $planId');

      // Only activate if status is success and statusId is 1
      if (status.toLowerCase() == 'success' && statusId == '1') {
        print('🎉 Payment successful from redirect! Activating subscription...');

        final user = SupabaseService.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        // Get plan details to determine amount
        double amount = 6.90; // Default fallback
        String planName = 'Unknown Plan';

        try {
          final planDetails = await SupabaseService.from('subscription_plans')
              .select('price, name')
              .eq('id', planId)
              .maybeSingle();
          if (planDetails != null) {
            amount = double.tryParse(planDetails['price']?.toString() ?? '6.90') ?? 6.90;
            planName = planDetails['name'] ?? 'Unknown Plan';
          }
        } catch (e) {
          print('⚠️ Could not get plan details: $e');
        }

        print('💰 Plan: $planName (RM${amount.toStringAsFixed(2)})');

        // Check if user already has active subscription
        final hasExisting = await _hasActiveSubscription(user.id);
        print('📱 User has existing subscription: $hasExisting');

        // Use SubscriptionService for activation (handles both new and extension)
        if (_subscriptionService != null) {
          print('🚀 Activating subscription via SubscriptionService...');

          await _subscriptionService!.activateSubscription(
            userId: user.id,
            planId: planId,
            amount: amount,
            paymentMethod: 'toyyibpay',
            transactionId: transactionId,
          );

          // Update pending payment status if exists
          try {
            await _subscriptionService!.updatePendingPaymentStatus(billCode, 'completed');
            print('✅ Pending payment status updated');
          } catch (e) {
            print('⚠️ Could not update pending payment status (may not exist): $e');
          }

        } else {
          throw Exception('SubscriptionService not initialized');
        }

        // Reload subscriptions to reflect changes
        await loadUserSubscriptions();

        print('✅ Subscription activated successfully from redirect!');
        print('🎯 Type: ${hasExisting ? 'Extension' : 'New subscription'}');
        return true;
      } else {
        print('⚠️ Payment redirect shows non-success status: $status (ID: $statusId)');
        return false;
      }
    } catch (e) {
      print('❌ Error handling payment redirect: $e');
      _setError('Error processing payment: $e');
      return false;
    }
  }
  
  /// Manual direct activation - ONLY use when payment is confirmed successful
  /// This method should be called explicitly, not as automatic fallback
  Future<bool> manualDirectActivation({
    required String billId,
    required String planId,
    required String userId,
    required String reason,
    double? amount, // Optional amount parameter
  }) async {
    try {
      print('🔧 Attempting direct activation for bill: $billId');
      
      // Use passed amount or get plan details to determine amount
      double finalAmount = amount ?? 6.90; // Use passed amount or default fallback

      if (amount == null) {
        // Only fetch from database if amount not provided
        try {
          final planDetails = await SupabaseService.from('subscription_plans')
              .select('price')
              .eq('id', planId)
              .maybeSingle();
          if (planDetails != null) {
            finalAmount = double.tryParse(planDetails['price']?.toString() ?? '6.90') ?? 6.90;
          }
        } catch (e) {
          print('⚠️ Could not get plan price for direct activation: $e');
        }
      }

      print('💰 Using amount: RM${finalAmount.toStringAsFixed(2)} for activation');
      
      // Call fixed direct activation edge function
      final response = await http.post(
        Uri.parse('https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/direct-activation-fixed'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseService.client.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'billId': billId,
          'userId': userId,
          'planId': planId,
          'transactionId': 'direct_${DateTime.now().millisecondsSinceEpoch}',
          'amount': finalAmount,
          'reason': reason
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        print('❌ Direct activation HTTP error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error in direct activation: $e');
      return false;
    }
  }
}
