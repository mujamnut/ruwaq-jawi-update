import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/models/user_notification.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/enhanced_notification_service.dart';
import 'notification_screen/widgets/notification_detail_bottom_sheet.dart';
import 'notification_screen/utils/notification_ui_utils.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Search & filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeFilter = 'all'; // all, unread, high, content, payment, announcement

  // Selection mode
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  // Pagination
  final ScrollController _listController = ScrollController();
  @override
  void initState() {
    super.initState();
    // Load notifications using the unified provider
    // ✅ IMPROVED: Don't auto mark as read - let user control
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<NotificationsProvider>();
      await provider.loadInbox();
    });
    _listController.addListener(() {
      if (!_listController.hasClients) return;
      final max = _listController.position.maxScrollExtent;
      final offset = _listController.position.pixels;
      if (max - offset < 200) {
        context.read<NotificationsProvider>().loadMore();
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
        title: _selectionMode
            ? Text('${_selectedIds.length} dipilih')
            : const Text('Notifikasi'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectionMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.mark_email_read_outlined),
              tooltip: 'Tandai dibaca',
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () async {
                      final provider = context.read<NotificationsProvider>();
                      for (final id in _selectedIds.toList()) {
                        await provider.markAsRead(id);
                      }
                      setState(() {
                        _selectionMode = false;
                        _selectedIds.clear();
                      });
                    },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Padam',
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () async {
                      final confirm = await _showDeleteDialog(context);
                      if (confirm == true) {
                        final provider = context.read<NotificationsProvider>();
                        for (final id in _selectedIds.toList()) {
                          await provider.deleteNotification(id);
                        }
                        setState(() {
                          _selectionMode = false;
                          _selectedIds.clear();
                        });
                      }
                    },
            ),
          ] else ...[
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
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari notifikasi...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderColor),
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Semua', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Belum Baca', 'unread'),
                const SizedBox(width: 8),
                _buildFilterChip('Penting', 'high'),
                const SizedBox(width: 8),
                _buildFilterChip('Kandungan', 'content'),
                const SizedBox(width: 8),
                _buildFilterChip('Pembayaran', 'payment'),
                const SizedBox(width: 8),
                _buildFilterChip('Pengumuman', 'announcement'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer<NotificationsProvider>(
              builder: (context, notificationProvider, child) {
                return _buildNotificationsBody(notificationProvider);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _listController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSwipeBackground({
    required bool alignLeft,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          PhosphorIcon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllAsRead(NotificationsProvider provider) async {
    try {
      final success = await EnhancedNotificationService.markAllAsRead();
      if (!mounted) return;
      if (success) {
        await provider.loadInbox();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Semua notifikasi ditandakan sebagai dibaca'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;
        final unreadNotifications = provider.inbox.where((n) => !n.isReadByUser(user.id)).toList();
        for (final notification in unreadNotifications) {
          await provider.markAsRead(notification.id);
        }
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

    final filtered = _applyFilterAndSearch(provider);
    if (filtered.isEmpty) {
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
                  PhosphorIcons.bell(),
                  size: 64,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tiada notifikasi untuk penapis/carian',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cuba ubah penapis atau padam carian.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final grouped = _groupByDate(filtered);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        controller: _listController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: grouped.length + (provider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= grouped.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            );
          }

          final item = grouped[index];
          if (item is _Header) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
              ),
            );
          } else if (item is UserNotificationItem) {
            final idx = index;
            return AnimatedContainer(
              duration: Duration(milliseconds: 120 + ((idx % 10) * 15)),
              curve: Curves.easeOut,
              child: _buildNotificationCard(item, provider),
            );
          }
          return const SizedBox.shrink();
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

  Widget _buildFilterChip(String label, String key) {
    final selected = _activeFilter == key;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textPrimaryColor,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: AppTheme.primaryColor,
      onSelected: (_) => setState(() => _activeFilter = key),
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
    final isSelected = _selectedIds.contains(notification.id);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(
        alignLeft: true,
        color: isRead ? Colors.amber : AppTheme.primaryColor,
        icon: isRead ? PhosphorIcons.eye() : PhosphorIcons.check(),
        label: isRead ? 'Belum Baca' : 'Tandai Baca',
      ),
      secondaryBackground: _buildSwipeBackground(
        alignLeft: false,
        color: AppTheme.errorColor,
        icon: PhosphorIcons.trash(),
        label: 'Padam',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe kanan: toggle read/unread
          if (isRead) {
            context.read<NotificationsProvider>().markAsUnreadLocal(notification.id);
          } else {
            await context.read<NotificationsProvider>().markAsRead(notification.id);
          }
          return false;
        } else {
          final confirm = await _showDeleteDialog(context);
          return confirm == true;
        }
      },
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
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : (isRead
                  ? AppTheme.surfaceColor
                  : AppTheme.primaryColor.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isRead
                    ? AppTheme.borderColor
                    : AppTheme.primaryColor.withValues(alpha: 0.3)),
            width: isSelected ? 2 : (isRead ? 1 : 2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: (isSelected || !isRead) ? 0.08 : 0.05),
              blurRadius: (isSelected || !isRead) ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_selectionMode) {
                setState(() {
                  final isSelected = _selectedIds.contains(notification.id);
                  if (isSelected) {
                    _selectedIds.remove(notification.id);
                    if (_selectedIds.isEmpty) _selectionMode = false;
                  } else {
                    _selectedIds.add(notification.id);
                  }
                });
                return;
              }
              // ✅ IMPROVED: Show bottom sheet instead of auto navigate
              HapticFeedback.lightImpact();
              _showNotificationDetail(notification, provider);
            },
            onLongPress: () {
              setState(() {
                _selectionMode = true;
                _selectedIds.add(notification.id);
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification Icon - reduced size
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: notificationColorForType(
                        notificationType,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        notificationIconForType(notificationType),
                        color: notificationColorForType(notificationType),
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
                            if (_selectionMode)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondaryColor,
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
                          maxLines: 2,  // ✅ IMPROVED: Reduced to 2 lines - less clutter
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        // ✅ IMPROVED: Simplified metadata row - removed redundant buttons
                        Row(
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
                            const Spacer(),
                            // Simple tap indicator
                            PhosphorIcon(
                              PhosphorIcons.caretRight(),
                              size: 16,
                              color: AppTheme.textSecondaryColor,
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

  /// ✅ NEW: Show notification detail in bottom sheet
  Future<void> _showNotificationDetail(
    UserNotificationItem notification,
    NotificationsProvider provider,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final isRead = notification.isReadByUser(user.id);

    await NotificationDetailBottomSheet.show(
      context: context,
      notification: notification,
      isRead: isRead,
      onMarkAsRead: () async {
        await provider.markAsRead(notification.id);
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
                  const Text('Ditandakan sebagai dibaca'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      onMarkAsUnread: () async {
        // Local-only toggle to unread for now
        provider.markAsUnreadLocal(notification.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.eye(),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text('Ditandakan sebagai belum dibaca'),
                ],
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      onDelete: () async {
        try {
          await provider.deleteNotification(notification.id);
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
                duration: const Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                action: SnackBarAction(
                  label: 'Batal',
                  textColor: Colors.white,
                  onPressed: () {
                    // TODO: Implement undo delete
                  },
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
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
      onNavigate: (context) {
        // Reuse existing navigation logic
        _handleNotificationTap(notification, context);
      },
    );
  }

  IconData _getNotificationIcon(String type) => notificationIconForType(type);

  Color _getNotificationColor(String type) => notificationColorForType(type);

  String _formatTimeAgo(DateTime dateTime) => formatTimeAgoShort(dateTime);

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
              context.go('/player/$kitabId?episode=$episodeParam');
            } else {
              context.go('/player/$kitabId');
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

// Helpers
List<UserNotificationItem> _applyFilterAndSearchStatic(
  List<UserNotificationItem> list,
  String activeFilter,
  String query,
) {
  var items = list;

  // Filter by type/state
  items = items.where((n) {
    final type = n.type.toLowerCase();
    switch (activeFilter) {
      case 'unread':
        // Unread resolved at runtime in state-specific helper
        return true;
      case 'high':
        return n.isHighPriority;
      case 'content':
        return type.contains('content');
      case 'payment':
        return type.contains('payment') || n.isPaymentNotification;
      case 'announcement':
        return n.isAdminAnnouncement;
      default:
        return true;
    }
  }).toList();

  // Search text
  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    items = items
        .where((n) => n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q))
        .toList();
  }

  // Sort
  items.sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
  return items;
}

extension on _NotificationScreenState {
  List<UserNotificationItem> _applyFilterAndSearch(NotificationsProvider provider) {
    var items = provider.inbox;
    final user = Supabase.instance.client.auth.currentUser;
    items = _applyFilterAndSearchStatic(items, _activeFilter, _searchQuery);
    if (_activeFilter == 'unread' && user != null) {
      items = items.where((n) => !n.isReadByUser(user.id)).toList();
    }
    return items;
  }

  List<dynamic> _groupByDate(List<UserNotificationItem> list) {
    final items = <dynamic>[];
    String? currentHeader;
    String labelFor(DateTime dt) {
      final now = DateTime.now();
      final d = DateUtils.dateOnly(dt);
      final today = DateUtils.dateOnly(now);
      final yesterday = today.subtract(const Duration(days: 1));
      if (d == today) return 'Hari ini';
      if (d == yesterday) return 'Semalam';
      if (now.difference(d).inDays < 7) return 'Minggu ini';
      return 'Lebih lama';
    }

    for (final n in list) {
      final label = labelFor(n.deliveredAt);
      if (label != currentHeader) {
        currentHeader = label;
        items.add(_Header(label));
      }
      items.add(n);
    }
    return items;
  }
}

class _Header {
  final String title;
  _Header(this.title);
}
