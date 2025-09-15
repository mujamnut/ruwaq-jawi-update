import 'package:flutter/foundation.dart';
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
            planType: _getPlanType(planId),
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
    notifyListeners();
  }

  /// Load available subscription plans
  Future<void> loadSubscriptionPlans() async {
    try {
      _isProcessing = true;
      _error = null;
      notifyListeners();

      // Updated to match ACTUAL database structure - Fix plan ID mapping
      _subscriptionPlans = [
        SubscriptionPlan(
          id: 'monthly_basic',  // ← FIXED: Use actual 1 month plan ID from database
          name: '1 Bulan Premium',
          description: 'Akses penuh kepada semua kandungan Islam',
          price: 6.90,
          currency: 'MYR',
          durationDays: 30,
          features: [
            'Akses kepada 500+ kitab Islam',
            'Video kuliah premium',
            'Muat turun offline',
            'Sokongan keutamaan',
            'Ciri carian lanjutan',
          ],
          isActive: true,
        ),
        SubscriptionPlan(
          id: 'quarterly_pr',
          name: '3 Bulan Premium',
          description: 'Akses penuh dengan jimat 20%',
          price: 17.90,
          currency: 'MYR',
          durationDays: 90,
          features: [
            'Akses kepada 500+ kitab Islam',
            'Video kuliah premium',
            'Muat turun offline',
            'Sokongan keutamaan',
            'Ciri carian lanjutan',
            'Jimat RM 3.80',
          ],
          isActive: true,
        ),
        SubscriptionPlan(
          id: 'monthly_premium',  // ← FIXED: Database "monthly_premium" is actually 6 month plan
          name: '6 Bulan Premium',
          description: 'Akses penuh dengan jimat 33%',
          price: 27.90,
          currency: 'MYR',
          durationDays: 180, // ✅ FIXED: 6 months should be 180 days
          features: [
            'Akses kepada 500+ kitab Islam',
            'Video kuliah premium',
            'Muat turun offline',
            'Sokongan keutamaan',
            'Ciri carian lanjutan',
            'Jimat RM 13.50',
          ],
          isActive: true,
        ),
        SubscriptionPlan(
          id: 'yearly_premium',
          name: '1 Tahun Premium',
          description: 'Akses penuh dengan jimat terbanyak',
          price: 60.00,
          currency: 'MYR',
          durationDays: 365,
          features: [
            'Akses kepada 500+ kitab Islam',
            'Video kuliah premium',
            'Muat turun offline',
            'Sokongan keutamaan',
            'Ciri carian lanjutan',
            'Jimat RM 22.80 (hampir 3 bulan percuma!)',
          ],
          isActive: true,
        ),
      ];

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
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
