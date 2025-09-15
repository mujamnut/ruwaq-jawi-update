import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/providers/notifications_provider.dart';
import '../../../core/theme/app_theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // Load inbox on open
    Future.microtask(() => context.read<NotificationsProvider>().loadInbox());
  }

  Future<void> _refresh() async {
    await context.read<NotificationsProvider>().loadInbox();
  }

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('ms', timeago.MsMessages());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.bell(),
              color: AppTheme.textLightColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Notifikasi'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        elevation: 0,
        actions: [
          Consumer<NotificationsProvider>(
            builder: (context, notifier, _) {
              final hasNotifications = notifier.inbox.isNotEmpty;
              if (hasNotifications) {
                return TextButton(
                  onPressed: () async {
                    final confirm = await _showClearAllDialog(context);
                    if (confirm == true) {
                      // Clear all notifications
                      for (final notification in notifier.inbox) {
                        await notifier.deleteNotification(notification.id);
                      }
                    }
                  },
                  child: Text(
                    'Padam Semua',
                    style: TextStyle(
                      color: AppTheme.textLightColor.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, notifier, _) {
          final notifications = notifier.inbox;

          if (notifier.isLoading && notifications.isEmpty) {
            return _buildLoadingState();
          }

          if (notifier.error != null && notifications.isEmpty) {
            return _buildErrorState(notifier.error!, context);
          }

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.primaryColor,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return AnimatedContainer(
                  duration: Duration(milliseconds: 200 + (index * 50)),
                  curve: Curves.easeOutBack,
                  child: _buildNotificationCard(item, notifier, context),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryColor),
          SizedBox(height: 16),
          Text(
            'Memuat notifikasi...',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: PhosphorIcon(
                PhosphorIcons.warning(),
                size: 64,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ralat Memuat Notifikasi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: PhosphorIcon(
                PhosphorIcons.arrowClockwise(),
                color: AppTheme.textLightColor,
                size: 18,
              ),
              label: const Text('Cuba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textLightColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: PhosphorIcon(
                  PhosphorIcons.bellSlash(),
                  size: 64,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tiada Notifikasi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Anda belum menerima sebarang notifikasi. Semua notifikasi akan dipaparkan di sini.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    dynamic item,
    NotificationsProvider notifier,
    BuildContext context,
  ) {
    final isRead = item.readAt != null;
    final title = item.title;
    final body = item.body;
    final createdAt = item.deliveredAt;
    final notificationType = item.type;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(PhosphorIcons.trash(), color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              'Padam',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) => _showDeleteDialog(context),
      onDismissed: (_) async {
        await notifier.deleteNotification(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.checkCircle(),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Notifikasi dipadam'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isRead
              ? AppTheme.surfaceColor
              : AppTheme.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? AppTheme.borderColor
                : AppTheme.primaryColor.withOpacity(0.3),
            width: isRead ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isRead ? 0.05 : 0.08),
              blurRadius: isRead ? 8 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              if (!isRead) {
                await notifier.markAsRead(item.id);
              }
              // Handle notification tap action
              _handleNotificationTap(item, context);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getNotificationColor(
                        notificationType,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        _getNotificationIcon(notificationType),
                        color: _getNotificationColor(notificationType),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontWeight: isRead
                                          ? FontWeight.w600
                                          : FontWeight.w700,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          body,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondaryColor,
                                height: 1.4,
                              ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              timeago.format(createdAt, locale: 'ms'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            if (!isRead)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Baru',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'email':
        return PhosphorIcons.envelope();
      case 'push':
        return PhosphorIcons.bell();
      case 'announcement':
        return PhosphorIcons.megaphone();
      case 'update':
        return PhosphorIcons.downloadSimple();
      case 'promotion':
        return PhosphorIcons.gift();
      case 'reminder':
        return PhosphorIcons.clock();
      case 'system':
        return PhosphorIcons.gear();
      default:
        return PhosphorIcons.bellRinging();
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'email':
        return Colors.blue;
      case 'push':
        return AppTheme.primaryColor;
      case 'announcement':
        return Colors.orange;
      case 'update':
        return Colors.green;
      case 'promotion':
        return Colors.purple;
      case 'reminder':
        return Colors.amber;
      case 'system':
        return Colors.grey;
      default:
        return AppTheme.primaryColor;
    }
  }

  void _handleNotificationTap(dynamic item, BuildContext context) {
    // Handle notification tap based on type or data
    final data = item.data;
    if (data != null && data['action_url'] != null) {
      // Navigate to specific URL or screen
      // context.push(data['action_url']);
    }
  }

  Future<bool?> _showDeleteDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.trash(),
              color: AppTheme.errorColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('Padam Notifikasi?'),
          ],
        ),
        content: const Text(
          'Anda pasti mahu memadamkan notifikasi ini? Tindakan ini tidak boleh dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Padam'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showClearAllDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.trash(),
              color: AppTheme.errorColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('Padam Semua?'),
          ],
        ),
        content: const Text(
          'Anda pasti mahu memadamkan semua notifikasi? Tindakan ini tidak boleh dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Padam Semua'),
          ),
        ],
      ),
    );
  }
}
