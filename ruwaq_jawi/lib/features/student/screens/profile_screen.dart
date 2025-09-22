import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  bool _isEditingName = false;
  final _nameController = TextEditingController();
  Map<String, dynamic>? _currentSubscription;
  bool _isLoadingSubscription = true;

  // Animation controllers for smooth animations
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
      value: 0.0, // Start with 0 opacity
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
      value: 0.0, // Start with 0 position
    );

    // Create animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        _nameController.text = authProvider.userProfile?.fullName ?? '';
        // Start animations with delay to ensure proper initialization
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _fadeAnimationController.forward();
            _slideAnimationController.forward();
          }
        });
      }
    });
    _loadCurrentSubscription();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSubscription() async {
    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        final response = await SupabaseService.from('user_subscriptions')
            .select('*, subscription_plans(*)')
            .eq('user_id', user.id)
            .eq('status', 'active')
            .gte('end_date', DateTime.now().toIso8601String())
            .order('end_date', ascending: false)
            .limit(1)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _currentSubscription = response;
            _isLoadingSubscription = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentSubscription = null;
            _isLoadingSubscription = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading subscription: $e');
      if (mounted) {
        setState(() {
          _currentSubscription = null;
          _isLoadingSubscription = false;
        });
      }
    }
  }

  Future<void> _handleUpdateName() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updateProfile(
      fullName: _nameController.text.trim(),
    );

    if (success && mounted) {
      setState(() {
        _isEditingName = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nama berjaya dikemaskini'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log Keluar'),
        content: Text('Adakah anda pasti mahu log keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text('Log Keluar'),
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
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isChangingPassword = false;
    bool obscureOldPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Tukar Kata Laluan'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Old Password Field
                  TextField(
                    controller: oldPasswordController,
                    obscureText: obscureOldPassword,
                    decoration: InputDecoration(
                      labelText: 'Kata Laluan Lama',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: PhosphorIcon(
                          obscureOldPassword
                              ? PhosphorIcons.eye()
                              : PhosphorIcons.eyeSlash(),
                        ),
                        onPressed: () {
                          setState(() {
                            obscureOldPassword = !obscureOldPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // New Password Field
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'Kata Laluan Baru',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: PhosphorIcon(
                          obscureNewPassword
                              ? PhosphorIcons.eye()
                              : PhosphorIcons.eyeSlash(),
                        ),
                        onPressed: () {
                          setState(() {
                            obscureNewPassword = !obscureNewPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Sahkan Kata Laluan Baru',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: PhosphorIcon(
                          obscureConfirmPassword
                              ? PhosphorIcons.eye()
                              : PhosphorIcons.eyeSlash(),
                        ),
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password Requirements
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            PhosphorIcon(
                              PhosphorIcons.info(),
                              color: AppTheme.primaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Keperluan Kata Laluan:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Sekurang-kurangnya 6 aksara\n'
                          '• Berbeza daripada kata laluan lama',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isChangingPassword
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        oldPasswordController.dispose();
                        newPasswordController.dispose();
                        confirmPasswordController.dispose();
                      },
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isChangingPassword
                    ? null
                    : () async {
                        // Validate inputs
                        if (oldPasswordController.text.trim().isEmpty) {
                          _showSnackBar(
                            'Sila masukkan kata laluan lama',
                            isError: true,
                          );
                          return;
                        }

                        if (newPasswordController.text.trim().isEmpty) {
                          _showSnackBar(
                            'Sila masukkan kata laluan baru',
                            isError: true,
                          );
                          return;
                        }

                        if (newPasswordController.text.length < 6) {
                          _showSnackBar(
                            'Kata laluan baru mestilah sekurang-kurangnya 6 aksara',
                            isError: true,
                          );
                          return;
                        }

                        if (newPasswordController.text !=
                            confirmPasswordController.text) {
                          _showSnackBar(
                            'Kata laluan baru dan pengesahan tidak sepadan',
                            isError: true,
                          );
                          return;
                        }

                        if (oldPasswordController.text ==
                            newPasswordController.text) {
                          _showSnackBar(
                            'Kata laluan baru mestilah berbeza daripada kata laluan lama',
                            isError: true,
                          );
                          return;
                        }

                        setState(() {
                          isChangingPassword = true;
                        });

                        try {
                          // Change password using AuthProvider
                          if (!mounted) return;
                          final authProvider = context.read<AuthProvider>();
                          final success = await authProvider.changePassword(
                            oldPassword: oldPasswordController.text.trim(),
                            newPassword: newPasswordController.text.trim(),
                          );

                          if (!mounted) return;
                          if (success) {
                            Navigator.of(context).pop();
                            _showSnackBar('Kata laluan berjaya ditukar');
                          } else {
                            _showSnackBar(
                              'Ralat menukar kata laluan. Sila semak kata laluan lama anda.',
                              isError: true,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            _showSnackBar(
                              'Ralat: ${e.toString()}',
                              isError: true,
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              isChangingPassword = false;
                            });
                          }
                        }

                        // Dispose controllers
                        oldPasswordController.dispose();
                        newPasswordController.dispose();
                        confirmPasswordController.dispose();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.textLightColor,
                ),
                child: isChangingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Tukar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? AppTheme.errorColor
              : AppTheme.successColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
          ),
          child: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.arrowLeft(),
              color: AppTheme.textPrimaryColor,
              size: 20,
            ),
            onPressed: () => context.go('/home'),
          ),
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
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            );
          }

          return AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildProfileHeader(authProvider, userProfile),
                    const SizedBox(height: 32),

                    _buildSavedItemsSection(),
                    const SizedBox(height: 24),

                    _buildSubscriptionSection(userProfile),
                    const SizedBox(height: 24),

                    _buildSettingsSection(),
                    const SizedBox(height: 100),
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

  Widget _buildProfileHeader(AuthProvider authProvider, userProfile) {
    final theme = Theme.of(context);
    final isPremium = authProvider.hasActiveSubscription;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Column(
              children: [
                Stack(
                  children: [
                    // Main avatar container
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        shape: BoxShape.circle,
                        border: isPremium ? Border.all(
                          color: const Color(0xFFFFD700),
                          width: 3,
                        ) : Border.all(
                          color: AppTheme.borderColor,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
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
                      child: ClipOval(
                        child: userProfile.avatarUrl != null
                            ? Image.network(
                                userProfile.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultAvatar(userProfile.fullName ?? 'User');
                                },
                              )
                            : _buildDefaultAvatar(userProfile.fullName ?? 'User'),
                      ),
                    ),

                    // Premium crown for premium users
                    if (isPremium)
                      Positioned(
                        top: 0,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCrown,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),

                    // Edit button
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setState(() {
                              _isEditingName = !_isEditingName;
                              if (_isEditingName) {
                                _nameController.text = userProfile.fullName ?? '';
                              }
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.backgroundColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: PhosphorIcon(
                              PhosphorIcons.pencilSimple(PhosphorIconsStyle.fill),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_isEditingName) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _nameController,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Masukkan nama',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditingName = false;
                                  });
                                },
                                child: Text(
                                  'Batal',
                                  style: TextStyle(color: AppTheme.textSecondaryColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _handleUpdateName,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Simpan',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    userProfile.fullName ?? 'Pengguna',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      authProvider.user?.email ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build default avatar with initials
  Widget _buildDefaultAvatar(String name) {
    String getInitials(String fullName) {
      final words = fullName.trim().split(' ');
      if (words.isEmpty) return 'U';
      if (words.length == 1) return words[0][0].toUpperCase();
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Text(
          getInitials(name),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSavedItemsSection() {
    return _buildSection(
      title: 'My Library',
      child: _buildEnhancedMenuItem(
        icon: PhosphorIcons.heart(PhosphorIconsStyle.fill),
        iconColor: const Color(0xFFE91E63),
        title: 'Loved Items',
        subtitle: 'Pengajian and E-Books loved',
        onTap: () => context.push('/saved'),
      ),
    );
  }

  Widget _buildSubscriptionSection(userProfile) {
    return _buildSection(
      title: 'Subscription',
      child: _isLoadingSubscription
          ? Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFFFFD700), const Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCrown,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Memuat langganan...',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
              ),
            )
          : _buildEnhancedMenuItem(
              icon: _currentSubscription != null
                  ? PhosphorIcons.crown(PhosphorIconsStyle.fill)
                  : HugeIcons.strokeRoundedCrown,
              iconColor: _currentSubscription != null
                  ? const Color(0xFFFFD700)
                  : AppTheme.primaryColor,
              title: _currentSubscription != null
                  ? 'Premium Access'
                  : 'Basic Access',
              subtitle: _currentSubscription != null
                  ? _getSubscriptionDetails(_currentSubscription!)
                  : 'Upgrade to Premium',
              onTap: () => context.push('/subscription-detail'),
              isPremium: _currentSubscription != null,
            ),
    );
  }

  String _getSubscriptionDetails(Map<String, dynamic> subscription) {
    try {
      final endDateStr = subscription['end_date'] as String?;
      final planName = subscription['subscription_plans']?['name'] as String?;
      final amount = subscription['amount'] as String?;

      if (endDateStr == null || endDateStr.isEmpty) {
        return planName ?? 'Active subscription';
      }

      final endDate = DateTime.parse(endDateStr);
      final daysLeft = endDate.difference(DateTime.now()).inDays;

      if (daysLeft < 0) {
        return 'Subscription expired';
      }

      final planInfo = planName ?? 'Premium';
      final priceInfo = amount != null ? ' - RM$amount' : '';

      if (daysLeft <= 7) {
        return '$planInfo$priceInfo - $daysLeft hari lagi';
      } else {
        return '$planInfo$priceInfo - Aktif hingga ${endDate.day}/${endDate.month}/${endDate.year}';
      }
    } catch (e) {
      debugPrint('Error formatting subscription details: $e');
      return 'Active subscription';
    }
  }

  Widget _buildSettingsSection() {
    return _buildSection(
      title: 'Settings',
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Password Change - only essential setting
            _buildSettingItem(
              icon: PhosphorIcons.lockKey(PhosphorIconsStyle.fill),
              iconColor: const Color(0xFF3B82F6),
              title: 'Tukar Kata Laluan',
              subtitle: 'Kemas kini kata laluan akaun anda',
              onTap: _handleChangePassword,
              isFirst: true,
            ),
            Divider(height: 1, color: AppTheme.borderColor, indent: 20, endIndent: 20),
            // Logout
            _buildSettingItem(
              icon: PhosphorIcons.signOut(PhosphorIconsStyle.fill),
              iconColor: const Color(0xFFEF4444),
              title: 'Logout',
              subtitle: null,
              onTap: _handleSignOut,
              isLast: true,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
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
                  child: icon is IconData
                      ? Icon(icon, color: iconColor, size: 24)
                      : PhosphorIcon(icon, color: iconColor, size: 24),
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
                        color: isDestructive ? iconColor : AppTheme.textPrimaryColor,
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
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        SizedBox(height: 12),
        child,
      ],
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
                    ? Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3), width: 2)
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
                                      iconColor.withValues(alpha: 0.05)
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isPremium
                                  ? Colors.transparent
                                  : iconColor.withValues(alpha: 0.2),
                            ),
                            boxShadow: isPremium ? [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Center(
                            child: icon is IconData
                                ? Icon(
                                    icon,
                                    color: isPremium ? Colors.white : iconColor,
                                    size: 26
                                  )
                                : icon.runtimeType.toString().contains('HugeIcon')
                                    ? HugeIcon(
                                        icon: icon,
                                        color: isPremium ? Colors.white : iconColor,
                                        size: 26
                                      )
                                    : PhosphorIcon(
                                        icon,
                                        color: isPremium ? Colors.white : iconColor,
                                        size: 26
                                      ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                  if (isPremium)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'PREMIUM',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
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
            ),
          ),
        );
      },
    );
  }
}
