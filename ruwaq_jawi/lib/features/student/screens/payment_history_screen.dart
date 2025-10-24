import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/payment_processing_service.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isRecovering = false;
  String? _recoveryMessage;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
      value: 0.0,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
      value: 0.0,
    );

    // Create animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Load payment history
        context.read<SubscriptionProvider>().loadUserSubscriptions();

        // Start animations with delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _fadeAnimationController.forward();
            _slideAnimationController.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Payment History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppTheme.textPrimaryColor,
            size: 24,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/verify-payment'),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              color: AppTheme.textPrimaryColor,
              size: 20,
            ),
            tooltip: 'Verify Payment Manually',
          ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: SlideTransition(
              position: _slideAnimation,
              child: Consumer<SubscriptionProvider>(
                builder: (context, subscriptionProvider, child) {
                  if (subscriptionProvider.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    );
                  }

                  final subscriptions = subscriptionProvider.subscriptions;

                  if (subscriptions.isEmpty) {
                    return _buildEmptyState();
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await subscriptionProvider.loadUserSubscriptions();
                      if (mounted) {
                        _fadeAnimationController.reset();
                        _slideAnimationController.reset();
                        _fadeAnimationController.forward();
                        _slideAnimationController.forward();
                      }
                    },
                    color: AppTheme.primaryColor,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: subscriptions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final subscription = subscriptions[index];
                        return _buildPaymentCard(subscription.toJson(), index);
                      },
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> subscription, int index) {
    final isPremium = subscription['is_premium'] ?? false;
    final status = subscription['status'] ?? 'unknown';
    final startDate = subscription['start_date'] as String?;
    final endDate = subscription['end_date'] as String?;
    final price = subscription['amount'] as String? ?? '0.00';
    final planName = subscription['plan_name'] ?? 'Unknown Plan';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toLowerCase()) {
      case 'active':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = PhosphorIcons.checkCircle(PhosphorIconsStyle.fill);
        statusText = 'Active';
        break;
      case 'expired':
        statusColor = const Color(0xFFF44336);
        statusIcon = PhosphorIcons.xCircle(PhosphorIconsStyle.fill);
        statusText = 'Expired';
        break;
      case 'cancelled':
        statusColor = const Color(0xFFFF9800);
        statusIcon = PhosphorIcons.xCircle(PhosphorIconsStyle.fill);
        statusText = 'Cancelled';
        break;
      case 'pending':
        statusColor = const Color(0xFF2196F3);
        statusIcon = PhosphorIcons.clock(PhosphorIconsStyle.fill);
        statusText = 'Pending';
        break;
      default:
        statusColor = AppTheme.textSecondaryColor;
        statusIcon = PhosphorIcons.question(PhosphorIconsStyle.fill);
        statusText = 'Unknown';
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: isPremium
                    ? Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                        width: 2,
                      )
                    : Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with plan and status
                        Row(
                          children: [
                            // Plan icon
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: isPremium
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFFFD700),
                                          Color(0xFFFFA500),
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          AppTheme.primaryColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          AppTheme.primaryColor.withValues(
                                            alpha: 0.05,
                                          ),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPremium
                                      ? Colors.transparent
                                      : AppTheme.primaryColor.withValues(
                                          alpha: 0.2,
                                        ),
                                ),
                              ),
                              child: Center(
                                child: PhosphorIcon(
                                  PhosphorIcons.crown(PhosphorIconsStyle.fill),
                                  color: isPremium
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Plan details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    planName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'RM $price',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PhosphorIcon(
                                    statusIcon,
                                    color: statusColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Divider
                        Container(
                          height: 1,
                          color: AppTheme.borderColor.withValues(alpha: 0.5),
                        ),

                        const SizedBox(height: 16),

                        // Date information
                        if (startDate != null) ...[
                          _buildDateRow('Start Date', startDate),
                        ],
                        if (endDate != null) ...[
                          const SizedBox(height: 8),
                          _buildDateRow('End Date', endDate),
                        ],

                        // Recovery button for pending payments
                        if (status.toLowerCase() == 'pending' && !_isRecovering) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _recoverPayment(subscription),
                              icon: _isRecovering
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : PhosphorIcon(
                                      PhosphorIcons.arrowClockwise(PhosphorIconsStyle.fill),
                                      size: 16,
                                    ),
                              label: Text(_isRecovering ? 'Recovering...' : 'Recover Payment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],

                        // Recovery message
                        if (_recoveryMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _recoveryMessage!.contains('✅')
                                  ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                                  : const Color(0xFFF44336).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _recoveryMessage!.contains('✅')
                                    ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                                    : const Color(0xFFF44336).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _recoveryMessage!,
                              style: TextStyle(
                                color: _recoveryMessage!.contains('✅')
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFF44336),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateRow(String label, String date) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDate(date),
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  /// Recover stuck payment
  Future<void> _recoverPayment(Map<String, dynamic> subscription) async {
    final billId = subscription['payment_id'] as String?;
    final planId = subscription['plan_id'] as String?;

    if (billId == null) {
      _showError('No Bill ID found for this payment');
      return;
    }

    setState(() {
      _isRecovering = true;
      _recoveryMessage = null;
    });

    try {
      final result = await PaymentProcessingService().recoverPayment(
        billId: billId,
        planId: planId,
        forceVerify: true,
      );

      if (mounted) {
        if (result.success) {
          _showSuccess(result.message);
          // Reload payment history
          await context.read<SubscriptionProvider>().loadUserSubscriptions();
        } else {
          _showError(result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Payment recovery failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecovering = false;
        });
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFF44336),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedInvoice02,
                          color: AppTheme.primaryColor,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Payment History',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You haven\'t made any payments yet. Start your journey with our premium plans!',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondaryColor,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/subscription'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: PhosphorIcon(
                          PhosphorIcons.crown(PhosphorIconsStyle.fill),
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'View Premium Plans',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}