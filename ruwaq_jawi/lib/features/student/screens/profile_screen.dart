import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

// Import managers
import 'profile_screen/managers/profile_animation_manager.dart';
import 'profile_screen/managers/profile_data_manager.dart';
import 'profile_screen/managers/subscription_manager.dart';

// Import services
import 'profile_screen/services/password_change_service.dart';
import 'profile_screen/services/profile_notification_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  // Managers
  late ProfileAnimationManager _animationManager;
  late ProfileDataManager _dataManager;
  late SubscriptionManager _subscriptionManager;

  @override
  void initState() {
    super.initState();

    // Initialize managers
    _animationManager = ProfileAnimationManager();
    _animationManager.initialize(this);

    _dataManager = ProfileDataManager(onStateChanged: () => setState(() {}));
    _subscriptionManager = SubscriptionManager(
      onStateChanged: () => setState(() {}),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _dataManager.initializeNameController(context);
        // Start animations
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _animationManager.startAnimations();
          }
        });
      }
    });

    _subscriptionManager.loadCurrentSubscription();
  }

  @override
  void dispose() {
    _dataManager.dispose();
    _animationManager.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateName() async {
    final success = await _dataManager.updateName(context);
    if (success && mounted) {
      ProfileNotificationHelper.showNameUpdateSuccess(context);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Keluar'),
        content: const Text('Adakah anda pasti mahu log keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Log Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _handleChangePassword() {
    PasswordChangeService.showPasswordChangeDialog(context);
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
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppTheme.textPrimaryColor,
            size: 30,
          ),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          'Profile',
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final userProfile = authProvider.userProfile;

          if (userProfile == null) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            );
          }

          return AnimatedBuilder(
            animation: _animationManager.fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _animationManager.fadeAnimation.value.clamp(0.0, 1.0),
                child: SlideTransition(
                  position: _animationManager.slideAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        _buildAvatar(userProfile),
                        const SizedBox(height: 16),
                        _buildProfileInfo(authProvider, userProfile),
                        const SizedBox(height: 32),
                        _buildSavedItemsSection(),
                        const SizedBox(height: 20),
                        _buildSubscriptionSection(userProfile),
                        const SizedBox(height: 20),
                        _buildSettingsSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Import the widget build methods from backup file for now
  // In production, these would be extracted to separate widget files

  Widget _buildAvatar(userProfile) {
    final isPremium = _subscriptionManager.currentSubscription != null;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Premium border gradient
              if (isPremium)
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFFA500),
                        Color(0xFFFFD700),
                      ],
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.backgroundColor,
                    ),
                  ),
                ),
              // Avatar
              Container(
                width: isPremium ? 102 : 100,
                height: isPremium ? 102 : 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.7),
                    ],
                  ),
                  border: !isPremium
                      ? Border.all(color: AppTheme.borderColor, width: 3)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    (userProfile.fullName ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Premium crown badge
              if (isPremium)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      border: Border.all(
                        color: AppTheme.backgroundColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: PhosphorIcon(
                      PhosphorIcons.crown(PhosphorIconsStyle.fill),
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileInfo(AuthProvider authProvider, userProfile) {
    final isPremium = _subscriptionManager.currentSubscription != null;

    return Column(
      children: [
        // Name
        Text(
          userProfile.fullName ?? 'Pengguna',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        // Email
        Text(
          userProfile.email ?? '',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 15),
        ),
        const SizedBox(height: 16),
        // Edit Profile button
        OutlinedButton.icon(
          onPressed: () => context.push('/edit-profile'),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedPencilEdit01,
            color: AppTheme.primaryColor,
            size: 18,
          ),
          label: Text(
            'Edit Profile',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppTheme.primaryColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
        // Premium badge or member since
        if (isPremium) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIcons.crown(PhosphorIconsStyle.fill),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Premium Member',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedUserCircle,
                  color: AppTheme.textSecondaryColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Free Member',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSavedItemsSection() {
    return _buildEnhancedMenuItem(
      icon: PhosphorIcons.bookmarkSimple(),
      iconColor: AppTheme.primaryColor,
      title: 'Item yang Disimpan',
      subtitle: 'Lihat video dan e-book yang disimpan',
      onTap: () => context.push('/saved'),
    );
  }

  Widget _buildSubscriptionSection(userProfile) {
    return _buildSection(
      title: 'Langganan',
      child: _subscriptionManager.isLoadingSubscription
          ? Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            )
          : _subscriptionManager.currentSubscription != null
          ? _buildActiveSubscriptionCard()
          : _buildInactiveSubscriptionCard(),
    );
  }

  Widget _buildActiveSubscriptionCard() {
    final sub = _subscriptionManager.currentSubscription!;
    final plan = sub['subscription_plans'];
    final endDate = DateTime.parse(sub['end_date']);
    final daysLeft = endDate.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.crown(PhosphorIconsStyle.fill),
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan['name'] ?? 'Premium',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Aktif sehingga ${endDate.day}/${endDate.month}/${endDate.year}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            '$daysLeft hari lagi',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveSubscriptionCard() {
    return _buildEnhancedMenuItem(
      icon: PhosphorIcons.crown(),
      iconColor: const Color(0xFFFFD700),
      title: 'Langgan Premium',
      subtitle: 'Akses tanpa had ke semua kandungan',
      onTap: () => context.push('/subscription'),
      isPremium: true,
    );
  }

  Widget _buildSettingsSection() {
    return _buildSection(
      title: 'Tetapan',
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            _buildSettingItem(
              icon: PhosphorIcons.lock(),
              iconColor: AppTheme.primaryColor,
              title: 'Tukar Kata Laluan',
              onTap: _handleChangePassword,
              isFirst: true,
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            _buildSettingItem(
              icon: PhosphorIcons.signOut(),
              iconColor: AppTheme.errorColor,
              title: 'Log Keluar',
              onTap: _handleSignOut,
              isLast: true,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildSettingItem({
    required dynamic icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isFirst ? 20 : 0),
          topRight: Radius.circular(isFirst ? 20 : 0),
          bottomLeft: Radius.circular(isLast ? 20 : 0),
          bottomRight: Radius.circular(isLast ? 20 : 0),
        ),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: PhosphorIcon(icon, color: iconColor, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDestructive
                        ? iconColor
                        : AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppTheme.textSecondaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedMenuItem({
    required dynamic icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return Container(
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
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: isPremium
                        ? const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          )
                        : LinearGradient(
                            colors: [
                              iconColor.withValues(alpha: 0.1),
                              iconColor.withValues(alpha: 0.05),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      icon,
                      color: isPremium ? Colors.white : iconColor,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: AppTheme.textSecondaryColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
