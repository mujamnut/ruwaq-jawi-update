import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/models/subscription.dart';
import '../../../../../core/models/user_profile.dart';
import '../../../../../core/theme/app_theme.dart';

class AdminUserCard extends StatelessWidget {
  const AdminUserCard({
    super.key,
    required this.user,
    required this.subscription,
    required this.onView,
    required this.onToggleSubscription,
    this.onPromote,
  });

  final UserProfile user;
  final Subscription? subscription;
  final VoidCallback onView;
  final VoidCallback onToggleSubscription;
  final VoidCallback? onPromote;

  @override
  Widget build(BuildContext context) {
    final hasActiveSubscription = subscription != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: user.isAdmin
                        ? Colors.purple.withValues(alpha: 0.1)
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: HugeIcon(
                      icon: user.isAdmin
                          ? HugeIcons.strokeRoundedUserSettings01
                          : HugeIcons.strokeRoundedUser,
                      color: user.isAdmin ? Colors.purple : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user.email != null && user.email!.isNotEmpty)
                          Text(
                            user.email!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textSecondaryColor),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showUserActionsBottomSheet(
                      context,
                      hasActiveSubscription: hasActiveSubscription,
                    ),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedMoreVertical,
                      color: AppTheme.textSecondaryColor,
                    ),
                    tooltip: 'Tindakan',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: user.isAdmin
                          ? Colors.purple.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: user.isAdmin ? Colors.purple : Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasActiveSubscription
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hasActiveSubscription ? 'AKTIF' : 'TIADA LANGGANAN',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: hasActiveSubscription ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(user.createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondaryColor),
                  ),
                ],
              ),
              if (hasActiveSubscription) ...[
                const SizedBox(height: 8),
                Text(
                  'Langganan: ${subscription!.planDisplayName} '
                  '(${subscription!.daysRemaining} hari lagi)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondaryColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minit lalu';
    } else {
      return 'Baru sahaja';
    }
  }

  void _showUserActionsBottomSheet(
    BuildContext context, {
    required bool hasActiveSubscription,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const HugeIcon(
                  icon: HugeIcons.strokeRoundedView,
                  color: Colors.blue,
                ),
                title: const Text('Lihat Detail'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  onView();
                },
              ),
              if (!user.isAdmin)
                ListTile(
                  leading: HugeIcon(
                    icon: hasActiveSubscription
                        ? HugeIcons.strokeRoundedCancel01
                        : HugeIcons.strokeRoundedCheckmarkCircle02,
                    color: hasActiveSubscription ? Colors.red : Colors.green,
                  ),
                  title: Text(
                    hasActiveSubscription
                        ? 'Batalkan Langganan'
                        : 'Aktifkan Langganan',
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    onToggleSubscription();
                  },
                ),
              if (!user.isAdmin && onPromote != null)
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedUserSettings01,
                    color: Colors.green,
                  ),
                  title: const Text('Jadikan Admin'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    onPromote?.call();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
