import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AdminDashboardStatsGrid extends StatelessWidget {
  const AdminDashboardStatsGrid({super.key, required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        _AdminDashboardStatCard(
          title: 'Jumlah Pengguna',
          value: '${stats['totalUsers'] ?? 0}',
          icon: HugeIcons.strokeRoundedUserMultiple,
          color: Colors.blue,
        ),
        _AdminDashboardStatCard(
          title: 'Jumlah Kitab',
          value: '${stats['totalKitabs'] ?? 0}',
          icon: HugeIcons.strokeRoundedBook02,
          color: Colors.green,
        ),
        _AdminDashboardStatCard(
          title: 'Kategori',
          value: '${stats['totalCategories'] ?? 0}',
          icon: HugeIcons.strokeRoundedGrid,
          color: Colors.orange,
        ),
        _AdminDashboardStatCard(
          title: 'Premium Users',
          value: '${stats['premiumUsers'] ?? 0}',
          icon: HugeIcons.strokeRoundedStar,
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _AdminDashboardStatCard extends StatelessWidget {
  const _AdminDashboardStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: HugeIcon(icon: icon, color: color, size: 24.0),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
