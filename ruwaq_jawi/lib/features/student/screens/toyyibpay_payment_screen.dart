import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../screens/payment_callback_page.dart';

class ToyyibpayPaymentScreen extends StatefulWidget {
  final String billCode;
  final String billUrl;
  final String? planId;
  final double? amount;

  const ToyyibpayPaymentScreen({
    Key? key,
    required this.billCode,
    required this.billUrl,
    this.planId,
    this.amount,
  }) : super(key: key);

  @override
  State<ToyyibpayPaymentScreen> createState() => _ToyyibpayPaymentScreenState();
}

class _ToyyibpayPaymentScreenState extends State<ToyyibpayPaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            print('WebView loaded URL: $url');

            // Check for payment redirect URLs
            if (url.contains('payment-redirect')) {
              if (url.contains('status=success')) {
                // Payment successful - navigate back with success
                _handlePaymentComplete(true);
              } else if (url.contains('status=failed')) {
                // Payment failed - navigate back with failure
                _handlePaymentComplete(false);
              }
            }

            // Also check for ToyyibPay direct status
            if (url.contains('status=1')) {
              _handlePaymentComplete(true);
            } else if (url.contains('status=2') || url.contains('status=3')) {
              _handlePaymentComplete(false);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // You can add additional URL filtering here if needed
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.billUrl));
  }

  void _handlePaymentComplete(bool isSuccess) {
    // Prevent multiple navigation calls
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;
    print('🔄 Payment completed with status: $isSuccess');
    print('📋 Bill Code: ${widget.billCode}');

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      try {
        if (isSuccess && widget.planId != null && widget.amount != null) {
          // 🚀 NEW: Navigate to payment verification screen
          print('✅ Navigating to payment verification...');

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentCallbackPage(
                billId: widget.billCode,
                planId: widget.planId!,
                amount: widget.amount!,
              ),
            ),
          );
        } else {
          // Old flow - return status or navigate to subscription
          if (Navigator.canPop(context)) {
            Navigator.pop(context, isSuccess);
          } else {
            context.go('/subscription');
          }
        }
      } catch (e) {
        print('❌ Navigation error in payment screen: $e');
        // Fallback navigation
        try {
          if (isSuccess && widget.planId != null && widget.amount != null) {
            // Try go_router for payment callback
            context.go(
              '/payment-callback?billId=${widget.billCode}&planId=${widget.planId}&amount=${widget.amount}',
            );
          } else {
            context.go('/subscription');
          }
        } catch (e2) {
          print('❌ Failed fallback navigation: $e2');
          // Last resort
          context.go('/home');
        }
      } finally {
        // Reset the flag after a delay
        Future.delayed(const Duration(seconds: 2), () {
          _hasNavigated = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog when user tries to go back
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Payment?'),
            content: const Text(
              'Are you sure you want to cancel this payment? Your transaction will not be completed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No, continue payment'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, cancel payment'),
              ),
            ],
          ),
        );

        if (shouldPop == true) {
          if (!mounted) return false;
          Navigator.pop(context, false); // Return payment cancelled
          return false;
        }

        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          leading: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.arrowLeft(),
              color: Colors.white,
              size: 20,
            ),
            onPressed: () async {
              final shouldClose = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel Payment?'),
                  content: const Text(
                    'Are you sure you want to cancel this payment? Your transaction will not be completed.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No, continue payment'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes, cancel payment'),
                    ),
                  ],
                ),
              );

              if (shouldClose == true && mounted) {
                Navigator.pop(context, false); // Return payment cancelled
              }
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
