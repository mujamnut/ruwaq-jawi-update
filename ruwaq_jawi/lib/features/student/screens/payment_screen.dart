import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/payment_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/payment_models.dart';
import 'toyyibpay_payment_screen.dart';

class PaymentScreen extends StatelessWidget {
  final SubscriptionPlan plan;
  final String userEmail;
  final String userName;
  final String userPhone;
  final String userId;

  const PaymentScreen({
    Key? key,
    required this.plan,
    required this.userEmail,
    required this.userName,
    required this.userPhone,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan Details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${plan.price} ${plan.currency}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Consumer<PaymentProvider>(
                builder: (context, paymentProvider, _) {
                  if (paymentProvider.isProcessing) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ElevatedButton(
                    onPressed: () => _processPayment(context, paymentProvider),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Proceed to Payment',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(
    BuildContext context,
    PaymentProvider paymentProvider,
  ) async {
    try {
      print('Processing payment for email: $userEmail'); // Debug log

      // Ensure phone number is not empty
      final phone = userPhone.isNotEmpty ? userPhone : '60123456789';

      print('Processing payment with phone: $phone'); // Debug log

      final payment = await paymentProvider.createSubscriptionPayment(
        plan: plan,
        userEmail: userEmail,
        userName: userName,
        userPhone: phone,
        redirectUrl: '', // This will be handled by ToyyibpayPaymentScreen
        webhookUrl: '', // This will be handled by ToyyibpayPaymentScreen
        userId: userId,
      );

      if (payment == null) {
        throw Exception(paymentProvider.error ?? 'Failed to create payment');
      }

      if (!context.mounted) return;

      // Launch Toyyibpay payment page
      print('🚀 Launching ToyyibPay with Plan ID: ${plan.id}, Amount: ${plan.price}');
      
      final paymentResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ToyyibpayPaymentScreen(
            billCode: payment.id,
            billUrl: payment.url,
            planId: plan.id, // ✨ NEW: Pass plan ID for verification
            amount: plan.price, // ✨ NEW: Pass amount for verification
          ),
        ),
      );

      if (!context.mounted) return;

      if (paymentResult == true) {
        // Payment successful - refresh auth provider and navigate properly
        if (context.mounted) {
          // Refresh subscription status
          final authProvider = context.read<AuthProvider>();
          await authProvider.refreshSubscriptionStatus();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful! Premium content is now unlocked.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate back to subscription screen or home
          if (context.canPop()) {
            context.pop(true);
          } else {
            context.go('/home');
          }
        }
      } else {
        // Payment failed or cancelled
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment was not completed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }
}
