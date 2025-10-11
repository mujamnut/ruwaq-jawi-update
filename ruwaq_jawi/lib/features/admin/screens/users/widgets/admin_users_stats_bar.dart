import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

class AdminUsersStatsBar extends StatelessWidget {
  const AdminUsersStatsBar({
    super.key,
    required this.totalUsers,
    required this.activeSubscriptions,
  });

  final int totalUsers;
  final int activeSubscriptions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          Text(
            '$totalUsers pengguna',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 16, color: AppTheme.borderColor),
          const SizedBox(width: 16),
          Text(
            '$activeSubscriptions aktif',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
