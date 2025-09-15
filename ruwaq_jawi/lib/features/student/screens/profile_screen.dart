import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditingName = false;
  final _nameController = TextEditingController();
  Map<String, dynamic>? _currentSubscription;
  bool _isLoadingSubscription = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      _nameController.text = authProvider.userProfile?.fullName ?? '';
    });
    _loadCurrentSubscription();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      print('Error loading subscription: $e');
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
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
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
                          final authProvider = context.read<AuthProvider>();
                          final success = await authProvider.changePassword(
                            oldPassword: oldPasswordController.text.trim(),
                            newPassword: newPasswordController.text.trim(),
                          );

                          if (success && mounted) {
                            Navigator.of(context).pop();
                            _showSnackBar('Kata laluan berjaya ditukar');
                          } else if (mounted) {
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
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.caretLeft(),
              color: AppTheme.primaryColor,
              size: 20,
            ),
            onPressed: () => context.go('/home'),
          ),
        ),
        title: Text(
          'Profile',
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            fontSize: 18,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final userProfile = authProvider.userProfile;

          if (userProfile == null) {
            return Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                _buildProfileHeader(authProvider, userProfile),
                SizedBox(height: 30),

                _buildSavedItemsSection(),
                SizedBox(height: 20),

                _buildSubscriptionSection(userProfile),
                SizedBox(height: 20),

                _buildSettingsSection(),
                SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(AuthProvider authProvider, userProfile) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(60),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return PhosphorIcon(
                      PhosphorIcons.user(),
                      size: 60,
                      color: AppTheme.textSecondaryColor,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isEditingName = !_isEditingName;
                    if (_isEditingName) {
                      _nameController.text = userProfile.fullName ?? '';
                    }
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: PhosphorIcon(
                    PhosphorIcons.pencil(),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        if (_isEditingName) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Masukkan nama',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditingName = false;
                        });
                      },
                      child: Text('Batal'),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _handleUpdateName,
                      child: Text('Simpan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            userProfile.fullName ?? 'Pengguna',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ],
        SizedBox(height: 4),

        Text(
          authProvider.user?.email ?? '',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSavedItemsSection() {
    return _buildSection(
      title: 'My Library',
      child: _buildMenuItem(
        icon: PhosphorIcons.heart(),
        iconColor: AppTheme.primaryColor,
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: PhosphorIcon(
                    PhosphorIcons.crown(),
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Memuat langganan...',
                  style: TextStyle(color: AppTheme.textPrimaryColor),
                ),
                trailing: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : _buildMenuItem(
              icon: PhosphorIcons.crown(),
              iconColor: AppTheme.primaryColor,
              title: _currentSubscription != null
                  ? 'Premium Access'
                  : 'Basic Access',
              subtitle: _currentSubscription != null
                  ? _getSubscriptionDetails(_currentSubscription!)
                  : 'Upgrade to Premium',
              onTap: () => context.push('/subscription-detail'),
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
      print('Error formatting subscription details: $e');
      return 'Active subscription';
    }
  }

  Widget _buildSettingsSection() {
    return _buildSection(
      title: 'Settings',
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PhosphorIcon(
                  PhosphorIcons.globe(),
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              title: Text(
                'Language',
                style: TextStyle(color: AppTheme.textPrimaryColor),
              ),
              trailing: PhosphorIcon(
                PhosphorIcons.caretRight(),
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Pilih Bahasa'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text('Bahasa Melayu'),
                          onTap: () => Navigator.pop(context),
                        ),
                        ListTile(
                          title: Text('English'),
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PhosphorIcon(
                  PhosphorIcons.lockKey(),
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              title: Text(
                'Tukar Kata Laluan',
                style: TextStyle(color: AppTheme.textPrimaryColor),
              ),
              subtitle: Text(
                'Kemas kini kata laluan akaun anda',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
              trailing: PhosphorIcon(
                PhosphorIcons.caretRight(),
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              onTap: _handleChangePassword,
            ),
            Divider(height: 1, color: AppTheme.borderColor),
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: PhosphorIcon(
                  PhosphorIcons.signOut(),
                  color: AppTheme.errorColor,
                  size: 20,
                ),
              ),
              title: Text(
                'Logout',
                style: TextStyle(color: AppTheme.textPrimaryColor),
              ),
              trailing: PhosphorIcon(
                PhosphorIcons.caretRight(),
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              onTap: _handleSignOut,
            ),
          ],
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

  Widget _buildMenuItem({
    required dynamic icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: PhosphorIcon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              )
            : null,
        trailing: PhosphorIcon(
          PhosphorIcons.caretRight(),
          color: theme.textTheme.bodySmall?.color,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}
