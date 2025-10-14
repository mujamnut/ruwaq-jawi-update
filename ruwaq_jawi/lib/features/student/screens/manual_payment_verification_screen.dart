import 'package:flutter/material.dart';
import '../../../core/services/direct_payment_verification_service.dart';
import '../../../core/services/supabase_service.dart';

class ManualPaymentVerificationScreen extends StatefulWidget {
  const ManualPaymentVerificationScreen({super.key});

  @override
  State<ManualPaymentVerificationScreen> createState() =>
      _ManualPaymentVerificationScreenState();
}

class _ManualPaymentVerificationScreenState
    extends State<ManualPaymentVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _billCodeController = TextEditingController();
  bool _isLoading = false;
  bool _isVerified = false;
  Map<String, dynamic>? _verificationResult;

  @override
  void dispose() {
    _billCodeController.dispose();
    super.dispose();
  }

  Future<void> _verifyPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final directService = DirectPaymentVerificationService();
      final billId = _billCodeController.text.trim();

      // Step 1: Verify payment directly with ToyyibPay API
      final verificationResult = await directService.verifyPaymentWithToyyibPay(billId);

      if (!verificationResult.success) {
        setState(() {
          _isLoading = false;
          _isVerified = false;
          _verificationResult = {
            'billId': billId,
            'message': verificationResult.message ?? 'Pengesahan gagal',
          };
        });
        _showErrorDialog(verificationResult.message ?? 'Pengesahan gagal');
        return;
      }

      if (!verificationResult.isPaid) {
        setState(() {
          _isLoading = false;
          _isVerified = false;
          _verificationResult = {
            'billId': billId,
            'message': 'Pembayaran belum dijumpai atau masih pending. Sila semak semula dalam beberapa minit.',
          };
        });
        _showErrorDialog('Pembayaran belum dijumpai atau masih pending. Sila semak semula dalam beberapa minit.');
        return;
      }

      // Step 2: Activate subscription directly
      final activationResult = await directService.activateSubscriptionDirectly(
        billId: billId,
        userId: SupabaseService.currentUser?.id ?? '',
        planId: 'quarterly_pr', // Default plan - could be enhanced to detect from payment
        amount: verificationResult.amount,
      );

      setState(() {
        _isLoading = false;
        _isVerified = activationResult.success;
        _verificationResult = {
          'billId': billId,
          'message': activationResult.message,
          'subscriptionStatus': activationResult.subscriptionStatus,
          'planId': activationResult.planId,
          'endDate': activationResult.endDate,
          'amount': verificationResult.amount.toString(),
          'transactionId': verificationResult.transactionId,
        };
      });

      if (activationResult.success) {
        _showSuccessDialog(activationResult);
      } else {
        _showErrorDialog(activationResult.message);
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Ralat semasa pengesahan pembayaran: $e');
    }
  }

  void _showSuccessDialog(dynamic result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF00BF6D).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF00BF6D),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pembayaran Berjaya!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              result.message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            if (_verificationResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                        'Kod Bil', _verificationResult!['billId'] ?? ''),
                    _buildInfoRow('Status', _verificationResult!['subscriptionStatus'] ?? 'Aktif'),
                    if (_verificationResult!['planId'] != null)
                      _buildInfoRow('Plan', _verificationResult!['planId']),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BF6D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Selesai',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error,
                color: Color(0xFFEF4444),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pengesahan Gagal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFF00BF6D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF1F2937),
            size: 24,
          ),
        ),
        title: const Text(
          'Pengesahan Pembayaran Manual',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Mengapa perlu pengesahan manual?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kadangkala sistem pembayaran automatik mengalami masalah teknikal. Jika anda telah membuat pembayaran tetapi langganan masih tidak aktif, gunakan fungsi ini untuk mengesahkan pembayaran anda secara manual.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF92400E),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Verification Form
              if (!_isVerified) ...[
                const Text(
                  'Masukkan Kod Bil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kod bil boleh didapati dalam resit pembayaran atau email pengesahan dari ToyyibPay.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),

                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _billCodeController,
                    decoration: InputDecoration(
                      hintText: 'Contoh: abc123xyz',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5E7EB),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5E7EB),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF00BF6D),
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.receipt,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Sila masukkan kod bil';
                      }
                      if (value.trim().length < 3) {
                        return 'Kod bil tidak sah';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BF6D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: const Color(0xFFD1D5DB),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Semak Status Pembayaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Help Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📌 Panduan mencari Kod Bil:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Semak email pengesahan dari ToyyibPay\n'
                        '2. Lihat resit pembayaran dalam akaun ToyyibPay\n'
                        '3. Kod bil biasanya bermula dengan huruf dan nombor\n'
                        '4. Contoh format: abc123xyz',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Success State
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00BF6D),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF00BF6D),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Pembayaran Berjaya Disahkan!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Langganan anda kini telah diaktifkan.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF065F46),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_verificationResult != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow(
                                'Kod Bil',
                                _verificationResult!['billId'] ?? '',
                              ),
                              if (_verificationResult!['transactionId'] != null)
                                _buildInfoRow(
                                  'ID Transaksi',
                                  _verificationResult!['transactionId'],
                                ),
                              if (_verificationResult!['amount'] != null)
                                _buildInfoRow(
                                  'Jumlah',
                                  'RM${_verificationResult!['amount']}',
                                ),
                              _buildInfoRow(
                                'Status',
                                _verificationResult!['subscriptionStatus'] ?? 'Aktif',
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BF6D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Kembali ke Akaun',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}