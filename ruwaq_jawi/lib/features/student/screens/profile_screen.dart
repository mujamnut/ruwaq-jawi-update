import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/avatar_service.dart';

// Import managers
import 'profile_screen/managers/profile_animation_manager.dart';
import 'profile_screen/managers/profile_data_manager.dart';
import 'profile_screen/managers/subscription_manager.dart';

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
  late final AnimationController _ringController;

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

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
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
    _ringController.dispose();
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

  Future<void> _handleUploadCustomAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;
      if (!mounted) return;

      _showLoadingDialog('Uploading avatar...');

      final authProvider = context.read<AuthProvider>();
      final userProfile = authProvider.userProfile;

      if (userProfile == null) {
        if (!mounted) return;
        Navigator.pop(context);
        _showErrorMessage('User profile not found');
        return;
      }

      final userId = userProfile.id;
      final file = File(image.path);
      final fileExt = image.path.split('.').last;
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('user-avatars')
          .upload(filePath, file);

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('user-avatars')
          .getPublicUrl(filePath);

      // Update user profile
      await authProvider.updateAvatar(publicUrl);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showSuccessMessage('Avatar updated successfully!');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showErrorMessage('Failed to upload avatar: $e');
    }
  }

  void _handleManageAvatar() async {
    final authProvider = context.read<AuthProvider>();
    final userProfile = authProvider.userProfile;

    if (userProfile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedUserSquare,
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
                        const Text(
                          'Manage Avatar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<AvatarSource?>(
                          future: authProvider.getAvatarSource(),
                          builder: (context, snapshot) {
                            String sourceText = 'Unknown';
                            Color sourceColor = AppTheme.textSecondaryColor;

                            if (snapshot.hasData) {
                              switch (snapshot.data!) {
                                case AvatarSource.gravatar:
                                  sourceText = 'Gravatar';
                                  sourceColor = AppTheme.primaryColor;
                                  break;
                                case AvatarSource.uiAvatars:
                                  sourceText = 'Generated';
                                  sourceColor = const Color(0xFF00BCD4);
                                  break;
                                case AvatarSource.initials:
                                  sourceText = 'Initials';
                                  sourceColor = const Color(0xFF9C27B0);
                                  break;
                                case AvatarSource.custom:
                                  sourceText = 'Custom';
                                  sourceColor = const Color(0xFF4CAF50);
                                  break;
                              }
                            }

                            return Text(
                              'Current: $sourceText',
                              style: TextStyle(
                                fontSize: 14,
                                color: sourceColor,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Avatar options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Upload custom image
                  _buildAvatarOption(
                    icon: HugeIcons.strokeRoundedImage02,
                    title: 'Upload Custom Image',
                    subtitle: 'Choose image from your phone',
                    onTap: () {
                      Navigator.pop(context);
                      _handleUploadCustomAvatar();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Refresh from email
                  _buildAvatarOption(
                    icon: HugeIcons.strokeRoundedRefresh,
                    title: 'Refresh from Email',
                    subtitle: 'Get latest avatar from Gravatar',
                    onTap: () async {
                      if (!context.mounted) return;

                      Navigator.pop(context);
                      _showLoadingDialog('Refreshing avatar...');

                      try {
                        final success = await authProvider.refreshAvatarFromEmail();
                        if (!context.mounted) return;
                        Navigator.pop(context); // Close loading dialog

                        if (success) {
                          _showSuccessMessage('Avatar refreshed successfully!');
                        } else {
                          _showErrorMessage('No avatar found for your email. Try registering on Gravatar.com');
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context); // Close loading dialog
                        _showErrorMessage('Failed to refresh avatar. Please try again.');
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  // View avatar info
                  _buildAvatarOption(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    title: 'Avatar Info',
                    subtitle: 'Learn about avatar sources',
                    onTap: () {
                      Navigator.pop(context);
                      _showAvatarInfoDialog();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCancelCircle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showAvatarInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Avatars'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avatar Sources:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            Text('• Gravatar: Global avatar from gravatar.com'),
            Text('• Generated: Auto-generated with your initials'),
            Text('• Custom: Manually uploaded avatar'),
            SizedBox(height: 16),
            Text(
              'To get a Gravatar:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('1. Visit gravatar.com'),
            Text('2. Sign up with the same email'),
            Text('3. Upload your avatar'),
            Text('4. It will appear here automatically'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarOption({
    required dynamic icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    color: AppTheme.primaryColor,
                    size: 24,
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
                      style: const TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
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
                              _buildBillingSection(),
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
    final createdAt = userProfile.createdAt;
    final joinedDate = createdAt != null
        ? '${_getMonthName(createdAt.month)} ${createdAt.year}'
        : 'Recently';

    // Use neutral background for all users (premium + free)
    final Gradient headerGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.backgroundColor,
        AppTheme.surfaceColor,
      ],
    );

    // Dark text on light header for both plans
    final Color titleColor = AppTheme.textPrimaryColor;
    final Color emailColor = AppTheme.textSecondaryColor;
    final Color joinedColor = AppTheme.textSecondaryColor.withValues(alpha: 0.9);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: headerGradient,
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
              const SizedBox(height: 8),

              // Avatar with verification badge
              _buildAvatarWithBadge(userProfile),

              const SizedBox(height: 16),

              // Name
              Text(
                userProfile.fullName ?? 'Pengguna',
                style: TextStyle(
                  color: titleColor,
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
                  color: emailColor,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Joined date
              Text(
                'Joined $joinedDate',
                style: TextStyle(
                  color: joinedColor,
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

    // Keep ring animation in sync with premium status
    if (isPremium) {
      if (!_ringController.isAnimating) _ringController.repeat();
    } else {
      if (_ringController.isAnimating) _ringController.stop();
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _handleUploadCustomAvatar();
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Premium rotating ring (gold sweep gradient)
                if (isPremium)
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (context, _) {
                      final angle = _ringController.value * 2 * math.pi;
                      return Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: const [
                              Color(0xFFFFD700),
                              Color(0xFFFFA500),
                              Color(0xFFFFD700),
                              Color(0xFFDAA520),
                              Color(0xFFFFD700),
                            ],
                            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                            transform: GradientRotation(angle),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                // Avatar
                Container(
                  width: isPremium ? 104 : 100,
                  height: isPremium ? 104 : 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPremium ? Colors.white : Colors.transparent,
                    border: isPremium
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 3,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildProfileAvatarImage(
                      userProfile,
                      size: isPremium ? 98 : 100,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileAvatarImage(userProfile, {double size = 94}) {
    final avatarUrl = userProfile.avatarUrl;
    final fullName = userProfile.fullName ?? 'User';
    final initials = AvatarService.getInitials(fullName);

    // Handle initials:// scheme for local generated avatars
    if (avatarUrl != null && avatarUrl.startsWith('initials://')) {
      final name = avatarUrl.replaceFirst('initials://', '').split('?')[0];
      final extractedInitials = AvatarService.getInitials(name);
      return _buildInitialsAvatar(extractedInitials, size: size);
    }

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialsAvatar(initials, size: size);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else {
      return _buildInitialsAvatar(initials, size: size);
    }
  }

  Widget _buildInitialsAvatar(String initials, {double size = 94}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            Color(0xFF00A85C),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                title: 'Reading History',
                subtitle: 'Recently viewed',
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
    context.push('/reading-history');
  }

  void _handleDownloads() {
    // TODO: Navigate to downloads screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloads feature coming soon')),
    );
  }

  void _handleNotifications() {
    context.push('/notifications');
  }

  void _handlePrivacySecurity() {
    context.push('/privacy-security');
  }

  void _handleHelpSupport() {
    context.push('/help-support');
  }

  void _handleSubscription() {
    context.push('/subscription');
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
                icon: PhosphorIcons.user(),
                iconColor: AppTheme.primaryColor,
                title: 'Edit Profile',
                subtitle: null,
                onTap: () => context.push('/edit-profile'),
                isFirst: true,
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              _buildMenuItem(
                icon: PhosphorIcons.userCircle(),
                iconColor: AppTheme.primaryColor,
                title: 'Manage Avatar',
                subtitle: null,
                onTap: _handleManageAvatar,
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

  Widget _buildBillingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'BILLING & SUBSCRIPTION',
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
                icon: PhosphorIcons.crown(),
                iconColor: AppTheme.primaryColor,
                title: 'Subscription',
                subtitle: 'Manage your plan',
                onTap: _handleSubscription,
                isFirst: true,
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              _buildMenuItem(
                icon: PhosphorIcons.receipt(),
                iconColor: const Color(0xFF00BCD4),
                title: 'Payment History',
                subtitle: 'View past payments',
                onTap: () => context.push('/payment-history'),
                isLast: true,
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
