import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/unified_notification_service.dart';

class PaymentCallbackPage extends StatefulWidget {
  final String billId;
  final String planId;
  final double amount;

  const PaymentCallbackPage({
    super.key,
    required this.billId,
    required this.planId,
    required this.amount,
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

      final subscriptionProvider = Provider.of<SubscriptionProvider>(
        context,
        listen: false,
      );

      // Store pending payment first jika belum ada
      try {
        await subscriptionProvider.storePendingPayment(
          billId: widget.billId,
          planId: widget.planId,
          amount: widget.amount,
        );
      } catch (e) {
        print('! Error storing pending payment (non-critical): $e');
      }

      print('🔍 Payment callback reached - VERIFYING actual payment status...');
      print(
        '📋 Bill ID: ${widget.billId}, Plan: ${widget.planId}, Amount: RM${widget.amount}',
      );

      // CRITICAL: VERIFY PAYMENT STATUS BEFORE ACTIVATION
      bool success = false; // Default to failed, must verify first

      // MANDATORY: Verify payment with ToyyibPay API first
      print('🔍 Step 1: Verifying payment status with ToyyibPay API...');
      final paymentVerified = await subscriptionProvider.verifyPaymentStatus(
        billId: widget.billId,
        planId: widget.planId,
        amount: widget.amount,
      );

      if (paymentVerified) {
        print('✅ Payment VERIFIED successful via API!');
        success = true;

        // Now proceed with activation
        try {
          final user = SupabaseService.currentUser;
          if (user != null) {
            print('🎯 Payment verified - proceeding with subscription activation...');

            // Try direct activation only after payment verification
            final activationResult = await subscriptionProvider
                .manualDirectActivation(
                  billId: widget.billId,
                  planId: widget.planId,
                  userId: user.id,
                  amount: widget.amount,
                  reason:
                      'Payment VERIFIED successful via ToyyibPay API - Bill: ${widget.billId} - Amount: RM${widget.amount}',
                );

            if (activationResult) {
              print('✅ Subscription activated after payment verification!');

              // COMPREHENSIVE REFRESH - Update all providers after successful payment
              try {
                print('🔄 Starting comprehensive app refresh after payment verification...');

              // 0. Insert payment success notification to database
              try {
                // Get current user ID
                final currentUser = UnifiedNotificationService.currentUserId;
                if (currentUser != null) {
                  final notificationSuccess = await UnifiedNotificationService.createIndividualNotification(
                    userId: currentUser,
                    title: 'Pembayaran Berjaya! 🎉',
                    body: 'Terima kasih! Pembayaran RM${widget.amount} untuk langganan ${widget.planId} telah berjaya. Langganan anda kini aktif.',
                    type: 'payment_success',
                    metadata: {
                      'bill_id': widget.billId,
                      'plan_id': widget.planId,
                      'amount': widget.amount.toString(),
                      'payment_date': DateTime.now().toIso8601String(),
                      'action_url': '/subscription',
                    },
                  );

                  if (notificationSuccess) {
                    print('✅ Payment notification inserted to database successfully');
                  } else {
                    print('❌ Failed to insert payment notification to database');
                  }
                } else {
                  print('❌ No current user found, cannot insert payment notification');
                }
              } catch (e) {
                print('❌ Error inserting payment notification: $e');
              }

              // 1. Refresh AuthProvider (subscription status and profile)
              if (mounted) {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                await authProvider.checkActiveSubscription();
                print('✅ AuthProvider refreshed - subscription status updated');
              }

              // 2. Refresh SubscriptionProvider (subscription data)
              await subscriptionProvider.loadUserSubscriptions();
              print('✅ SubscriptionProvider refreshed - subscription data updated');

              // 3. Refresh KitabProvider (ebook and content data with premium access)
              if (mounted) {
                try {
                  final kitabProvider = Provider.of<KitabProvider>(
                    context,
                    listen: false,
                  );
                  await kitabProvider.refresh();
                  print('✅ KitabProvider refreshed - content premium access updated');
                } catch (e) {
                  print('⚠️ Error refreshing KitabProvider: $e');
                }
              }

              print('🎉 All providers refreshed successfully!');
            } catch (e) {
              print('⚠️ Error during comprehensive refresh: $e');
            }
          } else {
            print('❌ Subscription activation failed after payment verification');
            success = false; // If activation fails, mark as failed
          }
        } else {
          print('❌ User not authenticated - cannot activate subscription');
          success = false;
        }
      } catch (e) {
        print('❌ Error during activation: $e');
        success = false; // If error during activation, mark as failed
      }
      } else {
        print('❌ Payment verification FAILED - payment was not successful');
        print('💡 This could be a cancelled or failed payment');
        success = false;
      }

      if (success) {
        print('🎉 Payment verified and activated successfully!');
      } else {
        print('❌ Payment process failed - no charges applied');
      }

      setState(() {
        _isVerifying = false;
        _paymentSuccess = success;

        if (success) {
          _message = 'Pembayaran berjaya! Langganan anda telah diaktifkan.';
        } else {
          _message =
              'Pembayaran tidak berjaya atau dibatalkan. Tiada bayaran dikenakan.';
        }
      });

      if (success) {
        // Auto navigate selepas 3 seconds
        await Future.delayed(Duration(seconds: 3));
        if (mounted) {
          context.go('/subscription');
        }
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
      await Future.delayed(Duration(seconds: 2)); // Wait before retry
      await _verifyPayment();
    } else {
      setState(() {
        _message =
            'Tidak dapat mengesahkan pembayaran selepas beberapa cubaan. Sila hubungi support.';
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
            // Status icon
            if (_isVerifying)
              Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              )
            else if (_paymentSuccess)
              Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 80),
                  SizedBox(height: 20),
                ],
              )
            else
              Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.orange, size: 80),
                  SizedBox(height: 20),
                ],
              ),

            // Status message
            Text(
              _message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),

            SizedBox(height: 40),

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
