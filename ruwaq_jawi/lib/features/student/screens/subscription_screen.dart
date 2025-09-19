import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/payment_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/payment_models.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/student_bottom_nav.dart';

// Enum for subscription actions
enum SubscriptionAction {
  purchase, // Can buy (no active subscription)
  upgrade, // Can upgrade to higher tier
  currentPlan, // Same as current plan (disabled)
  notAvailable, // Lower tier while active (disabled)
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Future<void> _loadPlansFuture;
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _loadPlansFuture = _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final paymentProvider = Provider.of<PaymentProvider>(
        context,
        listen: false,
      );
      await paymentProvider.loadSubscriptionPlans();

      // Set initial plan selection after loading plans
      final plans = paymentProvider.subscriptionPlans;
      if (plans.isNotEmpty && _selectedPlanId == null) {
        _selectedPlanId = plans.first.id;
      }
    } catch (e) {
      print('Error loading plans: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Premium Benefits',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // DEBUG: Manual refresh subscription button
          IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.arrowClockwise(),
              color: Colors.black87,
              size: 20,
            ),
            onPressed: () async {
              try {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing subscription status...'),
                  ),
                );

                await authProvider.checkActiveSubscription();
                // checkActiveSubscription() already refreshes profile data

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      authProvider.hasActiveSubscription
                          ? 'Subscription: AKTIF ✅'
                          : 'Subscription: TIDAK AKTIF ❌',
                    ),
                    backgroundColor: authProvider.hasActiveSubscription
                        ? Colors.green
                        : Colors.orange,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loadPlansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Consumer<PaymentProvider>(
            builder: (context, paymentProvider, child) {
              final plans = paymentProvider.subscriptionPlans;

              if (plans.isEmpty) {
                return const Center(
                  child: Text('Tiada pelan langganan tersedia'),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Benefits Section
                    _buildBenefitsSection(),

                    const SizedBox(height: 32),

                    // Subscription Plans
                    _buildSubscriptionPlans(plans),

                    const SizedBox(height: 24),

                    // Terms and Subscribe Button
                    _buildSubscribeButton(plans),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const StudentBottomNav(currentIndex: 3),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = [
      {
        'title': 'Akses 2000+ konten pembelajaran',
        'icon': PhosphorIcons.bookOpen(),
      },
      {
        'title': 'Topik trending dan pilihan pakar',
        'icon': PhosphorIcons.trendUp(),
      },
      {
        'title': 'Rekomendasi kitab yang disesuaikan',
        'icon': PhosphorIcons.bookmarkSimple(),
      },
      {
        'title': 'Simpan favorit ke perpustakaan peribadi',
        'icon': PhosphorIcons.heart(),
      },
      {
        'title': 'Panduan interaktif dan cabaran harian',
        'icon': PhosphorIcons.gameController(),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...benefits.map(
          (benefit) => _buildBenefitItem(
            benefit['title'] as String,
            benefit['icon'] as PhosphorIconData,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(String title, PhosphorIconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlans(List<SubscriptionPlan> plans) {
    // Sort plans by duration (shortest first)
    final sortedPlans = [...plans];
    sortedPlans.sort(
      (a, b) => (a.durationDays ?? 0).compareTo(b.durationDays ?? 0),
    );

    return Column(
      children: sortedPlans.map((plan) => _buildPlanCard(plan)).toList(),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isSelected = _selectedPlanId == plan.id;
    final isRecommended = plan.id == 'semiannual_pr'; // 6 months recommended

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = plan.id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getPlanDisplayName(plan),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RM${_getMonthlyPrice(plan).toStringAsFixed(2)} per month',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'RM${plan.price.toStringAsFixed(2)} ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      TextSpan(
                        text:
                            'every ${_getPlanDisplayName(plan).toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Recommended badge
            if (isRecommended)
              Positioned(
                top: -8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'FREE for 7-days',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribeButton(List<SubscriptionPlan> plans) {
    // Get the selected plan, fallback to first if somehow selectedPlanId is null
    final selectedPlan = plans.firstWhere(
      (plan) => plan.id == _selectedPlanId,
      orElse: () => plans.first,
    );

    return Column(
      children: [
        // Terms text
        Text(
          'FREE for 7-days, then RM${selectedPlan.price.toStringAsFixed(2)} every ${_getPlanDisplayName(selectedPlan).toLowerCase()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Subscribe button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _handleSubscribe(selectedPlan),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 2,
            ),
            child: Text(
              'Start your 7-days FREE trial',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Terms and conditions
        Text(
          'By subscribing, you agree to our Terms of Service and Privacy Policy. Your subscription will automatically renew.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  String _getPlanDisplayName(SubscriptionPlan plan) {
    switch (plan.id) {
      case 'monthly_basic': // ← FIXED: Actual 1 month plan ID
        return '1 month';
      case 'quarterly_pr':
        return '3 months';
      case 'monthly_premium': // ← FIXED: This is actually 6 month plan in database
        return '6 months';
      case 'yearly_premium': // ← FIXED: Use correct yearly plan ID
        return '12 months';
      default:
        return '${(plan.durationDays ?? 30) ~/ 30} months';
    }
  }

  double _getMonthlyPrice(SubscriptionPlan plan) {
    final months = (plan.durationDays ?? 30) / 30;
    return plan.price / months;
  }

  void _handleSubscribe(SubscriptionPlan selectedPlan) async {
    try {
      print('DEBUG: User clicked subscribe for plan ${selectedPlan.id}');

      final user = SupabaseService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sila log masuk untuk melanggan'),
            backgroundColor: Colors.red,
          ),
        );
        context.go('/auth');
        return;
      }

      // Get available plans from provider
      final paymentProvider = Provider.of<PaymentProvider>(
        context,
        listen: false,
      );
      final availablePlans = paymentProvider.subscriptionPlans;

      // Get the selected plan based on user choice
      final chosenPlan = availablePlans.firstWhere(
        (plan) => plan.id == _selectedPlanId,
        orElse: () => selectedPlan,
      );

      print(
        'DEBUG: Selected plan: ${chosenPlan.id}, Price: RM${chosenPlan.price}',
      );

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Create ToyyibPay bill
      final paymentResponse = await paymentProvider.createSubscriptionPayment(
        plan: chosenPlan,
        userEmail: user.email ?? '',
        userName: user.userMetadata?['full_name'] ?? 'User',
        userPhone: user.phone ?? '',
        redirectUrl: 'https://your-app.com/payment/callback',
        webhookUrl: 'https://your-app.com/webhook/payment',
        userId: user.id,
      );

      // Hide loading
      if (context.mounted) Navigator.pop(context);

      if (paymentResponse != null) {
        // Navigate to ToyyibPay payment screen
        context.push(
          '/payment/toyyibpay',
          extra: {
            'billCode': paymentResponse.id,
            'billUrl': paymentResponse.url,
            'planId': chosenPlan.id,
            'amount': chosenPlan.price,
          },
        );
      } else {
        throw Exception('Gagal membuat bil pembayaran');
      }
    } catch (e) {
      // Hide loading if still showing
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ralat: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
