import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with TickerProviderStateMixin {
  late Future<void> _loadPlansFuture;
  String? _selectedPlanId;
  late AnimationController _animationController;
  late AnimationController _scaleAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadPlansFuture = _loadPlans();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _scaleAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation after a brief delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scaleAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      print('🔥 SubscriptionScreen: Starting to load plans...');
      final paymentProvider = Provider.of<PaymentProvider>(
        context,
        listen: false,
      );

      print(
        '📱 SubscriptionScreen: Calling PaymentProvider.loadSubscriptionPlans()...',
      );
      await paymentProvider.loadSubscriptionPlans();

      // Set initial plan selection after loading plans
      final plans = paymentProvider.subscriptionPlans;
      print(
        '📋 SubscriptionScreen: Received ${plans.length} plans from PaymentProvider',
      );

      if (plans.isNotEmpty && _selectedPlanId == null) {
        _selectedPlanId = plans.first.id;
        print('✅ SubscriptionScreen: Selected initial plan: $_selectedPlanId');
      } else if (plans.isEmpty) {
        print('⚠️ SubscriptionScreen: No plans available');
      }

      // Check for any errors from PaymentProvider
      if (paymentProvider.error != null) {
        print(
          '❌ SubscriptionScreen: PaymentProvider has error: ${paymentProvider.error}',
        );
      }
    } catch (e) {
      print('❌ SubscriptionScreen: Error loading plans: $e');
      // Don't rethrow to prevent ErrorBoundary conflicts during build
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Premium Benefits',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: FutureBuilder<void>(
        future: _loadPlansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat pelan langganan...',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          // Check for FutureBuilder errors
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.warning(),
                    color: AppTheme.errorColor,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ralat Memuat Pelan',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Gagal memuatkan pelan langganan: ${snapshot.error}',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadPlansFuture = _loadPlans();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cuba Lagi'),
                  ),
                ],
              ),
            );
          }

          return Consumer<PaymentProvider>(
            builder: (context, paymentProvider, child) {
              final plans = paymentProvider.subscriptionPlans;
              final error = paymentProvider.error;

              // Check for PaymentProvider errors
              if (error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.warning(),
                        color: AppTheme.errorColor,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ralat Sistem Pembayaran',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          error,
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          paymentProvider.clearError();
                          setState(() {
                            _loadPlansFuture = _loadPlans();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cuba Lagi'),
                      ),
                    ],
                  ),
                );
              }

              if (plans.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.warningCircle(),
                        color: AppTheme.textSecondaryColor,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tiada pelan langganan tersedia',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sila cuba lagi kemudian',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loadPlansFuture = _loadPlans();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Muat Semula'),
                      ),
                    ],
                  ),
                );
              }

              return AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBenefitsSection(),
                            const SizedBox(height: 40),
                            _buildSubscriptionPlans(plans),
                            const SizedBox(height: 32),
                            _buildSubscribeButton(plans),
                            const SizedBox(height: 20), // Bottom padding
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
        'description': 'Video, audio, dan teks berkualiti tinggi',
      },
      {
        'title': 'Topik trending dan pilihan pakar',
        'icon': PhosphorIcons.trendUp(),
        'description': 'Kandungan terkini dari para ulama',
      },
      {
        'title': 'Rekomendasi kitab yang disesuaikan',
        'icon': PhosphorIcons.bookmarkSimple(),
        'description': 'Berdasarkan tahap pembelajaran anda',
      },
      {
        'title': 'Simpan favorit ke perpustakaan peribadi',
        'icon': PhosphorIcons.heart(),
        'description': 'Akses mudah ke kandungan kegemaran',
      },
      {
        'title': 'Panduan interaktif dan cabaran harian',
        'icon': PhosphorIcons.gameController(),
        'description': 'Tingkatkan ilmu dengan cara menyeronokkan',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: PhosphorIcon(
                      PhosphorIcons.crown(PhosphorIconsStyle.fill),
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
                          'Kenapa Premium?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nikmati pengalaman pembelajaran terbaik',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...benefits.asMap().entries.map(
                (entry) => _buildBenefitItem(
                  entry.value['title'] as String,
                  entry.value['icon'] as PhosphorIconData,
                  entry.value['description'] as String,
                  entry.key,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(
    String title,
    PhosphorIconData icon,
    String description,
    int index,
  ) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PhosphorIcon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondaryColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: PhosphorIcon(
                      PhosphorIcons.check(PhosphorIconsStyle.bold),
                      color: AppTheme.successColor,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionPlans(List<SubscriptionPlan> plans) {
    // Sort plans by duration (shortest first)
    final sortedPlans = [...plans];
    sortedPlans.sort((a, b) => a.durationDays.compareTo(b.durationDays));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Pelan Langganan',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Semua pelan termasuk 7 hari percubaan percuma',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 24),
        ...sortedPlans.asMap().entries.map(
          (entry) => TweenAnimationBuilder(
            duration: Duration(milliseconds: 800 + (entry.key * 150)),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            builder: (context, double value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * 30),
                child: Opacity(
                  opacity: value,
                  child: _buildPlanCard(entry.value, entry.key),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, int index) {
    final isSelected = _selectedPlanId == plan.id;
    final isRecommended = plan.id == 'semiannual_pr'; // 6 months recommended

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = plan.id;
        });
        // Add haptic feedback for better UX
        HapticFeedback.lightImpact();
        // Scale animation on tap
        _scaleAnimationController.forward().then((_) {
          _scaleAnimationController.reverse();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.05),
              spreadRadius: isSelected ? 2 : 0,
              blurRadius: isSelected ? 20 : 8,
              offset: Offset(0, isSelected ? 8 : 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                      : AppTheme.neutralGray,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                        : AppTheme.borderColor,
                                  ),
                                ),
                                child: PhosphorIcon(
                                  PhosphorIcons.calendar(),
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondaryColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _getPlanDisplayName(plan),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'RM${_getMonthlyPrice(plan).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                ' sebulan',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.borderColor,
                          width: 2,
                        ),
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? PhosphorIcon(
                              PhosphorIcons.check(PhosphorIconsStyle.bold),
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.05)
                        : AppTheme.neutralGray,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.2)
                          : AppTheme.borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jumlah Bayaran',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'RM${plan.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' setiap ${_getPlanDisplayName(plan).toLowerCase()}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: PhosphorIcon(
                            PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                            color: Colors.white,
                            size: 20,
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
                top: -12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryLightColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.crown(PhosphorIconsStyle.fill),
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'POPULAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Trial info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PhosphorIcon(
                    PhosphorIcons.gift(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Percubaan 7 hari PERCUMA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      Text(
                        'Kemudian RM${selectedPlan.price.toStringAsFixed(2)} setiap ${_getPlanDisplayName(selectedPlan).toLowerCase()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 3,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.crown(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mulakan Percubaan PERCUMA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Terms and conditions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.neutralGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.info(),
                      color: AppTheme.textSecondaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Maklumat Penting',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Dengan melanggan, anda bersetuju dengan Terma Perkhidmatan dan Dasar Privasi kami. Langganan akan diperbaharui secara automatik.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        return '${plan.durationDays ~/ 30} months';
    }
  }

  double _getMonthlyPrice(SubscriptionPlan plan) {
    final months = plan.durationDays / 30;
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
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Menyediakan pembayaran...',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
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
