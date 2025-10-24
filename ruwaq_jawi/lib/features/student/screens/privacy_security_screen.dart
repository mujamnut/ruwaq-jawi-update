import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import 'profile_screen/services/password_change_service.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _notificationsEnabled = true;
  bool _locationEnabled = false;
  bool _analyticsEnabled = true;
  bool _marketingEnabled = false;
  bool _twoFactorEnabled = false;
  bool _biometricEnabled = false;
  bool _autoBackupEnabled = true;

  @override
  void initState() {
    super.initState();

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
        _loadPrivacySettings();

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

  Future<void> _loadPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _locationEnabled = prefs.getBool('location_enabled') ?? false;
        _analyticsEnabled = prefs.getBool('analytics_enabled') ?? true;
        _marketingEnabled = prefs.getBool('marketing_enabled') ?? false;
        _twoFactorEnabled = prefs.getBool('two_factor_enabled') ?? false;
        _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
        _autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? true;
      });
    } catch (e) {
      // Error loading privacy settings - silently handle
    }
  }

  Future<void> _savePrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('location_enabled', _locationEnabled);
      await prefs.setBool('analytics_enabled', _analyticsEnabled);
      await prefs.setBool('marketing_enabled', _marketingEnabled);
      await prefs.setBool('two_factor_enabled', _twoFactorEnabled);
      await prefs.setBool('biometric_enabled', _biometricEnabled);
      await prefs.setBool('auto_backup_enabled', _autoBackupEnabled);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedSecurityCheck,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Privacy settings saved successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAlertCircle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('Error saving settings: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Privacy & Security',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Privacy Settings Section
                    _buildSection(
                      title: 'Privacy Settings',
                      icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                      iconColor: const Color(0xFF4CAF50),
                      children: [
                        _buildSwitchTile(
                          title: 'Push Notifications',
                          subtitle: 'Receive notifications about your account and activity',
                          icon: PhosphorIcons.bell(PhosphorIconsStyle.fill),
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _notificationsEnabled = value;
                            });
                            _savePrivacySettings();
                          },
                        ),
                        _buildSwitchTile(
                          title: 'Location Services',
                          subtitle: 'Allow app to access your location for better services',
                          icon: PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                          value: _locationEnabled,
                          onChanged: (value) {
                            setState(() {
                              _locationEnabled = value;
                            });
                            _savePrivacySettings();
                          },
                        ),
                        _buildSwitchTile(
                          title: 'Usage Analytics',
                          subtitle: 'Help improve the app with anonymous usage data',
                          icon: PhosphorIcons.chartBar(PhosphorIconsStyle.fill),
                          value: _analyticsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _analyticsEnabled = value;
                            });
                            _savePrivacySettings();
                          },
                        ),
                        _buildSwitchTile(
                          title: 'Marketing Communications',
                          subtitle: 'Receive promotional offers and app updates',
                          icon: PhosphorIcons.envelope(PhosphorIconsStyle.fill),
                          value: _marketingEnabled,
                          onChanged: (value) {
                            setState(() {
                              _marketingEnabled = value;
                            });
                            _savePrivacySettings();
                          },
                        ),
                        _buildSwitchTile(
                          title: 'Auto Backup',
                          subtitle: 'Automatically backup your reading progress and bookmarks',
                          icon: PhosphorIcons.cloud(PhosphorIconsStyle.fill),
                          value: _autoBackupEnabled,
                          onChanged: (value) {
                            setState(() {
                              _autoBackupEnabled = value;
                            });
                            _savePrivacySettings();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Security Settings Section
                    _buildSection(
                      title: 'Security Settings',
                      icon: PhosphorIcons.lock(PhosphorIconsStyle.fill),
                      iconColor: AppTheme.primaryColor,
                      children: [
                        _buildActionTile(
                          title: 'Change Password',
                          subtitle: 'Update your account password',
                          icon: PhosphorIcons.key(PhosphorIconsStyle.fill),
                          onTap: _handleChangePassword,
                        ),
                        _buildSwitchTile(
                          title: 'Two-Factor Authentication',
                          subtitle: 'Add an extra layer of security to your account',
                          icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                          value: _twoFactorEnabled,
                          onChanged: (value) {
                            _handleTwoFactorAuth(value);
                          },
                        ),
                        _buildSwitchTile(
                          title: 'Biometric Authentication',
                          subtitle: 'Use fingerprint or face recognition to sign in',
                          icon: PhosphorIcons.fingerprint(PhosphorIconsStyle.fill),
                          value: _biometricEnabled,
                          onChanged: (value) {
                            _handleBiometricAuth(value);
                          },
                        ),
                        _buildActionTile(
                          title: 'Login Activity',
                          subtitle: 'View recent login history and active sessions',
                          icon: PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.fill),
                          onTap: _handleLoginActivity,
                        ),
                        _buildActionTile(
                          title: 'Connected Devices',
                          subtitle: 'Manage devices that have access to your account',
                          icon: PhosphorIcons.devices(PhosphorIconsStyle.fill),
                          onTap: _handleConnectedDevices,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Data Management Section
                    _buildSection(
                      title: 'Data Management',
                      icon: PhosphorIcons.database(PhosphorIconsStyle.fill),
                      iconColor: const Color(0xFF2196F3),
                      children: [
                        _buildActionTile(
                          title: 'Download Your Data',
                          subtitle: 'Get a copy of your personal data',
                          icon: PhosphorIcons.downloadSimple(PhosphorIconsStyle.fill),
                          onTap: _handleDownloadData,
                        ),
                        _buildActionTile(
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account and data',
                          icon: PhosphorIcons.userMinus(PhosphorIconsStyle.fill),
                          iconColor: const Color(0xFFF44336),
                          onTap: _handleDeleteAccount,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Legal Section
                    _buildSection(
                      title: 'Legal',
                      icon: PhosphorIcons.scales(PhosphorIconsStyle.fill),
                      iconColor: const Color(0xFFFF9800),
                      children: [
                        _buildActionTile(
                          title: 'Privacy Policy',
                          subtitle: 'Learn how we protect your data',
                          icon: PhosphorIcons.fileText(PhosphorIconsStyle.fill),
                          onTap: _handlePrivacyPolicy,
                        ),
                        _buildActionTile(
                          title: 'Terms of Service',
                          subtitle: 'Read our terms and conditions',
                          icon: PhosphorIcons.fileText(PhosphorIconsStyle.fill),
                          onTap: _handleTermsOfService,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      icon,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: AppTheme.primaryColor,
                  inactiveThumbColor: AppTheme.borderColor,
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Color iconColor = AppTheme.primaryColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
                const SizedBox(width: 8),
                PhosphorIcon(
                  PhosphorIcons.caretRight(),
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleChangePassword() {
    PasswordChangeService.showPasswordChangeDialog(context);
  }

  Future<void> _handleTwoFactorAuth(bool enable) async {
    if (enable) {
      final result = await _showTwoFactorSetupDialog();
      if (result == true) {
        setState(() {
          _twoFactorEnabled = true;
        });
        _savePrivacySettings();
        _showSuccessDialog('2FA Enabled', 'Two-factor authentication has been enabled for your account.');
      }
    } else {
      final confirmed = await _showConfirmationDialog(
        'Disable 2FA',
        'Are you sure you want to disable two-factor authentication? This will make your account less secure.',
      );
      if (confirmed == true) {
        setState(() {
          _twoFactorEnabled = false;
        });
        _savePrivacySettings();
        _showSuccessDialog('2FA Disabled', 'Two-factor authentication has been disabled.');
      }
    }
  }

  Future<void> _handleBiometricAuth(bool enable) async {
    if (enable) {
      final result = await _showBiometricSetupDialog();
      if (result == true) {
        setState(() {
          _biometricEnabled = true;
        });
        _savePrivacySettings();
        _showSuccessDialog('Biometric Enabled', 'Biometric authentication has been enabled.');
      }
    } else {
      setState(() {
        _biometricEnabled = false;
      });
      _savePrivacySettings();
      _showSuccessDialog('Biometric Disabled', 'Biometric authentication has been disabled.');
    }
  }

  void _handleLoginActivity() {
    _showLoginActivityDialog();
  }

  void _handleConnectedDevices() {
    _showConnectedDevicesDialog();
  }

  void _handleDownloadData() {
    _showDataDownloadDialog();
  }

  void _handleDeleteAccount() {
    _showDeleteAccountDialog();
  }

  void _handlePrivacyPolicy() async {
    final Uri privacyPolicyUrl = Uri.parse('https://ruwaqjawi.com/privacy-policy');
    if (await canLaunchUrl(privacyPolicyUrl)) {
      await launchUrl(privacyPolicyUrl, mode: LaunchMode.externalApplication);
    } else {
      _showPrivacyPolicyDialog();
    }
  }

  void _handleTermsOfService() async {
    final Uri termsUrl = Uri.parse('https://ruwaqjawi.com/terms-of-service');
    if (await canLaunchUrl(termsUrl)) {
      await launchUrl(termsUrl, mode: LaunchMode.externalApplication);
    } else {
      _showTermsOfServiceDialog();
    }
  }

  // Dialog Methods
  Future<bool?> _showTwoFactorSetupDialog() async {
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedMethod = 'email';

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Setup Two-Factor Authentication',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose how you want to receive verification codes',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  title: const Text('Email'),
                  subtitle: Text(emailController.text.isEmpty ? 'Enter email address' : emailController.text),
                  leading: Radio<String>(
                    value: 'email',
                    groupValue: selectedMethod,
                    onChanged: (value) {
                      setState(() => selectedMethod = value!);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('SMS'),
                  subtitle: Text(phoneController.text.isEmpty ? 'Enter phone number' : phoneController.text),
                  leading: Radio<String>(
                    value: 'sms',
                    groupValue: selectedMethod,
                    onChanged: (value) {
                      setState(() => selectedMethod = value!);
                    },
                  ),
                ),
                if (selectedMethod == 'email') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
                if (selectedMethod == 'sms') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if ((selectedMethod == 'email' && emailController.text.isNotEmpty) ||
                              (selectedMethod == 'sms' && phoneController.text.isNotEmpty)) {
                            Navigator.of(context).pop(true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Enable'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showBiometricSetupDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedFingerPrint,
                color: AppTheme.primaryColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Enable Biometric Authentication',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Use your fingerprint or face recognition to sign in quickly and securely.',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Enable'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginActivityDialog() {
    final loginActivities = [
      {'device': 'iPhone 13 Pro', 'location': 'Kuala Lumpur, Malaysia', 'time': '2 hours ago', 'status': 'active'},
      {'device': 'Windows PC', 'location': 'Kuala Lumpur, Malaysia', 'time': '1 day ago', 'status': 'active'},
      {'device': 'iPad Air', 'location': 'Shah Alam, Malaysia', 'time': '3 days ago', 'status': 'logged_out'},
      {'device': 'Samsung Galaxy S21', 'location': 'Johor Bahru, Malaysia', 'time': '1 week ago', 'status': 'logged_out'},
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Login Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Recent login attempts and active sessions',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: loginActivities.length,
                  itemBuilder: (context, index) {
                    final activity = loginActivities[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  activity['device']!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: activity['status'] == 'active'
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  activity['status'] == 'active' ? 'Active' : 'Logged out',
                                  style: TextStyle(
                                    color: activity['status'] == 'active' ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedMapPin,
                                color: AppTheme.textSecondaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                activity['location']!,
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedClock01,
                                color: AppTheme.textSecondaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                activity['time']!,
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConnectedDevicesDialog() {
    final devices = [
      {'name': 'iPhone 13 Pro', 'type': 'Mobile', 'lastActive': 'Currently active', 'thisDevice': true},
      {'name': 'Windows PC', 'type': 'Desktop', 'lastActive': '2 hours ago', 'thisDevice': false},
      {'name': 'iPad Air', 'type': 'Tablet', 'lastActive': '3 days ago', 'thisDevice': false},
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Connected Devices',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Devices that have access to your account',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: HugeIcon(
                                icon: device['type'].toString() == 'Mobile'
                                  ? HugeIcons.strokeRoundedSmartPhone01
                                  : device['type'].toString() == 'Tablet'
                                    ? HugeIcons.strokeRoundedTablet01
                                    : HugeIcons.strokeRoundedComputer,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      device['name'].toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (device['thisDevice'] == true) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'This Device',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  device['lastActive'].toString(),
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (device['thisDevice'] != true)
                            TextButton(
                              onPressed: () {
                                _showRemoveDeviceDialog(device['name'].toString());
                              },
                              child: const Text('Remove'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRemoveDeviceDialog(String deviceName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $deviceName'),
        content: Text('Are you sure you want to remove $deviceName from your account? You will need to sign in again on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Close devices dialog too
              _showSuccessDialog('Device Removed', '$deviceName has been removed from your account.');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showDataDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedDownload01,
                color: AppTheme.primaryColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Download Your Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Request a copy of your personal data, including:\n\n• Profile information\n• Reading progress\n• Bookmarks and notes\n• Purchase history\n• Support requests',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showSuccessDialog('Data Requested', 'Your data download request has been submitted. You will receive an email with your data within 24 hours.');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Request'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    final confirmationController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedUserRemove01,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '⚠️ This action cannot be undone\n\nDeleting your account will:\n• Permanently remove your profile\n• Delete all reading progress and bookmarks\n• Cancel active subscriptions\n• Remove all purchase history',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Enter your password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmationController,
                  decoration: InputDecoration(
                    labelText: 'Type "DELETE" to confirm',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          if (confirmationController.text != 'DELETE') {
                            _showErrorDialog('Confirmation Required', 'Please type "DELETE" to confirm account deletion.');
                            return;
                          }

                          setState(() => isLoading = true);

                          // Simulate API call
                          await Future.delayed(const Duration(seconds: 3));

                          if (mounted) {
                            Navigator.of(context).pop();
                            _showSuccessDialog('Account Deleted', 'Your account has been permanently deleted. We\'re sorry to see you go.');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Delete Account'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'Last updated: January 2024\n\n'
                    '1. Information We Collect\n'
                    '• Account information (name, email, password)\n'
                    '• Usage data (reading progress, bookmarks)\n'
                    '• Device information and IP address\n\n'
                    '2. How We Use Your Information\n'
                    '• Provide and maintain our service\n'
                    '• Send account-related notifications\n'
                    '• Improve our app and user experience\n'
                    '• Respond to your questions and support requests\n\n'
                    '3. Data Security\n'
                    'We implement appropriate security measures to protect your personal information.\n\n'
                    '4. Your Rights\n'
                    '• Access your personal data\n'
                    '• Request deletion of your data\n'
                    '• Opt-out of marketing communications\n'
                    '• Download your data\n\n'
                    '5. Contact Us\n'
                    'For privacy questions, contact: privacy@ruwaqjawi.com',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsOfServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Terms of Service',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'Last updated: January 2024\n\n'
                    '1. Acceptance of Terms\n'
                    'By using Maktabah Ruwaq Jawi, you agree to these terms.\n\n'
                    '2. Service Description\n'
                    'Maktabah Ruwaq Jawi provides access to Islamic books, videos, and educational content.\n\n'
                    '3. User Accounts\n'
                    '• You must be at least 13 years old\n'
                    '• You are responsible for maintaining account security\n'
                    '• You must provide accurate information\n\n'
                    '4. Subscription and Payment\n'
                    '• Premium features require subscription\n'
                    '• Payments are processed through secure third-party providers\n'
                    '• Subscriptions auto-renew unless cancelled\n\n'
                    '5. Content and Intellectual Property\n'
                    'All content is protected by copyright and other intellectual property laws.\n\n'
                    '6. User Conduct\n'
                    '• Use the service for lawful purposes only\n'
                    '• Do not reproduce or distribute content without permission\n'
                    '• Respect other users and intellectual property rights\n\n'
                    '7. Disclaimer of Warranties\n'
                    'The service is provided "as is" without warranties of any kind.\n\n'
                    '8. Limitation of Liability\n'
                    'We are not liable for any indirect, incidental, or consequential damages.\n\n'
                    '9. Contact Information\n'
                    'For questions about these terms, contact: support@ruwaqjawi.com',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(String title, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedSecurityCheck,
          color: Colors.green,
          size: 48,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedAlertCircle,
          color: Colors.red,
          size: 48,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
