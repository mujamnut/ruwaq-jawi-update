import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/services/payment_processing_service.dart';

class PaymentCallbackPage extends StatefulWidget {
  final String billId;
  final String planId;
  final double amount;
  final String? redirectStatus;
  final String? redirectStatusId;

  const PaymentCallbackPage({
    super.key,
    required this.billId,
    required this.planId,
    required this.amount,
    this.redirectStatus,
    this.redirectStatusId,
  });

  @override
  State<PaymentCallbackPage> createState() => _PaymentCallbackPageState();
}

class _PaymentCallbackPageState extends State<PaymentCallbackPage> {
  bool _isVerifying = true;
  bool _paymentSuccess = false;
  String _message = 'Mengesahkan status pembayaran...';
  int _retryCount = 0;
  static const int _maxRetries = 3;

  /// Check if ToyyibPay redirect indicates successful payment
  bool? _isRedirectSuccessful() {
    // ToyyibPay success indicators:
    // status = 'success' AND status_id = '1'  -> Payment successful
    // status = 'success' AND status_id = '2'  -> Payment pending
    // status = 'success' AND status_id = '3'  -> Payment failed
    // status = 'failed' -> Payment failed
    // status = 'cancel' -> Payment cancelled

    if (widget.redirectStatus?.toLowerCase() == 'success' &&
        widget.redirectStatusId == '1') {
      return true;
    }

    if (widget.redirectStatus?.toLowerCase() == 'failed') {
      return false;
    }

    if (widget.redirectStatus?.toLowerCase() == 'cancel' ||
        widget.redirectStatus?.toLowerCase() == 'cancelled') {
      return false;
    }

    return null; // Unknown - need API verification
  }

  /// Centralized payment success handler
  /// Uses PaymentProcessingService for standardized processing
  Future<void> handlePaymentSuccess() async {
    try {
      // Payment record is now automatically created by PaymentProcessingService

      // Use centralized payment processing service
      final paymentService = PaymentProcessingService();
      final result = await paymentService.processPayment(
        billId: widget.billId,
        planId: widget.planId,
        amount: widget.amount,
        redirectStatus: widget.redirectStatus,
        redirectStatusId: widget.redirectStatusId,
        source: PaymentSource.redirect,
      );

      if (result.success) {
        // Comprehensive app refresh after successful payment
        await _refreshAllProviders();
      }

    } catch (e) {
      // Error handling
    }
  }

  /// Refresh all providers after successful payment
  Future<void> _refreshAllProviders() async {
    try {
      // 1. Refresh AuthProvider (subscription status and profile)
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(
          context,
          listen: false,
        );
        await authProvider.checkActiveSubscription();
      }

      // 2. Refresh SubscriptionProvider (subscription data)
      final subscriptionProvider = Provider.of<SubscriptionProvider>(
        context,
        listen: false,
      );
      await subscriptionProvider.loadUserSubscriptions();

      // 3. Refresh KitabProvider (ebook and content data with premium access)
      if (mounted) {
        try {
          final kitabProvider = Provider.of<KitabProvider>(
            context,
            listen: false,
          );
          await kitabProvider.refresh();
        } catch (e) {
          // Error refreshing KitabProvider
        }
      }

    } catch (e) {
      // Error during comprehensive refresh
    }
  }

  @override
  void initState() {
    super.initState();
    _verifyPayment();
  }

  Future<void> _verifyPayment() async {
    try {
      setState(() {
        _isVerifying = true;
        _message = 'Mengesahkan status pembayaran...';
      });

      // Use centralized payment processing service
      final paymentService = PaymentProcessingService();
      final result = await paymentService.processPayment(
        billId: widget.billId,
        planId: widget.planId,
        amount: widget.amount,
        redirectStatus: widget.redirectStatus,
        redirectStatusId: widget.redirectStatusId,
        source: PaymentSource.redirect,
      );

      if (result.success) {
        // Refresh all providers after successful payment
        await _refreshAllProviders();

        setState(() {
          _isVerifying = false;
          _paymentSuccess = true;
          _message = 'Pembayaran berjaya! Langganan anda telah diaktifkan.';
        });

        // Auto navigate after 3 seconds
        await Future.delayed(Duration(seconds: 3));
        if (mounted) {
          context.go('/subscription');
        }

      } else {
        setState(() {
          _isVerifying = false;
          _paymentSuccess = false;

          // Check if payment was cancelled based on redirect status
          final redirectSuccess = _isRedirectSuccessful();
          if (redirectSuccess == false) {
            _message = 'Pembayaran telah dibatalkan. Tiada bayaran dikenakan.';
          } else {
            _message = result.message.isEmpty ? 'Pembayaran tidak berjaya. Tiada bayaran dikenakan.' : result.message;
          }
        });
      }

    } catch (e) {
      setState(() {
        _isVerifying = false;
        _paymentSuccess = false;
        _message = 'Ralat mengesahkan pembayaran: $e';
      });
    }
  }

  Future<void> _retryVerification() async {
    if (_retryCount < _maxRetries) {
      _retryCount++;

      setState(() {
        _isVerifying = true;
        _message = 'Cuba semula... (${_retryCount + 1}/$_maxRetries)';
      });

      // Wait before retry with exponential backoff
      await Future.delayed(Duration(seconds: 2 * _retryCount));

      // Use centralized payment processing service again
      await _verifyPayment();
    } else {
      setState(() {
        _isVerifying = false;
        _message = 'Tidak dapat mengesahkan pembayaran selepas beberapa cubaan. Sila hubungi support.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Status Pembayaran',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Disable back button
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status icon / animations
            if (_isVerifying)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Lottie.asset(
                        'assets/animations/sandy_loading.json',
                        width: 160,
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: 12),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              )
            else if (_paymentSuccess)
              Column(
                children: [
                  Lottie.asset(
                    'assets/animations/success.json',
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                    repeat: false,
                  ),
                  SizedBox(height: 8),
                ],
              )
            else
              Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.orange, size: 80),
                  SizedBox(height: 20),
                ],
              ),

            // Status message (only when not verifying)
            if (!_isVerifying)
              Text(
                _message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),

            if (!_isVerifying) SizedBox(height: 40),

            // Payment details - simplified for better UX
            if (!_isVerifying) // Only show details when not loading
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _paymentSuccess ? Icons.check_circle : Icons.info_outline,
                          color: _paymentSuccess ? Colors.green : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Jumlah: RM${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (_retryCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Cubaan: ${_retryCount + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            SizedBox(height: 40),

            // Action buttons
            if (!_isVerifying) ...[
              if (!_paymentSuccess && _retryCount < _maxRetries)
                ElevatedButton(
                  onPressed: _retryVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text('Cuba Lagi'),
                ),

              SizedBox(height: 16),

              OutlinedButton(
                onPressed: () {
                  context.go('/subscription');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(_paymentSuccess ? 'Lihat Langganan' : 'Kembali'),
              ),
            ],

            if (_retryCount >= _maxRetries && !_paymentSuccess) ...[
              SizedBox(height: 20),
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Jika pembayaran sudah dibuat, ia mungkin mengambil masa untuk diproses. Sila tunggu beberapa minit dan cuba semak semula.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          // DISABLED automatic verification of all payments
                          // This prevents false positive activations
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Sila hubungi support jika pembayaran sebenarnya berjaya',
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                        child: Text('Hubungi Support'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
