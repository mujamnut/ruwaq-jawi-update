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

      // Debug logging removed
    } catch (e) {
      // Debug logging removed
      // Use hardcoded for testing (remove in production!)
      secretKey = 'sandbox_secret_key_here'; // Replace with actual sandbox key
    }

    // Always initialize SubscriptionService, even without credentials
    _subscriptionService = SubscriptionService(
      SupabaseService.client,
      toyyibPaySecretKey: secretKey,
    );

    // Debug logging removed
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
    // Debug logging removed
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

      // Debug logging removed
      // Debug logging removed
      // Debug logging removed
      // Debug logging removed

      // STEP 1: Verify payment with verify-payment Edge Function (v31)
      // Debug logging removed
      final paymentResult = await _verifyPaymentOnly(
        billId: billId,
        userId: user.id,
        planId: planId,
      );

      if (!paymentResult['success']) {
        // Debug logging removed
        // Debug logging removed
        // Debug logging removed
        return false;
      }

      // Debug logging removed
      // Debug logging removed
      // Debug logging removed

      // STEP 2: Activate/Extend subscription
      // Debug logging removed

      // Check if user has existing active subscription
      final hasExistingSubscription = await _hasActiveSubscription(user.id);

      bool activationSuccess = false;

      if (hasExistingSubscription) {
        // Debug logging removed
        activationSuccess = await _extendSubscription(
          userId: user.id,
          planId: planId,
          paymentData: paymentResult['paymentData'],
        );
      } else {
        // Debug logging removed
        activationSuccess = await _activateSubscription(
          userId: user.id,
          planId: planId,
          paymentData: paymentResult['paymentData'],
        );
      }

      if (activationSuccess) {
        // Debug logging removed
        // Reload subscriptions to reflect changes
        await loadUserSubscriptions();
        // Debug logging removed
        return true;
      } else {
        // Debug logging removed
        return false;
      }

    } catch (e) {
      // Debug logging removed
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

      // Debug logging removed

      final response = await http.post(
        Uri.parse('https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/verify-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseService.client.auth.currentSession?.accessToken}',
        },
        body: requestBody,
      );

      // Debug logging removed
      // Debug logging removed
      // Debug logging removed

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          // Debug logging removed
          // Debug logging removed
          // Debug logging removed
          // Debug logging removed
          return data;
        } catch (jsonError) {
          // Debug logging removed
          return {'success': false, 'error': 'Invalid response format'};
        }
      } else {
        // Debug logging removed
        return {'success': false, 'error': 'HTTP error ${response.statusCode}'};
      }
    } catch (error) {
      // Debug logging removed
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

      // Debug logging removed

      final response = await http.post(
        Uri.parse('https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/extend-subscription'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseService.client.auth.currentSession?.accessToken}',
        },
        body: requestBody,
      );

      // Debug logging removed
      // Debug logging removed
      // Debug logging removed

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          // Debug logging removed
          // Debug logging removed
          // Debug logging removed
          // Debug logging removed
          // Debug logging removed
          return data['success'] ?? false;
        } catch (jsonError) {
          // Debug logging removed
          return false;
        }
      } else {
        // Debug logging removed
        return false;
      }
    } catch (error) {
      // Debug logging removed
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

      // Debug logging removed

      final response = await http.post(
        Uri.parse('https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/activate-subscription'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseService.client.auth.currentSession?.accessToken}',
        },
        body: requestBody,
      );

      // Debug logging removed
      // Debug logging removed
      // Debug logging removed

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          // Debug logging removed
          // Debug logging removed
          // Debug logging removed
          // Debug logging removed
          // Debug logging removed
          return data['success'] ?? false;
        } catch (jsonError) {
          // Debug logging removed
          return false;
        }
      } else {
        // Debug logging removed
        return false;
      }
    } catch (error) {
      // Debug logging removed
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
      // Debug logging removed
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
      // Debug logging removed
      return [];
    }
  }

  /// Verify all pending payments untuk user
  Future<void> verifyAllPendingPayments() async {
    try {
      _setLoading(true);
      
      final pendingPayments = await getPendingPayments();
      // Debug logging removed
      
      for (final payment in pendingPayments) {
        final billId = payment['bill_id'];
        final planId = payment['plan_id'];
        final amount = payment['amount']?.toDouble() ?? 0.0;

        // Debug logging removed
        await verifyPaymentStatus(
          billId: billId,
          planId: planId,
          amount: amount,
        );
        
        // Small delay antara requests
        await Future.delayed(Duration(milliseconds: 500));
      }
      
    } catch (e) {
      // Debug logging removed
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
      // Debug logging removed
      // Debug logging removed
      // Debug logging removed
      // Debug logging removed
      // Debug logging removed
      // Debug logging removed

      // Only activate if status is success and statusId is 1
      if (status.toLowerCase() == 'success' && statusId == '1') {
        // Debug logging removed

        final user = SupabaseService.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        // Get plan details to determine amount
        double amount = 6.90; // Default fallback

        try {
          final planDetails = await SupabaseService.from('subscription_plans')
              .select('price')
              .eq('id', planId)
              .maybeSingle();
          if (planDetails != null) {
            amount = double.tryParse(planDetails['price']?.toString() ?? '6.90') ?? 6.90;
          }
        } catch (e) {
          // Debug logging removed
        }

        // Debug logging removed

        // Check if user already has active subscription
        await _hasActiveSubscription(user.id);
        // Debug logging removed

        // Use SubscriptionService for activation (handles both new and extension)
        if (_subscriptionService != null) {
          // Debug logging removed

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
            // Debug logging removed
          } catch (e) {
            // Debug logging removed
          }

        } else {
          throw Exception('SubscriptionService not initialized');
        }

        // Reload subscriptions to reflect changes
        await loadUserSubscriptions();

        // Debug logging removed
        // Debug logging removed
        return true;
      } else {
        // Debug logging removed
        return false;
      }
    } catch (e) {
      // Debug logging removed
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
      // Debug logging removed
      
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
          // Debug logging removed
        }
      }

      // Debug logging removed
      
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
        // Debug logging removed
        return false;
      }
    } catch (e) {
      // Debug logging removed
      return false;
    }
  }
}
