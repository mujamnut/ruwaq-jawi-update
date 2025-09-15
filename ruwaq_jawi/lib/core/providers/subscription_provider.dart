import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../services/subscription_service_new.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  
  Future<void> _initializeSubscriptionService() async {
    // Try to get ToyyibPay credentials from app settings
    String? secretKey;
    String? categoryCode;
    
    try {
      final secretSetting = await SupabaseService.getSetting('toyyibpay_secret_key');
      final categorySetting = await SupabaseService.getSetting('toyyibpay_category_code');
      
      secretKey = secretSetting?.settingValue?['value'];
      categoryCode = categorySetting?.settingValue?['value'];
      
      print('🔑 ToyyibPay credentials loaded: ${secretKey != null ? 'Secret Key found' : 'No secret key'}');
    } catch (e) {
      print('⚠️ Could not load ToyyibPay credentials from settings: $e');
      // Use hardcoded for testing (remove in production!)
      secretKey = 'sandbox_secret_key_here'; // Replace with actual sandbox key
    }
    
    _subscriptionService = SubscriptionService(
      SupabaseService.client,
      toyyibPaySecretKey: secretKey,
      toyyibPayCategoryCode: categoryCode,
    );
  }

  // Getters
  List<Subscription> get subscriptions => _subscriptions;
  List<Transaction> get transactions => _transactions;
  Map<String, dynamic> get subscriptionPlans => _subscriptionPlans;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Subscription? get activeSubscription {
    try {
      return _subscriptions.firstWhere((sub) => sub.isActive);
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

      // Convert to Subscription model format
      _subscriptions = response.map<Subscription>((sub) {
        return Subscription(
          id: sub['id'],
          userId: sub['user_id'],
          planType: sub['subscription_plan_id'] ?? 'unknown',
          startDate: DateTime.parse(sub['start_date']),
          endDate: DateTime.parse(sub['end_date']),
          status: sub['status'],
          paymentMethod: 'toyyibpay', // Default since provider field doesn't exist
          amount: double.parse(sub['amount'].toString()),
          currency: sub['currency'] ?? 'MYR',
          autoRenew: false, // Database doesn't have this field
          createdAt: DateTime.parse(sub['created_at']),
          updatedAt: DateTime.parse(sub['updated_at']),
        );
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

  // Map plan ID to plan type for compatibility
  String _mapPlanIdToType(String planId) {
    switch (planId.toLowerCase()) {
      case 'monthly_basic':
      case 'monthly_premium':
        return '1month';
      case 'quarterly_premium':
        return '3month';
      case 'semiannual_premium':
        return '6month';
      case 'yearly_premium':
        return '12month';
      default:
        return '1month';
    }
  }

  /// Store pending payment untuk di-track
  Future<void> storePendingPayment({
    required String billId,
    required String planId,
    required double amount,
  }) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (_subscriptionService != null) {
        await _subscriptionService!.storePendingPayment(
          billId: billId,
          userId: user.id,
          planId: planId,
          amount: amount,
        );
      } else {
        print('⚠️ SubscriptionService not initialized yet');
        throw Exception('SubscriptionService not initialized');
      }
      
      print('✅ Pending payment stored: $billId');
    } catch (e) {
      print('❌ Error storing pending payment: $e');
      _setError('Failed to store pending payment: $e');
    }
  }

  /// Verify payment status dengan fallback method
  Future<bool> verifyPaymentStatus({
    required String billId,
    required String planId,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final user = SupabaseService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔍 Verifying payment status for Bill ID: $billId');

      // First try: Call verify-payment edge function
      try {
        final response = await http.post(
          Uri.parse('https://ckgxglvozrsognqqkpkk.supabase.co/functions/v1/verify-payment'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${SupabaseService.client.auth.currentSession?.accessToken}',
          },
          body: jsonEncode({
            'billId': billId,
            'userId': user.id,
            'planId': planId,
          }),
        );

        print('📥 Edge function response: ${response.statusCode} - ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['success'] == true) {
            print('🎉 Payment verified via edge function!');
            await loadUserSubscriptions();
            return true;
          } else {
            print('⏳ Edge function says payment not ready: ${data['message']}');
          }
        } else {
          print('⚠️ Edge function failed with ${response.statusCode}');
        }
      } catch (edgeError) {
        print('⚠️ Edge function error: $edgeError');
      }

      // Second try: Direct verification using subscription service
      print('🔄 Falling back to direct verification...');
      if (_subscriptionService == null) {
        print('⚠️ SubscriptionService not initialized, skipping direct verification');
        return false;
      }
      
      final success = await _subscriptionService!.verifyAndActivatePayment(
        billId: billId,
        userId: user.id,
        planId: planId,
      );

      if (success) {
        print('🎉 Payment verified via direct method!');
        
        // Update pending payment status
        await _subscriptionService!.updatePendingPaymentStatus(billId, 'completed');
        
        // Reload subscriptions to reflect changes
        await loadUserSubscriptions();
        return true;
      } else {
        print('⏳ Direct verification also says payment not ready');
        
        // DISABLED: Direct activation fallback
        // Reason: This causes false positive activations for cancelled/failed payments
        // Only use direct activation when explicitly needed via separate method
        print('⚠️ Payment verification failed via API. Direct activation DISABLED to prevent false positives.');
        print('💡 If payment was actually successful, use manual verification or contact support.');
        
        return false;
      }
      
    } catch (e) {
      print('❌ Error verifying payment: $e');
      _setError('Error verifying payment: $e');
      return false;
    } finally {
      _setLoading(false);
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
        
        print('⏳ Verifying payment: $billId');
        await verifyPaymentStatus(
          billId: billId,
          planId: planId,
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
  
  /// Handle payment redirect dari ToyyibPay
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
      
      // If status is success and statusId is 1, activate immediately
      if (status.toLowerCase() == 'success' && statusId == '1') {
        print('🎉 Payment successful from redirect! Activating subscription...');
        
        final user = SupabaseService.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }
        
        // Get plan details to determine amount
        double amount = 6.90; // Default to 1 month price
        try {
          final planDetails = await SupabaseService.from('subscription_plans')
              .select('price')
              .eq('id', planId)
              .maybeSingle();
          if (planDetails != null) {
            amount = double.tryParse(planDetails['price']?.toString() ?? '6.90') ?? 6.90;
          }
        } catch (e) {
          print('⚠️ Could not get plan price: $e');
        }
        
        // Direct activation
        if (_subscriptionService != null) {
          await _subscriptionService!.activateSubscription(
            userId: user.id,
            planId: planId,
            amount: amount,
            paymentMethod: 'toyyibpay',
            transactionId: transactionId,
          );
          
          // Update pending payment status
          await _subscriptionService!.updatePendingPaymentStatus(billCode, 'completed');
        } else {
          throw Exception('SubscriptionService not initialized');
        }
        
        // Reload subscriptions
        await loadUserSubscriptions();
        
        print('✅ Subscription activated successfully from redirect!');
        return true;
      } else {
        print('⚠️ Payment redirect shows non-success status');
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
