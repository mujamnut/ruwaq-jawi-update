import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/services/unified_notification_service.dart';
import '../../../core/theme/app_theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<UnifiedNotification> unifiedNotifications = [];
  bool isLoadingUnified = true;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    // Load unified notifications only
    _loadUnifiedNotifications();
    _loadUnreadCount();
  }

  Future<void> _loadUnifiedNotifications() async {
    setState(() => isLoadingUnified = true);
    try {
      final notifications = await UnifiedNotificationService.getNotifications(limit: 50);
      setState(() {
        unifiedNotifications = notifications;
        isLoadingUnified = false;
      });
    } catch (e) {
      setState(() => isLoadingUnified = false);
      debugPrint('Error loading unified notifications: $e');
    }
  }

  Future<void> _loadUnreadCount() async {
    final count = await UnifiedNotificationService.getUnreadCount();
    setState(() => unreadCount = count);
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadUnifiedNotifications(),
      _loadUnreadCount(),
    ]);
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
          if (unifiedNotifications.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirm = await _showClearAllDialog(context);
                if (confirm == true) {
                  // Clear all unified notifications
                  await UnifiedNotificationService.markAllAsRead();
                  await _loadUnifiedNotifications();
                }
              },
              child: Text(
                'Tandai Semua Dibaca',
                style: TextStyle(
                  color: AppTheme.textLightColor.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _buildUnifiedNotificationsBody(),
    );
  }

  Widget _buildUnifiedNotificationsBody() {
    if (isLoadingUnified && unifiedNotifications.isEmpty) {
      return _buildLoadingState();
    }

    if (unifiedNotifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: unifiedNotifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = unifiedNotifications[index];
          return AnimatedContainer(
            duration: Duration(milliseconds: 200 + (index * 50)),
            curve: Curves.easeOutBack,
            child: _buildUnifiedNotificationCard(item, context),
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

  Widget _buildUnifiedNotificationCard(
    UnifiedNotification item,
    BuildContext context,
  ) {
    // Check if notification is read - simplified logic
    final currentUserId = UnifiedNotificationService.currentUserId;
    final isRead = currentUserId != null ? !item.isUnreadForUser(currentUserId) : true;

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
        // Capture context before async operations
        final scaffoldMessenger = ScaffoldMessenger.of(context);

        // Delete notification using service
        final success = await UnifiedNotificationService.deleteNotification(item.id);

        if (success) {
          // Refresh notifications list to reflect changes
          await _loadUnifiedNotifications();

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
        } else {
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
                await UnifiedNotificationService.markAsRead(item.id);
                // Refresh to update UI
                await _loadUnifiedNotifications();
              }

              // Handle notification tap action
              if (mounted && currentContext.mounted) {
                _handleNotificationTap(item, currentContext);
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
                            Text(
                              _formatTimeAgo(createdAt),
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

  void _handleNotificationTap(UnifiedNotification item, BuildContext context) {
    // Handle notification tap based on action URL
    final actionUrl = item.actionUrl;
    if (actionUrl.isNotEmpty && actionUrl != '/home') {
      // Navigate to specific URL or screen
      // context.push(actionUrl);
      debugPrint('Navigate to: $actionUrl');
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
