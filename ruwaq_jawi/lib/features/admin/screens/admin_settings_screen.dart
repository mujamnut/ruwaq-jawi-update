import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/auth_provider.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appNameController = TextEditingController();
  final _appVersionController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _privacyPolicyController = TextEditingController();
  final _termsController = TextEditingController();
  final _aboutController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  void _loadSettings() {
    final settings = context.read<SettingsProvider>();
    settings.loadSettings();

    _appNameController.text = settings.appName;
    _appVersionController.text = settings.appVersion;
    _supportEmailController.text = settings.supportEmail;
    _privacyPolicyController.text = settings.privacyPolicy;
    _termsController.text = settings.termsOfService;
    _aboutController.text = settings.aboutApp;
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _appVersionController.dispose();
    _supportEmailController.dispose();
    _privacyPolicyController.dispose();
    _termsController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Tetapan Aplikasi',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedFloppyDisk,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          if (settings.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAppInfoSection(),
                  const SizedBox(height: 24),
                  _buildSubscriptionSettings(settings),
                  const SizedBox(height: 24),
                  _buildContentSettings(settings),
                  const SizedBox(height: 24),
                  _buildNotificationSettings(settings),
                  const SizedBox(height: 24),
                  _buildSecuritySettings(settings),
                  const SizedBox(height: 24),
                  _buildLegalSection(),
                  const SizedBox(height: 24),
                  _buildSystemSettings(settings),
                  const SizedBox(height: 24),
                  _buildBackupSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maklumat Aplikasi',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _appNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Aplikasi',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Sila masukkan nama aplikasi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _appVersionController,
              decoration: const InputDecoration(
                labelText: 'Versi Aplikasi',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Sila masukkan versi aplikasi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _supportEmailController,
              decoration: const InputDecoration(
                labelText: 'Email Sokongan',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Sila masukkan email sokongan';
                }
                if (!value.contains('@')) {
                  return 'Sila masukkan email yang sah';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSettings(SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tetapan Langganan',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Aktifkan Langganan Premium'),
              subtitle: const Text('Membolehkan pengguna berlangganan premium'),
              value: settings.enablePremiumSubscription,
              onChanged: (value) {
                settings.updatePremiumSubscription(value);
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Harga Langganan Bulanan'),
              subtitle: Text('RM ${settings.monthlyPrice.toStringAsFixed(2)}'),
              trailing: const HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                color: Colors.grey,
              ),
              onTap: () => _showPriceDialog('monthly', settings.monthlyPrice),
            ),
            ListTile(
              title: const Text('Harga Langganan Tahunan'),
              subtitle: Text('RM ${settings.yearlyPrice.toStringAsFixed(2)}'),
              trailing: const HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                color: Colors.grey,
              ),
              onTap: () => _showPriceDialog('yearly', settings.yearlyPrice),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Percubaan Percuma'),
              subtitle: const Text(
                '7 hari percubaan percuma untuk pengguna baru',
              ),
              value: settings.enableFreeTrial,
              onChanged: (value) {
                settings.updateFreeTrial(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSettings(SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tetapan Kandungan',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto-approve Kandungan'),
              subtitle: const Text(
                'Kandungan baru akan diluluskan secara automatik',
              ),
              value: settings.autoApproveContent,
              onChanged: (value) {
                settings.updateAutoApproveContent(value);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Aktifkan Muat Turun'),
              subtitle: const Text(
                'Membolehkan pengguna memuat turun kandungan',
              ),
              value: settings.enableDownloads,
              onChanged: (value) {
                settings.updateDownloads(value);
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Saiz Maksimum Fail'),
              subtitle: Text('${settings.maxFileSize} MB'),
              trailing: const HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                color: Colors.grey,
              ),
              onTap: () => _showFileSizeDialog(settings.maxFileSize),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Watermark pada PDF'),
              subtitle: const Text('Tambah watermark pada fail PDF'),
              value: settings.enableWatermark,
              onChanged: (value) {
                settings.updateWatermark(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings(SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tetapan Notifikasi',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Hantar notifikasi kepada pengguna'),
              value: settings.enablePushNotifications,
              onChanged: (value) {
                settings.updatePushNotifications(value);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Hantar notifikasi melalui email'),
              value: settings.enableEmailNotifications,
              onChanged: (value) {
                settings.updateEmailNotifications(value);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Notifikasi Kandungan Baru'),
              subtitle: const Text('Maklumkan pengguna tentang kandungan baru'),
              value: settings.notifyNewContent,
              onChanged: (value) {
                settings.updateNewContentNotification(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySettings(SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tetapan Keselamatan',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Two-Factor Authentication'),
              subtitle: const Text('Memerlukan 2FA untuk admin'),
              value: settings.requireTwoFactor,
              onChanged: (value) {
                settings.updateTwoFactor(value);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Session Timeout'),
              subtitle: const Text('Auto logout selepas tidak aktif'),
              value: settings.enableSessionTimeout,
              onChanged: (value) {
                settings.updateSessionTimeout(value);
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Masa Session (minit)'),
              subtitle: Text('${settings.sessionTimeoutMinutes} minit'),
              trailing: const HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                color: Colors.grey,
              ),
              onTap: () => _showTimeoutDialog(settings.sessionTimeoutMinutes),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Audit Logging'),
              subtitle: const Text('Rekod semua aktiviti admin'),
              value: settings.enableAuditLogging,
              onChanged: (value) {
                settings.updateAuditLogging(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dokumen Undang-undang',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _privacyPolicyController,
              decoration: const InputDecoration(
                labelText: 'Dasar Privasi',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _termsController,
              decoration: const InputDecoration(
                labelText: 'Terma & Syarat',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _aboutController,
              decoration: const InputDecoration(
                labelText: 'Tentang Aplikasi',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSettings(SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tetapan Sistem',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Mode Penyelenggaraan'),
              subtitle: const Text('Tutup aplikasi untuk penyelenggaraan'),
              value: settings.maintenanceMode,
              onChanged: (value) {
                settings.updateMaintenanceMode(value);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Debug Mode'),
              subtitle: const Text('Aktifkan mod debug untuk troubleshooting'),
              value: settings.debugMode,
              onChanged: (value) {
                settings.updateDebugMode(value);
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Bersihkan Cache'),
              subtitle: const Text('Kosongkan cache aplikasi'),
              trailing: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete01,
                color: Colors.grey,
              ),
              onTap: () => _showClearCacheDialog(),
            ),
            const Divider(),
            ListTile(
              title: const Text('Reset Tetapan'),
              subtitle: const Text('Kembalikan semua tetapan kepada default'),
              trailing: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                color: Colors.grey,
              ),
              onTap: () => _showResetDialog(),
            ),
            const Divider(),
            ListTile(
              title: const Text('Log Keluar'),
              subtitle: const Text('Keluar dari akaun admin'),
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedLogout01,
                color: Colors.red,
              ),
              trailing: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight02,
                color: Colors.grey,
              ),
              onTap: () => _showLogoutDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sandaran & Pemulihan',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Buat Sandaran'),
              subtitle: const Text('Sandaran data dan tetapan'),
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedCloudUpload,
                color: Colors.blue,
              ),
              trailing: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight02,
                color: Colors.grey,
              ),
              onTap: () => _createBackup(),
            ),
            const Divider(),
            ListTile(
              title: const Text('Pulihkan dari Sandaran'),
              subtitle: const Text('Pulihkan data dari fail sandaran'),
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                color: Colors.orange,
              ),
              trailing: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight02,
                color: Colors.grey,
              ),
              onTap: () => _restoreBackup(),
            ),
            const Divider(),
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return SwitchListTile(
                  title: const Text('Auto Backup'),
                  subtitle: const Text('Sandaran automatik setiap hari'),
                  value: settings.autoBackup,
                  onChanged: (value) {
                    settings.updateAutoBackup(value);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceDialog(String type, double currentPrice) {
    final controller = TextEditingController(text: currentPrice.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Tetapkan Harga ${type == 'monthly' ? 'Bulanan' : 'Tahunan'}',
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Harga (RM)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text) ?? 0;
              if (type == 'monthly') {
                context.read<SettingsProvider>().updateMonthlyPrice(price);
              } else {
                context.read<SettingsProvider>().updateYearlyPrice(price);
              }
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showFileSizeDialog(int currentSize) {
    final controller = TextEditingController(text: currentSize.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tetapkan Saiz Maksimum Fail'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Saiz (MB)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final size = int.tryParse(controller.text) ?? 10;
              context.read<SettingsProvider>().updateMaxFileSize(size);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showTimeoutDialog(int currentTimeout) {
    final controller = TextEditingController(text: currentTimeout.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tetapkan Masa Session'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Masa (minit)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final timeout = int.tryParse(controller.text) ?? 30;
              context.read<SettingsProvider>().updateSessionTimeoutMinutes(
                timeout,
              );
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bersihkan Cache'),
        content: const Text(
          'Adakah anda pasti mahu membersihkan cache? Tindakan ini tidak boleh dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SettingsProvider>().clearCache();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache telah dibersihkan')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Bersihkan'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Tetapan'),
        content: const Text(
          'Adakah anda pasti mahu mereset semua tetapan kepada default? Tindakan ini tidak boleh dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SettingsProvider>().resetSettings();
              Navigator.pop(context);
              _loadSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tetapan telah direset')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _createBackup() {
    context.read<SettingsProvider>().createBackup();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sandaran sedang dibuat...')));
  }

  void _restoreBackup() {
    // This would typically open a file picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pilih fail sandaran untuk dipulihkan')),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Keluar'),
        content: const Text(
          'Adakah anda pasti mahu log keluar dari akaun admin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close confirmation dialog first
              Navigator.pop(dialogContext);

              // Store context reference before async operations
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final authProvider = context.read<AuthProvider>();

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => const AlertDialog(
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Sedang log keluar...'),
                    ],
                  ),
                ),
              );

              try {
                // Perform logout
                await authProvider.signOut();

                // Close loading dialog and navigate
                if (mounted) {
                  navigator.pop(); // Close loading dialog
                  context.go('/login');
                }
              } catch (e) {
                // Close loading dialog and show error
                if (mounted) {
                  navigator.pop(); // Close loading dialog
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Ralat log keluar: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Keluar'),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    if (_formKey.currentState?.validate() ?? false) {
      final settings = context.read<SettingsProvider>();

      settings.updateAppInfo(
        _appNameController.text,
        _appVersionController.text,
        _supportEmailController.text,
      );

      settings.updateLegalDocuments(
        _privacyPolicyController.text,
        _termsController.text,
        _aboutController.text,
      );

      settings.saveSettings();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tetapan telah disimpan')));
    }
  }
}
