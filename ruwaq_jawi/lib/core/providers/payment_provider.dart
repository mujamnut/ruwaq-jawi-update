import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../services/toyyibpay_service.dart';
import '../services/subscription_service.dart';
import '../services/supabase_service.dart';
import '../services/payment_processing_service.dart';
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
      // Debug logging removed

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

      // 🔥 FIXED: Use centralized PaymentProcessingService instead of direct activation
      // Debug logging removed

      // Determine payment status from ToyyibPay response
      String? redirectStatus;
      String? redirectStatusId;

      if (status['paid'] == true || status['status'] == 'Success' || status['status'] == 'success') {
        redirectStatus = 'success';
        redirectStatusId = '1'; // Success
      } else if (status['status'] == 'failed' || status['status'] == 'Failed') {
        redirectStatus = 'failed';
        redirectStatusId = '3'; // Failed
      }

      // Extract user and plan info from billExternalReferenceNo for processing
      String? userId;
      String? planId;
      double amount = 0.0;

      if (status['billExternalReferenceNo'] != null) {
        final referenceNo = status['billExternalReferenceNo'] as String;
        final parts = referenceNo.split('_');
        if (parts.length == 2) {
          userId = parts[0];
          planId = parts[1];
          amount = PaymentAmountHelper.fromCents(int.parse(status['billAmount'].toString())); // 🔥 FIXED: Use helper
        }
      }

      // Use centralized payment processing
      if (userId != null && planId != null) {
        final paymentService = PaymentProcessingService();
        final result = await paymentService.processPayment(
          billId: billCode,
          planId: planId,
          amount: amount,
          redirectStatus: redirectStatus,
          redirectStatusId: redirectStatusId,
          source: PaymentSource.redirect,
        );

        // Debug logging removed
        // Debug logging removed

        // Refresh auth provider if payment was successful
        if (result.success && _authProvider != null) {
          await _authProvider!.refreshSubscriptionStatus();
          // Debug logging removed
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

  
  void clearError() {
    _error = null;
    _safeNotifyListeners();
  }

  /// Load available subscription plans from database
  Future<void> loadSubscriptionPlans() async {
    try {
      // Debug logging removed
      _isProcessing = true;
      _error = null;
      _safeNotifyListeners();

      // Debug logging removed
      // Fetch subscription plans from database with enhanced error handling and retry mechanism
      final plansData = await SupabaseService.retryOperation<List<Map<String, dynamic>>>(
        () => _subscriptionService.getSubscriptionPlans().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            // Debug logging removed
            throw Exception('Masa tamat semasa memuatkan pelan. Sila semak sambungan internet.');
          },
        ),
        maxRetries: 3,
        delay: const Duration(seconds: 1),
        operationName: 'Load subscription plans',
      );

      // Debug logging removed
      if (plansData.isEmpty) {
        // Debug logging removed
        _error = 'Tiada pelan langganan dijumpai dalam pangkalan data';
        _safeNotifyListeners();
        return;
      }

      // Debug logging removed
      // Convert database records to SubscriptionPlan objects
      _subscriptionPlans = plansData.map((planData) {
        try {
          final planId = planData['id'] as String;
          final durationDays = planData['duration_days'] as int;
          final price = double.parse(planData['price'].toString());

          // Debug logging removed

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
          // Debug logging removed
          throw Exception('Ralat memproses pelan ${planData['id']}: $e');
        }
      }).toList();

      // Debug logging removed
      // Debug logging removed

      _safeNotifyListeners();
    } catch (e) {
      // Debug logging removed

      // Enhanced error handling for different error types
      String errorMessage = 'Gagal memuatkan pelan langganan: ${e.toString()}';
      final errorString = e.toString().toLowerCase();

      if (errorString.contains('socketexception') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('no address associated with hostname')) {
        errorMessage = 'Tiada sambungan internet. Sila semak sambungan anda dan cuba lagi.';
      } else if (errorString.contains('timeout')) {
        errorMessage = 'Masa tamat. Sila semak sambungan internet dan cuba lagi.';
      } else if (errorString.contains('authretryablefetchexception') ||
                 errorString.contains('access token is expired')) {
        errorMessage = 'Sesi telah tamat. Sila log masuk semula.';
      } else if (errorString.contains('permission denied') ||
                 errorString.contains('unauthorized')) {
        errorMessage = 'Ralat kebenaran. Sila log masuk semula.';
      }

      _error = errorMessage;
      _safeNotifyListeners();
      // Don't rethrow to prevent ErrorBoundary conflicts
    } finally {
      _isProcessing = false;
      // Debug logging removed
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
      // Debug logging removed // Debug log

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

      // ✅ REMOVED: Payment record creation now handled by PaymentProcessingService
      // This eliminates duplicate payment records and race conditions
      // Debug logging removed

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
