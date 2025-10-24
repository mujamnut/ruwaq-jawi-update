import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/notifications_provider.dart';
import '../../../../core/models/user_notification.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../student/screens/notification_screen/widgets/notification_detail_bottom_sheet.dart';

class AdminNotificationInboxScreen extends StatefulWidget {
  const AdminNotificationInboxScreen({super.key});

  @override
  State<AdminNotificationInboxScreen> createState() => _AdminNotificationInboxScreenState();
}

class _AdminNotificationInboxScreenState extends State<AdminNotificationInboxScreen> {
  // Filter
  String _activeFilter = 'all'; // all, unread, high, content, payment, announcement

  // Selection mode
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  // Pagination
  final ScrollController _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<NotificationsProvider>();
      await provider.loadInbox();
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
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppTheme.backgroundColor,
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
            : IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  color: AppTheme.textPrimaryColor,
                ),
                onPressed: () => context.go('/admin'),
              ),
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
                      if (confirm == true && mounted) {
                        final provider = context.read<NotificationsProvider>();
                        for (final id in _selectedIds.toList()) {
                          await provider.deleteNotification(id);
                        }
                        if (mounted) {
                          setState(() {
                            _selectionMode = false;
                            _selectedIds.clear();
                          });
                        }
                      }
                    },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    super.dispose();
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
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedNotificationOff01,
                  size: 64,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tiada notifikasi untuk penapis ini',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cuba ubah penapis untuk melihat notifikasi lain.',
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
    final hasMore = provider.hasMore;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        controller: _listController,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        itemCount: grouped.length + (hasMore || provider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= grouped.length) {
            // Load More button or loading indicator
            if (provider.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              );
            }

            if (hasMore) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: OutlinedButton(
                  onPressed: () => provider.loadMore(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowDown01,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Muat lebih banyak',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          }

          final group = grouped[index];
          return _buildDateGroupCard(group, provider);
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
              const HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
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
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedNotificationOff01,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      onSelected: (_) => setState(() => _activeFilter = key),
    );
  }

  Widget _buildDateGroupCard(_DateGroup group, NotificationsProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                group.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
              ),
            ),
            // Notification items with dividers
            ...List.generate(
              group.items.length * 2 - 1,
              (index) {
                if (index.isOdd) {
                  // Divider
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppTheme.borderColor.withValues(alpha: 0.5),
                    ),
                  );
                } else {
                  // Notification item
                  final itemIndex = index ~/ 2;
                  final notification = group.items[itemIndex];
                  return _buildNotificationItem(notification, provider);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    UserNotificationItem notification,
    NotificationsProvider provider,
  ) {
    final user = Supabase.instance.client.auth.currentUser;
    final isRead = user != null ? notification.isReadByUser(user.id) : true;

    final title = notification.title;
    final body = notification.body;
    final createdAt = notification.deliveredAt;
    final isSelected = _selectedIds.contains(notification.id);

    return Material(
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
          HapticFeedback.lightImpact();
          _showNotificationDetail(notification, provider);
        },
        onLongPress: () {
          setState(() {
            _selectionMode = true;
            _selectedIds.add(notification.id);
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with Time on same row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                            color: AppTheme.textPrimaryColor,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      Text(
                        _formatTime(createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                      if (_selectionMode)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            size: 18,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Body
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      height: 1.4,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
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
        provider.markAsUnreadLocal(notification.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedEye,
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
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
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
                  onPressed: () {},
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
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedAlert02,
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
    );
  }

  String _formatTime(DateTime dateTime) {
    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';

    // Convert to 12-hour format
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }

    return '$hour:$minute $period';
  }

  Future<bool?> _showDeleteDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedDelete02,
              color: AppTheme.errorColor,
              size: 24,
            ),
            SizedBox(width: 12),
            Text('Padam Notifikasi?'),
          ],
        ),
        content: const Text(
          'Anda pasti mahu memadamkan notifikasi ini? Tindakan ini tidak boleh dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
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
}

// Helpers
extension on _AdminNotificationInboxScreenState {
  List<UserNotificationItem> _applyFilterAndSearch(NotificationsProvider provider) {
    var items = provider.inbox;
    final user = Supabase.instance.client.auth.currentUser;

    // Filter by type/state
    items = items.where((n) {
      final type = n.type.toLowerCase();
      switch (_activeFilter) {
        case 'unread':
          return user != null ? !n.isReadByUser(user.id) : true;
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

    // Sort by date
    items.sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));

    return items;
  }

  List<_DateGroup> _groupByDate(List<UserNotificationItem> list) {
    final groups = <_DateGroup>[];
    DateTime? currentDate;
    List<UserNotificationItem> currentItems = [];

    for (final n in list) {
      final notifDate = DateUtils.dateOnly(n.deliveredAt);

      if (currentDate == null || notifDate != currentDate) {
        // Save previous group if exists
        if (currentDate != null && currentItems.isNotEmpty) {
          final label = _formatDateHeader(currentDate);
          groups.add(_DateGroup(label, List.from(currentItems)));
        }
        currentDate = notifDate;
        currentItems = [n];
      } else {
        currentItems.add(n);
      }
    }

    // Add last group
    if (currentDate != null && currentItems.isNotEmpty) {
      final label = _formatDateHeader(currentDate);
      groups.add(_DateGroup(label, currentItems));
    }

    return groups;
  }

  String _formatDateHeader(DateTime date) {
    final months = [
      'Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun',
      'Julai', 'Ogos', 'September', 'Oktober', 'November', 'Disember'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _DateGroup {
  final String title;
  final List<UserNotificationItem> items;
  _DateGroup(this.title, this.items);
}
