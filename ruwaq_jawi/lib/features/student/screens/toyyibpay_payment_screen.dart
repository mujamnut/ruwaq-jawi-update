import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ToyyibpayPaymentScreen extends StatefulWidget {
  final String billCode;
  final String billUrl;
  final String? planId;
  final double? amount;

  const ToyyibpayPaymentScreen({
    super.key,
    required this.billCode,
    required this.billUrl,
    this.planId,
    this.amount,
  });

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
      ..loadRequest(Uri.parse(widget.billUrl))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }

            // EARLY DETECTION: Check URL immediately when page starts loading
            _checkForPaymentCompletion(url);
          },
          onPageFinished: (String url) {
            // Double-check for payment completion
            _checkForPaymentCompletion(url);

            // Only hide loading if we haven't started navigation
            if (mounted && !_hasNavigated) {
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Check for payment completion before allowing navigation
            _checkForPaymentCompletion(request.url);

            return NavigationDecision.navigate;
          },
        ),
      );
  }

  void _checkForPaymentCompletion(String url) {
    // Skip if already handled
    if (_hasNavigated) return;

    bool shouldHandle = false;
    bool isSuccess = false;
    String? status;
    String? statusId;

    // Check for various ToyyibPay completion patterns
    if (url.contains('payment-redirect') ||
        url.contains('status=') ||
        url.contains('Payment Successful') ||
        url.contains('Payment Failed') ||
        url.contains('Transaction ID')) {
      shouldHandle = true;

      // Extract URL parameters for precise verification
      final uri = Uri.tryParse(url);
      if (uri != null) {
        status = uri.queryParameters['status'];
        statusId = uri.queryParameters['status_id'];
      }

      // Determine success/failure based on parameters
      isSuccess = (status?.toLowerCase() == 'success' && statusId == '1') ||
                  url.contains('status=success') ||
                  url.contains('status=1') ||
                  url.contains('Payment Successful');
    }

    if (shouldHandle) {
      // Hide WebView immediately to prevent code display
      if (mounted) {
        setState(() => _isLoading = true);
      }

      _handlePaymentComplete(isSuccess, status, statusId);
    }
  }

  void _handlePaymentComplete(bool isSuccess, [String? status, String? statusId]) {
    // Prevent multiple navigation calls
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      try {
        if (isSuccess && widget.planId != null && widget.amount != null) {
          // SUCCESS: Navigate to payment verification screen with redirect parameters
          // Build URL with redirect parameters for reliable verification
          String callbackUrl = '/payment-callback?billId=${widget.billCode}&planId=${widget.planId}&amount=${widget.amount}';

          if (status != null) {
            callbackUrl += '&redirectStatus=$status';
          }
          if (statusId != null) {
            callbackUrl += '&redirectStatusId=$statusId';
          }

          // Use go_router instead of Navigator.pushReplacement
          context.pushReplacement(callbackUrl);
        } else {
          // FAILED/CANCELLED: Navigate back to subscription with error message

          if (Navigator.canPop(context)) {
            Navigator.pop(context, false);
          } else {
            context.go('/subscription');
          }

          // Show error message after navigation
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Pembayaran dibatalkan atau gagal'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          });
        }
      } catch (e) {
        // Fallback navigation
        try {
          if (isSuccess && widget.planId != null && widget.amount != null) {
            // Try go_router for payment callback
            String fallbackUrl = '/payment-callback?billId=${widget.billCode}&planId=${widget.planId}&amount=${widget.amount}';

            if (status != null) fallbackUrl += '&redirectStatus=$status';
            if (statusId != null) fallbackUrl += '&redirectStatusId=$statusId';

            context.go(fallbackUrl);
          } else {
            context.go('/subscription');
          }
        } catch (e2) {
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
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

        if (shouldPop == true && context.mounted) {
          Navigator.pop(context, false); // Return payment cancelled
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Payment',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.arrowLeft(),
              color: Colors.black87,
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
            if (_isLoading)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Memproses pembayaran...',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
