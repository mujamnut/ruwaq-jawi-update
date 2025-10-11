import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_theme.dart';

class AdminUsersEmptyState extends StatelessWidget {
  const AdminUsersEmptyState({
    super.key,
    required this.hasSearchQuery,
  });

  final bool hasSearchQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedUserMultiple,
            size: 64.0,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearchQuery ? 'Tiada pengguna ditemui' : 'Belum ada pengguna',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearchQuery
                ? 'Cuba cari dengan nama lain'
                : 'Pengguna akan muncul di sini setelah mendaftar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
        ],
      ),
    );
  }
}
