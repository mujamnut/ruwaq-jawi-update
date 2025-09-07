import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/admin_bottom_nav.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get payments with user information
      final paymentsData = await SupabaseService.from('payments')
          .select('''
            *,
            user_id,
            subscription_id,
            profiles!inner(full_name),
            subscriptions(subscription_plans(name))
          ''')
          .order('created_at', ascending: false);

      // Calculate statistics
      final totalPayments = paymentsData.length;
      final successfulPayments = paymentsData.where((p) => p['status'] == 'succeeded').length;
      final pendingPayments = paymentsData.where((p) => p['status'] == 'pending').length;
      final failedPayments = paymentsData.where((p) => p['status'] == 'failed').length;
      
      final totalRevenue = paymentsData
          .where((p) => p['status'] == 'succeeded')
          .fold(0.0, (sum, p) => sum + ((p['amount_cents'] as int? ?? 0) / 100));

      setState(() {
        _payments = List<Map<String, dynamic>>.from(paymentsData);
        _stats = {
          'totalPayments': totalPayments,
          'successfulPayments': successfulPayments,
          'pendingPayments': pendingPayments,
          'failedPayments': failedPayments,
          'totalRevenue': totalRevenue,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ralat memuatkan data pembayaran: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Transaksi Pembayaran',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return GestureDetector(
                onTap: () => context.go('/admin/profile'),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    radius: 18,
                    child: authProvider.userProfile?.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              authProvider.userProfile!.avatarUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 20,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 1),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Ralat',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPayments,
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildPaymentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistik Pembayaran',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Jumlah Transaksi',
              _stats['totalPayments'].toString(),
              Icons.receipt,
              Colors.blue,
            ),
            _buildStatCard(
              'Berjaya',
              _stats['successfulPayments'].toString(),
              Icons.check_circle,
              Colors.green,
            ),
            _buildStatCard(
              'Pending',
              _stats['pendingPayments'].toString(),
              Icons.pending,
              Colors.orange,
            ),
            _buildStatCard(
              'Jumlah Hasil',
              'RM ${_stats['totalRevenue'].toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Senarai Transaksi',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_payments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tiada transaksi pembayaran dijumpai',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Semua transaksi pembayaran akan dipaparkan di sini',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _payments.length,
            itemBuilder: (context, index) {
              final payment = _payments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(payment['status']),
                    child: Icon(
                      _getStatusIcon(payment['status']),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    payment['profiles']?['full_name'] ?? 'Pengguna tidak dikenali',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Jumlah: RM ${((payment['amount_cents'] as int? ?? 0) / 100).toStringAsFixed(2)}'),
                      Text('Status: ${_getStatusText(payment['status'])}'),
                      if (payment['description'] != null)
                        Text('Keterangan: ${payment['description']}'),
                      Text(
                        'Tarikh: ${_formatDate(payment['created_at'])}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        payment['provider']?.toString().toUpperCase() ?? 'UNKNOWN',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (payment['reference_number'] != null)
                        Text(
                          payment['reference_number'],
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  onTap: () => _showPaymentDetails(payment),
                ),
              );
            },
          ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'succeeded':
      case 'completed':
        return Colors.green;
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'failed':
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'succeeded':
      case 'completed':
        return Icons.check;
      case 'pending':
      case 'processing':
        return Icons.access_time;
      case 'failed':
      case 'canceled':
        return Icons.close;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'succeeded':
        return 'Berjaya';
      case 'completed':
        return 'Selesai';
      case 'pending':
        return 'Menunggu';
      case 'processing':
        return 'Diproses';
      case 'failed':
        return 'Gagal';
      case 'canceled':
        return 'Dibatalkan';
      default:
        return status?.toUpperCase() ?? 'TIDAK DIKENALI';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Tidak diketahui';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Butiran Transaksi'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID Transaksi', payment['id']),
              _buildDetailRow('Pengguna', payment['profiles']?['full_name'] ?? 'Tidak diketahui'),
              _buildDetailRow('Jumlah', 'RM ${((payment['amount_cents'] as int? ?? 0) / 100).toStringAsFixed(2)}'),
              _buildDetailRow('Mata Wang', payment['currency'] ?? 'MYR'),
              _buildDetailRow('Status', _getStatusText(payment['status'])),
              _buildDetailRow('Pembekal', payment['provider']?.toString().toUpperCase() ?? 'TIDAK DIKETAHUI'),
              if (payment['provider_payment_id'] != null)
                _buildDetailRow('ID Pembayaran Pembekal', payment['provider_payment_id']),
              if (payment['reference_number'] != null)
                _buildDetailRow('Nombor Rujukan', payment['reference_number']),
              if (payment['description'] != null)
                _buildDetailRow('Keterangan', payment['description']),
              _buildDetailRow('Tarikh Dicipta', _formatDate(payment['created_at'])),
              if (payment['paid_at'] != null)
                _buildDetailRow('Tarikh Pembayaran', _formatDate(payment['paid_at'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? 'Tidak tersedia'),
          ),
        ],
      ),
    );
  }
}
