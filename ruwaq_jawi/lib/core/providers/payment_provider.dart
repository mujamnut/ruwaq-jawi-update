import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../services/toyyibpay_service.dart';
import '../services/subscription_service.dart';
import '../models/payment_models.dart';
import 'auth_provider.dart';

class PaymentProvider with ChangeNotifier {
  final ToyyibpayService _paymentService;
  final SubscriptionService _subscriptionService;
  AuthProvider? _authProvider;
  bool _isProcessing = false;
  String? _error;
  List<SubscriptionPlan> _subscriptionPlans = [];

  PaymentProvider(this._paymentService, this._subscriptionService);

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  /// Safe method to notify listeners, prevents setState during build
  void _safeNotifyListeners() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  bool get isProcessing => _isProcessing;
  String? get error => _error;
  List<SubscriptionPlan> get subscriptionPlans => _subscriptionPlans;

  Future<Map<String, dynamic>> createPayment({
    required double amount,
    required String userId,
    required String planId,
    required String description,
    required String email,
    required String name,
    String? phone,
  }) async {
    try {
      _isProcessing = true;
      _error = null;
      notifyListeners();

      // Print debug info
      print('Creating payment with email: $email');

      final result = await _paymentService.createBill(
        amount: amount,
        userId: userId,
        planId: planId,
        description: description,
        email: email,
        name: name,
        phone: phone,
      );

      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> checkPaymentStatus(String billCode) async {
    try {
      _isProcessing = true;
      _error = null;
      notifyListeners();

      final status = await _paymentService.getBillStatus(billCode);

      // Check if payment is successful
      if (status['paid'] == true ||
          status['status'] == 'Success' ||
          status['status'] == 'success') {
        // Extract user and plan info from billExternalReferenceNo
        final referenceNo = status['billExternalReferenceNo'] as String;
        final parts = referenceNo.split('_');
        if (parts.length == 2) {
          final userId = parts[0];
          final planId = parts[1];

          print('PaymentProvider: Payment successful, activating subscription...');
          print('PaymentProvider: User ID: $userId, Plan: ${_getPlanType(planId)}');
          
          // Activate subscription
          await _subscriptionService.activateSubscription(
            userId: userId,
            planId: planId,
            amount:
                double.parse(status['billAmount']) / 100, // Convert from cents
            paymentMethod: 'toyyibpay',
            transactionId: status['billpaymentStatus'],
          );
          
          print('PaymentProvider: Subscription activated, refreshing auth provider...');
          
          // Refresh auth provider subscription status
          if (_authProvider != null) {
            await _authProvider!.refreshSubscriptionStatus();
            print('PaymentProvider: Auth provider refreshed');
          } else {
            print('PaymentProvider: Warning - Auth provider not available');
          }
        }
      }

      return status;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  String _getPlanType(String planId) {
    // Convert plan ID to subscription duration - FIXED to match database structure
    switch (planId.toLowerCase()) {
      case 'monthly_basic':
        return '1month';        // ✅ 1 month plan
      case 'quarterly_pr':
        return '3month';        // ✅ 3 months plan
      case 'monthly_premium':
        return '6month';        // ✅ FIXED: monthly_premium is actually 6 month plan in database
      case 'yearly_premium':
        return '12month';       // ✅ 12 months plan
      default:
        return '1month'; // Default to monthly plan
    }
  }

  void clearError() {
    _error = null;
    _safeNotifyListeners();
  }

  /// Load available subscription plans from database
  Future<void> loadSubscriptionPlans() async {
    try {
      print('🚀 PaymentProvider: Starting to load subscription plans...');
      _isProcessing = true;
      _error = null;
      _safeNotifyListeners();

      print('📡 PaymentProvider: Fetching plans from database...');
      // Fetch subscription plans from database
      final plansData = await _subscriptionService.getSubscriptionPlans();

      print('📦 PaymentProvider: Received ${plansData.length} plans from database');
      if (plansData.isEmpty) {
        print('⚠️ PaymentProvider: No plans found in database');
        _error = 'Tiada pelan langganan dijumpai dalam pangkalan data';
        _safeNotifyListeners();
        return;
      }

      print('🔄 PaymentProvider: Converting database records to SubscriptionPlan objects...');
      // Convert database records to SubscriptionPlan objects
      _subscriptionPlans = plansData.map((planData) {
        try {
          final planId = planData['id'] as String;
          final durationDays = planData['duration_days'] as int;
          final price = double.parse(planData['price'].toString());

          print('📋 PaymentProvider: Processing plan $planId - $durationDays days - RM$price');

          return SubscriptionPlan(
            id: planId,
            name: _getLocalizedPlanName(planId, durationDays),
            description: _getPlanDescription(planId, durationDays),
            price: price,
            currency: planData['currency'] as String,
            durationDays: durationDays,
            features: _getPlanFeatures(planId, durationDays),
            isActive: planData['is_active'] as bool,
          );
        } catch (e) {
          print('❌ PaymentProvider: Error processing plan ${planData['id']}: $e');
          throw Exception('Ralat memproses pelan ${planData['id']}: $e');
        }
      }).toList();

      print('✅ PaymentProvider: Successfully loaded ${_subscriptionPlans.length} subscription plans');
      print('📊 PaymentProvider: Plans: ${_subscriptionPlans.map((p) => '${p.name} (${p.id})').join(', ')}');

      _safeNotifyListeners();
    } catch (e) {
      print('❌ PaymentProvider: Error loading subscription plans: $e');
      _error = 'Gagal memuatkan pelan langganan: ${e.toString()}';
      _safeNotifyListeners();
      // Don't rethrow to prevent ErrorBoundary conflicts
    } finally {
      _isProcessing = false;
      print('🏁 PaymentProvider: Finished loading subscription plans (isProcessing: $_isProcessing)');
      _safeNotifyListeners();
    }
  }

  /// Generate localized plan name based on duration
  String _getLocalizedPlanName(String planId, int durationDays) {
    switch (durationDays) {
      case 30:
        return '1 Bulan Premium';
      case 90:
        return '3 Bulan Premium';
      case 180:
        return '6 Bulan Premium';
      case 365:
        return '1 Tahun Premium';
      default:
        return '$durationDays Hari Premium';
    }
  }

  /// Generate plan description with savings information
  String _getPlanDescription(String planId, int durationDays) {
    switch (durationDays) {
      case 30:
        return 'Akses penuh kepada semua kandungan Islam';
      case 90:
        return 'Akses penuh dengan jimat 20%';
      case 180:
        return 'Akses penuh dengan jimat 33%';
      case 365:
        return 'Akses penuh dengan jimat terbanyak';
      default:
        return 'Akses penuh kepada semua kandungan Islam';
    }
  }

  /// Generate plan features based on duration and calculate savings
  List<String> _getPlanFeatures(String planId, int durationDays) {
    final baseFeatures = [
      'Akses kepada 500+ kitab Islam',
      'Video kuliah premium',
      'Muat turun offline',
      'Sokongan keutamaan',
      'Ciri carian lanjutan',
    ];

    switch (durationDays) {
      case 30:
        return baseFeatures;
      case 90:
        return [...baseFeatures, 'Jimat RM 3.80'];
      case 180:
        return [...baseFeatures, 'Jimat RM 13.50'];
      case 365:
        return [...baseFeatures, 'Jimat RM 22.80 (hampir 3 bulan percuma!)'];
      default:
        return baseFeatures;
    }
  }

  /// Create a subscription payment (wrapper around ToyyibpayService.createBill)
  /// Returns a [PaymentResponse] on success or null on failure.
  Future<PaymentResponse?> createSubscriptionPayment({
    required SubscriptionPlan plan,
    required String userEmail,
    required String userName,
    required String userPhone,
    required String redirectUrl,
    required String webhookUrl,
    required String userId,
  }) async {
    try {
      _isProcessing = true;
      _error = null;
      notifyListeners();

      // Ensure phone number is valid
      final phone = userPhone.isNotEmpty ? userPhone : '60123456789';
      print('Creating payment with phone: $phone'); // Debug log

      final result = await _paymentService.createBill(
        amount: plan.price,
        userId: userId,
        planId: plan.id,
        description: '${plan.name} - ${plan.durationDays} days',
        email: userEmail,
        name: userName,
        phone: phone,
      );

      final billCode = result['billCode'] as String?;
      final billUrl = result['billUrl'] as String?;

      if (billCode == null || billUrl == null) {
        _error = 'Invalid bill response';
        notifyListeners();
        return null;
      }

      final payment = PaymentResponse(
        id: billCode,
        url: billUrl,
        status: 'pending',
        referenceNumber: billCode,
        amount: plan.price.toStringAsFixed(2),
        currency: plan.currency,
        createdAt: DateTime.now(),
      );

      return payment;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
