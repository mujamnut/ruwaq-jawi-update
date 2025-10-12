import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:ruwaq_jawi/core/theme/app_theme.dart';

class AdminDashboardRecentActivitySection extends StatelessWidget {
  const AdminDashboardRecentActivitySection({
    super.key,
    required this.recentActivities,
  });

  final List<Map<String, dynamic>> recentActivities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aktiviti Terkini',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (recentActivities.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedInbox,
                    size: 48.0,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Tiada kandungan baru',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tiada e-book atau video ditambah dalam 24 jam terakhir',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentActivities.length,
            itemBuilder: (context, index) {
              final activity = recentActivities[index];
              return _AdminDashboardActivityItem(activity: activity);
            },
          ),
      ],
    );
  }
}

class _AdminDashboardActivityItem extends StatelessWidget {
  const _AdminDashboardActivityItem({
    required this.activity,
  });

  final Map<String, dynamic> activity;

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'ebook':
        return HugeIcons.strokeRoundedBook01;
      case 'video':
        return HugeIcons.strokeRoundedPlay;
      default:
        return HugeIcons.strokeRoundedTime04;
    }
  }

  Color _getActivityColor(String? type) {
    switch (type) {
      case 'ebook':
        return const Color(0xFF00BF6D);
      case 'video':
        return const Color(0xFF6366F1);
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getActivityColor(activity['type']).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: _getActivityIcon(activity['type']),
              color: _getActivityColor(activity['type']),
              size: 20.0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'] ?? 'Aktiviti',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity['description'] ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  activity['time'] ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
