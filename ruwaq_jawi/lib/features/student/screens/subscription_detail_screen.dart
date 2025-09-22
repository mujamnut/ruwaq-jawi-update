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

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadData() async {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    await Future.wait([
      subscriptionProvider.loadUserSubscriptions(),
      subscriptionProvider.loadSubscriptionPlans(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
      _animationController.forward();
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);

    // Comprehensive refresh for subscription data
    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      await Future.wait([
        subscriptionProvider.loadUserSubscriptions(),
        subscriptionProvider.loadSubscriptionPlans(),
      ]);
      print('🔄 Subscription data refreshed');
    } catch (e) {
      print('⚠️ Error refreshing subscription data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.arrowLeft(),
              color: AppTheme.textPrimaryColor,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Status Langganan',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: AppTheme.primaryColor,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildContent(),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildContent() {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, child) {
        final activeSubscription = provider.activeSubscription;
        final subscriptions = provider.subscriptions;
        final transactions = provider.transactions;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubscriptionCard(activeSubscription),
              const SizedBox(height: 32),
              _buildSubscriptionHistory(subscriptions),
              const SizedBox(height: 32),
              _buildTransactionHistory(transactions),
              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionCard(Subscription? subscription) {
    final theme = Theme.of(context);
    final isActive = subscription?.isActive == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? AppTheme.primaryColor.withOpacity(0.3)
              : AppTheme.borderColor,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? AppTheme.primaryColor.withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
            blurRadius: isActive ? 20 : 8,
            offset: Offset(0, isActive ? 8 : 2),
            spreadRadius: isActive ? 2 : 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : AppTheme.neutralGray,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.primaryColor.withOpacity(0.2)
                        : AppTheme.borderColor,
                  ),
                ),
                child: PhosphorIcon(
                  isActive
                      ? PhosphorIcons.crown(PhosphorIconsStyle.fill)
                      : PhosphorIcons.warning(),
                  color: isActive
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive
                          ? 'Premium Active'
                          : 'Basic Access',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subscription?.planDisplayName ?? 'Akses Terhad',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'AKTIF',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          if (subscription != null) ...[
            _buildInfoGrid(subscription),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.neutralGray,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.lockKey(),
                    color: AppTheme.textSecondaryColor,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Anda belum mempunyai langganan aktif',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upgrade ke Premium untuk menikmati akses penuh!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/subscription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.crown(),
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Upgrade ke Premium',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoGrid(Subscription subscription) {
    final infoItems = <Map<String, dynamic>>[
      {
        'label': 'Status',
        'value': _getStatusText(subscription.status),
        'icon': _getStatusIcon(subscription.status),
        'color': _getStatusColor(subscription.status),
      },
      {
        'label': 'Tempoh',
        'value': '${_formatDate(subscription.startDate)} - ${_formatDate(subscription.endDate)}',
        'icon': PhosphorIcons.calendar(),
        'color': AppTheme.textSecondaryColor,
      },
      if (subscription.isActive) ...[
        {
          'label': 'Baki Hari',
          'value': '${subscription.daysRemaining} hari',
          'icon': PhosphorIcons.clock(),
          'color': AppTheme.textSecondaryColor,
        },
      ],
      {
        'label': 'Harga',
        'value': subscription.formattedAmount,
        'icon': PhosphorIcons.money(),
        'color': AppTheme.textSecondaryColor,
      },
      if (subscription.autoRenew) ...[
        {
          'label': 'Perpanjangan Auto',
          'value': 'Aktif',
          'icon': PhosphorIcons.repeat(),
          'color': AppTheme.successColor,
        },
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.neutralGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: infoItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              _buildInfoRow(
                item['label'] as String,
                item['value'] as String,
                item['icon'] as dynamic,
                item['color'] as Color,
              ),
              if (index < infoItems.length - 1)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  height: 1,
                  color: AppTheme.borderColor,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    dynamic icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: PhosphorIcon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.neutralGray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: PhosphorIcon(
                    PhosphorIcons.clockCounterClockwise(),
                    color: AppTheme.textSecondaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tiada sejarah langganan',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sejarah langganan anda akan dipaparkan di sini',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.neutralGray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: PhosphorIcon(
                    PhosphorIcons.receipt(),
                    color: AppTheme.textSecondaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tiada sejarah transaksi',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sejarah transaksi anda akan dipaparkan di sini',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
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
        return PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
      case 'pending':
        return PhosphorIcons.clock();
      case 'cancelled':
        return PhosphorIcons.xCircle(PhosphorIconsStyle.fill);
      case 'expired':
        return PhosphorIcons.warning(PhosphorIconsStyle.fill);
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
