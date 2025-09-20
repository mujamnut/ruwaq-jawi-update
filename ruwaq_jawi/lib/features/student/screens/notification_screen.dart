import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/models/user_notification.dart';
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
    // Load notifications using the unified provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<NotificationsProvider>();
      await provider.loadInbox();

      // Auto mark all unread notifications as read when user opens notification tab
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final unreadNotifications = provider.inbox.where((n) => !n.isReadByUser(user.id)).toList();
        for (final notification in unreadNotifications) {
          await provider.markAsRead(notification.id);
        }
      }
    });
  }

  Future<void> _refresh() async {
    await context.read<NotificationsProvider>().loadInbox();
  }

  @override
  Widget build(BuildContext context) {
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
            builder: (context, notificationProvider, child) {
              if (notificationProvider.inbox.isNotEmpty && notificationProvider.unreadCount > 0) {
                return TextButton(
                  onPressed: () async {
                    final confirm = await _showClearAllDialog(context);
                    if (confirm == true) {
                      await _markAllAsRead(notificationProvider);
                    }
                  },
                  child: Text(
                    'Tandai Semua Dibaca',
                    style: TextStyle(
                      color: AppTheme.textLightColor.withValues(alpha: 0.9),
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
        builder: (context, notificationProvider, child) {
          return _buildNotificationsBody(notificationProvider);
        },
      ),
    );
  }

  Future<void> _markAllAsRead(NotificationsProvider provider) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final unreadNotifications = provider.inbox.where((n) => !n.isReadByUser(user.id)).toList();

      for (final notification in unreadNotifications) {
        await provider.markAsRead(notification.id);
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Widget _buildNotificationsBody(NotificationsProvider provider) {
    if (provider.isLoading && provider.inbox.isEmpty) {
      return _buildLoadingState();
    }

    if (provider.error != null) {
      return _buildErrorState(provider);
    }

    if (provider.inbox.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: provider.inbox.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final notification = provider.inbox[index];
          return AnimatedContainer(
            duration: Duration(milliseconds: 200 + (index * 50)),
            curve: Curves.easeOutBack,
            child: _buildNotificationCard(notification, provider),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(NotificationsProvider provider) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                PhosphorIcons.warningCircle(),
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Ralat Memuat Notifikasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                provider.error ?? 'Terdapat masalah semasa memuat notifikasi',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  provider.clearError();
                  _refresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Cuba Lagi'),
              ),
            ],
          ),
        ],
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
    UserNotificationItem notification,
    NotificationsProvider provider,
  ) {
    final user = Supabase.instance.client.auth.currentUser;
    final isRead = user != null ? notification.isReadByUser(user.id) : true;

    final title = notification.title;
    final body = notification.body;
    final createdAt = notification.deliveredAt;
    final notificationType = notification.type;

    return Dismissible(
      key: ValueKey(notification.id),
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
        // Capture context before async operations
        final scaffoldMessenger = ScaffoldMessenger.of(context);

        try {
          // Delete notification using provider
          await provider.deleteNotification(notification.id);

          if (mounted) {
            scaffoldMessenger.showSnackBar(
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
        } catch (e) {
          // Show error if delete failed
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.warningCircle(),
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text('Gagal memadamkan notifikasi'),
                  ],
                ),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isRead
              ? AppTheme.surfaceColor
              : AppTheme.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? AppTheme.borderColor
                : AppTheme.primaryColor.withValues(alpha: 0.3),
            width: isRead ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isRead ? 0.05 : 0.08),
              blurRadius: isRead ? 8 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              // Capture context before async operations
              final currentContext = context;

              if (!isRead) {
                await provider.markAsRead(notification.id);
              }

              // Handle notification tap action
              if (mounted && currentContext.mounted) {
                _handleNotificationTap(notification, currentContext);
              }
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
                      ).withValues(alpha: 0.1),
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
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    _formatTimeAgo(createdAt),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textSecondaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
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
                            ),
                            // Dismiss button
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isRead)
                                  InkWell(
                                    onTap: () async {
                                      await provider.markAsRead(notification.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                PhosphorIcon(PhosphorIcons.checkCircle(), color: Colors.white, size: 20),
                                                const SizedBox(width: 12),
                                                const Text('Ditandakan sebagai dibaca'),
                                              ],
                                            ),
                                            backgroundColor: AppTheme.successColor,
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 2),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: PhosphorIcon(
                                        PhosphorIcons.check(),
                                        size: 16,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () async {
                                    final shouldDelete = await _showDeleteDialog(context);
                                    if (shouldDelete == true) {
                                      await provider.deleteNotification(notification.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                PhosphorIcon(PhosphorIcons.checkCircle(), color: Colors.white, size: 20),
                                                const SizedBox(width: 12),
                                                const Text('Notifikasi dipadam'),
                                              ],
                                            ),
                                            backgroundColor: AppTheme.successColor,
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 2),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: PhosphorIcon(
                                      PhosphorIcons.x(),
                                      size: 16,
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ),
                              ],
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return '${(difference.inDays / 7).floor()} minggu yang lalu';
    }
  }

  Future<void> _handleNotificationTap(UserNotificationItem notification, BuildContext context) async {
    final provider = context.read<NotificationsProvider>();

    try {
      // 1. Mark as read first (auto-dismiss)
      await provider.markAsRead(notification.id);

      // 2. Then navigate based on notification type and action URL
      if (mounted && context.mounted) {
        final actionUrl = notification.actionUrl;
        final notificationType = notification.type.toLowerCase();

        // Handle payment/subscription notifications
        if (notificationType.contains('payment') ||
            notificationType.contains('subscription') ||
            notificationType.contains('purchase') ||
            notification.isPaymentNotification ||
            notification.isSubscriptionNotification) {

          // Navigate to subscription screen for payment-related notifications
          context.go('/subscription');
        }
        // Handle content notifications with actionUrl
        else if (actionUrl != null && actionUrl.isNotEmpty && actionUrl != '/home') {
          if (actionUrl.contains('/player/')) {
            // Content player for full episodes
            final kitabId = actionUrl.split('/player/').last.split('?').first;
            final episodeParam = actionUrl.contains('episode=')
                ? actionUrl.split('episode=').last.split('&').first
                : null;

            if (episodeParam != null) {
              context.go('/player/$kitabId?episode=$episodeParam');
            } else {
              context.go('/player/$kitabId');
            }
          } else if (actionUrl.contains('/video/')) {
            // Video-only player
            final kitabId = actionUrl.split('/video/').last.split('?').first;
            final episodeParam = actionUrl.contains('episode=')
                ? actionUrl.split('episode=').last.split('&').first
                : null;

            if (episodeParam != null) {
              context.go('/video/$kitabId?episode=$episodeParam');
            } else {
              context.go('/video/$kitabId');
            }
          } else if (actionUrl.contains('/ebook/')) {
            // E-book navigation
            final ebookId = actionUrl.split('/ebook/').last;
            context.go('/ebook/$ebookId');
          } else if (actionUrl.contains('/kitab/')) {
            // Kitab detail navigation
            final kitabId = actionUrl.split('/kitab/').last;
            context.go('/kitab/$kitabId');
          } else if (actionUrl.contains('/payment') || actionUrl.contains('/subscription')) {
            // Payment/subscription related notifications
            if (actionUrl.contains('/subscription/detail') || actionUrl.contains('/subscription-detail')) {
              context.go('/subscription-detail');
            } else {
              context.go('/subscription');
            }
          } else {
            // Generic navigation using go_router
            try {
              context.go(actionUrl);
            } catch (e) {
              debugPrint('Navigation error for URL: $actionUrl, Error: $e');
            }
          }
        }
        // For admin announcements or general notifications without specific action
        else if (notification.isAdminAnnouncement) {
          // Stay on notification screen for admin announcements
          debugPrint('Admin announcement notification - staying on notification screen');
        }
      }

      // Show feedback that notification was dismissed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                PhosphorIcon(PhosphorIcons.checkCircle(), color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Text('Notifikasi dibaca'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
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
              PhosphorIcons.checkCircle(),
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('Tandai Semua Dibaca?'),
          ],
        ),
        content: const Text(
          'Anda pasti mahu menandakan semua notifikasi sebagai dibaca?',
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
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Tandai Dibaca'),
          ),
        ],
      ),
    );
  }
}
