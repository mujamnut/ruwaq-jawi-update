import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AdminDashboardQuickActions extends StatelessWidget {
  const AdminDashboardQuickActions({
    super.key,
    required this.onAddCategory,
    required this.onAddKitab,
    required this.onManageUsers,
    required this.onReports,
    required this.onNotifications,
    required this.onManageCategories,
  });

  final VoidCallback onAddCategory;
  final VoidCallback onAddKitab;
  final VoidCallback onManageUsers;
  final VoidCallback onReports;
  final VoidCallback onNotifications;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tindakan Pantas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            _AdminDashboardActionButton(
              title: 'Tambah Kategori',
              icon: HugeIcons.strokeRoundedPlusSignCircle,
              color: const Color(0xFF00BF6D),
              onTap: onAddCategory,
            ),
            _AdminDashboardActionButton(
              title: 'Tambah Kitab',
              icon: HugeIcons.strokeRoundedLibrary,
              color: const Color(0xFF00BF6D),
              onTap: onAddKitab,
            ),
            _AdminDashboardActionButton(
              title: 'Urus Pengguna',
              icon: HugeIcons.strokeRoundedUserSettings01,
              color: const Color(0xFF00BF6D),
              onTap: onManageUsers,
            ),
            _AdminDashboardActionButton(
              title: 'Laporan',
              icon: HugeIcons.strokeRoundedAnalytics01,
              color: const Color(0xFF00BF6D),
              onTap: onReports,
            ),
            _AdminDashboardActionButton(
              title: 'Notifikasi',
              icon: HugeIcons.strokeRoundedNotification03,
              color: const Color(0xFF00BF6D),
              onTap: onNotifications,
            ),
            _AdminDashboardActionButton(
              title: 'Urus Kategori',
              icon: HugeIcons.strokeRoundedFolder02,
              color: const Color(0xFF00BF6D),
              onTap: onManageCategories,
            ),
            ],
        ),
      ],
    );
  }
}

class _AdminDashboardActionButton extends StatelessWidget {
  const _AdminDashboardActionButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(icon: icon, color: color, size: 20.0),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
