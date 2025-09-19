import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/subscription.dart';

class SubscriptionDetailScreen extends StatefulWidget {
  const SubscriptionDetailScreen({super.key});

  @override
  State<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    await Future.wait([
      subscriptionProvider.loadUserSubscriptions(),
      subscriptionProvider.loadSubscriptionPlans(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.caretLeft(),
              color: AppTheme.textLightColor,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Status Langganan',
          style: theme.appBarTheme.titleTextStyle?.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _refreshData, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, child) {
        final activeSubscription = provider.activeSubscription;
        final subscriptions = provider.subscriptions;
        final transactions = provider.transactions;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubscriptionCard(activeSubscription),
              const SizedBox(height: 24),
              _buildSubscriptionHistory(subscriptions),
              const SizedBox(height: 24),
              _buildTransactionHistory(transactions),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionCard(Subscription? subscription) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: subscription?.isActive == true
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.8),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey[600]!, Colors.grey[700]!],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (subscription?.isActive == true
                        ? AppTheme.primaryColor
                        : Colors.grey)
                    .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: PhosphorIcon(
                  subscription?.isActive == true
                      ? PhosphorIcons.crown()
                      : PhosphorIcons.warning(),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription?.isActive == true
                          ? 'Premium Active'
                          : 'Basic Access',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subscription?.planDisplayName ?? 'Akses Terhad',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (subscription != null) ...[
            _buildStatusRow(
              'Status',
              _getStatusText(subscription.status),
              _getStatusIcon(subscription.status),
              _getStatusColor(subscription.status),
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              'Tempoh',
              '${_formatDate(subscription.startDate)} - ${_formatDate(subscription.endDate)}',
              PhosphorIcons.calendar(),
              Colors.white70,
            ),
            const SizedBox(height: 12),
            if (subscription.isActive) ...[
              _buildStatusRow(
                'Baki Hari',
                '${subscription.daysRemaining} hari',
                PhosphorIcons.clock(),
                Colors.white70,
              ),
              const SizedBox(height: 12),
            ],
            _buildStatusRow(
              'Harga',
              subscription.formattedAmount,
              PhosphorIcons.money(),
              Colors.white70,
            ),
            if (subscription.autoRenew) ...[
              const SizedBox(height: 12),
              _buildStatusRow(
                'Perpanjangan Auto',
                'Aktif',
                PhosphorIcons.repeat(),
                Colors.white70,
              ),
            ],
          ] else ...[
            Text(
              'Anda belum mempunyai langganan aktif. Upgrade ke Premium untuk menikmati akses penuh!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/subscription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Upgrade ke Premium',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String value,
    dynamic icon,
    Color color,
  ) {
    return Row(
      children: [
        PhosphorIcon(icon, color: color, size: 16),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionHistory(List subscriptions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sejarah Langganan',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (subscriptions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                PhosphorIcon(
                  PhosphorIcons.clockCounterClockwise(),
                  color: AppTheme.textSecondaryColor,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tiada sejarah langganan',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ...subscriptions.map(
            (sub) => _buildHistoryItem(
              sub.planDisplayName,
              '${_formatDate(sub.startDate)} - ${_formatDate(sub.endDate)}',
              sub.formattedAmount,
              _getStatusText(sub.status),
              _getStatusColor(sub.status),
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionHistory(List transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sejarah Transaksi',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                PhosphorIcon(
                  PhosphorIcons.receipt(),
                  color: AppTheme.textSecondaryColor,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tiada sejarah transaksi',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ...transactions.map(
            (transaction) => _buildHistoryItem(
              'Pembayaran ${transaction.paymentMethod}',
              _formatDate(transaction.createdAt),
              'RM ${transaction.amount.toStringAsFixed(2)}',
              transaction.status,
              _getStatusColor(transaction.status),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryItem(
    String title,
    String subtitle,
    String amount,
    String status,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Aktif';
      case 'pending':
        return 'Menunggu';
      case 'cancelled':
        return 'Dibatalkan';
      case 'expired':
        return 'Tamat Tempoh';
      case 'completed':
        return 'Selesai';
      case 'failed':
        return 'Gagal';
      default:
        return status;
    }
  }

  dynamic _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return PhosphorIcons.checkCircle();
      case 'pending':
        return PhosphorIcons.clock();
      case 'cancelled':
        return PhosphorIcons.xCircle();
      case 'expired':
        return PhosphorIcons.warning();
      default:
        return PhosphorIcons.info();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'completed':
        return AppTheme.successColor;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'failed':
        return AppTheme.errorColor;
      case 'expired':
        return Colors.grey;
      default:
        return AppTheme.textSecondaryColor;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
