import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimaryColor,
        title: const Text('Profil'),
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft02,
            color: AppTheme.textPrimaryColor,
          ),
          onPressed: () => context.go('/admin/dashboard'),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Profil',
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedEdit01,
              color: AppTheme.primaryColor,
            ),
            onPressed: () => _showEditProfileDialog(context),
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final UserProfile? profile = authProvider.userProfile;
          final supabaseUser = authProvider.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileHeaderSection(profile, supabaseUser),
                const SizedBox(height: 16),
                _buildAccountInfoCard(profile, supabaseUser),
                const SizedBox(height: 16),
                _buildQuickLinksCard(),
                const SizedBox(height: 16),
                _buildSystemInfoCard(),
                const SizedBox(height: 16),
                _buildDangerZoneCard(authProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeaderSection(UserProfile? profile, dynamic supabaseUser) {
    final displayName =
        (profile?.fullName?.trim().isNotEmpty ?? false) ? profile!.fullName! : 'Admin';
    final displayEmail = profile?.email ?? supabaseUser?.email ?? '-';
    final avatarUrl = profile?.avatarUrl;
    final initials = _extractInitials(displayName.isNotEmpty ? displayName : displayEmail);

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    avatarUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      color: AppTheme.primaryColor,
                      size: 40.0,
                    ),
                  ),
                )
              : Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          displayEmail,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'ADMIN',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Card _buildAccountInfoCard(UserProfile? profile, dynamic supabaseUser) {
    final lastUpdated = profile?.updatedAt;
    final entries = <_InfoEntry>[
      _InfoEntry('Nama Penuh', profile?.fullName ?? '-'),
      _InfoEntry('Email', profile?.email ?? supabaseUser?.email ?? '-'),
      _InfoEntry('Nombor Telefon', profile?.phoneNumber ?? '-'),
      _InfoEntry('Tarikh Daftar', _formatDate(supabaseUser?.createdAt?.toString())),
      _InfoEntry('Terakhir Login', _formatDate(lastUpdated?.toIso8601String())),
    ];

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maklumat Akaun',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            ...entries.map((entry) => _buildInfoRow(entry.label, entry.value)),
          ],
        ),
      ),
    );
  }

  Card _buildQuickLinksCard() {
    final links = <_QuickLinkItem>[
      _QuickLinkItem(
        icon: HugeIcons.strokeRoundedUserMultiple,
        title: 'Pengurusan Pengguna',
        subtitle: 'Lihat dan urus semua pengguna sistem',
        route: '/admin/users',
      ),
      _QuickLinkItem(
        icon: HugeIcons.strokeRoundedLibrary,
        title: 'Pengurusan Kandungan',
        subtitle: 'Tambah dan kemas kini kitab serta video',
        route: '/admin/content',
      ),
      _QuickLinkItem(
        icon: HugeIcons.strokeRoundedAnalytics01,
        title: 'Analitik & Laporan',
        subtitle: 'Pantau prestasi sistem secara keseluruhan',
        route: '/admin/analytics-real',
      ),
      _QuickLinkItem(
        icon: HugeIcons.strokeRoundedCreditCard,
        title: 'Langganan & Pembayaran',
        subtitle: 'Jejak status langganan dan transaksi',
        route: '/admin/subscriptions',
      ),
    ];

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Pintasan Admin',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(links.length, (index) {
              final link = links[index];
              final isLast = index == links.length - 1;
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: HugeIcon(
                        icon: link.icon,
                        color: AppTheme.primaryColor,
                        size: 20.0,
                      ),
                    ),
                    title: Text(
                      link.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      link.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                    ),
                    trailing: const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight02,
                      color: Colors.grey,
                      size: 18.0,
                    ),
                    onTap: () => _navigateTo(link.route),
                  ),
                  if (!isLast)
                    Divider(
                      height: 8,
                      thickness: 0.6,
                      color: AppTheme.borderColor.withValues(alpha: 0.4),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Card _buildSystemInfoCard() {
    final systemItems = <_InfoEntry>[
      const _InfoEntry('Versi Aplikasi', '1.0.0'),
      const _InfoEntry('Platform', 'Flutter'),
      const _InfoEntry('Backend', 'Supabase'),
    ];

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maklumat Sistem',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            ...systemItems.map((item) => _buildInfoRow(item.label, item.value)),
          ],
        ),
      ),
    );
  }

  Card _buildDangerZoneCard(AuthProvider authProvider) {
    return Card(
      elevation: 0,
      color: Colors.red.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kawasan Sensitif',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log keluar dari akaun admin anda untuk menamatkan sesi semasa.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade700,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _handleLogout(authProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const HugeIcon(
                        icon: HugeIcons.strokeRoundedLogout01,
                        color: Colors.white,
                        size: 18.0,
                      ),
                label: Text(_isLoading ? 'Sedang Log Keluar...' : 'Log Keluar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return '-';
    }
  }

  String _extractInitials(String source) {
    final parts = source.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first.characters.first.toUpperCase() : 'A';
    }
    return (parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '');
  }

  void _navigateTo(String route) {
    Future.microtask(() {
      if (!mounted) return;
      context.go(route);
    });
  }

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final nameController = TextEditingController(
      text: authProvider.userProfile?.fullName ?? '',
    );
    final phoneController = TextEditingController(
      text: authProvider.userProfile?.phoneNumber ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Penuh',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Nombor Telefon',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profil akan dikemaskini'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(AuthProvider authProvider) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengesahan'),
        content: const Text('Adakah anda pasti mahu log keluar dari sistem admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Log Keluar'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await authProvider.signOut();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat log keluar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _QuickLinkItem {
  const _QuickLinkItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

class _InfoEntry {
  const _InfoEntry(this.label, this.value);

  final String label;
  final String value;
}
