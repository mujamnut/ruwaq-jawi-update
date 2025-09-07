// CONTOH: Macam mana nak integrate payment verification dalam existing payment flow

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// 1. Update existing payment button/method
class PaymentButton extends StatelessWidget {
  final String planId;
  final double amount;
  final String planName;

  const PaymentButton({
    Key? key,
    required this.planId,
    required this.amount,
    required this.planName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _processPayment(context),
      child: Text('Bayar RM${amount.toStringAsFixed(2)}'),
    );
  }

  Future<void> _processPayment(BuildContext context) async {
    try {
      // 1. Create ToyyibPay payment link (existing code anda)
      final billId = await _createToyyibPayBill(context);

      if (billId != null) {
        // 2. Store pending payment untuk tracking
        final subscriptionProvider = Provider.of<SubscriptionProvider>(
          context,
          listen: false,
        );
        await subscriptionProvider.storePendingPayment(
          billId: billId,
          planId: planId,
          amount: amount,
        );

        // 3. Redirect ke ToyyibPay
        final paymentUrl =
            'https://dev.toyyibpay.com/${billId}'; // Adjust URL format
        await _launchPaymentUrl(paymentUrl, billId, context);
      }
    } catch (e) {
      _showErrorDialog(context, 'Ralat membuat pembayaran: $e');
    }
  }

  Future<String?> _createToyyibPayBill(BuildContext context) async {
    // GANTI: Existing code anda untuk create ToyyibPay bill
    // Return Bill ID yang ToyyibPay bagi

    // Example (ganti dengan implementation sebenar):
    /*
    final response = await http.post(
      Uri.parse('https://dev.toyyibpay.com/index.php/api/createBill'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userSecretKey': 'YOUR_SECRET_KEY',
        'categoryCode': 'YOUR_CATEGORY_CODE',
        'billName': planName,
        'billDescription': 'Subscription $planName',
        'billAmount': amount.toString(),
        'billReturnUrl': 'https://yourapp.com/payment-callback', // Your callback URL
        'billCallbackUrl': '', // Leave empty since no webhook
        'billExternalReferenceNo': 'REF_${DateTime.now().millisecondsSinceEpoch}',
        'billTo': user.email,
        'billEmail': user.email,
        'billPhone': user.phone ?? '',
      }),
    );
    
    final data = jsonDecode(response.body);
    return data['BillCode']; // atau field lain yang ToyyibPay return
    */

    // For testing purposes:
    return 'TEST_BILL_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _launchPaymentUrl(
    String paymentUrl,
    String billId,
    BuildContext context,
  ) async {
    try {
      // Launch ToyyibPay URL
      final uri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        // Navigate to callback page yang akan auto-verify payment
        Navigator.pushNamed(
          context,
          '/payment-callback',
          arguments: {'billId': billId, 'planId': planId, 'amount': amount},
        );
      } else {
        _showErrorDialog(context, 'Tidak dapat membuka link pembayaran');
      }
    } catch (e) {
      _showErrorDialog(context, 'Ralat membuka pembayaran: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ralat'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

// 2. Update router untuk handle payment callback
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/payment-callback':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PaymentCallbackPage(
            billId: args['billId'],
            planId: args['planId'],
            amount: args['amount'],
          ),
        );

      // ... other routes

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(body: Center(child: Text('Page not found'))),
        );
    }
  }
}

// 3. Background payment verification service (optional)
class PaymentVerificationService {
  static const Duration _checkInterval = Duration(minutes: 2);

  static void startBackgroundVerification(BuildContext context) {
    Timer.periodic(_checkInterval, (timer) async {
      try {
        final subscriptionProvider = Provider.of<SubscriptionProvider>(
          context,
          listen: false,
        );

        // Check jika ada pending payments untuk current user
        final pendingPayments = await subscriptionProvider.getPendingPayments();

        if (pendingPayments.isNotEmpty) {
          print(
            '🔍 Found ${pendingPayments.length} pending payments, verifying...',
          );

          // Verify each pending payment
          for (final payment in pendingPayments) {
            final success = await subscriptionProvider.verifyPaymentStatus(
              billId: payment['bill_id'],
              planId: payment['plan_id'],
            );

            if (success) {
              // Show notification atau update UI
              _showPaymentSuccessNotification(context, payment);
              break; // Stop checking after first success
            }
          }
        }
      } catch (e) {
        print('❌ Error in background verification: $e');
      }
    });
  }

  static void _showPaymentSuccessNotification(
    BuildContext context,
    Map<String, dynamic> payment,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🎉 Pembayaran berjaya! Langganan anda telah diaktifkan.',
        ),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Lihat',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, '/subscription');
          },
        ),
      ),
    );
  }
}

// 4. Usage dalam main app widget
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SubscriptionProvider(),
      child: MaterialApp(
        title: 'Ruwaq Jawi',
        onGenerateRoute: AppRouter.generateRoute,
        builder: (context, child) {
          // Start background verification
          PaymentVerificationService.startBackgroundVerification(context);
          return child!;
        },
      ),
    );
  }
}

// 5. Add ke pubspec.yaml dependencies:
/*
dependencies:
  http: ^1.1.0
  url_launcher: ^6.2.1
*/
