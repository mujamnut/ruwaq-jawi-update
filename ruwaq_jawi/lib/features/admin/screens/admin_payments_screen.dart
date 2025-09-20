import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    try {
      final profile = await SupabaseService.from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        if (mounted) {
          context.go('/home');
        }
        return;
      }

      _loadPayments();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Akses ditolak. Anda tidak mempunyai kebenaran admin.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPayments() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get transactions with user information (correct table name)
      final paymentsData = await SupabaseService.from('transactions')
          .select('''
            *,
            profiles!inner(full_name)
          ''')
          .order('created_at', ascending: false)
          .limit(100); // Add pagination limit

      // Calculate statistics
      final totalPayments = paymentsData.length;
      final successfulPayments = paymentsData.where((p) => p['status'] == 'completed').length;
      final pendingPayments = paymentsData.where((p) => p['status'] == 'pending').length;
      final failedPayments = paymentsData.where((p) => p['status'] == 'failed').length;

      final totalRevenue = paymentsData
          .where((p) => p['status'] == 'completed')
          .fold(0.0, (sum, p) => sum + (double.tryParse(p['amount'].toString()) ?? 0.0));

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
      if (_retryCount < _maxRetries) {
        _retryCount++;
        await Future.delayed(Duration(seconds: 2));
        return _loadPayments();
      }

      setState(() {
        _error = 'Tidak dapat memuat data pembayaran selepas $_maxRetries cubaan. Sila periksa sambungan internet anda.';
        _isLoading = false;
      });
      print('Payment loading error: $e'); // Log for debugging
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
                                  HugeIcons.strokeRoundedUser,
                                  color: Colors.white,
                                  size: 20.0,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            HugeIcons.strokeRoundedUser,
                            color: Colors.white,
                            size: 20.0,
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
            const HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: 64.0, color: Colors.red),
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
              onPressed: () {
                _retryCount = 0;
                _loadPayments();
              },
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
              HugeIcons.strokeRoundedInvoice01,
              Colors.blue,
            ),
            _buildStatCard(
              'Selesai',
              _stats['successfulPayments'].toString(),
              HugeIcons.strokeRoundedCheckmarkCircle02,
              Colors.green,
            ),
            _buildStatCard(
              'Pending',
              _stats['pendingPayments'].toString(),
              HugeIcons.strokeRoundedClock01,
              Colors.orange,
            ),
            _buildStatCard(
              'Jumlah Hasil',
              'RM ${_stats['totalRevenue'].toStringAsFixed(2)}',
              HugeIcons.strokeRoundedMoney04,
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
                      HugeIcons.strokeRoundedInvoice01,
                      size: 48.0,
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
                      size: 20.0,
                    ),
                  ),
                  title: Text(
                    payment['profiles']?['full_name'] ?? 'Pengguna tidak dikenali',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Jumlah: RM ${(double.tryParse(payment['amount'].toString()) ?? 0.0).toStringAsFixed(2)}'),
                      Text('Status: ${_getStatusText(payment['status'])}'),
                      Text('Kaedah: ${payment['payment_method'] ?? 'N/A'}'),
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
                        payment['payment_method']?.toString().toUpperCase() ?? 'MANUAL',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (payment['transaction_id'] != null)
                        Text(
                          payment['transaction_id'].toString().length > 10
                              ? '${payment['transaction_id'].toString().substring(0, 10)}...'
                              : payment['transaction_id'],
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
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return HugeIcons.strokeRoundedCheckmarkCircle02;
      case 'pending':
        return HugeIcons.strokeRoundedClock01;
      case 'failed':
        return HugeIcons.strokeRoundedCancel01;
      default:
        return HugeIcons.strokeRoundedHelpCircle;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return 'Selesai';
      case 'pending':
        return 'Menunggu';
      case 'failed':
        return 'Gagal';
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
              _buildDetailRow('Jumlah', 'RM ${(double.tryParse(payment['amount'].toString()) ?? 0.0).toStringAsFixed(2)}'),
              _buildDetailRow('Mata Wang', payment['currency'] ?? 'MYR'),
              _buildDetailRow('Status', _getStatusText(payment['status'])),
              _buildDetailRow('Kaedah Bayar', payment['payment_method']?.toString().toUpperCase() ?? 'MANUAL'),
              if (payment['transaction_id'] != null)
                _buildDetailRow('ID Transaksi', payment['transaction_id']),
              if (payment['subscription_id'] != null)
                _buildDetailRow('ID Langganan', payment['subscription_id']),
              _buildDetailRow('Tarikh Dicipta', _formatDate(payment['created_at'])),
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
