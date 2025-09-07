import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/subscription_provider.dart';

class PaymentCallbackPage extends StatefulWidget {
  final String billId;
  final String planId;
  final double amount;

  const PaymentCallbackPage({
    Key? key,
    required this.billId,
    required this.planId,
    required this.amount,
  }) : super(key: key);

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

      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      
      // Store pending payment first jika belum ada
      await subscriptionProvider.storePendingPayment(
        billId: widget.billId,
        planId: widget.planId,
        amount: widget.amount,
      );

      // Verify payment status
      final success = await subscriptionProvider.verifyPaymentStatus(
        billId: widget.billId,
        planId: widget.planId,
      );

      setState(() {
        _isVerifying = false;
        _paymentSuccess = success;
        
        if (success) {
          _message = 'Pembayaran berjaya! Langganan anda telah diaktifkan.';
        } else {
          _message = 'Pembayaran masih dalam proses atau gagal. Sila cuba lagi.';
        }
      });

      if (success) {
        // Auto navigate selepas 2 seconds
        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/subscription-success');
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
        _message = 'Tidak dapat mengesahkan pembayaran selepas beberapa cubaan. Sila hubungi support.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Status Pembayaran'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 80,
                  ),
                  SizedBox(height: 20),
                ],
              )
            else
              Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.orange,
                    size: 80,
                  ),
                  SizedBox(height: 20),
                ],
              ),

            // Status message
            Text(
              _message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            SizedBox(height: 40),

            // Payment details
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maklumat Pembayaran:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Bill ID: ${widget.billId}'),
                  Text('Plan ID: ${widget.planId}'),
                  Text('Jumlah: RM${widget.amount.toStringAsFixed(2)}'),
                  if (_retryCount > 0) 
                    Text('Cubaan: ${_retryCount + 1}'),
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
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/subscription', 
                    (route) => false,
                  );
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
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Jika pembayaran sudah dibuat, ia mungkin mengambil masa untuk diproses. Sila tunggu beberapa minit dan cuba semak semula.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
                          await subscriptionProvider.verifyAllPendingPayments();
                        },
                        child: Text('Semak Semua Pembayaran'),
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
