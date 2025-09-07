import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/payment_models.dart';
import '../../../core/providers/payment_provider.dart';
import '../../../core/config/payment_config.dart';

class PaymentScreen extends StatefulWidget {
  final SubscriptionPlan plan;
  final String userEmail;
  final String userName;
  final String userPhone;
  final String userId;

  const PaymentScreen({
    super.key,
    required this.plan,
    required this.userEmail,
    required this.userName,
    required this.userPhone,
    required this.userId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  String? _error;
  PaymentResponse? _paymentResponse;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _initiatePayment();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _isLoading = true);
              _handleNavigationChange(url);
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onProgress: (int progress) {
            if (mounted && progress < 100) {
              setState(() => _isLoading = true);
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _error = 'WebView error: ${error.description}';
                _isLoading = false;
              });
            }
          },
        ),
      );
  }

  Future<void> _initiatePayment() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final paymentProvider = Provider.of<PaymentProvider>(
        context,
        listen: false,
      );
      final phone = widget.userPhone.isNotEmpty
          ? widget.userPhone
          : '+60123456789';

      final payment = await paymentProvider.createSubscriptionPayment(
        plan: widget.plan,
        userEmail: widget.userEmail,
        userName: widget.userName,
        userPhone: phone,
        redirectUrl: PaymentConfig.paymentSuccessUrl,
        webhookUrl: PaymentConfig.webhookUrl,
        userId: widget.userId,
      );

      if (!mounted) return;

      if (payment != null) {
        setState(() => _paymentResponse = payment);
        await _loadPaymentUrl(payment.url);
      } else {
        setState(() {
          _error = paymentProvider.error ?? 'Failed to create payment';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error initiating payment: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPaymentUrl(String url) async {
    if (!mounted) return;

    try {
      await _webViewController.loadRequest(Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading payment page: $e';
        _isLoading = false;
      });
    }
  }

  void _handleNavigationChange(String url) {
    if (url.startsWith('ruwaqjawi://payment/')) {
      final status = url.split('/').last;
      context.go('/subscription/payment/$status');
    }
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initiatePayment,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentContent() {
    return WebViewWidget(controller: _webViewController);
  }

  Widget _buildLoadingOverlay() {
    return const Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/subscription'),
        ),
      ),
      body: Stack(
        children: [
          if (_error != null)
            _buildErrorState()
          else if (_paymentResponse == null)
            _buildLoadingState()
          else
            _buildPaymentContent(),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }
}
