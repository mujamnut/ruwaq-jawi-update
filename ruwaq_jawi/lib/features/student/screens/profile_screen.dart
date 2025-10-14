import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/theme/app_theme.dart';

// Import managers
import 'profile_screen/managers/profile_animation_manager.dart';
import 'profile_screen/managers/profile_data_manager.dart';
import 'profile_screen/managers/subscription_manager.dart';

// Import services
import 'profile_screen/services/password_change_service.dart';

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

        // Load KitabProvider data for profile statistics
        final kitabProvider = context.read<KitabProvider>();
        if (kitabProvider.ebookList.isEmpty || kitabProvider.videoKitabList.isEmpty) {
          kitabProvider.initialize(); // Load both ebooks and video kitabs
        }

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
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildGradientHeader(userProfile),
                            // Premium card overlapping the gradient header
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: -160, // Overlap by 60px
                              child: _buildPremiumCard(),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 210,
                        ), // Space for overlapping card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              _buildProfileMenuSection(),
                              const SizedBox(height: 24),
                              _buildNotificationsSection(),
                              const SizedBox(height: 24),
                              _buildSettingsSection(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
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

  Widget _buildGradientHeader(userProfile) {
    final isPremium = _subscriptionManager.currentSubscription != null;
    final createdAt = userProfile.createdAt;
    final joinedDate = createdAt != null
        ? '${_getMonthName(createdAt.month)} ${createdAt.year}'
        : 'Recently';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            children: [
              // Premium Member badge (always show in header)
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
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

              SizedBox(height: isPremium ? 20 : 0),

              // Avatar with verification badge
              _buildAvatarWithBadge(userProfile),

              const SizedBox(height: 16),

              // Name
              Text(
                userProfile.fullName ?? 'Pengguna',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Email
              Text(
                userProfile.email ?? '',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Joined date
              Text(
                'Joined $joinedDate',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  
  Widget _buildAvatarWithBadge(userProfile) {
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
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    (userProfile.fullName ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumCard() {
    final isPremium = _subscriptionManager.currentSubscription != null;

    if (!isPremium) {
      // Show free/basic plan card
      return Consumer<KitabProvider>(
        builder: (context, kitabProvider, child) {
          // Get actual free books count from ebooks table
          final freeBooksCount = kitabProvider.freeEbooks.length;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Basic Plan header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedBook02,
                          color: AppTheme.primaryColor,
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
                            'Basic Plan',
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Free access to kitab',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: const Color(0xFF4CAF50),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Divider
                Container(height: 1, color: AppTheme.borderColor),

                const SizedBox(height: 20),

                // Free plan benefits - 3 columns with dividers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Actual Free Books Access
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$freeBooksCount',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Free Books',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(width: 1, height: 40, color: AppTheme.borderColor),
                    // Total Videos
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${kitabProvider.freeVideoKitab.length}',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Videos',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(width: 1, height: 40, color: AppTheme.borderColor),
                    // SD Quality
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'SD',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Quality',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    // Show active premium card with stats
    final sub = _subscriptionManager.currentSubscription!;
    final endDate = DateTime.parse(sub['end_date']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Premium Plan header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.crown(PhosphorIconsStyle.fill),
                    color: Colors.white,
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
                      'Premium Plan',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Active until ${endDate.day} ${_getMonthName(endDate.month)} ${endDate.year}',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    color: const Color(0xFF4CAF50),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Divider
          Container(height: 1, color: AppTheme.borderColor),

          const SizedBox(height: 20),

          // Benefits row - 3 columns with dividers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Books Access with infinity icon
              Expanded(
                child: Column(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedInfinity01,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Books Access',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Divider
              Container(width: 1, height: 40, color: AppTheme.borderColor),
              // 24/7 Support
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '24/7',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Support',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Divider
              Container(width: 1, height: 40, color: AppTheme.borderColor),
              // HD Quality
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'HD',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quality',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              _buildMenuItem(
                icon: HugeIcons.strokeRoundedFavourite,
                iconColor: AppTheme.primaryColor,
                title: 'Saved Items',
                subtitle: '12 items saved',
                onTap: () => context.push('/saved'),
                isFirst: true,
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              _buildMenuItem(
                icon: PhosphorIcons.clockCounterClockwise(),
                iconColor: const Color(0xFF00BCD4),
                title: 'History',
                subtitle: 'Recent Records',
                onTap: _handleHistory,
              ),

              Divider(height: 1, color: AppTheme.borderColor),
              _buildMenuItem(
                icon: PhosphorIcons.downloadSimple(),
                iconColor: const Color(0xFF9C27B0),
                title: 'Downloads',
                subtitle: 'Offline reading',
                onTap: _handleDownloads,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'NOTIFICATIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: _buildMenuItem(
            icon: PhosphorIcons.bell(),
            iconColor: const Color(0xFFFF9800),
            title: 'Notifications',
            subtitle: null,
            onTap: _handleNotifications,
            isFirst: true,
            isLast: true,
          ),
        ),
      ],
    );
  }

  void _handleHistory() {
    context.push('/payment-history');
  }

  void _handleDownloads() {
    // TODO: Navigate to downloads screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloads feature coming soon')),
    );
  }

  void _handleNotifications() {
    // TODO: Navigate to notifications settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification settings coming soon')),
    );
  }

  void _handlePrivacySecurity() {
    context.push('/privacy-security');
  }

  void _handleHelpSupport() {
    context.push('/help-support');
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'SETTINGS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            children: [
              _buildMenuItem(
                icon: PhosphorIcons.lock(),
                iconColor: AppTheme.primaryColor,
                title: 'Change Password',
                subtitle: null,
                onTap: _handleChangePassword,
                isFirst: true,
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              _buildMenuItem(
                icon: PhosphorIcons.shieldCheck(),
                iconColor: const Color(0xFF00BCD4),
                title: 'Privacy & Security',
                subtitle: null,
                onTap: _handlePrivacySecurity,
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              _buildMenuItem(
                icon: PhosphorIcons.chatsCircle(),
                iconColor: const Color(0xFF4CAF50),
                title: 'Help & Support',
                subtitle: null,
                onTap: _handleHelpSupport,
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              _buildMenuItem(
                icon: PhosphorIcons.signOut(),
                iconColor: AppTheme.errorColor,
                title: 'Logout',
                subtitle: null,
                onTap: _handleSignOut,
                isLast: true,
                isDestructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required dynamic icon,
    required Color iconColor,
    required String title,
    String? subtitle,
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
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive
                            ? iconColor
                            : AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
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
    );
  }
}
