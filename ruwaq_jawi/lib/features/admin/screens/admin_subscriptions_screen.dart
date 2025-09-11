import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/admin_bottom_nav.dart';

class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() => _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _subscriptionPlans = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load subscriptions with user and plan details
      final subscriptionsData = await SupabaseService.from('subscriptions')
          .select('''
            *,
            profiles!inner(full_name, role, subscription_status),
            subscription_plans!inner(name, price, duration_days)
          ''')
          .order('created_at', ascending: false);

      // Load subscription plans
      final plansData = await SupabaseService.from('subscription_plans')
          .select('*')
          .eq('is_active', true)
          .order('price', ascending: true);

      // Calculate statistics
      final totalSubscriptions = subscriptionsData.length;
      final activeSubscriptions = subscriptionsData.where((s) => s['status'] == 'active').length;
      final expiredSubscriptions = subscriptionsData.where((s) => s['status'] == 'expired').length;
      final canceledSubscriptions = subscriptionsData.where((s) => s['status'] == 'cancelled').length;
      
      final totalRevenue = subscriptionsData
          .where((s) => s['status'] == 'active')
          .fold(0.0, (sum, s) => sum + double.parse(s['amount'].toString()));

      setState(() {
        _subscriptions = List<Map<String, dynamic>>.from(subscriptionsData);
        _subscriptionPlans = List<Map<String, dynamic>>.from(plansData);
        _stats = {
          'totalSubscriptions': totalSubscriptions,
          'activeSubscriptions': activeSubscriptions,
          'expiredSubscriptions': expiredSubscriptions,
          'canceledSubscriptions': canceledSubscriptions,
          'totalRevenue': totalRevenue,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ralat memuatkan data langganan: ${e.toString()}';
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
          'Pengurusan Langganan',
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
              onPressed: _loadData,
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildSubscriptionPlans(),
            const SizedBox(height: 24),
            _buildSubscriptionsList(),
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
          'Statistik Langganan',
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
              'Jumlah Langganan',
              _stats['totalSubscriptions'].toString(),
              HugeIcons.strokeRoundedCreditCard,
              Colors.blue,
            ),
            _buildStatCard(
              'Aktif',
              _stats['activeSubscriptions'].toString(),
              HugeIcons.strokeRoundedCheckmarkCircle02,
              Colors.green,
            ),
            _buildStatCard(
              'Tamat Tempoh',
              _stats['expiredSubscriptions'].toString(),
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

  Widget _buildSubscriptionPlans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pelan Langganan Tersedia',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _subscriptionPlans.length,
            itemBuilder: (context, index) {
              final plan = _subscriptionPlans[index];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 16),
                child: Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'RM ${double.parse(plan['price'].toString()).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${plan['duration_days']} hari',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          plan['description'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Senarai Langganan Aktif',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_subscriptions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedCreditCard,
                      size: 48.0,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tiada langganan dijumpai',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
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
            itemCount: _subscriptions.length,
            itemBuilder: (context, index) {
              final subscription = _subscriptions[index];
              final isActive = subscription['status'] == 'active';
              final endDate = DateTime.parse(subscription['current_period_end']);
              final isExpiringSoon = endDate.isBefore(DateTime.now().add(const Duration(days: 7)));
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(subscription['status']),
                    child: Icon(
                      _getStatusIcon(subscription['status']),
                      color: Colors.white,
                      size: 20.0,
                    ),
                  ),
                  title: Text(
                    subscription['profiles']['full_name'] ?? 'Pengguna tidak dikenali',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pelan: ${subscription['subscription_plans']['name']}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text('Jumlah: RM ${double.parse(subscription['amount'].toString()).toStringAsFixed(2)}'),
                      Text('Status: ${_getStatusText(subscription['status'])}'),
                      Text(
                        'Tamat: ${_formatDate(subscription['current_period_end'])}',
                        style: TextStyle(
                          color: isExpiringSoon && isActive ? Colors.orange : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (subscription['auto_renew'] == true)
                        Icon(
                          HugeIcons.strokeRoundedRefresh,
                          color: Colors.green,
                          size: 16.0,
                        ),
                      Text(
                        subscription['provider']?.toString().toUpperCase() ?? 'MANUAL',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showSubscriptionDetails(subscription),
                ),
              );
            },
          ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'trialing':
        return Colors.blue;
      case 'past_due':
        return Colors.orange;
      case 'paused':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return HugeIcons.strokeRoundedCheckmarkCircle02;
      case 'expired':
        return HugeIcons.strokeRoundedClock01;
      case 'cancelled':
        return HugeIcons.strokeRoundedCancel01;
      case 'trialing':
        return HugeIcons.strokeRoundedClock01;
      case 'past_due':
        return HugeIcons.strokeRoundedAlert02;
      case 'paused':
        return HugeIcons.strokeRoundedPauseCircle;
      default:
        return HugeIcons.strokeRoundedHelpCircle;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'Aktif';
      case 'expired':
        return 'Tamat Tempoh';
      case 'cancelled':
        return 'Dibatalkan';
      case 'trialing':
        return 'Percubaan';
      case 'past_due':
        return 'Lewat Bayar';
      case 'paused':
        return 'Dijeda';
      default:
        return status?.toUpperCase() ?? 'TIDAK DIKENALI';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Tidak diketahui';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showSubscriptionDetails(Map<String, dynamic> subscription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Butiran Langganan'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID Langganan', subscription['id']),
              _buildDetailRow('Pengguna', subscription['profiles']['full_name'] ?? 'Tidak diketahui'),
              _buildDetailRow('Pelan', subscription['subscription_plans']['name']),
              _buildDetailRow('Harga Pelan', 'RM ${double.parse(subscription['subscription_plans']['price'].toString()).toStringAsFixed(2)}'),
              _buildDetailRow('Jumlah Bayar', 'RM ${double.parse(subscription['amount'].toString()).toStringAsFixed(2)}'),
              _buildDetailRow('Mata Wang', subscription['currency'] ?? 'MYR'),
              _buildDetailRow('Status', _getStatusText(subscription['status'])),
              _buildDetailRow('Mula', _formatDate(subscription['started_at'])),
              _buildDetailRow('Tempoh Semasa (Mula)', _formatDate(subscription['current_period_start'])),
              _buildDetailRow('Tempoh Semasa (Tamat)', _formatDate(subscription['current_period_end'])),
              _buildDetailRow('Pembaharuan Auto', subscription['auto_renew'] == true ? 'Ya' : 'Tidak'),
              _buildDetailRow('Pembekal', subscription['provider']?.toString().toUpperCase() ?? 'MANUAL'),
              if (subscription['provider_subscription_id'] != null)
                _buildDetailRow('ID Langganan Pembekal', subscription['provider_subscription_id']),
              if (subscription['canceled_at'] != null)
                _buildDetailRow('Tarikh Pembatalan', _formatDate(subscription['canceled_at'])),
              _buildDetailRow('Tarikh Dicipta', _formatDate(subscription['created_at'])),
            ],
          ),
        ),
        actions: [
          if (subscription['status'] == 'active') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCancelSubscriptionDialog(subscription);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Batal Langganan'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showCancelSubscriptionDialog(Map<String, dynamic> subscription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batal Langganan'),
        content: Text(
          'Adakah anda pasti mahu membatalkan langganan untuk ${subscription['profiles']['full_name']}?\n\nTindakan ini tidak boleh dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelSubscription(subscription['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ya, Batal'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSubscription(String subscriptionId) async {
    try {
      await SupabaseService.from('subscriptions')
          .update({
            'status': 'cancelled',
            'canceled_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Langganan telah dibatalkan'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat membatalkan langganan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
